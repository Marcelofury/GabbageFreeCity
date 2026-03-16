/**
 * Payment Routes
 * MarzPay mobile money flow for MTN and Airtel Uganda.
 */

const express = require('express');
const router = express.Router();
const { authenticateToken, requireUserType } = require('../middleware/auth');
const paymentController = require('../controllers/paymentController');

function requireAdmin(req, res, next) {
    const adminUserIds = (process.env.ADMIN_USER_IDS || '')
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);

    const isAdmin = req.user?.is_admin === true || adminUserIds.includes(req.user?.id);
    if (!isAdmin) {
        return res.status(403).json({
            success: false,
            message: 'Admin access required',
        });
    }

    return next();
}

router.post('/initiate', authenticateToken, requireUserType('resident'), paymentController.initiatePayment);
router.post('/marzpay/callback', paymentController.handleMarzpayCallback);
router.post('/validate-phone', paymentController.validatePhone);
router.get('/wallet-balance', authenticateToken, requireAdmin, paymentController.getWalletBalance);
router.get('/marzpay-transactions', authenticateToken, requireAdmin, paymentController.getMarzpayTransactions);

module.exports = router;
