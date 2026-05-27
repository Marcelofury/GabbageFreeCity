/**
 * Subscription Routes
 * Handles subscription plans and purchases
 */

const express = require('express');
const router = express.Router();
const { authenticateToken, requireUserType } = require('../middleware/auth');
const subscriptionController = require('../controllers/subscriptionController');

router.get('/plans', authenticateToken, subscriptionController.listPlans);
router.get('/my', authenticateToken, requireUserType('resident'), subscriptionController.getMySubscription);
router.post('/purchase', authenticateToken, requireUserType('resident'), subscriptionController.purchaseSubscription);
router.post('/run-due-check', subscriptionController.runDueCheck);

module.exports = router;
