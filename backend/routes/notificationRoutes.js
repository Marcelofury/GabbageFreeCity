const express = require('express');
const router = express.Router();
const { supabase } = require('../config/supabase');
const { authenticateToken } = require('../middleware/auth');

router.get('/', authenticateToken, async (req, res, next) => {
    try {
        const limit = Math.min(parseInt(req.query.limit || '50', 10), 100);
        const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

        const { data, error } = await supabase
            .from('notifications')
            .select('*')
            .eq('user_id', req.user.id)
            .order('created_at', { ascending: false })
            .range(offset, offset + limit - 1);

        if (error) throw error;

        const { count, error: countError } = await supabase
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', req.user.id)
            .eq('is_read', false);

        if (countError) throw countError;

        res.json({
            success: true,
            data: {
                notifications: data || [],
                unread_count: count || 0,
            },
        });
    } catch (error) {
        next(error);
    }
});

router.patch('/:id/read', authenticateToken, async (req, res, next) => {
    try {
        const { id } = req.params;

        const { data, error } = await supabase
            .from('notifications')
            .update({
                is_read: true,
                read_at: new Date().toISOString(),
            })
            .eq('id', id)
            .eq('user_id', req.user.id)
            .select()
            .single();

        if (error) throw error;

        res.json({
            success: true,
            message: 'Notification marked as read',
            data: { notification: data },
        });
    } catch (error) {
        next(error);
    }
});

router.patch('/read-all', authenticateToken, async (req, res, next) => {
    try {
        const { error } = await supabase
            .from('notifications')
            .update({
                is_read: true,
                read_at: new Date().toISOString(),
            })
            .eq('user_id', req.user.id)
            .eq('is_read', false);

        if (error) throw error;

        res.json({
            success: true,
            message: 'All notifications marked as read',
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
