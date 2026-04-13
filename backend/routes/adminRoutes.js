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
        const [
            { count: activeCollectors, error: activeError },
            { count: inactiveCollectors, error: inactiveError },
            { count: openAssignments, error: assignmentError },
            { count: collectionsToday, error: collectionsTodayError },
            { count: totalReports, error: totalReportsError },
            { count: pendingReports, error: pendingReportsError },
            { count: acceptedReports, error: acceptedReportsError },
            { count: completedReports, error: completedReportsError },
            { data: paidPayments, error: paidPaymentsError },
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
                .select('amount')
                .eq('payment_status', 'successful'),
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
            completedReportsError || paidPaymentsError || completionSamplesError
        ) {
            throw (
                activeError || inactiveError || assignmentError || collectionsTodayError ||
                totalReportsError || pendingReportsError || acceptedReportsError ||
                completedReportsError || paidPaymentsError || completionSamplesError
            );
        }

        const totalRevenueUgx = (paidPayments || []).reduce((sum, row) => {
            const amount = Number(row.amount || 0);
            return sum + (Number.isFinite(amount) ? amount : 0);
        }, 0);

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
                analytics: {
                    completion_rate_percent: completionRate,
                    total_revenue_ugx: totalRevenueUgx,
                    average_completion_minutes: avgCompletionMinutes,
                    paid_transactions: (paidPayments || []).length,
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
