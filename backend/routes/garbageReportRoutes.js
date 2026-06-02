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

function formatSmsTemplate(template, variables) {
    return String(template || '').replace(/\{(\w+)\}/g, (_, key) => String(variables?.[key] ?? ''));
}

function parseCoordinatesFromLocation(locationValue) {
    if (!locationValue || typeof locationValue !== 'string') {
        return { latitude: null, longitude: null };
    }

    const pointMatch = locationValue.match(/POINT\s*\(([-\d.]+)\s+([-\d.]+)\)/i);
    if (!pointMatch) {
        return { latitude: null, longitude: null };
    }

    return {
        latitude: Number(pointMatch[2]),
        longitude: Number(pointMatch[1]),
    };
}

// Validation schema
const createReportSchema = Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    address_description: Joi.string().max(500).required(),
    garbage_type: Joi.string().valid('mixed', 'plastic', 'organic', 'electronic', 'hazardous').default('mixed'),
    package_count: Joi.number().integer().min(1).max(100).required(),
    photo_url: Joi.string().uri().allow('', null).optional()
});

const SUCCESSFUL_PAYMENT_STATUSES = ['successful', 'completed', 'paid', 'success'];

async function getActiveSubscription(residentId) {
    const nowIso = new Date().toISOString();

    const { data, error } = await supabase
        .from('subscriptions')
        .select('id, status, end_date, remaining_collections')
        .eq('resident_id', residentId)
        .eq('status', 'active')
        .gte('end_date', nowIso)
        .gt('remaining_collections', 0)
        .order('end_date', { ascending: true })
        .limit(1)
        .maybeSingle();

    if (error) {
        throw error;
    }

    return data || null;
}

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

        const { latitude, longitude, address_description, garbage_type, package_count, photo_url } = value;

        const activeSubscription = await getActiveSubscription(req.user.id);
        if (!activeSubscription) {
            return res.status(403).json({
                success: false,
                message: 'Active subscription required before reporting garbage.',
            });
        }

        // Create report
        const reportData = {
            resident_id: req.user.id,
            location: `POINT(${longitude} ${latitude})`,
            address_description,
            garbage_type,
            package_count,
            estimated_volume: `${package_count} package${package_count === 1 ? '' : 's'}`,
            photo_url,
            status: 'pending',
            payment_required: false,
            payment_amount: 0,
            payment_status: 'completed',
            subscription_id: activeSubscription.id,
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
                package_count: report.package_count,
                status: report.status,
                payment_amount: report.payment_amount,
                currency: 'UGX'
            }
        });

        await createNotification({
            userId: req.user.id,
            title: 'Report submitted',
            message: formatSmsTemplate(
                process.env.SMS_REPORT_CREATED || 'Hello {name}, your report at {location} was submitted successfully. -KCCA GFC',
                {
                    name: req.user.full_name || 'Resident',
                    location: address_description,
                }
            ),
            type: 'report',
            data: {
                report_id: report.id,
                status: report.status,
            },
            sendSms: true,
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
 * GET /api/garbage-reports/my-collections
 * Get resident completed collection history with proof details
 */
router.get('/my-collections', authenticateToken, requireUserType('resident'), async (req, res, next) => {
    try {
        const period = String(req.query.period || 'month').toLowerCase();
        const validPeriods = ['week', 'month', 'all'];

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
                assigned_collector:users!garbage_reports_assigned_collector_id_fkey (
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
            .eq('resident_id', req.user.id)
            .eq('status', 'completed')
            .order('completed_at', { ascending: false });

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

        const normalizedReports = (reports || []).map((report) => {
            const logArray = Array.isArray(report.collection_log) ? report.collection_log : [];
            return {
                ...report,
                collection_log: logArray[0] || null,
            };
        });

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

        if (!report.subscription_id) {
            return res.status(400).json({
                success: false,
                message: 'Active subscription required for collection assignment'
            });
        }

        const { data: subscription, error: subscriptionError } = await supabase
            .from('subscriptions')
            .select('status, end_date, remaining_collections')
            .eq('id', report.subscription_id)
            .maybeSingle();

        if (subscriptionError) {
            throw subscriptionError;
        }

        const nowIso = new Date().toISOString();
        if (!subscription || subscription.status !== 'active' || subscription.end_date < nowIso || subscription.remaining_collections <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Subscription is not active for this report'
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

        const parsedCoords = parseCoordinatesFromLocation(updatedReport.location);

        res.json({
            success: true,
            message: 'Report assigned successfully',
            data: {
                report: {
                    ...updatedReport,
                    latitude: parsedCoords.latitude,
                    longitude: parsedCoords.longitude,
                },
            }
        });

        await createNotification({
            userId: report.resident_id,
            title: 'Collector assigned',
            message: formatSmsTemplate(
                process.env.SMS_COLLECTION_ASSIGNED || 'Hello {name}, collector {collector} is on the way to {location}. -KCCA GFC',
                {
                    name: 'Resident',
                    collector: req.user.full_name || req.user.username || 'Collector',
                    location: report.address_description || 'your location',
                }
            ),
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
                message: status === 'completed'
                    ? formatSmsTemplate(
                        process.env.SMS_COLLECTION_COMPLETED || 'Collection completed at {location}. Thank you for using GFC! -KCCA GFC',
                        { location: report.address_description || 'your location' }
                    )
                    : `Your report status is now ${status.replace('_', ' ')}.`,
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
