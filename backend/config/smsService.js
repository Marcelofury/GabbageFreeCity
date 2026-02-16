/**
 * Mambo SMS Service Configuration
 * Ugandan SMS Gateway for notifications
 * API Documentation: https://mambosms.com/api-documentation
 */

const axios = require('axios');

/**
 * Send SMS notification via Mambo SMS
 * @param {string} phoneNumber - Recipient phone (+256... or 256...)
 * @param {string} message - SMS content
 * @returns {Promise<Object>} SMS result
 */
async function sendSMS(phoneNumber, message) {
    // Check if Mambo SMS is configured
    if (!process.env.MAMBO_SMS_USERNAME || !process.env.MAMBO_SMS_PASSWORD) {
        console.warn('⚠️  Mambo SMS credentials not configured - skipping SMS to', phoneNumber);
        return { success: false, message: 'SMS service not configured' };
    }

    try {
        // Format phone number (remove + prefix if present)
        const formattedPhone = phoneNumber.replace(/^\+/, '');

        // Mambo SMS API endpoint
        const apiUrl = 'https://sms.mambosms.com/api/send';

        // Prepare request parameters
        const params = {
            username: process.env.MAMBO_SMS_USERNAME,
            password: process.env.MAMBO_SMS_PASSWORD,
            sender: process.env.MAMBO_SMS_SENDER_ID || 'KCCA-GFC',
            recipients: formattedPhone,
            message: message
        };

        // Add API key if available (some providers use this for authentication)
        if (process.env.MAMBO_SMS_API_KEY) {
            params.api_key = process.env.MAMBO_SMS_API_KEY;
        }

        console.log(`📱 Sending SMS to ${phoneNumber} via Mambo SMS...`);

        // Send SMS request
        const response = await axios.get(apiUrl, { 
            params,
            timeout: 10000 // 10 second timeout
        });

        // Check response
        if (response.data && response.data.success) {
            console.log(`✅ SMS sent successfully to ${phoneNumber}`);
            return { 
                success: true, 
                result: response.data,
                messageId: response.data.messageId
            };
        } else {
            console.error('❌ Mambo SMS error:', response.data);
            return { 
                success: false, 
                error: response.data?.message || 'Failed to send SMS'
            };
        }
    } catch (error) {
        console.error('❌ SMS error:', error.message);
        return { 
            success: false, 
            error: error.message 
        };
    }
}

/**
 * Send bulk SMS to multiple recipients
 * @param {Array<string>} phoneNumbers - Array of phone numbers
 * @param {string} message - SMS content
 * @returns {Promise<Object>} SMS result
 */
async function sendBulkSMS(phoneNumbers, message) {
    if (!process.env.MAMBO_SMS_USERNAME || !process.env.MAMBO_SMS_PASSWORD) {
        console.warn('⚠️  Mambo SMS credentials not configured');
        return { success: false, message: 'SMS service not configured' };
    }

    try {
        // Format phone numbers (remove + prefix)
        const formattedPhones = phoneNumbers
            .map(phone => phone.replace(/^\+/, ''))
            .join(',');

        const apiUrl = 'https://sms.mambosms.com/api/send';

        const params = {
            username: process.env.MAMBO_SMS_USERNAME,
            password: process.env.MAMBO_SMS_PASSWORD,
            sender: process.env.MAMBO_SMS_SENDER_ID || 'KCCA-GFC',
            recipients: formattedPhones,
            message: message
        };

        // Add API key if available
        if (process.env.MAMBO_SMS_API_KEY) {
            params.api_key = process.env.MAMBO_SMS_API_KEY;
        }

        console.log(`📱 Sending bulk SMS to ${phoneNumbers.length} recipients...`);

        const response = await axios.get(apiUrl, { 
            params,
            timeout: 15000
        });

        if (response.data && response.data.success) {
            console.log(`✅ Bulk SMS sent successfully to ${phoneNumbers.length} recipients`);
            return { 
                success: true, 
                result: response.data 
            };
        } else {
            console.error('❌ Mambo SMS bulk error:', response.data);
            return { 
                success: false, 
                error: response.data?.message || 'Failed to send bulk SMS'
            };
        }
    } catch (error) {
        console.error('❌ Bulk SMS error:', error.message);
        return { 
            success: false, 
            error: error.message 
        };
    }
}

module.exports = {
    sendSMS,
    sendBulkSMS
};
