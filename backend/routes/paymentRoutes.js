/**
 * Payment Routes
 * MarzPay mobile money flow for MTN and Airtel Uganda.
 */

const express = require('express');
const router = express.Router();
const { authenticateToken, requireUserType, requireAdmin } = require('../middleware/auth');
const paymentController = require('../controllers/paymentController');

router.post('/initiate', authenticateToken, requireUserType('resident'), paymentController.initiatePayment);
router.post('/marzpay/callback', paymentController.handleMarzpayCallback);
router.post('/validate-phone', paymentController.validatePhone);
router.post('/sync-status', authenticateToken, paymentController.syncPaymentStatus);
router.get('/wallet-balance', authenticateToken, requireAdmin, paymentController.getWalletBalance);
router.get('/marzpay-transactions', authenticateToken, requireAdmin, paymentController.getMarzpayTransactions);
router.post('/reconcile', authenticateToken, requireAdmin, paymentController.reconcileMarzpayPayment);

module.exports = router;
