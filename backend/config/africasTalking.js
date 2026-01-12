/**
 * Africa's Talking SMS Service Configuration
 */

const credentials = {
    apiKey: process.env.AFRICAS_TALKING_API_KEY,
    username: process.env.AFRICAS_TALKING_USERNAME || 'sandbox'
};

let smsService = null;

// Initialize Africa's Talking only if credentials are available
if (credentials.apiKey && credentials.username) {
    const AfricasTalking = require('africastalking')(credentials);
    smsService = AfricasTalking.SMS;
    console.log('✅ Africa\'s Talking SMS service initialized');
} else {
    console.warn('⚠️  Africa\'s Talking credentials not configured - SMS disabled');
}

/**
 * Send SMS notification
 * @param {string} phoneNumber - Recipient phone (+256...)
 * @param {string} message - SMS content
 * @returns {Promise<Object>} SMS result
 */
async function sendSMS(phoneNumber, message) {
    if (!smsService) {
        console.warn('SMS service not available - skipping SMS to', phoneNumber);
        return { success: false, message: 'SMS service not configured' };
    }

    try {
        const options = {
            to: [phoneNumber],
            message: message,
            from: process.env.AFRICAS_TALKING_SENDER_ID || 'KCCA-GFC'
        };

        const result = await smsService.send(options);
        console.log('📱 SMS sent to', phoneNumber);
        return { success: true, result };
    } catch (error) {
        console.error('❌ SMS error:', error);
        return { success: false, error: error.message };
    }
}

module.exports = {
    sendSMS
};
