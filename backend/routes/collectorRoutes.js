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

        res.json({
            success: true,
            data: { reports }
        });

    } catch (error) {
        next(error);
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

        // Create collection log
        const { data: collectionLog, error: logError } = await supabase
            .from('collection_logs')
            .insert([{
                report_id,
                collector_id: req.user.id,
                qr_code_scanned: !!qr_code_data,
                qr_scan_timestamp: qr_code_data ? new Date().toISOString() : null,
                collection_location: `POINT(${longitude} ${latitude})`,
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

        res.json({
            success: true,
            message: 'Collection verified successfully',
            data: { collection_log: collectionLog }
        });

    } catch (error) {
        next(error);
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
