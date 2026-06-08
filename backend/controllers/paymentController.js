const Joi = require('joi');
const { randomUUID } = require('crypto');
const marzpayService = require('../services/marzpayService');
const { supabase } = require('../config/supabase');
const { createNotification } = require('../services/notificationService');

const MIN_AMOUNT = Number(process.env.MARZPAY_MIN_AMOUNT || 500);
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

    if (['successful', 'completed', 'success', 'succeeded', 'paid'].includes(normalized)) {
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

function formatSmsTemplate(template, variables) {
    return String(template || '').replace(/\{(\w+)\}/g, (_, key) => String(variables?.[key] ?? ''));
}

function addMonths(date, months) {
    const result = new Date(date.getTime());
    result.setMonth(result.getMonth() + Number(months || 0));
    return result;
}

function buildPaymentSmsMessage({ success, name, amount }) {
    const successTemplate = process.env.SMS_PAYMENT_SUCCESS ||
        'Webale nyo {name}! Payment of UGX {amount} received. Collector assigned soon. -KCCA GFC';
    const failedTemplate = process.env.SMS_PAYMENT_FAILED ||
        'Sorry {name}, payment of UGX {amount} failed. Please try again. -KCCA GFC';

    const selected = success ? successTemplate : failedTemplate;
    return formatSmsTemplate(selected, {
        name: name || 'Resident',
        amount: Number(amount || 0).toFixed(0),
    });
}

async function notifyPaymentTransition({
    residentId,
    reportId,
    transactionRef,
    providerRef,
    amount,
    newPaymentStatus,
    previousPaymentStatus,
}) {
    if (!residentId) {
        return;
    }

    const changed = String(previousPaymentStatus || '').toLowerCase() !== String(newPaymentStatus || '').toLowerCase();
    if (!changed) {
        return;
    }

    const isSuccess = newPaymentStatus === 'successful';
    const isFailed = newPaymentStatus === 'failed';

    const { data: resident } = await supabase
        .from('users')
        .select('full_name')
        .eq('id', residentId)
        .maybeSingle();

    const title = isSuccess ? 'Payment successful' : isFailed ? 'Payment failed' : 'Payment update';
    const message = isSuccess || isFailed
        ? buildPaymentSmsMessage({ success: isSuccess, name: resident?.full_name, amount })
        : `Payment status changed to ${newPaymentStatus}.`;

    await createNotification({
        userId: residentId,
        title,
        message,
        type: 'payment',
        data: {
            report_id: reportId,
            transaction_ref: transactionRef,
            provider_ref: providerRef,
            payment_status: newPaymentStatus,
        },
        sendSms: isSuccess || isFailed,
    });
}

async function notifySubscriptionTransition({ residentId, subscriptionId, newPaymentStatus, amount, planName }) {
    if (!residentId || !subscriptionId) {
        return;
    }

    const isSuccess = newPaymentStatus === 'successful';
    const isFailed = newPaymentStatus === 'failed';

    const title = isSuccess ? 'Subscription activated' : isFailed ? 'Subscription payment failed' : 'Subscription payment update';
    const message = isSuccess
        ? `Your ${planName || 'subscription'} is active. UGX ${Number(amount || 0).toFixed(0)} received.`
        : isFailed
            ? `Subscription payment of UGX ${Number(amount || 0).toFixed(0)} failed. Please try again.`
            : `Subscription payment status changed to ${newPaymentStatus}.`;

    await createNotification({
        userId: residentId,
        title,
        message,
        type: 'payment',
        data: {
            subscription_id: subscriptionId,
            payment_status: newPaymentStatus,
        },
        sendSms: isSuccess || isFailed,
    });
}

async function updateSubscriptionFromPayment(subscriptionId, newPaymentStatus, amount) {
    if (!subscriptionId) {
        return null;
    }

    const { data: subscription, error } = await supabase
        .from('subscriptions')
        .select('id, resident_id, status, start_date, end_date, total_collections, remaining_collections, plan:subscription_plans(prepay_months, monthly_collections, name)')
        .eq('id', subscriptionId)
        .maybeSingle();

    if (error) {
        throw error;
    }

    if (!subscription) {
        return null;
    }

    const now = new Date();
    const nowIso = now.toISOString();
    let status = subscription.status;
    const prepayMonths = Number(subscription.plan?.prepay_months || 3);
    const monthlyCollections = Number(subscription.plan?.monthly_collections || 0);
    const totalCollections = monthlyCollections * prepayMonths;

    if (newPaymentStatus === 'successful') {
        status = 'active';
    } else if (newPaymentStatus === 'failed') {
        status = 'cancelled';
    } else {
        status = 'pending';
    }

    const startDate = subscription.start_date || (status === 'active' ? nowIso : null);
    const endDate = startDate
        ? (subscription.end_date || addMonths(new Date(startDate), prepayMonths).toISOString())
        : subscription.end_date;
    const remainingCollections = subscription.remaining_collections > 0
        ? subscription.remaining_collections
        : totalCollections;

    const { data: updated, error: updateError } = await supabase
        .from('subscriptions')
        .update({
            status,
            start_date: startDate,
            end_date: endDate,
            total_collections: totalCollections || subscription.total_collections,
            remaining_collections: remainingCollections,
            updated_at: nowIso,
        })
        .eq('id', subscriptionId)
        .select('id, resident_id, status')
        .single();

    if (updateError) {
        throw updateError;
    }

    await notifySubscriptionTransition({
        residentId: subscription.resident_id,
        subscriptionId,
        newPaymentStatus,
        amount,
        planName: subscription.plan?.name,
    });

    return updated;
}

function extractLookupPayload(payload) {
    const root = payload || {};
    const data = root.data || {};
    const transaction = data.transaction || root.transaction || {};

    const status =
        transaction.status ||
        data.status ||
        root.status ||
        root.transactionStatus ||
        root.transaction_status ||
        'pending';

    const providerRef =
        transaction.provider_reference ||
        data.provider_reference ||
        root.provider_reference ||
        transaction.providerRef ||
        data.providerRef ||
        root.providerRef ||
        transaction.providerReference ||
        data.providerReference ||
        root.providerReference ||
        null;

    const transactionRef =
        transaction.reference ||
        data.reference ||
        root.reference ||
        root.transactionRef ||
        root.transaction_ref ||
        null;

    return {
        status,
        providerRef,
        transactionRef,
        raw: root,
    };
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

function isMissingSchemaObject(error, objectName) {
    const text = `${error?.message || ''} ${error?.details || ''} ${error?.hint || ''}`.toLowerCase();
    return text.includes(String(objectName || '').toLowerCase()) &&
        (text.includes('could not find') || text.includes('does not exist'));
}

async function insertPaymentWithSchemaFallback(paymentPayload) {
    let { error } = await supabase
        .from('payments')
        .insert([paymentPayload]);

    if (!error) {
        return;
    }

    if (!isMissingSchemaObject(error, 'provider_reference')) {
        throw error;
    }

    const fallbackPayload = { ...paymentPayload };
    delete fallbackPayload.provider_reference;

    const fallbackResult = await supabase
        .from('payments')
        .insert([fallbackPayload]);

    if (fallbackResult.error) {
        throw fallbackResult.error;
    }
}

async function applyMarzpayCallbackFallback({ transactionRef, providerRef, providerStatus, payload }) {
    const { data: payment, error: paymentLookupError } = await supabase
        .from('payments')
        .select('id, report_id, resident_id, amount, payment_status')
        .or(`transaction_ref.eq.${transactionRef},flw_ref.eq.${transactionRef}`)
        .limit(1)
        .maybeSingle();

    if (paymentLookupError) {
        throw paymentLookupError;
    }

    if (!payment) {
        return null;
    }

    const mappedStatus = mapMarzPayStatus(providerStatus);
    const newPaymentStatus = toPaymentStatus(mappedStatus);

    const updatePayload = {
        transaction_id: providerRef || payment.transaction_id || transactionRef,
        payment_status: newPaymentStatus,
        webhook_response: payload || {},
        completed_at: newPaymentStatus === 'successful' ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
    };

    if (providerRef) {
        updatePayload.provider_reference = providerRef;
    }

    let paymentUpdateResult = await supabase
        .from('payments')
        .update(updatePayload)
        .eq('id', payment.id)
        .select('payment_status')
        .single();

    if (paymentUpdateResult.error && isMissingSchemaObject(paymentUpdateResult.error, 'provider_reference')) {
        const noProviderRefPayload = { ...updatePayload };
        delete noProviderRefPayload.provider_reference;

        paymentUpdateResult = await supabase
            .from('payments')
            .update(noProviderRefPayload)
            .eq('id', payment.id)
            .select('payment_status')
            .single();
    }

    if (paymentUpdateResult.error) {
        throw paymentUpdateResult.error;
    }

    let oldOrderStatus = 'pending';

    if (payment.report_id) {
        const { data: currentReport, error: reportLookupError } = await supabase
            .from('garbage_reports')
            .select('payment_status')
            .eq('id', payment.report_id)
            .single();

        if (!reportLookupError && currentReport) {
            oldOrderStatus = currentReport.payment_status || 'pending';
        }

        const newOrderStatus = mappedStatus;

        const { error: reportUpdateError } = await supabase
            .from('garbage_reports')
            .update({
                payment_status: newOrderStatus,
                updated_at: new Date().toISOString(),
            })
            .eq('id', payment.report_id);

        if (reportUpdateError) {
            throw reportUpdateError;
        }
    }

    return {
        payment_id: payment.id,
        report_id: payment.report_id,
        previous_payment_status: payment.payment_status,
        new_payment_status: newPaymentStatus,
        previous_order_status: oldOrderStatus,
        new_order_status: mappedStatus,
    };
}

async function applyMarzpayTransition({ transactionRef, providerRef, providerStatus, payload }) {
    let transition = null;
    const mappedStatus = mapMarzPayStatus(providerStatus);

    const rpcResult = await supabase.rpc('apply_marzpay_callback', {
        p_transaction_ref: transactionRef,
        p_provider_reference: providerRef,
        p_provider_status: mappedStatus,
        p_payload: payload || {},
    });

    if (!rpcResult.error && Array.isArray(rpcResult.data) && rpcResult.data.length > 0) {
        transition = rpcResult.data[0];
    } else {
        const canFallback = isMissingSchemaObject(rpcResult.error, 'apply_marzpay_callback') ||
            isMissingSchemaObject(rpcResult.error, 'provider_reference');

        if (!canFallback && rpcResult.error) {
            throw rpcResult.error;
        }

        transition = await applyMarzpayCallbackFallback({
            transactionRef,
            providerRef,
            providerStatus: mappedStatus,
            payload: payload || {},
        });
    }

    return transition;
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
        const inferredBaseUrl = `${req.protocol}://${req.get('host')}`;
        const callbackBase = process.env.APP_BASE_URL || process.env.API_BASE_URL || inferredBaseUrl;
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

        await insertPaymentWithSchemaFallback({
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
        });

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

        const transition = await applyMarzpayTransition({
            transactionRef,
            providerRef,
            providerStatus,
            payload: req.body || {},
        });

        if (!transition) {
            return res.status(404).json({
                success: false,
                message: 'Payment transaction not found',
            });
        }

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
            .select('resident_id, report_id, subscription_id, amount')
            .eq('transaction_ref', transactionRef)
            .maybeSingle();

        if (paymentRow?.subscription_id) {
            await updateSubscriptionFromPayment(paymentRow.subscription_id, transition.new_payment_status, paymentRow.amount);
        } else {
            await notifyPaymentTransition({
                residentId: paymentRow?.resident_id,
                reportId: paymentRow?.report_id,
                transactionRef,
                providerRef,
                amount: paymentRow?.amount,
                newPaymentStatus: transition.new_payment_status,
                previousPaymentStatus: transition.previous_payment_status,
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

async function reconcileMarzpayPayment(req, res) {
    const schema = Joi.object({
        transaction_ref: Joi.string().min(8).optional(),
        provider_reference: Joi.string().min(4).optional(),
        provider_uuid: Joi.string().min(8).optional(),
    }).or('transaction_ref', 'provider_reference', 'provider_uuid');

    const { error, value } = schema.validate(req.body || {});
    if (error) {
        return res.status(400).json({ success: false, message: error.details[0].message });
    }

    try {
        let paymentQuery = supabase
            .from('payments')
            .select('id, report_id, subscription_id, resident_id, amount, transaction_ref, flw_ref, transaction_id');

        if (value.transaction_ref) {
            paymentQuery = paymentQuery.or(`transaction_ref.eq.${value.transaction_ref},flw_ref.eq.${value.transaction_ref}`);
        } else if (value.provider_reference) {
            paymentQuery = paymentQuery.or(`provider_reference.eq.${value.provider_reference},transaction_id.eq.${value.provider_reference}`);
        } else {
            paymentQuery = paymentQuery.eq('transaction_id', value.provider_uuid);
        }

        const { data: payment, error: paymentError } = await paymentQuery.limit(1).maybeSingle();
        if (paymentError) {
            throw paymentError;
        }

        if (!payment) {
            return res.status(404).json({ success: false, message: 'Payment not found for provided reference' });
        }

        const providerUuid = value.provider_uuid || payment.transaction_id;
        let providerPayload = null;

        if (providerUuid) {
            providerPayload = await marzpayService.checkTransactionStatus(providerUuid);
        } else {
            const history = await marzpayService.getTransactionHistory({
                reference: payment.transaction_ref || payment.flw_ref,
            });

            providerPayload = Array.isArray(history?.data)
                ? { data: { transaction: history.data[0] || null } }
                : history;
        }

        const extracted = extractLookupPayload(providerPayload || {});
        const effectiveTransactionRef = payment.transaction_ref || payment.flw_ref || extracted.transactionRef;

        if (!effectiveTransactionRef) {
            return res.status(400).json({ success: false, message: 'Unable to determine transaction reference' });
        }

        const transition = await applyMarzpayTransition({
            transactionRef: effectiveTransactionRef,
            providerRef: extracted.providerRef || value.provider_reference || payment.transaction_id || null,
            providerStatus: extracted.status,
            payload: providerPayload || {},
        });

        if (!transition) {
            return res.status(404).json({ success: false, message: 'Payment row exists but transition could not be applied' });
        }

        if (payment.subscription_id) {
            await updateSubscriptionFromPayment(payment.subscription_id, transition.new_payment_status, payment.amount);
        }

        return res.json({
            success: true,
            message: 'Payment reconciliation completed',
            data: {
                payment_id: transition.payment_id,
                report_id: transition.report_id,
                previous_payment_status: transition.previous_payment_status,
                new_payment_status: transition.new_payment_status,
                previous_order_status: transition.previous_order_status,
                new_order_status: transition.new_order_status,
                provider_status: extracted.status,
            },
        });
    } catch (reconcileError) {
        return res.status(reconcileError.statusCode || 500).json({
            success: false,
            message: reconcileError.message || 'Failed to reconcile payment',
        });
    }
}

async function syncPaymentStatus(req, res) {
    const schema = Joi.object({
        transaction_ref: Joi.string().min(8).optional(),
        report_id: Joi.string().uuid().optional(),
    }).or('transaction_ref', 'report_id');

    const { error, value } = schema.validate(req.body || {});
    if (error) {
        return res.status(400).json({ success: false, message: error.details[0].message });
    }

    try {
        let paymentQuery = supabase
            .from('payments')
            .select('id, report_id, subscription_id, resident_id, amount, transaction_ref, flw_ref, transaction_id')
            .order('created_at', { ascending: false })
            .limit(1);

        if (value.transaction_ref) {
            paymentQuery = paymentQuery.or(`transaction_ref.eq.${value.transaction_ref},flw_ref.eq.${value.transaction_ref}`);
        }

        if (value.report_id) {
            paymentQuery = paymentQuery.eq('report_id', value.report_id);
        }

        if (req.user.user_type !== 'admin') {
            paymentQuery = paymentQuery.eq('resident_id', req.user.id);
        }

        const { data: rows, error: paymentError } = await paymentQuery;
        if (paymentError) {
            throw paymentError;
        }

        const payment = Array.isArray(rows) ? rows[0] : null;
        if (!payment) {
            return res.status(404).json({ success: false, message: 'Payment not found' });
        }

        const providerUuid = payment.transaction_id;
        let providerPayload = null;

        if (providerUuid) {
            try {
                providerPayload = await marzpayService.checkTransactionStatus(providerUuid);
            } catch (_) {
                providerPayload = null;
            }
        }

        if (!providerPayload) {
            const history = await marzpayService.getTransactionHistory({
                reference: payment.transaction_ref || payment.flw_ref,
            });

            providerPayload = Array.isArray(history?.data)
                ? { data: { transaction: history.data[0] || null } }
                : history;
        }

        const extracted = extractLookupPayload(providerPayload || {});
        const effectiveTransactionRef = payment.transaction_ref || payment.flw_ref || extracted.transactionRef;

        if (!effectiveTransactionRef) {
            return res.status(400).json({ success: false, message: 'Unable to determine transaction reference' });
        }

        const transition = await applyMarzpayTransition({
            transactionRef: effectiveTransactionRef,
            providerRef: extracted.providerRef || payment.transaction_id || null,
            providerStatus: extracted.status,
            payload: providerPayload || {},
        });

        if (!transition) {
            return res.status(404).json({ success: false, message: 'Payment transition not found' });
        }

        if (payment.subscription_id) {
            await updateSubscriptionFromPayment(payment.subscription_id, transition.new_payment_status, payment.amount);
        } else {
            await notifyPaymentTransition({
                residentId: payment.resident_id,
                reportId: transition.report_id,
                transactionRef: effectiveTransactionRef,
                providerRef: extracted.providerRef || payment.transaction_id || null,
                amount: null,
                newPaymentStatus: transition.new_payment_status,
                previousPaymentStatus: transition.previous_payment_status,
            });
        }

        return res.json({
            success: true,
            message: 'Payment status synchronized',
            data: {
                payment_id: transition.payment_id,
                report_id: transition.report_id,
                previous_payment_status: transition.previous_payment_status,
                new_payment_status: transition.new_payment_status,
                previous_order_status: transition.previous_order_status,
                new_order_status: transition.new_order_status,
                provider_status: extracted.status,
            },
        });
    } catch (syncError) {
        return res.status(syncError.statusCode || 500).json({
            success: false,
            message: syncError.message || 'Failed to synchronize payment status',
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
    reconcileMarzpayPayment,
    syncPaymentStatus,
    mapMarzPayStatus,
};
