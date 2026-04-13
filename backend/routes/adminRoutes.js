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
        const [{ count: activeCollectors, error: activeError }, { count: inactiveCollectors, error: inactiveError }, { count: openAssignments, error: assignmentError }, { count: collectionsToday, error: completedError }] = await Promise.all([
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
        ]);

        if (activeError || inactiveError || assignmentError || completedError) {
            throw activeError || inactiveError || assignmentError || completedError;
        }

        return res.json({
            success: true,
            data: {
                active_collectors: activeCollectors || 0,
                inactive_collectors: inactiveCollectors || 0,
                open_assignments: openAssignments || 0,
                collections_today: collectionsToday || 0,
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
