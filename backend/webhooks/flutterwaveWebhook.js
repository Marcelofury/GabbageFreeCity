/**
 * GARBAGE FREE CITY (GFC) - FLUTTERWAVE WEBHOOK HANDLER
 * 
 * This module handles incoming webhook notifications from Flutterwave
 * for Mobile Money payments (MTN and Airtel Money in Uganda).
 * 
 * Key Features:
 * - Verifies webhook signature using Flutterwave secret hash
 * - Updates payment status in Supabase
 * - Sends SMS confirmation via Africa's Talking
 * - Updates garbage report status when payment is successful
 * 
 * Security: Always verify the webhook signature to prevent spoofing
 */

const express = require('express');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY // Use service key for admin operations
);

/**
 * Verify Flutterwave webhook signature
 * 
 * Flutterwave sends a signature in the 'verif-hash' header.
 * We must verify this matches our secret hash to ensure the webhook is authentic.
 * 
 * @param {string} signature - The signature from request header
 * @returns {boolean} - True if signature is valid
 */
function verifyFlutterwaveSignature(signature) {
    const secretHash = process.env.FLUTTERWAVE_SECRET_HASH;
    
    if (!secretHash) {
        console.error('⚠️ FLUTTERWAVE_SECRET_HASH not configured!');
        return false;
    }
    
    return signature === secretHash;
}

/**
 * Send SMS notification using Africa's Talking
 * 
 * @param {string} phoneNumber - Recipient phone number (+256...)
 * @param {string} message - SMS message content
 */
async function sendSMSNotification(phoneNumber, message) {
    try {
        // Initialize Africa's Talking (do this once in your app initialization)
        const credentials = {
            apiKey: process.env.AFRICAS_TALKING_API_KEY,
            username: process.env.AFRICAS_TALKING_USERNAME // e.g., 'KCCA' or 'sandbox'
        };
        
        const AfricasTalking = require('africastalking')(credentials);
        const sms = AfricasTalking.SMS;
        
        const options = {
            to: [phoneNumber],
            message: message,
            from: 'KCCA-GFC' // Your approved sender ID
        };
        
        const result = await sms.send(options);
        console.log('📱 SMS sent:', result);
        return result;
        
    } catch (error) {
        console.error('❌ SMS Error:', error);
        // Don't throw - SMS failure shouldn't break payment processing
    }
}

/**
 * MAIN WEBHOOK HANDLER
 * 
 * Endpoint: POST /webhooks/flutterwave
 * 
 * This receives payment notifications from Flutterwave and:
 * 1. Verifies the webhook signature
 * 2. Updates payment status in database
 * 3. Updates garbage report status if payment successful
 * 4. Sends SMS confirmation to resident
 */
async function handleFlutterwaveWebhook(req, res) {
    try {
        // ============================================
        // STEP 1: VERIFY WEBHOOK SIGNATURE
        // ============================================
        const signature = req.headers['verif-hash'];
        
        if (!verifyFlutterwaveSignature(signature)) {
            console.error('❌ Invalid webhook signature');
            return res.status(401).json({
                success: false,
                message: 'Invalid signature'
            });
        }
        
        console.log('✅ Webhook signature verified');
        
        // ============================================
        // STEP 2: EXTRACT PAYMENT DATA
        // ============================================
        const payload = req.body;
        
        // Flutterwave webhook payload structure
        const {
            event, // e.g., 'charge.completed'
            data: {
                id: transactionId,
                tx_ref: flwRef, // Our custom reference
                amount,
                currency,
                status, // successful, failed, cancelled
                customer: {
                    phone_number: customerPhone,
                    name: customerName
                },
                payment_type // mobilemoneyuganda, card, etc.
            }
        } = payload;
        
        console.log('📥 Webhook received:', {
            event,
            transactionId,
            flwRef,
            status,
            amount
        });
        
        // ============================================
        // STEP 3: UPDATE PAYMENT IN DATABASE
        // ============================================
        
        // Map Flutterwave status to our payment_status
        let paymentStatus;
        switch (status) {
            case 'successful':
                paymentStatus = 'successful';
                break;
            case 'failed':
                paymentStatus = 'failed';
                break;
            case 'cancelled':
                paymentStatus = 'cancelled';
                break;
            default:
                paymentStatus = 'processing';
        }
        
        // Update payment record
        const { data: payment, error: paymentError } = await supabase
            .from('payments')
            .update({
                transaction_id: transactionId,
                payment_status: paymentStatus,
                webhook_response: payload, // Store full webhook data
                completed_at: status === 'successful' ? new Date().toISOString() : null,
                updated_at: new Date().toISOString()
            })
            .eq('flw_ref', flwRef)
            .select('*, garbage_reports(id, resident_id, status)')
            .single();
        
        if (paymentError) {
            console.error('❌ Database error:', paymentError);
            // Still return 200 to Flutterwave to avoid retries
            return res.status(200).json({
                success: false,
                message: 'Payment record not found'
            });
        }
        
        console.log('💾 Payment updated:', payment.id);
        
        // ============================================
        // STEP 4: UPDATE GARBAGE REPORT STATUS
        // ============================================
        
        if (paymentStatus === 'successful' && payment.report_id) {
            const { error: reportError } = await supabase
                .from('garbage_reports')
                .update({
                    status: 'pending', // Ready for assignment to collector
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
            // Get resident phone number
            const { data: resident } = await supabase
                .from('users')
                .select('phone_number, full_name')
                .eq('id', payment.resident_id)
                .single();
            
            if (resident) {
                const message = `Webale nyo ${resident.full_name}! Your payment of UGX ${amount.toLocaleString()} for garbage collection has been received. A collector will be assigned soon. -KCCA GFC`;
                
                await sendSMSNotification(resident.phone_number, message);
            }
        } else if (paymentStatus === 'failed') {
            // Notify about failed payment
            const { data: resident } = await supabase
                .from('users')
                .select('phone_number, full_name')
                .eq('id', payment.resident_id)
                .single();
            
            if (resident) {
                const message = `Sorry ${resident.full_name}, your payment of UGX ${amount} failed. Please try again or contact KCCA support. -KCCA GFC`;
                
                await sendSMSNotification(resident.phone_number, message);
            }
        }
        
        // ============================================
        // STEP 6: RESPOND TO FLUTTERWAVE
        // ============================================
        
        // Always return 200 OK to Flutterwave to stop retries
        return res.status(200).json({
            success: true,
            message: 'Webhook processed successfully',
            paymentStatus
        });
        
    } catch (error) {
        console.error('❌ Webhook processing error:', error);
        
        // Still return 200 to avoid Flutterwave retries
        // Log the error for investigation
        return res.status(200).json({
            success: false,
            message: 'Error processing webhook',
            error: error.message
        });
    }
}

/**
 * EXPORT ROUTE CONFIGURATION
 * 
 * Use this in your Express app:
 * 
 * const flutterwaveWebhook = require('./webhooks/flutterwaveWebhook');
 * app.use('/webhooks', flutterwaveWebhook.router);
 */

const router = express.Router();

// IMPORTANT: Use express.json() middleware but preserve raw body for verification
// Flutterwave doesn't use HMAC signature, just a secret hash comparison
router.post('/flutterwave',
    express.json(),
    handleFlutterwaveWebhook
);

module.exports = {
    router,
    handleFlutterwaveWebhook // Export for testing
};

/**
 * ============================================
 * USAGE EXAMPLE IN YOUR MAIN APP (server.js)
 * ============================================
 * 
 * const express = require('express');
 * const flutterwaveWebhook = require('./webhooks/flutterwaveWebhook');
 * 
 * const app = express();
 * 
 * // Mount webhook routes
 * app.use('/webhooks', flutterwaveWebhook.router);
 * 
 * // Your other routes...
 * 
 * const PORT = process.env.PORT || 3000;
 * app.listen(PORT, () => {
 *     console.log(`🚀 GFC Backend running on port ${PORT}`);
 * });
 * 
 * ============================================
 * ENVIRONMENT VARIABLES REQUIRED (.env)
 * ============================================
 * 
 * # Supabase
 * SUPABASE_URL=https://your-project.supabase.co
 * SUPABASE_SERVICE_KEY=your-service-role-key
 * 
 * # Flutterwave
 * FLUTTERWAVE_SECRET_HASH=your-secret-hash
 * FLUTTERWAVE_PUBLIC_KEY=FLWPUBK-xxxxx
 * FLUTTERWAVE_SECRET_KEY=FLWSECK-xxxxx
 * 
 * # Africa's Talking
 * AFRICAS_TALKING_API_KEY=your-api-key
 * AFRICAS_TALKING_USERNAME=KCCA (or sandbox)
 * 
 * ============================================
 * FLUTTERWAVE WEBHOOK CONFIGURATION
 * ============================================
 * 
 * 1. Go to: https://dashboard.flutterwave.com/dashboard/settings/webhooks
 * 2. Add webhook URL: https://your-domain.com/webhooks/flutterwave
 * 3. Set secret hash (save in .env as FLUTTERWAVE_SECRET_HASH)
 * 4. Enable events: charge.completed
 * 
 * ============================================
 * TESTING LOCALLY WITH NGROK
 * ============================================
 * 
 * 1. Install ngrok: npm install -g ngrok
 * 2. Start your server: node server.js
 * 3. In another terminal: ngrok http 3000
 * 4. Copy the https URL (e.g., https://abc123.ngrok.io)
 * 5. Add to Flutterwave: https://abc123.ngrok.io/webhooks/flutterwave
 * 6. Make a test payment and watch your console logs
 * 
 * ============================================
 * UGANDAN MOBILE MONEY NOTES
 * ============================================
 * 
 * - MTN Mobile Money: Most widely used in Uganda
 * - Airtel Money: Second most popular
 * - Flutterwave payment_type will be 'mobilemoneyuganda'
 * - Typical transaction: UGX 5,000 - 50,000 for waste collection
 * - Users familiar with *165# (MTN) and *185# (Airtel) USSD codes
 * 
 */
