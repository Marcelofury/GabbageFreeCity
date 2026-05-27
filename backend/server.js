/**
 * GARBAGE FREE CITY (GFC) - MAIN SERVER
 * 
 * Express server for Smart Waste Management System
 * Kampala Capital City Authority (KCCA)
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// Import routes
const authRoutes = require('./routes/authRoutes');
const garbageReportRoutes = require('./routes/garbageReportRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const collectorRoutes = require('./routes/collectorRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const adminRoutes = require('./routes/adminRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');

// Import middleware
const errorHandler = require('./middleware/errorHandler');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE
// ============================================

// Trust proxy - Required for Render/Heroku deployments
app.set('trust proxy', 1);

// Security headers
app.use(helmet());

// CORS - Allow Flutter app to access API
app.use(cors({
    origin: process.env.NODE_ENV === 'production' 
        ? ['https://yourdomain.com'] 
        : '*',
    credentials: true
}));

// Request logging
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting - Prevent abuse
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// ============================================
// ROUTES
// ============================================

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'GFC Backend is running',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV
    });
});

// API Routes   
app.use('/api/auth', authRoutes);
app.use('/api/garbage-reports', garbageReportRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/collectors', collectorRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/subscriptions', subscriptionRoutes);

// 404 Handler
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        message: 'Route not found'
    });
});

// ============================================
// ERROR HANDLING
// ============================================

app.use(errorHandler);

// ============================================
// START SERVER
// ============================================

app.listen(PORT, () => {
    const smsUsername = process.env.EGO_SMS_API_USERNAME || process.env.EGO_SMS_USERNAME;
    const smsApiKey =
        process.env.EGO_SMS_API_KEY ||
        process.env.EGO_SMS_PASSWORD ||
        process.env.EGO_SMS_API_PASSWORD;
    const smsMode = String(process.env.EGO_SMS_USE_SANDBOX || '').toLowerCase() === 'true' ? 'sandbox' : 'production';

    console.log('');
    console.log('🗑️  ========================================');
    console.log('    GARBAGE FREE CITY (GFC) - BACKEND');
    console.log('    Kampala Capital City Authority');
    console.log('   ========================================');
    console.log('');
    console.log(`   🚀 Server running on port ${PORT}`);
    console.log(`   🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`   📡 API: http://localhost:${PORT}/api`);
    console.log(`   ❤️  Health: http://localhost:${PORT}/health`);
    console.log('');
    console.log('   📱 Integrations:');
    console.log(`   ✓ Supabase: ${process.env.SUPABASE_URL ? 'Connected' : '❌ Not configured'}`);
    console.log(`   ✓ MarzPay: ${process.env.MARZPAY_API_KEY ? 'Configured' : '❌ Not configured'}`);
    console.log(`   ✓ EGO SMS: ${smsUsername && smsApiKey ? `Configured (${smsMode})` : '❌ Not configured'}`);
    console.log('');
    console.log('   Press Ctrl+C to stop');
    console.log('   ========================================');
    console.log('');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
    });
});

module.exports = app;
