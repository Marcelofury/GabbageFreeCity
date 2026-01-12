/**
 * Authentication Middleware
 */

const jwt = require('jsonwebtoken');
const { supabase } = require('../config/supabase');

/**
 * Verify JWT token and attach user to request
 */
async function authenticateToken(req, res, next) {
    try {
        const authHeader = req.headers['authorization'];
        const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Access token required'
            });
        }

        // Verify JWT
        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        // Fetch user from database
        const { data: user, error } = await supabase
            .from('users')
            .select('*')
            .eq('id', decoded.userId)
            .single();

        if (error || !user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid token or user not found'
            });
        }

        if (!user.is_active) {
            return res.status(403).json({
                success: false,
                message: 'Account is deactivated'
            });
        }

        // Attach user to request
        req.user = user;
        next();

    } catch (error) {
        return res.status(401).json({
            success: false,
            message: 'Invalid or expired token'
        });
    }
}

/**
 * Require specific user type (resident or collector)
 */
function requireUserType(...allowedTypes) {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        if (!allowedTypes.includes(req.user.user_type)) {
            return res.status(403).json({
                success: false,
                message: `Access denied. Required role: ${allowedTypes.join(' or ')}`
            });
        }

        next();
    };
}

module.exports = {
    authenticateToken,
    requireUserType
};
