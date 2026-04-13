/**
 * Authentication Routes
 * Handles user registration and login
 */

const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const bcrypt = require('bcryptjs');
const { supabase } = require('../config/supabase');
const { sendSMS } = require('../config/smsService');
const { createNotification } = require('../services/notificationService');

// Validation schemas
const registerSchema = Joi.object({
    username: Joi.string().trim().min(3).max(30).pattern(/^[a-zA-Z0-9_.-]+$/).required()
        .messages({ 'string.pattern.base': 'Username can only contain letters, numbers, _, ., -' }),
    password: Joi.string().min(8).max(128).required(),
    phone_number: Joi.string().pattern(/^\+256[0-9]{9}$/).required()
        .messages({ 'string.pattern.base': 'Phone must be in format +256XXXXXXXXX' }),
    full_name: Joi.string().min(2).max(100).required(),
    user_type: Joi.string().valid('resident', 'collector').required(),
    email: Joi.string().email().allow(null, '').optional(),
    area: Joi.string().max(100).allow(null, '').optional(),
    latitude: Joi.number().min(-90).max(90).allow(null).optional(),
    longitude: Joi.number().min(-180).max(180).allow(null).optional()
});

const loginSchema = Joi.object({
    username: Joi.string().trim().min(3).max(30).required(),
    password: Joi.string().min(8).max(128).required()
});

const setPasswordSchema = Joi.object({
    username: Joi.string().trim().min(3).max(30).required(),
    phone_number: Joi.string().pattern(/^\+256[0-9]{9}$/).required()
        .messages({ 'string.pattern.base': 'Phone must be in format +256XXXXXXXXX' }),
    new_password: Joi.string().min(8).max(128).required(),
});

function getAdminConfig() {
    const username = String(process.env.ADMIN_USERNAME || 'gfcadmin').trim().toLowerCase();
    const password = String(process.env.ADMIN_PASSWORD || 'gfcadmin1234');
    const fullName = String(process.env.ADMIN_FULL_NAME || 'GFC Administrator').trim();
    const phoneNumber = String(process.env.ADMIN_PHONE_NUMBER || '+256700000000').trim();

    return {
        username,
        password,
        fullName,
        phoneNumber,
    };
}

async function getOrCreateAdminUser(config) {
    const { data: existingAdmin, error: fetchError } = await supabase
        .from('users')
        .select('*')
        .eq('username', config.username)
        .single();

    if (existingAdmin) {
        if (existingAdmin.user_type !== 'admin' || existingAdmin.is_admin !== true || !existingAdmin.is_active) {
            const { data: updatedAdmin, error: updateError } = await supabase
                .from('users')
                .update({
                    user_type: 'admin',
                    is_admin: true,
                    is_active: true,
                    full_name: existingAdmin.full_name || config.fullName,
                    phone_number: existingAdmin.phone_number || config.phoneNumber,
                    updated_at: new Date().toISOString(),
                })
                .eq('id', existingAdmin.id)
                .select('*')
                .single();

            if (updateError) throw updateError;
            return updatedAdmin;
        }

        return existingAdmin;
    }

    if (fetchError && fetchError.code !== 'PGRST116') {
        throw fetchError;
    }

    const passwordHash = await bcrypt.hash(config.password, 10);
    const { data: newAdmin, error: insertError } = await supabase
        .from('users')
        .insert([
            {
                username: config.username,
                password_hash: passwordHash,
                phone_number: config.phoneNumber,
                full_name: config.fullName,
                user_type: 'admin',
                is_admin: true,
                is_active: true,
                area: 'KCCA HQ',
            },
        ])
        .select('*')
        .single();

    if (insertError) throw insertError;
    return newAdmin;
}

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

        const { username, password, phone_number, full_name, user_type, email, area, latitude, longitude } = value;
        const normalizedUsername = username.toLowerCase();

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

        const { data: existingUsername } = await supabase
            .from('users')
            .select('id')
            .eq('username', normalizedUsername)
            .single();

        if (existingUsername) {
            return res.status(400).json({
                success: false,
                message: 'Username already taken'
            });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        // Prepare user data
        const userData = {
            username: normalizedUsername,
            password_hash: passwordHash,
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

        await createNotification({
            userId: newUser.id,
            title: 'Welcome to GFC',
            message: `Hello ${newUser.full_name}, your account is active.`,
            type: 'system',
        });

        res.status(201).json({
            success: true,
            message: 'Registration successful',
            data: {
                user: {
                    id: newUser.id,
                    username: newUser.username,
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
 * Username + password login
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

        const { username, password } = value;
        const normalizedUsername = username.toLowerCase();

        const adminConfig = getAdminConfig();
        if (normalizedUsername === adminConfig.username && password === adminConfig.password) {
            const adminUser = await getOrCreateAdminUser(adminConfig);

            const token = jwt.sign(
                { userId: adminUser.id, userType: 'admin' },
                process.env.JWT_SECRET,
                { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
            );

            return res.json({
                success: true,
                message: 'Admin login successful',
                data: {
                    user: {
                        id: adminUser.id,
                        username: adminUser.username,
                        phone_number: adminUser.phone_number,
                        full_name: adminUser.full_name,
                        user_type: 'admin',
                        area: adminUser.area,
                    },
                    token,
                },
            });
        }

        // Find user
        const { data: user, error: fetchError } = await supabase
            .from('users')
            .select('*')
            .eq('username', normalizedUsername)
            .single();

        if (fetchError || !user) {
            return res.status(401).json({
                success: false,
                message: 'Invalid username or password'
            });
        }

        const isValidPassword = user.password_hash
            ? await bcrypt.compare(password, user.password_hash)
            : false;

        if (!isValidPassword) {
            return res.status(401).json({
                success: false,
                message: 'Invalid username or password'
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
                    username: user.username,
                    phone_number: user.phone_number,
                    full_name: user.full_name,
                    user_type: user.user_type,
                    area: user.area
                },
                token
            }
        });

        await createNotification({
            userId: user.id,
            title: 'Login successful',
            message: 'You have signed in to Garbage Free City.',
            type: 'system',
        });

    } catch (error) {
        next(error);
    }
});

/**
 * POST /api/auth/set-password
 * Set or reset password for an existing account.
 */
router.post('/set-password', async (req, res, next) => {
    try {
        const { error, value } = setPasswordSchema.validate(req.body);
        if (error) {
            return res.status(400).json({
                success: false,
                message: error.details[0].message,
            });
        }

        const { username, phone_number, new_password } = value;
        const normalizedUsername = username.toLowerCase();

        const { data: user, error: fetchError } = await supabase
            .from('users')
            .select('id, username, full_name, phone_number, is_active')
            .eq('username', normalizedUsername)
            .eq('phone_number', phone_number)
            .single();

        if (fetchError || !user) {
            return res.status(404).json({
                success: false,
                message: 'Account not found for provided username and phone number',
            });
        }

        if (!user.is_active) {
            return res.status(403).json({
                success: false,
                message: 'Account is deactivated. Contact KCCA support.',
            });
        }

        const passwordHash = await bcrypt.hash(new_password, 10);

        const { error: updateError } = await supabase
            .from('users')
            .update({ password_hash: passwordHash })
            .eq('id', user.id);

        if (updateError) {
            throw updateError;
        }

        await createNotification({
            userId: user.id,
            title: 'Password updated',
            message: 'Your password was set successfully.',
            type: 'system',
        });

        await sendSMS(
            user.phone_number,
            'Your GFC account password was updated successfully. If this was not you, contact KCCA support immediately.'
        );

        return res.json({
            success: true,
            message: 'Password set successfully. You can now login.',
        });
    } catch (err) {
        return next(err);
    }
});

module.exports = router;
