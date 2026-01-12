/**
 * Global Error Handler Middleware
 */

function errorHandler(err, req, res, next) {
    console.error('❌ Error:', err);

    // Default error
    let statusCode = err.statusCode || 500;
    let message = err.message || 'Internal Server Error';

    // Validation errors (Joi)
    if (err.isJoi) {
        statusCode = 400;
        message = err.details[0].message;
    }

    // Supabase errors
    if (err.code === 'PGRST') {
        statusCode = 400;
        message = 'Database error: ' + err.message;
    }

    // JWT errors
    if (err.name === 'JsonWebTokenError') {
        statusCode = 401;
        message = 'Invalid token';
    }

    if (err.name === 'TokenExpiredError') {
        statusCode = 401;
        message = 'Token expired';
    }

    res.status(statusCode).json({
        success: false,
        message: message,
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
}

module.exports = errorHandler;
