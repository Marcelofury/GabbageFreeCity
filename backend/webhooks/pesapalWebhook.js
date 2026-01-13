/**
 * GARBAGE FREE CITY (GFC) - PESAPAL WEBHOOK HANDLER
 * 
 * This module handles incoming IPN (Instant Payment Notification) from Pesapal
 * for Mobile Money payments (MTN and Airtel Money in Uganda).
 * 
 * Key Features:
 * - Handles Pesapal IPN notifications
 * - Updates payment status in Supabase
 * - Sends SMS confirmation via Africa's Talking
 * - Updates garbage report status when payment is successful
 */

const express = require('express');
const crypto = require('crypto');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

/**
 * Get Pesapal OAuth Token
 */
async function getPesapalToken() {
    try {
        const response = await axios.post(
            process.env.PESAPAL_ENVIRONMENT === 'live'
                ? 'https://pay.pesapal.com/v3/api/Auth/RequestToken'
                : 'https://cybqa.pesapal.com/pesapalv3/api/Auth/RequestToken',
            {
                consumer_key: process.env.PESAPAL_CONSUMER_KEY,
                consumer_secret: process.env.PESAPAL_CONSUMER_SECRET
            },
            {
                headers: { 'Content-Type': 'application/json' }
            }
        );

        return response.data.token;
    } catch (error) {
        console.error('❌ Error getting Pesapal token:', error);
        throw error;
    }
}

/**
 * Get transaction status from Pesapal
 */
async function getTransactionStatus(orderTrackingId) {
    try {
        const token = await getPesapalToken();
        
        const response = await axios.get(
            process.env.PESAPAL_ENVIRONMENT === 'live'
                ? `https://pay.pesapal.com/v3/api/Transactions/GetTransactionStatus?orderTrackingId=${orderTrackingId}`
                : `https://cybqa.pesapal.com/pesapalv3/api/Transactions/GetTransactionStatus?orderTrackingId=${orderTrackingId}`,
            {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        return response.data;
    } catch (error) {
        console.error('❌ Error getting transaction status:', error);
        throw error;
    }
}

/**
 * Send SMS notification using Africa's Talking
 */
async function sendSMSNotification(phoneNumber, message) {
    try {
        const credentials = {
            apiKey: process.env.AFRICAS_TALKING_API_KEY,
            username: process.env.AFRICAS_TALKING_USERNAME
        };
        
        const AfricasTalking = require('africastalking')(credentials);
        const sms = AfricasTalking.SMS;
        
        const options = {
            to: [phoneNumber],
            message: message,
            from: 'KCCA-GFC'
        };
        
        const result = await sms.send(options);
        console.log('📱 SMS sent:', result);
        return result;
        
    } catch (error) {
        console.error('❌ SMS Error:', error);
    }
}

/**
 * MAIN WEBHOOK HANDLER (IPN)
 * 
 * Endpoint: GET /webhooks/pesapal
 * 
 * Pesapal sends IPN as GET request with:
 * - OrderTrackingId
 * - OrderMerchantReference
 */
async function handlePesapalIPN(req, res) {
    try {
        const { OrderTrackingId, OrderMerchantReference } = req.query;
        
        console.log('📥 Pesapal IPN received:', {
            OrderTrackingId,
            OrderMerchantReference
        });

        if (!OrderTrackingId || !OrderMerchantReference) {
            return res.status(400).send('Invalid IPN parameters');
        }

        // ============================================
        // STEP 1: GET TRANSACTION STATUS FROM PESAPAL
        // ============================================
        const transaction = await getTransactionStatus(OrderTrackingId);
        
        console.log('📊 Transaction status:', transaction);

        // ============================================
        // STEP 2: MAP PESAPAL STATUS TO OUR STATUS
        // ============================================
        let paymentStatus;
        switch (transaction.payment_status_description) {
            case 'Completed':
                paymentStatus = 'successful';
                break;
            case 'Failed':
                paymentStatus = 'failed';
                break;
            case 'Invalid':
            case 'Reversed':
                paymentStatus = 'cancelled';
                break;
            default:
                paymentStatus = 'processing';
        }

        // ============================================
        // STEP 3: UPDATE PAYMENT IN DATABASE
        // ============================================
        const { data: payment, error: paymentError } = await supabase
            .from('payments')
            .update({
                transaction_id: OrderTrackingId,
                payment_status: paymentStatus,
                webhook_response: transaction,
                completed_at: paymentStatus === 'successful' ? new Date().toISOString() : null,
                updated_at: new Date().toISOString()
            })
            .eq('flw_ref', OrderMerchantReference) // We'll use this field for Pesapal reference too
            .select('*, garbage_reports(id, resident_id, status)')
            .single();

        if (paymentError) {
            console.error('❌ Database error:', paymentError);
            return res.status(200).send('OK'); // Still return OK to Pesapal
        }

        console.log('💾 Payment updated:', payment.id);

        // ============================================
        // STEP 4: UPDATE GARBAGE REPORT STATUS
        // ============================================
        if (paymentStatus === 'successful' && payment.report_id) {
            const { error: reportError } = await supabase
                .from('garbage_reports')
                .update({
                    status: 'pending',
                    updated_at: new Date().toISOString()
                })
                .eq('id', payment.report_id);

            if (reportError) {
                console.error('❌ Failed to update report:', reportError);
            } else {
                console.log('📋 Garbage report status updated to pending');
            }
        }

        // ============================================
        // STEP 5: SEND SMS CONFIRMATION
        // ============================================
        if (paymentStatus === 'successful') {
            const { data: resident } = await supabase
                .from('users')
                .select('phone_number, full_name')
                .eq('id', payment.resident_id)
                .single();

            if (resident) {
                const message = `Webale nyo ${resident.full_name}! Your payment of UGX ${transaction.amount.toLocaleString()} for garbage collection has been received. A collector will be assigned soon. -KCCA GFC`;
                await sendSMSNotification(resident.phone_number, message);
            }
        } else if (paymentStatus === 'failed') {
            const { data: resident } = await supabase
                .from('users')
                .select('phone_number, full_name')
                .eq('id', payment.resident_id)
                .single();

            if (resident) {
                const message = `Sorry ${resident.full_name}, your payment of UGX ${transaction.amount} failed. Please try again or contact KCCA support. -KCCA GFC`;
                await sendSMSNotification(resident.phone_number, message);
            }
        }

        // ============================================
        // STEP 6: RESPOND TO PESAPAL
        // ============================================
        // Pesapal expects simple "OK" response
        return res.status(200).send('OK');

    } catch (error) {
        console.error('❌ Pesapal IPN processing error:', error);
        return res.status(200).send('OK'); // Still return OK to avoid retries
    }
}

/**
 * EXPORT ROUTE CONFIGURATION
 */
const router = express.Router();

// Pesapal IPN endpoint (GET request)
router.get('/pesapal', handlePesapalIPN);

module.exports = {
    router,
    handlePesapalIPN,
    getPesapalToken
};

/**
 * ============================================
 * USAGE EXAMPLE IN YOUR MAIN APP (server.js)
 * ============================================
 * 
 * const pesapalWebhook = require('./webhooks/pesapalWebhook');
 * app.use('/webhooks', pesapalWebhook.router);
 * 
 * ============================================
 * ENVIRONMENT VARIABLES REQUIRED (.env)
 * ============================================
 * 
 * PESAPAL_CONSUMER_KEY=your-consumer-key
 * PESAPAL_CONSUMER_SECRET=your-consumer-secret
 * PESAPAL_ENVIRONMENT=sandbox (or 'live')
 * 
 * ============================================
 * PESAPAL IPN CONFIGURATION
 * ============================================
 * 
 * 1. Register IPN URL in Pesapal dashboard
 * 2. IPN URL: https://your-domain.com/webhooks/pesapal
 * 3. Pesapal will send GET requests to this URL
 * 
 * ============================================
 * TESTING LOCALLY WITH NGROK
 * ============================================
 * 
 * 1. Start server: node server.js
 * 2. Start ngrok: ngrok http 3000
 * 3. Register IPN: https://abc123.ngrok.io/webhooks/pesapal
 * 4. Make test payment and watch logs
 */
