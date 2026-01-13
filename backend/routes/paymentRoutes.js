/**
 * Payment Routes
 * Handles Pesapal payment initialization
 */

const express = require('express');
const router = express.Router();
const Joi = require('joi');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const { supabase } = require('../config/supabase');
const { authenticateToken, requireUserType } = require('../middleware/auth');
const { getPesapalToken } = require('../webhooks/pesapalWebhook');

// Validation schema
const initiatePaymentSchema = Joi.object({
    report_id: Joi.string().uuid().required(),
    phone_number: Joi.string().pattern(/^\+256[0-9]{9}$/).required(),
    amount: Joi.number().min(1000).max(1000000).optional() // UGX
});

/**
 * POST /apiPesapal Mobile Money payment
 */
router.post('/initiate', authenticateToken, requireUserType('resident'), async (req, res, next) => {
    try {
        // Validate input
        const { error, value } = initiatePaymentSchema.validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                message: error.details[0].message
            });
        }

        const { report_id, phone_number } = value;

        // Verify report exists and belongs to user
        const { data: report, error: reportError } = await supabase
            .from('garbage_reports')
            .select('*')
            .eq('id', report_id)
            .eq('resident_id', req.user.id)
            .single();

        if (reportError || !report) {
            return res.status(404).json({
                success: false,
                message: 'Report not found'
            });
        }

        // Check if already paid
        const { data: existingPayment } = await supabase
            .from('payments')
            .select('*')
            .eq('report_id', report_id)
            .eq('payment_status', 'successful')
            .single();

        if (existingPayment) {
            return res.status(400).json({
                success: false,
                message: 'Report already paid'
            });
        }

        const amount = value.amount || report.payment_amount;
        const merchantRef = `GFC-${Date.now()}-${uuidv4().slice(0, 8)}`;

        // Create payment record
        const { data: payment, error: paymentError } = await supabase
            .from('payments')
            .insert([{
                report_id,
                resident_id: req.user.id,
                flw_ref: merchantRef, // Using this field for Pesapal reference
                amount,
                currency: 'UGX',
                payment_method: 'mobile_money',
                phone_number,
                payment_status: 'pending',
                initiated_at: new Date().toISOString()
            }])
            .select()
            .single();

        if (paymentError) {
            throw paymentError;
        }

        // Get Pesapal OAuth token
        const token = await getPesapalToken();

        // Initialize Pesapal payment
        const pesapalApiUrl = process.env.PESAPAL_ENVIRONMENT === 'live'
            ? 'https://pay.pesapal.com/v3/api/Transactions/SubmitOrderRequest'
            : 'https://cybqa.pesapal.com/pesapalv3/api/Transactions/SubmitOrderRequest';

        const pesapalResponse = await axios.post(
            pesapalApiUrl,
            {
                id: merchantRef,
                currency: 'UGX',
                amount: amount,
                description: `Garbage collection payment - Report ${report_id}`,
                callback_url: `${process.env.API_BASE_URL}/api/payments/callback`,
                notification_id: process.env.PESAPAL_IPN_URL,
                billing_address: {
                    phone_number: phone_number,
                    email_address: req.user.email || `${phone_number}@gfc.kcca.ug`,
                    country_code: 'UG',
                    first_name: req.user.full_name.split(' ')[0],
                    last_name: req.user.full_name.split(' ').slice(1).join(' ') || 'User'
                }
            },
            {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        res.json({
            success: true,
            message: 'Payment initiated. Please complete on your phone.',
            data: {
                payment_id: payment.id,
                merchant_reference: merchantRef,
                redirect_url: pesapalResponse.data.redirect_url,
                order_tracking_id: pesapalResponse.data.order_tracking_id
            }
        });

    } catch (error) {
        console.error('Payment initiation error:', error.response?.data || error);
        next(error);
    }
});

/**
 * GET /api/payments/status/:txRef
 * Check payment status
 */
router.get('/status/:txRef', authenticateToken, async (req, res, next) => {
    try {
        const { txRef } = req.params;

        const { data: payment, error } = await supabase
            .from('payments')
            .select('*, garbage_reports(*)')
            .eq('flw_ref', txRef)
            .single();

        if (error || !payment) {
            return res.status(404).json({
                success: false,
                message: 'Payment not found'
            });
        }

        res.json({
            success: true,
            data: { payment }
        });

    } catch (error) {
        next(error);
    }
});

module.exports = router;
