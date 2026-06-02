const express = require('express');
const router = express.Router();
const { supabase } = require('../config/supabase');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

router.use(authenticateToken, requireAdmin);

/**
 * GET /api/admin/dashboard
 * Collector-focused admin summary
 */
router.get('/dashboard', async (req, res, next) => {
    try {
        const successfulPaymentStatuses = ['successful', 'completed', 'paid', 'success'];

        const [
            { count: activeCollectors, error: activeError },
            { count: inactiveCollectors, error: inactiveError },
            { count: openAssignments, error: assignmentError },
            { count: collectionsToday, error: collectionsTodayError },
            { count: totalReports, error: totalReportsError },
            { count: pendingReports, error: pendingReportsError },
            { count: acceptedReports, error: acceptedReportsError },
            { count: completedReports, error: completedReportsError },
            { data: paidPayments, count: paidPaymentsCount, error: paidPaymentsError },
            { count: pendingPaymentsCount, error: pendingPaymentsError },
            { count: failedPaymentsCount, error: failedPaymentsError },
            { data: completionSamples, error: completionSamplesError },
        ] = await Promise.all([
            supabase
                .from('users')
                .select('*', { count: 'exact', head: true })
                .eq('user_type', 'collector')
                .eq('is_active', true),
            supabase
                .from('users')
                .select('*', { count: 'exact', head: true })
                .eq('user_type', 'collector')
                .eq('is_active', false),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .in('status', ['assigned', 'in_progress']),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .eq('status', 'completed')
                .gte('completed_at', new Date(new Date().setHours(0, 0, 0, 0)).toISOString()),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true }),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .eq('status', 'pending'),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .in('status', ['assigned', 'in_progress', 'completed']),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .eq('status', 'completed'),
            supabase
                .from('payments')
                .select('amount, transaction_id, provider_reference', { count: 'exact' })
                .in('payment_status', successfulPaymentStatuses),
            supabase
                .from('payments')
                .select('*', { count: 'exact', head: true })
                .eq('payment_status', 'pending'),
            supabase
                .from('payments')
                .select('*', { count: 'exact', head: true })
                .in('payment_status', ['failed', 'cancelled', 'rejected', 'declined']),
            supabase
                .from('garbage_reports')
                .select('reported_at, completed_at')
                .eq('status', 'completed')
                .not('completed_at', 'is', null)
                .order('completed_at', { ascending: false })
                .limit(200),
        ]);

        if (
            activeError || inactiveError || assignmentError || collectionsTodayError ||
            totalReportsError || pendingReportsError || acceptedReportsError ||
            completedReportsError || paidPaymentsError || pendingPaymentsError ||
            failedPaymentsError || completionSamplesError
        ) {
            throw (
                activeError || inactiveError || assignmentError || collectionsTodayError ||
                totalReportsError || pendingReportsError || acceptedReportsError ||
                completedReportsError || paidPaymentsError || pendingPaymentsError ||
                failedPaymentsError || completionSamplesError
            );
        }

        const totalRevenueUgx = (paidPayments || []).reduce((sum, row) => {
            const amount = Number(row.amount || 0);
            return sum + (Number.isFinite(amount) ? amount : 0);
        }, 0);

        const successfulTransactionRefs = new Set(
            (paidPayments || []).map((row) => String(row.transaction_id || row.provider_reference || '').trim()).filter(Boolean)
        );

        const completionDurations = (completionSamples || [])
            .map((row) => {
                const reported = row.reported_at ? new Date(row.reported_at).getTime() : null;
                const completed = row.completed_at ? new Date(row.completed_at).getTime() : null;
                if (!reported || !completed || completed < reported) {
                    return null;
                }
                return (completed - reported) / (1000 * 60);
            })
            .filter((value) => value != null);

        const avgCompletionMinutes = completionDurations.length > 0
            ? Math.round(completionDurations.reduce((sum, value) => sum + value, 0) / completionDurations.length)
            : 0;

        const completedCount = completedReports || 0;
        const totalCount = totalReports || 0;
        const completionRate = totalCount > 0
            ? Number(((completedCount / totalCount) * 100).toFixed(1))
            : 0;

        return res.json({
            success: true,
            data: {
                active_collectors: activeCollectors || 0,
                inactive_collectors: inactiveCollectors || 0,
                open_assignments: openAssignments || 0,
                collections_today: collectionsToday || 0,
                reports_made: totalCount,
                reports_pending: pendingReports || 0,
                reports_accepted: acceptedReports || 0,
                reports_completed: completedCount,
                analytics: {
                    completion_rate_percent: completionRate,
                    total_revenue_ugx: totalRevenueUgx,
                    average_completion_minutes: avgCompletionMinutes,
                    paid_transactions: paidPaymentsCount || (paidPayments || []).length,
                    successful_transactions: successfulTransactionRefs.size,
                    pending_payments: pendingPaymentsCount || 0,
                    failed_payments: failedPaymentsCount || 0,
                },
            },
        });
    } catch (error) {
        return next(error);
    }
});

/**
 * GET /api/admin/collectors
 * List collectors with assignment load
 */
router.get('/collectors', async (req, res, next) => {
    try {
        const search = String(req.query.search || '').trim().toLowerCase();
        const status = String(req.query.status || 'all').toLowerCase();

        let query = supabase
            .from('users')
            .select('id, username, full_name, phone_number, area, is_active, created_at, updated_at')
            .eq('user_type', 'collector')
            .order('full_name', { ascending: true });

        if (status === 'active') {
            query = query.eq('is_active', true);
        }

        if (status === 'inactive') {
            query = query.eq('is_active', false);
        }

        const { data: collectors, error } = await query;
        if (error) throw error;

        const filteredCollectors = !search
            ? collectors
            : collectors.filter((collector) => {
                const fullName = String(collector.full_name || '').toLowerCase();
                const username = String(collector.username || '').toLowerCase();
                const phone = String(collector.phone_number || '').toLowerCase();
                const area = String(collector.area || '').toLowerCase();

                return fullName.includes(search) || username.includes(search) || phone.includes(search) || area.includes(search);
            });

        const collectorIds = filteredCollectors.map((collector) => collector.id);
        let assignmentCountByCollector = {};

        if (collectorIds.length > 0) {
            const { data: assignments, error: assignmentError } = await supabase
                .from('garbage_reports')
                .select('assigned_collector_id, status')
                .in('assigned_collector_id', collectorIds)
                .in('status', ['assigned', 'in_progress']);

            if (assignmentError) throw assignmentError;

            assignmentCountByCollector = (assignments || []).reduce((acc, row) => {
                const key = row.assigned_collector_id;
                acc[key] = (acc[key] || 0) + 1;
                return acc;
            }, {});
        }

        const data = filteredCollectors.map((collector) => ({
            ...collector,
            active_assignments: assignmentCountByCollector[collector.id] || 0,
        }));

        return res.json({ success: true, data: { collectors: data } });
    } catch (error) {
        return next(error);
    }
});

/**
 * GET /api/admin/collections
 * Admin collection history with proof details
 */
router.get('/collections', async (req, res, next) => {
    try {
        const period = String(req.query.period || 'month').toLowerCase();
        const validPeriods = ['week', 'month', 'all'];
        const collectorId = String(req.query.collector_id || '').trim();
        const area = String(req.query.area || '').trim().toLowerCase();
        const outOfSchedule = String(req.query.out_of_schedule || '').trim().toLowerCase();

        if (!validPeriods.includes(period)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid period filter. Use week, month, or all.',
            });
        }

        let query = supabase
            .from('garbage_reports')
            .select(`
                id,
                address_description,
                package_count,
                estimated_volume,
                payment_amount,
                completed_at,
                resident:users!garbage_reports_resident_id_fkey (
                    id,
                    full_name,
                    phone_number,
                    area
                ),
                collector:users!garbage_reports_assigned_collector_id_fkey (
                    id,
                    full_name,
                    phone_number
                ),
                collection_log:collection_logs!collection_logs_report_id_fkey (
                    id,
                    qr_code_scanned,
                    qr_scan_timestamp,
                    scheduled_days,
                    out_of_schedule,
                    collection_location,
                    distance_from_report,
                    actual_volume,
                    notes,
                    photo_url,
                    started_at,
                    completed_at
                )
            `)
            .eq('status', 'completed')
            .order('completed_at', { ascending: false });

        if (collectorId) {
            query = query.eq('assigned_collector_id', collectorId);
        }

        if (period === 'week') {
            const weekAgo = new Date();
            weekAgo.setDate(weekAgo.getDate() - 7);
            query = query.gte('completed_at', weekAgo.toISOString());
        } else if (period === 'month') {
            const monthAgo = new Date();
            monthAgo.setMonth(monthAgo.getMonth() - 1);
            query = query.gte('completed_at', monthAgo.toISOString());
        }

        const { data: reports, error } = await query;
        if (error) {
            throw error;
        }

        let normalizedReports = (reports || []).map((report) => {
            const logArray = Array.isArray(report.collection_log) ? report.collection_log : [];
            return {
                ...report,
                collection_log: logArray[0] || null,
            };
        });

        if (area) {
            normalizedReports = normalizedReports.filter((report) => {
                const residentArea = String(report.resident?.area || '').toLowerCase();
                return residentArea.includes(area);
            });
        }

        if (outOfSchedule === 'true' || outOfSchedule === 'false') {
            const flag = outOfSchedule === 'true';
            normalizedReports = normalizedReports.filter(
                (report) => (report.collection_log?.out_of_schedule ?? false) === flag
            );
        }

        return res.json({
            success: true,
            data: {
                period,
                reports: normalizedReports,
            },
        });
    } catch (error) {
        return next(error);
    }
});

/**
 * PATCH /api/admin/collectors/:id/status
 * Activate or deactivate collector account
 */
router.patch('/collectors/:id/status', async (req, res, next) => {
    try {
        const { id } = req.params;
        const { is_active: isActive } = req.body;

        if (typeof isActive !== 'boolean') {
            return res.status(400).json({
                success: false,
                message: 'is_active must be a boolean value',
            });
        }

        const { data: collector, error: fetchError } = await supabase
            .from('users')
            .select('id, user_type')
            .eq('id', id)
            .single();

        if (fetchError || !collector || collector.user_type !== 'collector') {
            return res.status(404).json({
                success: false,
                message: 'Collector not found',
            });
        }

        const { data: updatedCollector, error: updateError } = await supabase
            .from('users')
            .update({
                is_active: isActive,
                updated_at: new Date().toISOString(),
            })
            .eq('id', id)
            .select('id, username, full_name, phone_number, area, is_active, updated_at')
            .single();

        if (updateError) throw updateError;

        if (!isActive) {
            await supabase
                .from('garbage_reports')
                .update({
                    assigned_collector_id: null,
                    status: 'pending',
                    assigned_at: null,
                    updated_at: new Date().toISOString(),
                })
                .eq('assigned_collector_id', id)
                .in('status', ['assigned', 'in_progress']);
        }

        return res.json({
            success: true,
            message: isActive ? 'Collector activated successfully' : 'Collector deactivated successfully',
            data: { collector: updatedCollector },
        });
    } catch (error) {
        return next(error);
    }
});

module.exports = router;
