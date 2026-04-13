const Joi = require('joi');
const { randomUUID } = require('crypto');
const marzpayService = require('../services/marzpayService');
const { supabase } = require('../config/supabase');
const { createNotification } = require('../services/notificationService');

const MIN_AMOUNT = Number(process.env.MARZPAY_MIN_AMOUNT || 20);
const MAX_AMOUNT = 10000000;

const initiatePaymentSchema = Joi.object({
    orderId: Joi.string().uuid().required(),
    method: Joi.string().required(),
    phone: Joi.string().required(),
});

const validatePhoneSchema = Joi.object({
    phone: Joi.string().required(),
});

function mapMarzPayStatus(status) {
    const normalized = String(status || '').toLowerCase();

    if (['successful', 'completed'].includes(normalized)) {
        return 'completed';
    }

    if (['failed', 'cancelled'].includes(normalized)) {
        return 'failed';
    }

    if (['pending', 'processing'].includes(normalized)) {
        return 'pending';
    }

    return 'pending';
}

function toPaymentStatus(orderPaymentStatus) {
    if (orderPaymentStatus === 'completed') {
        return 'successful';
    }

    if (orderPaymentStatus === 'failed') {
        return 'failed';
    }

    return 'pending';
}

function extractCallbackFields(payload) {
    const root = payload || {};
    const data = root.data || {};

    const transactionRef =
        root.reference ||
        root.transactionRef ||
        root.transaction_ref ||
        data.reference ||
        data.transactionRef ||
        data.transaction_ref;

    const providerRef =
        root.providerRef ||
        root.provider_reference ||
        root.providerReference ||
        data.providerRef ||
        data.provider_reference ||
        data.providerReference ||
        null;

    const providerStatus =
        root.status ||
        root.transactionStatus ||
        root.transaction_status ||
        data.status ||
        data.transactionStatus ||
        data.transaction_status ||
        'pending';

    return { transactionRef, providerRef, providerStatus };
}

async function initiatePayment(req, res, next) {
    try {
        const { error, value } = initiatePaymentSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ success: false, message: error.details[0].message });
        }

        const method = String(value.method || '').toLowerCase();
        if (!method.includes('marzpay')) {
            return res.status(400).json({ success: false, message: 'Unsupported payment method. Use marzpay.' });
        }

        const formattedPhone = marzpayService.formatPhoneNumber(value.phone);
        const phoneValidation = marzpayService.validateMobileNumber(value.phone);

        if (!phoneValidation.valid || !formattedPhone || formattedPhone.length !== 13) {
            return res.status(400).json({
                success: false,
                message: phoneValidation.message,
            });
        }

        if (!['MTN', 'AIRTEL'].includes(phoneValidation.provider)) {
            return res.status(400).json({
                success: false,
                message: 'Unsupported mobile provider. Use MTN or Airtel Uganda numbers.',
            });
        }

        const { data: order, error: orderError } = await supabase
            .from('garbage_reports')
            .select('*')
            .eq('id', value.orderId)
            .eq('resident_id', req.user.id)
            .single();

        if (orderError || !order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        const amount = Number(order.payment_amount);
        if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > MAX_AMOUNT) {
            return res.status(400).json({
                success: false,
                message: `Amount must be between ${MIN_AMOUNT} and ${MAX_AMOUNT} UGX`,
            });
        }

        const { data: existingSuccessful } = await supabase
            .from('payments')
            .select('id')
            .eq('report_id', value.orderId)
            .eq('payment_status', 'successful')
            .maybeSingle();

        if (existingSuccessful) {
            return res.status(409).json({ success: false, message: 'Order is already paid' });
        }

        const transactionRef = randomUUID();
        const callbackBase = process.env.APP_BASE_URL || process.env.API_BASE_URL;
        const callbackUrl =
            process.env.MARZPAY_CALLBACK_URL ||
            (callbackBase ? `${callbackBase}/api/payments/marzpay/callback` : undefined);

        const marzResponse = await marzpayService.collectMoney({
            reference: transactionRef,
            phoneNumber: formattedPhone,
            country: 'UG',
            amount,
            description: `Order #${value.orderId} payment`,
            callbackUrl,
        });

        const providerRef =
            marzResponse?.data?.transaction?.provider_reference ||
            marzResponse?.data?.providerRef ||
            marzResponse?.data?.provider_reference ||
            marzResponse?.data?.providerReference ||
            marzResponse?.data?.transaction?.reference ||
            marzResponse?.data?.reference ||
            null;

        const providerStatus =
            marzResponse?.data?.transaction?.status ||
            marzResponse?.data?.status ||
            marzResponse?.status ||
            'pending';
        const orderPaymentStatus = mapMarzPayStatus(providerStatus);
        const paymentStatus = toPaymentStatus(orderPaymentStatus);

        const { error: paymentError } = await supabase
            .from('payments')
            .insert([
                {
                    report_id: value.orderId,
                    resident_id: req.user.id,
                    amount,
                    currency: 'UGX',
                    payment_method: 'marzpay',
                    phone_number: formattedPhone,
                    payment_status: paymentStatus,
                    initiated_at: new Date().toISOString(),
                    transaction_ref: transactionRef,
                    provider_reference: providerRef,
                    flw_ref: transactionRef,
                    transaction_id: providerRef,
                    webhook_response: marzResponse,
                },
            ]);

        if (paymentError) {
            throw paymentError;
        }

        const { error: orderUpdateError } = await supabase
            .from('garbage_reports')
            .update({
                payment_status: 'processing',
            })
            .eq('id', value.orderId);

        if (orderUpdateError) {
            throw orderUpdateError;
        }

        await createNotification({
            userId: req.user.id,
            title: 'Payment initiated',
            message: `Your mobile money payment request for UGX ${amount} was sent.`,
            type: 'payment',
            data: {
                report_id: value.orderId,
                transaction_ref: transactionRef,
                payment_status: 'pending',
            },
        });

        return res.json({
            success: true,
            message: marzResponse?.message || 'Collection initiated successfully.',
            data: {
                transactionRef,
                status: 'pending',
                providerRef,
                message: marzResponse?.message || 'Collection initiated successfully.',
            },
        });
    } catch (error) {
        console.error('MarzPay initiation failed:', error.details || error.message);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Failed to initiate payment',
        });
    }
}

async function handleMarzpayCallback(req, res, next) {
    try {
        const { transactionRef, providerRef, providerStatus } = extractCallbackFields(req.body);

        if (!transactionRef) {
            return res.status(400).json({ success: false, message: 'transactionRef/reference is required' });
        }

        const mappedStatus = mapMarzPayStatus(providerStatus);

        const { data, error } = await supabase.rpc('apply_marzpay_callback', {
            p_transaction_ref: transactionRef,
            p_provider_reference: providerRef,
            p_provider_status: mappedStatus,
            p_payload: req.body || {},
        });

        if (error) {
            throw error;
        }

        if (!data || data.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Payment transaction not found',
            });
        }

        const transition = data[0];
        console.log('MarzPay callback transition:', {
            transactionRef,
            providerRef,
            previousPaymentStatus: transition.previous_payment_status,
            newPaymentStatus: transition.new_payment_status,
            previousOrderStatus: transition.previous_order_status,
            newOrderStatus: transition.new_order_status,
        });

        const { data: paymentRow } = await supabase
            .from('payments')
            .select('resident_id, report_id, amount')
            .eq('transaction_ref', transactionRef)
            .maybeSingle();

        if (paymentRow?.resident_id) {
            const isSuccess = transition.new_payment_status === 'successful';
            const isFailed = transition.new_payment_status === 'failed';

            await createNotification({
                userId: paymentRow.resident_id,
                title: isSuccess ? 'Payment successful' : isFailed ? 'Payment failed' : 'Payment update',
                message: isSuccess
                    ? `Payment of UGX ${paymentRow.amount} was successful.`
                    : isFailed
                        ? `Payment of UGX ${paymentRow.amount} failed. Please try again.`
                        : `Payment status changed to ${transition.new_payment_status}.`,
                type: 'payment',
                data: {
                    report_id: paymentRow.report_id,
                    transaction_ref: transactionRef,
                    provider_ref: providerRef,
                    payment_status: transition.new_payment_status,
                },
                sendSms: isSuccess || isFailed,
            });
        }

        return res.json({
            success: true,
            message: 'Callback processed',
            data: {
                transactionRef,
                providerRef,
                status: transition.new_order_status,
            },
        });
    } catch (error) {
        console.error('MarzPay callback failed:', error.details || error.message);
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Failed to process callback',
        });
    }
}

async function validatePhone(req, res) {
    const { error, value } = validatePhoneSchema.validate(req.body);
    if (error) {
        return res.status(400).json({ success: false, message: error.details[0].message });
    }

    const validation = marzpayService.validateMobileNumber(value.phone);

    return res.json({
        success: true,
        data: {
            ...validation,
            formattedPhone: marzpayService.formatPhoneNumber(value.phone),
        },
    });
}

async function getWalletBalance(req, res) {
    try {
        const balance = await marzpayService.getWalletBalance();
        return res.json({ success: true, data: balance });
    } catch (error) {
        const message =
            error.message && error.message.toLowerCase().includes('whitelist')
                ? 'Wallet balance check failed. Confirm backend server IP is whitelisted in MarzPay dashboard.'
                : error.message || 'Failed to fetch wallet balance';

        return res.status(error.statusCode || 500).json({ success: false, message });
    }
}

async function getMarzpayTransactions(req, res) {
    try {
        const transactions = await marzpayService.getTransactionHistory(req.query || {});
        return res.json({ success: true, data: transactions });
    } catch (error) {
        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || 'Failed to fetch MarzPay transactions',
        });
    }
}

module.exports = {
    initiatePayment,
    handleMarzpayCallback,
    validatePhone,
    getWalletBalance,
    getMarzpayTransactions,
    mapMarzPayStatus,
};
