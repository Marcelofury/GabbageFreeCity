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
const flutterwaveWebhook = require('./webhooks/flutterwaveWebhook');

// Import middleware
const errorHandler = require('./middleware/errorHandler');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE
// ============================================

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

// Webhook Routes (no rate limiting for webhooks)
app.use('/webhooks', flutterwaveWebhook.router);

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
    console.log(`   ✓ Flutterwave: ${process.env.FLUTTERWAVE_SECRET_KEY ? 'Connected' : '❌ Not configured'}`);
    console.log(`   ✓ Africa\'s Talking: ${process.env.AFRICAS_TALKING_API_KEY ? 'Connected' : '❌ Not configured'}`);
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
