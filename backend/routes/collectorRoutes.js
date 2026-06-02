/**
 * Collector Routes
 * Handles collector-specific operations
 */

const express = require('express');
const router = express.Router();
const Joi = require('joi');
const QRCode = require('qrcode');
const { supabase } = require('../config/supabase');
const { authenticateToken, requireUserType } = require('../middleware/auth');
const { createNotification } = require('../services/notificationService');

function formatSmsTemplate(template, variables) {
    return String(template || '').replace(/\{(\w+)\}/g, (_, key) => String(variables?.[key] ?? ''));
}

const updateProfileSchema = Joi.object({
    full_name: Joi.string().min(2).max(100).optional(),
    area: Joi.string().max(100).allow('', null).optional(),
    is_active: Joi.boolean().optional(),
}).or('full_name', 'area', 'is_active');

function parseCoordinatesFromLocation(locationValue) {
    if (!locationValue) {
        return { latitude: null, longitude: null };
    }

    if (typeof locationValue === 'string') {
        // Handles POINT(lng lat)
        const pointMatch = locationValue.match(/POINT\s*\(([-\d.]+)\s+([-\d.]+)\)/i);
        if (pointMatch) {
            return {
                latitude: Number(pointMatch[2]),
                longitude: Number(pointMatch[1]),
            };
        }
    }

    if (typeof locationValue === 'object') {
        const latitude = Number(locationValue.lat ?? locationValue.latitude ?? locationValue.y);
        const longitude = Number(locationValue.lng ?? locationValue.longitude ?? locationValue.x);
        if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
            return { latitude, longitude };
        }
    }

    return { latitude: null, longitude: null };
}

function normalizeWeeklyCollections(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

function scheduleForWeeklyCollections(weeklyCollections) {
    if (weeklyCollections === 1) {
        return { label: 'Tuesday', days: [2] };
    }

    if (weeklyCollections === 2) {
        return { label: 'Tuesday, Thursday', days: [2, 4] };
    }

    return { label: 'Custom', days: [] };
}

async function getScheduleForSubscription(subscriptionId) {
    if (!subscriptionId) {
        return null;
    }

    const { data, error } = await supabase
        .from('subscriptions')
        .select('id, plan:subscription_plans(weekly_collections)')
        .eq('id', subscriptionId)
        .maybeSingle();

    if (error) {
        throw error;
    }

    const weeklyCollections = normalizeWeeklyCollections(data?.plan?.weekly_collections);
    return weeklyCollections == null ? null : scheduleForWeeklyCollections(weeklyCollections);
}

async function attachReportCoordinates(reports) {
    if (!Array.isArray(reports) || reports.length === 0) {
        return [];
    }

    const reportIds = reports
        .map((report) => report.id)
        .filter(Boolean);

    if (reportIds.length === 0) {
        return reports;
    }

    const escapedIds = reportIds
        .map((id) => String(id).replace(/'/g, "''"))
        .map((id) => `'${id}'`)
        .join(',');

    const sql = `
        SELECT id::text AS id,
               ST_Y(location::geometry) AS lat,
               ST_X(location::geometry) AS lng
        FROM garbage_reports
        WHERE id IN (${escapedIds})
    `;

    const { data: coordsData } = await supabase.rpc('exec_sql', { sql });

    const coordMap = (coordsData || []).reduce((acc, row) => {
        acc[row.id] = {
            latitude: row.lat ?? null,
            longitude: row.lng ?? null,
        };
        return acc;
    }, {});

    return reports.map((report) => ({
        ...report,
        latitude: coordMap[report.id]?.latitude ?? parseCoordinatesFromLocation(report.location).latitude,
        longitude: coordMap[report.id]?.longitude ?? parseCoordinatesFromLocation(report.location).longitude,
    }));
}

/**
 * PATCH /api/collectors/location
 * Update collector's current location
 */
router.patch('/location', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const { latitude, longitude } = req.body;

        if (!latitude || !longitude) {
            return res.status(400).json({
                success: false,
                message: 'Latitude and longitude required'
            });
        }

        const { error } = await supabase
            .from('users')
            .update({
                current_location: `POINT(${longitude} ${latitude})`,
                updated_at: new Date().toISOString()
            })
            .eq('id', req.user.id);

        if (error) {
            throw error;
        }

        res.json({
            success: true,
            message: 'Location updated'
        });

    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/collectors/my-assignments
 * Get collector's assigned reports
 */
router.get('/my-assignments', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const { data: reports, error } = await supabase
            .from('garbage_reports')
            .select(`
                *,
                resident:users!garbage_reports_resident_id_fkey (
                    full_name,
                    phone_number,
                    area
                )
            `)
            .eq('assigned_collector_id', req.user.id)
            .in('status', ['assigned', 'in_progress'])
            .order('assigned_at', { ascending: true });

        if (error) {
            throw error;
        }

        const reportsWithCoords = await attachReportCoordinates(reports || []);

        res.json({
            success: true,
            data: { reports: reportsWithCoords }
        });

    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/collectors/collection-history
 * Get collector completed collection history with filters
 */
router.get('/collection-history', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const period = String(req.query.period || 'week').toLowerCase();
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
                resident:users!garbage_reports_resident_id_fkey (
                    full_name,
                    phone_number,
                    area
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
            .eq('assigned_collector_id', req.user.id)
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
 * POST /api/collectors/verify-collection
 * Verify collection with QR code scan
 */
router.post('/verify-collection', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const { report_id, latitude, longitude, qr_code_data } = req.body;

        if (!report_id || !latitude || !longitude) {
            return res.status(400).json({
                success: false,
                message: 'Report ID and location required'
            });
        }

        let parsedQr = null;
        try {
            parsedQr = JSON.parse(String(qr_code_data || ''));
        } catch (_) {
            return res.status(400).json({
                success: false,
                message: 'Invalid QR payload. Scan a resident report QR code.',
            });
        }

        const qrReportId = parsedQr?.report_id ? String(parsedQr.report_id) : null;
        if (!qrReportId || qrReportId !== String(report_id)) {
            return res.status(400).json({
                success: false,
                message: 'QR code does not match this assignment report.',
            });
        }

        if (parsedQr?.app && parsedQr.app !== 'GFC') {
            return res.status(400).json({
                success: false,
                message: 'Unsupported QR code source.',
            });
        }

        // Verify report is assigned to this collector
        const { data: report, error: reportError } = await supabase
            .from('garbage_reports')
            .select('*')
            .eq('id', report_id)
            .eq('assigned_collector_id', req.user.id)
            .single();

        if (reportError || !report) {
            return res.status(404).json({
                success: false,
                message: 'Report not found or not assigned to you'
            });
        }

        if (report.status !== 'in_progress') {
            return res.status(400).json({
                success: false,
                message: 'Report must be in progress before final QR verification.',
            });
        }

        const scheduleInfo = await getScheduleForSubscription(report.subscription_id);
        const scheduleLabel = scheduleInfo?.label ?? null;
        const scheduleDays = scheduleInfo?.days ?? [];
        const completionDay = new Date().getDay();
        const outOfSchedule = scheduleDays.length > 0 && !scheduleDays.includes(completionDay);

        // Create collection log
        const { data: collectionLog, error: logError } = await supabase
            .from('collection_logs')
            .insert([{
                report_id,
                collector_id: req.user.id,
                qr_code_scanned: !!qr_code_data,
                qr_scan_timestamp: qr_code_data ? new Date().toISOString() : null,
                collection_location: `POINT(${longitude} ${latitude})`,
                scheduled_days: scheduleLabel,
                out_of_schedule: outOfSchedule,
                started_at: new Date().toISOString(),
                completed_at: new Date().toISOString()
            }])
            .select()
            .single();

        if (logError) {
            throw logError;
        }

        // Update report status to completed
        await supabase
            .from('garbage_reports')
            .update({
                status: 'completed',
                completed_at: new Date().toISOString()
            })
            .eq('id', report_id);

        if (report.subscription_id) {
            const nowIso = new Date().toISOString();
            const { data: subscription, error: subscriptionError } = await supabase
                .from('subscriptions')
                .select('id, status, remaining_collections, end_date')
                .eq('id', report.subscription_id)
                .maybeSingle();

            if (subscriptionError) {
                throw subscriptionError;
            }

            if (subscription) {
                const remaining = Math.max(0, Number(subscription.remaining_collections || 0) - 1);
                const shouldExpire = remaining <= 0 || (subscription.end_date && subscription.end_date < nowIso);

                await supabase
                    .from('subscriptions')
                    .update({
                        remaining_collections: remaining,
                        status: shouldExpire ? 'expired' : subscription.status,
                        last_collection_at: nowIso,
                        updated_at: nowIso,
                    })
                    .eq('id', subscription.id);
            }
        }

        res.json({
            success: true,
            message: 'Collection verified successfully',
            data: {
                collection_log: collectionLog,
                schedule: {
                    scheduled_days: scheduleLabel,
                    out_of_schedule: outOfSchedule,
                },
            }
        });

        await createNotification({
            userId: req.user.id,
            title: 'Collection logged',
            message: 'Collection verification has been recorded successfully.',
            type: 'collection',
            data: {
                report_id,
                collection_log_id: collectionLog.id,
            },
        });

        if (report.resident_id) {
            await createNotification({
                userId: report.resident_id,
                title: 'Collection completed',
                message: formatSmsTemplate(
                    process.env.SMS_COLLECTION_COMPLETED || 'Collection completed at {location}. Thank you for using GFC! -KCCA GFC',
                    { location: report.address_description || 'your location' }
                ),
                type: 'collection',
                data: { report_id },
                sendSms: true,
            });
        }

    } catch (error) {
        next(error);
    }
});

/**
 * GET /api/collectors/profile
 * Get collector profile with live stats
 */
router.get('/profile', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const [{ count: assignedCount, error: assignedError }, { count: inProgressCount, error: inProgressError }, { count: completedCount, error: completedError }, { data: completedRows, error: completedRowsError }] = await Promise.all([
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .eq('assigned_collector_id', req.user.id)
                .eq('status', 'assigned'),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .eq('assigned_collector_id', req.user.id)
                .eq('status', 'in_progress'),
            supabase
                .from('garbage_reports')
                .select('*', { count: 'exact', head: true })
                .eq('assigned_collector_id', req.user.id)
                .eq('status', 'completed'),
            supabase
                .from('garbage_reports')
                .select('payment_amount')
                .eq('assigned_collector_id', req.user.id)
                .eq('status', 'completed'),
        ]);

        if (assignedError || inProgressError || completedError || completedRowsError) {
            throw assignedError || inProgressError || completedError || completedRowsError;
        }

        const managedValue = (completedRows || []).reduce((sum, row) => {
            const amount = Number(row.payment_amount || 0);
            return sum + (Number.isFinite(amount) ? amount : 0);
        }, 0);

        return res.json({
            success: true,
            data: {
                profile: {
                    id: req.user.id,
                    username: req.user.username,
                    full_name: req.user.full_name,
                    phone_number: req.user.phone_number,
                    area: req.user.area,
                    is_active: req.user.is_active,
                    created_at: req.user.created_at,
                },
                stats: {
                    assigned_count: assignedCount || 0,
                    in_progress_count: inProgressCount || 0,
                    completed_count: completedCount || 0,
                    managed_value_ugx: managedValue,
                },
            },
        });
    } catch (error) {
        return next(error);
    }
});

/**
 * PATCH /api/collectors/profile
 * Update collector profile/settings fields
 */
router.patch('/profile', authenticateToken, requireUserType('collector'), async (req, res, next) => {
    try {
        const { error: validationError, value } = updateProfileSchema.validate(req.body || {});
        if (validationError) {
            return res.status(400).json({
                success: false,
                message: validationError.details[0].message,
            });
        }

        const updateData = {
            updated_at: new Date().toISOString(),
        };

        if (Object.prototype.hasOwnProperty.call(value, 'full_name')) {
            updateData.full_name = value.full_name;
        }
        if (Object.prototype.hasOwnProperty.call(value, 'area')) {
            updateData.area = value.area;
        }
        if (Object.prototype.hasOwnProperty.call(value, 'is_active')) {
            updateData.is_active = value.is_active;
        }

        const { data: updatedUser, error } = await supabase
            .from('users')
            .update(updateData)
            .eq('id', req.user.id)
            .select('id, username, full_name, phone_number, area, is_active, updated_at')
            .single();

        if (error) throw error;

        return res.json({
            success: true,
            message: 'Profile updated successfully',
            data: { profile: updatedUser },
        });
    } catch (error) {
        return next(error);
    }
});

/**
 * GET /api/collectors/qr-code/:reportId
 * Generate QR code for a report
 */
router.get('/qr-code/:reportId', authenticateToken, async (req, res, next) => {
    try {
        const { reportId } = req.params;

        // Generate QR code data
        const qrData = JSON.stringify({
            report_id: reportId,
            timestamp: new Date().toISOString(),
            app: 'GFC'
        });

        // Generate QR code as data URL
        const qrCodeDataURL = await QRCode.toDataURL(qrData);

        res.json({
            success: true,
            data: {
                qr_code: qrCodeDataURL,
                qr_data: qrData
            }
        });

    } catch (error) {
        next(error);
    }
});

module.exports = router;
