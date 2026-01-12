/**
 * Garbage Report Routes
 * Handles garbage pile-up reporting and management
 */

const express = require('express');
const router = express.Router();
const Joi = require('joi');
const { supabase } = require('../config/supabase');
const { authenticateToken, requireUserType } = require('../middleware/auth');

// Validation schema
const createReportSchema = Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    address_description: Joi.string().max(500).required(),
    garbage_type: Joi.string().valid('mixed', 'plastic', 'organic', 'electronic', 'hazardous').default('mixed'),
    estimated_volume: Joi.string().valid('small', 'medium', 'large').required(),
    photo_url: Joi.string().uri().optional()
});

/**
 * POST /api/garbage-reports
 * Create a new garbage report (residents only)
 */
router.post('/', authenticateToken, requireUserType('resident'), async (req, res, next) => {
    try {
        // Validate input
        const { error, value } = createReportSchema.validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                message: error.details[0].message
            });
        }

        const { latitude, longitude, address_description, garbage_type, estimated_volume, photo_url } = value;

        // Create report
        const reportData = {
            resident_id: req.user.id,
            location: `POINT(${longitude} ${latitude})`,
            address_description,
            garbage_type,
            estimated_volume,
            photo_url,
            status: 'pending',
            payment_required: true,
            payment_amount: parseFloat(process.env.DEFAULT_COLLECTION_FEE || 5000),
            reported_at: new Date().toISOString()
        };

        const { data: report, error: insertError } = await supabase
            .from('garbage_reports')
            .insert([reportData])
            .select()
            .single();

        if (insertError) {
            throw insertError;
        }

        res.status(201).json({
            success: true,
            message: 'Garbage report created successfully',
            data: {
                report_id: report.id,
                status: report.status,
                payment_amount: report.payment_amount,
                currency: 'UGX'
            }
        });

    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/garbage-reports/my-reports
 * Get current user's reports
 */
router.get('/my-reports', authenticateToken, requireUserType('resident'), async (req, res, next) => {
    try {
        const { data: reports, error } = await supabase
            .from('garbage_reports')
            .select(`
                *,
                payments (
                    id,
                    payment_status,
                    amount,
                    transaction_id
                ),
                assigned_collector:users!garbage_reports_assigned_collector_id_fkey (
                    id,
                    full_name,
                    phone_number
                )
            `)
            .eq('resident_id', req.user.id)
            .order('reported_at', { ascending: false });

        if (error) {
            throw error;
        }

        res.json({
            success: true,
            data: { reports }
        });

    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/garbage-reports/nearby
 * Get nearby pending reports (collectors only)
 */
router.get('/nearby', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const { latitude, longitude, radius = 5000 } = req.query; // radius in meters

        if (!latitude || !longitude) {
            return res.status(400).json({
                success: false,
                message: 'Latitude and longitude required'
            });
        }

        // Use PostGIS to find reports within radius
        const { data: reports, error } = await supabase
            .rpc('get_nearby_reports', {
                collector_lat: parseFloat(latitude),
                collector_lng: parseFloat(longitude),
                radius_meters: parseInt(radius)
            });

        if (error) {
            // Fallback: get all pending reports
            const { data: allReports, error: fetchError } = await supabase
                .from('garbage_reports')
                .select(`
                    *,
                    resident:users!garbage_reports_resident_id_fkey (
                        full_name,
                        phone_number
                    )
                `)
                .eq('status', 'pending')
                .limit(20);

            if (fetchError) throw fetchError;

            return res.json({
                success: true,
                data: { reports: allReports }
            });
        }

        res.json({
            success: true,
            data: { reports }
        });

    } catch (error) {
        next(error);
    }
});

/**
 * PATCH /api/garbage-reports/:id/assign
 * Assign collector to a report (collectors only)
 */
router.patch('/:id/assign', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const { id } = req.params;

        // Check if report exists and is pending
        const { data: report, error: fetchError } = await supabase
            .from('garbage_reports')
            .select('*, payments(*)')
            .eq('id', id)
            .single();

        if (fetchError || !report) {
            return res.status(404).json({
                success: false,
                message: 'Report not found'
            });
        }

        if (report.status !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Report is not available for assignment'
            });
        }

        // Check if payment is successful
        const payment = report.payments?.[0];
        if (!payment || payment.payment_status !== 'successful') {
            return res.status(400).json({
                success: false,
                message: 'Payment not completed for this report'
            });
        }

        // Assign collector
        const { data: updatedReport, error: updateError } = await supabase
            .from('garbage_reports')
            .update({
                assigned_collector_id: req.user.id,
                status: 'assigned',
                assigned_at: new Date().toISOString()
            })
            .eq('id', id)
            .select()
            .single();

        if (updateError) {
            throw updateError;
        }

        res.json({
            success: true,
            message: 'Report assigned successfully',
            data: { report: updatedReport }
        });

    } catch (error) {
        next(error);
    }
});

/**
 * PATCH /api/garbage-reports/:id/status
 * Update report status
 */
router.patch('/:id/status', authenticateToken, async (req, res, next) => {
    try {
        const { id } = req.params;
        const { status } = req.body;

        const validStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status'
            });
        }

        const updateData = { status };
        if (status === 'in_progress') {
            updateData.started_at = new Date().toISOString();
        } else if (status === 'completed') {
            updateData.completed_at = new Date().toISOString();
        }

        const { data: report, error } = await supabase
            .from('garbage_reports')
            .update(updateData)
            .eq('id', id)
            .select()
            .single();

        if (error) {
            throw error;
        }

        res.json({
            success: true,
            message: 'Status updated',
            data: { report }
        });

    } catch (error) {
        next(error);
    }
});

module.exports = router;
