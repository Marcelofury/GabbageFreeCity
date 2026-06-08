const Joi = require('joi');
const { randomUUID } = require('crypto');
const { supabase } = require('../config/supabase');
const marzpayService = require('../services/marzpayService');
const { createNotification } = require('../services/notificationService');

const purchaseSchema = Joi.object({
    plan_id: Joi.string().uuid().required(),
    phone: Joi.string().required(),
});

function addMonths(date, months) {
    const copy = new Date(date.getTime());
    const targetMonth = copy.getMonth() + months;
    copy.setMonth(targetMonth);

    if (copy.getMonth() !== (targetMonth % 12 + 12) % 12) {
        copy.setDate(0);
    }

    return copy;
}

async function notifyStakeholders({ residentId, title, message, data, sendSms = true }) {
    const { data: staff, error: staffError } = await supabase
        .from('users')
        .select('id')
        .in('user_type', ['admin', 'collector'])
        .eq('is_active', true);

    if (staffError) {
        throw staffError;
    }

    const recipients = new Set([residentId, ...(staff || []).map((row) => row.id)]);

    await Promise.all(
        Array.from(recipients)
            .filter(Boolean)
            .map((userId) => createNotification({
                userId,
                title,
                message,
                type: 'system',
                data,
                sendSms,
            }))
    );
}

async function listPlans(req, res, next) {
    try {
        const { data, error } = await supabase
            .from('subscription_plans')
            .select('*')
            .eq('is_active', true)
            .order('weekly_collections', { ascending: true });

        if (error) throw error;

        return res.json({
            success: true,
            data: { plans: data || [] },
        });
    } catch (error) {
        return next(error);
    }
}

async function getMySubscription(req, res, next) {
    try {
        const nowIso = new Date().toISOString();
        const { data, error } = await supabase
            .from('subscriptions')
            .select('*, plan:subscription_plans(*)')
            .eq('resident_id', req.user.id)
            .eq('status', 'active')
            .gte('end_date', nowIso)
            .order('end_date', { ascending: false })
            .limit(1)
            .maybeSingle();

        if (error) throw error;

        if (!data) {
            const activated = await syncPendingSubscriptionPayment(req.user.id);
            if (activated) {
                const { data: refreshed, error: refetchError } = await supabase
                    .from('subscriptions')
                    .select('*, plan:subscription_plans(*)')
                    .eq('resident_id', req.user.id)
                    .eq('status', 'active')
                    .gte('end_date', new Date().toISOString())
                    .order('end_date', { ascending: false })
                    .limit(1)
                    .maybeSingle();

                if (!refetchError && refreshed) {
                    return res.json({
                        success: true,
                        data: { subscription: refreshed },
                    });
                }
            }
        }

        return res.json({
            success: true,
            data: { subscription: data || null },
        });
    } catch (error) {
        return next(error);
    }
}

async function syncPendingSubscriptionPayment(residentId) {
    try {
        const { data: pendingSub } = await supabase
            .from('subscriptions')
            .select('id, plan:subscription_plans(prepay_months, monthly_collections)')
            .eq('resident_id', residentId)
            .eq('status', 'pending')
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

        if (!pendingSub) return false;

        const { data: payment } = await supabase
            .from('payments')
            .select('id, amount, transaction_id, transaction_ref')
            .eq('subscription_id', pendingSub.id)
            .eq('payment_purpose', 'subscription')
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

        if (!payment || !payment.transaction_id) return false;

        let providerPayload;
        try {
            providerPayload = await marzpayService.checkTransactionStatus(payment.transaction_id);
        } catch {
            try {
                const history = await marzpayService.getTransactionHistory({ reference: payment.transaction_ref });
                providerPayload = Array.isArray(history?.data)
                    ? { data: { transaction: history.data[0] || null } }
                    : history;
            } catch {
                return false;
            }
        }

        const root = providerPayload || {};
        const data = root.data || {};
        const transaction = data.transaction || root.transaction || {};
        const providerStatus = transaction.status || data.status || root.status || 'pending';
        const isSuccess = ['successful', 'completed', 'success', 'succeeded', 'paid'].includes(String(providerStatus).toLowerCase());

        if (!isSuccess) return false;

        const nowIso = new Date().toISOString();
        const prepayMonths = Number(pendingSub.plan?.prepay_months || 3);
        const endDate = new Date();
        endDate.setMonth(endDate.getMonth() + prepayMonths);

        await supabase.from('payments').update({
            payment_status: 'successful',
            completed_at: nowIso,
            updated_at: nowIso,
        }).eq('id', payment.id);

        await supabase.from('subscriptions').update({
            status: 'active',
            start_date: nowIso,
            end_date: endDate.toISOString(),
            updated_at: nowIso,
        }).eq('id', pendingSub.id);

        return true;
    } catch {
        return false;
    }
}

async function purchaseSubscription(req, res, next) {
    try {
        const { error, value } = purchaseSchema.validate(req.body || {});
        if (error) {
            return res.status(400).json({ success: false, message: error.details[0].message });
        }

        const { data: plan, error: planError } = await supabase
            .from('subscription_plans')
            .select('*')
            .eq('id', value.plan_id)
            .eq('is_active', true)
            .maybeSingle();

        if (planError) throw planError;
        if (!plan) {
            return res.status(404).json({ success: false, message: 'Subscription plan not found' });
        }

        const nowIso = new Date().toISOString();
        const { data: existingActive } = await supabase
            .from('subscriptions')
            .select('id')
            .eq('resident_id', req.user.id)
            .eq('status', 'active')
            .gte('end_date', nowIso)
            .gt('remaining_collections', 0)
            .maybeSingle();

        if (existingActive) {
            return res.status(409).json({
                success: false,
                message: 'You already have an active subscription',
            });
        }

        const phoneValidation = marzpayService.validateMobileNumber(value.phone);
        const formattedPhone = marzpayService.formatPhoneNumber(value.phone);

        if (!phoneValidation.valid || !formattedPhone || formattedPhone.length !== 13) {
            return res.status(400).json({
                success: false,
                message: phoneValidation.message,
            });
        }

        const totalCollections = Number(plan.monthly_collections || 0) * Number(plan.prepay_months || 3);
        const { data: subscription, error: subscriptionError } = await supabase
            .from('subscriptions')
            .insert([{
                resident_id: req.user.id,
                plan_id: plan.id,
                status: 'pending',
                total_collections: totalCollections,
                remaining_collections: totalCollections,
                created_at: nowIso,
                updated_at: nowIso,
            }])
            .select()
            .single();

        if (subscriptionError) throw subscriptionError;

        const amount = Number(plan.prepay_price_ugx || 0);
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
            description: `Subscription ${plan.name} payment`,
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

        const paymentStatus = ['successful', 'completed', 'success'].includes(String(providerStatus).toLowerCase())
            ? 'successful'
            : ['failed', 'cancelled'].includes(String(providerStatus).toLowerCase())
                ? 'failed'
                : 'pending';

        const { error: paymentError } = await supabase
            .from('payments')
            .insert([{
                report_id: null,
                subscription_id: subscription.id,
                resident_id: req.user.id,
                amount,
                currency: 'UGX',
                payment_method: 'marzpay',
                phone_number: formattedPhone,
                payment_status: paymentStatus,
                initiated_at: nowIso,
                transaction_ref: transactionRef,
                provider_reference: providerRef,
                flw_ref: transactionRef,
                transaction_id: providerRef,
                payment_purpose: 'subscription',
                webhook_response: marzResponse,
            }]);

        if (paymentError) throw paymentError;

        if (paymentStatus === 'successful') {
            const endDate = addMonths(new Date(nowIso), Number(plan.prepay_months || 3)).toISOString();
            const { error: activateError } = await supabase
                .from('subscriptions')
                .update({
                    status: 'active',
                    start_date: nowIso,
                    end_date: endDate,
                    updated_at: nowIso,
                })
                .eq('id', subscription.id);

            if (!activateError) {
                subscription.status = 'active';
                subscription.start_date = nowIso;
                subscription.end_date = endDate;
            }
        }

        await createNotification({
            userId: req.user.id,
            title: 'Subscription payment initiated',
            message: `Your subscription payment request for UGX ${amount} was sent.`,
            type: 'payment',
            data: {
                subscription_id: subscription.id,
                transaction_ref: transactionRef,
                payment_status: paymentStatus,
            },
        });

        return res.json({
            success: true,
            message: marzResponse?.message || 'Subscription payment initiated successfully.',
            data: {
                subscription_id: subscription.id,
                transactionRef,
                status: 'pending',
                providerRef,
            },
        });
    } catch (error) {
        return next(error);
    }
}

async function runDueCheck(req, res, next) {
    try {
        const expectedSecret = process.env.SUBSCRIPTION_CRON_SECRET;
        const providedSecret = req.headers['x-cron-secret'];

        if (!expectedSecret || providedSecret !== expectedSecret) {
            return res.status(401).json({
                success: false,
                message: 'Unauthorized cron request',
            });
        }

        const now = new Date();
        const nowIso = now.toISOString();
        const dueDate = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
        const dueIso = dueDate.toISOString();

        const { data: dueSubscriptions, error: dueError } = await supabase
            .from('subscriptions')
            .select('id, resident_id, end_date, remaining_collections, plan:subscription_plans(name)')
            .eq('status', 'active')
            .gte('end_date', nowIso)
            .lte('end_date', dueIso);

        if (dueError) throw dueError;

        for (const subscription of dueSubscriptions || []) {
            await notifyStakeholders({
                residentId: subscription.resident_id,
                title: 'Subscription due soon',
                message: `Subscription ${subscription.plan?.name || ''} expires on ${subscription.end_date}.`,
                data: {
                    subscription_id: subscription.id,
                    end_date: subscription.end_date,
                    remaining_collections: subscription.remaining_collections,
                },
                sendSms: true,
            });
        }

        const { data: expiringRows, error: expiringError } = await supabase
            .from('subscriptions')
            .select('id, resident_id, end_date, remaining_collections, plan:subscription_plans(name)')
            .eq('status', 'active')
            .or(`end_date.lt.${nowIso},remaining_collections.lte.0`);

        if (expiringError) throw expiringError;

        for (const subscription of expiringRows || []) {
            await supabase
                .from('subscriptions')
                .update({
                    status: 'expired',
                    updated_at: nowIso,
                })
                .eq('id', subscription.id);

            await notifyStakeholders({
                residentId: subscription.resident_id,
                title: 'Subscription expired',
                message: `Subscription ${subscription.plan?.name || ''} has expired. Please renew to continue collection.`,
                data: {
                    subscription_id: subscription.id,
                    end_date: subscription.end_date,
                    remaining_collections: subscription.remaining_collections,
                },
                sendSms: true,
            });
        }

        return res.json({
            success: true,
            message: 'Subscription due check completed',
            data: {
                due_count: (dueSubscriptions || []).length,
                expired_count: (expiringRows || []).length,
            },
        });
    } catch (error) {
        return next(error);
    }
}

module.exports = {
    listPlans,
    getMySubscription,
    purchaseSubscription,
    runDueCheck,
    addMonths,
};
