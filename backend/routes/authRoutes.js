/**
 * Authentication Routes
 * Handles user registration and login
 */

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const { supabase } = require('../config/supabase');
const { sendSMS } = require('../config/africasTalking');

// Validation schemas
const registerSchema = Joi.object({
    phone_number: Joi.string().pattern(/^\+256[0-9]{9}$/).required()
        .messages({ 'string.pattern.base': 'Phone must be in format +256XXXXXXXXX' }),
    full_name: Joi.string().min(2).max(100).required(),
    user_type: Joi.string().valid('resident', 'collector').required(),
    email: Joi.string().email().optional(),
    area: Joi.string().max(100).optional(),
    latitude: Joi.number().min(-90).max(90).optional(),
    longitude: Joi.number().min(-180).max(180).optional()
});

const loginSchema = Joi.object({
    phone_number: Joi.string().pattern(/^\+256[0-9]{9}$/).required()
});

/**
 * POST /api/auth/register
 * Register a new user (resident or collector)
 */
router.post('/register', async (req, res, next) => {
    try {
        // Validate input
        const { error, value } = registerSchema.validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                message: error.details[0].message
            });
        }

        const { phone_number, full_name, user_type, email, area, latitude, longitude } = value;

        // Check if user already exists
        const { data: existingUser } = await supabase
            .from('users')
            .select('id')
            .eq('phone_number', phone_number)
            .single();

        if (existingUser) {
            return res.status(400).json({
                success: false,
                message: 'Phone number already registered'
            });
        }

        // Prepare user data
        const userData = {
            phone_number,
            full_name,
            user_type,
            email,
            area,
            is_active: true
        };

        // Add location if provided (for residents)
        if (latitude && longitude && user_type === 'resident') {
            userData.home_location = `POINT(${longitude} ${latitude})`;
        }

        // Insert user
        const { data: newUser, error: insertError } = await supabase
            .from('users')
            .insert([userData])
            .select()
            .single();

        if (insertError) {
            throw insertError;
        }

        // Generate JWT token
        const token = jwt.sign(
            { userId: newUser.id, userType: user_type },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        // Send welcome SMS
        await sendSMS(
            phone_number,
            `Welcome to GFC ${full_name}! Your account is ready. Start reporting garbage pile-ups in Kampala. -KCCA GFC`
        );

        res.status(201).json({
            success: true,
            message: 'Registration successful',
            data: {
                user: {
                    id: newUser.id,
                    phone_number: newUser.phone_number,
                    full_name: newUser.full_name,
                    user_type: newUser.user_type,
                    area: newUser.area
                },
                token
            }
        });

    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/auth/login
 * Simple phone number login (no password for MVP)
 */
router.post('/login', async (req, res, next) => {
    try {
        // Validate input
        const { error, value } = loginSchema.validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                message: error.details[0].message
            });
        }

        const { phone_number } = value;

        // Find user
        const { data: user, error: fetchError } = await supabase
            .from('users')
            .select('*')
            .eq('phone_number', phone_number)
            .single();

        if (fetchError || !user) {
            return res.status(401).json({
                success: false,
                message: 'Phone number not registered'
            });
        }

        if (!user.is_active) {
            return res.status(403).json({
                success: false,
                message: 'Account is deactivated. Contact KCCA support.'
            });
        }

        // Generate JWT token
        const token = jwt.sign(
            { userId: user.id, userType: user.user_type },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
        );

        res.json({
            success: true,
            message: 'Login successful',
            data: {
                user: {
                    id: user.id,
                    phone_number: user.phone_number,
                    full_name: user.full_name,
                    user_type: user.user_type,
                    area: user.area
                },
                token
            }
        });

    } catch (error) {
        next(error);
    }
});

module.exports = router;
