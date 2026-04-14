/**
 * Garbage Report Routes
 * Handles garbage pile-up reporting and management
 */

const express = require('express');
const router = express.Router();
const Joi = require('joi');
const { supabase } = require('../config/supabase');
const { authenticateToken, requireUserType } = require('../middleware/auth');
const { createNotification } = require('../services/notificationService');

// Validation schema
const createReportSchema = Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    address_description: Joi.string().max(500).required(),
    garbage_type: Joi.string().valid('mixed', 'plastic', 'organic', 'electronic', 'hazardous').default('mixed'),
    sack_count: Joi.number().integer().min(1).max(100).required(),
    photo_url: Joi.string().uri().allow('', null).optional()
});

const SUCCESSFUL_PAYMENT_STATUSES = ['successful', 'completed', 'paid', 'success'];

function derivePaymentStatus(report) {
    const paymentStatuses = (report?.payments || [])
        .map((p) => String(p?.payment_status || '').toLowerCase())
        .filter(Boolean);

    if (paymentStatuses.some((status) => SUCCESSFUL_PAYMENT_STATUSES.includes(status))) {
        return 'successful';
    }

    if (paymentStatuses.some((status) => status === 'processing' || status === 'initiated')) {
        return 'processing';
    }

    if (paymentStatuses.some((status) => status === 'failed' || status === 'rejected' || status === 'declined' || status === 'cancelled')) {
        return 'failed';
    }

    return paymentStatuses.includes('pending') ? 'pending' : String(report?.payment_status || 'pending');
}

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

        const { latitude, longitude, address_description, garbage_type, sack_count, photo_url } = value;
        const unitPrice = parseFloat(process.env.SACK_PRICE_UGX || 500);
        const paymentAmount = sack_count * unitPrice;

        // Create report
        const reportData = {
            resident_id: req.user.id,
            location: `POINT(${longitude} ${latitude})`,
            address_description,
            garbage_type,
            sack_count,
            estimated_volume: `${sack_count} sack${sack_count === 1 ? '' : 's'}`,
            photo_url,
            status: 'pending',
            payment_required: true,
            payment_amount: paymentAmount,
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
                sack_count: report.sack_count,
                status: report.status,
                payment_amount: report.payment_amount,
                currency: 'UGX'
            }
        });

        await createNotification({
            userId: req.user.id,
            title: 'Report submitted',
            message: `Your report at ${address_description} was created successfully.`,
            type: 'report',
            data: {
                report_id: report.id,
                status: report.status,
            },
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

        // For each report, extract coordinates using raw SQL
        const reportsWithCoords = await Promise.all(reports.map(async (report) => {
            try {
                const { data: coords } = await supabase
                    .rpc('exec_sql', { 
                        sql: `SELECT ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng FROM garbage_reports WHERE id = '${report.id}'`
                    });
                
                return {
                    ...report,
                    latitude: coords?.[0]?.lat || null,
                    longitude: coords?.[0]?.lng || null
                };
            } catch (err) {
                // Return report with null coordinates if extraction fails
                return { ...report, latitude: null, longitude: null };
            }
        }));

        res.json({
            success: true,
            data: { reports: reportsWithCoords }
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

        const normalizeWithCoords = async (rows) => {
            const safeRows = Array.isArray(rows) ? rows : [];
            const missingCoordIds = safeRows
                .filter((row) => (row.latitude == null || row.longitude == null) && row.id)
                .map((row) => String(row.id).replace(/'/g, "''"));

            if (missingCoordIds.length === 0) {
                return safeRows;
            }

            const sql = `
                SELECT id::text AS id,
                       ST_Y(location::geometry) AS lat,
                       ST_X(location::geometry) AS lng
                FROM garbage_reports
                WHERE id IN (${missingCoordIds.map((id) => `'${id}'`).join(',')})
            `;

            const { data: coordsData } = await supabase.rpc('exec_sql', { sql });
            const coordsMap = (coordsData || []).reduce((acc, entry) => {
                acc[entry.id] = {
                    latitude: entry.lat,
                    longitude: entry.lng,
                };
                return acc;
            }, {});

            return safeRows.map((row) => ({
                ...row,
                latitude: row.latitude ?? coordsMap[row.id]?.latitude ?? null,
                longitude: row.longitude ?? coordsMap[row.id]?.longitude ?? null,
            }));
        };

        const fetchAllPendingReports = async () => {
            const { data: allReports, error: fetchError } = await supabase
                .from('garbage_reports')
                .select(`
                    *,
                    payments (
                        id,
                        payment_status,
                        transaction_id
                    ),
                    resident:users!garbage_reports_resident_id_fkey (
                        full_name,
                        phone_number
                    )
                `)
                .eq('status', 'pending')
                .order('reported_at', { ascending: false })
                .limit(200);

            if (fetchError) throw fetchError;

            const reportsWithCoords = await normalizeWithCoords((allReports || []).map((row) => ({
                ...row,
                payment_status: derivePaymentStatus(row),
            })));

            return reportsWithCoords;
        };

        if (error) {
            const reportsWithCoords = await fetchAllPendingReports();
            return res.json({
                success: true,
                data: { reports: reportsWithCoords }
            });
        }

        let reportsWithCoords = await normalizeWithCoords(reports || []);

        if (reportsWithCoords.length === 0) {
            reportsWithCoords = await fetchAllPendingReports();
        }

        res.json({
            success: true,
            data: { reports: reportsWithCoords }
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

        // Check if payment is successful (support multiple normalized success variants)
        const hasSuccessfulPayment = (report.payments || []).some((payment) =>
            SUCCESSFUL_PAYMENT_STATUSES.includes(String(payment?.payment_status || '').toLowerCase())
        );
        if (report.payment_required !== false && !hasSuccessfulPayment) {
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

        await createNotification({
            userId: report.resident_id,
            title: 'Collector assigned',
            message: 'A collector has been assigned to your garbage report.',
            type: 'assignment',
            data: {
                report_id: id,
                status: 'assigned',
                collector_id: req.user.id,
            },
            sendSms: true,
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
            // Some environments don't have started_at; keep transition portable.
            updateData.updated_at = new Date().toISOString();
        } else if (status === 'completed') {
            updateData.completed_at = new Date().toISOString();
            updateData.updated_at = new Date().toISOString();
        } else {
            updateData.updated_at = new Date().toISOString();
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

        if (report.resident_id) {
            await createNotification({
                userId: report.resident_id,
                title: 'Report status updated',
                message: `Your report status is now ${status.replace('_', ' ')}.`,
                type: 'report',
                data: {
                    report_id: report.id,
                    status,
                },
                sendSms: status === 'completed',
            });
        }

    } catch (error) {
        next(error);
    }
});

module.exports = router;
