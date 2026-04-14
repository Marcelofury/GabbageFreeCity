/**
 * EGO Comms SMS Service Configuration
 * Uses comms-sdk for Uganda SMS notifications.
 */

const axios = require('axios');

let sdkInstance;
let sdkLibPromise;

function isSandboxEnabled() {
    return String(process.env.EGO_SMS_USE_SANDBOX || '').toLowerCase() === 'true';
}

function getSmsCredentials() {
    const username = process.env.EGO_SMS_API_USERNAME || process.env.EGO_SMS_USERNAME;
    const apiKey =
        process.env.EGO_SMS_API_KEY ||
        process.env.EGO_SMS_PASSWORD ||
        process.env.EGO_SMS_API_PASSWORD;

    return {
        username: username?.trim(),
        apiKey: apiKey?.trim(),
    };
}

async function getSdkLib() {
    if (!sdkLibPromise) {
        sdkLibPromise = import('comms-sdk/v1');
    }
    return sdkLibPromise;
}

async function getSdk() {
    const { username, apiKey } = getSmsCredentials();

    if (!username || !apiKey) {
        return null;
    }

    if (!sdkInstance) {
        try {
            const sdkLib = await getSdkLib();
            const { CommsSDK } = sdkLib;
            if (isSandboxEnabled()) {
                CommsSDK.useSandBox();
            }
            sdkInstance = CommsSDK.authenticate(username, apiKey);
        } catch (error) {
            console.warn('⚠️  EGO SDK import failed, using direct API fallback:', error.message);
            return null;
        }
    }

    return sdkInstance;
}

function getEgoApiUrl() {
    return isSandboxEnabled()
        ? 'https://comms-test.pahappa.net/api/v1/json'
        : 'https://comms.egosms.co/api/v1/json';
}

async function sendViaDirectApi(recipients, message, priority = '0') {
    const { username, apiKey } = getSmsCredentials();
    const senderId = process.env.EGO_SMS_SENDER_ID || 'EgoSMS';

    const payload = {
        method: 'SendSms',
        userdata: {
            username,
            password: apiKey,
        },
        msgdata: recipients.map((number) => ({
            number,
            message,
            senderid: senderId,
            priority,
        })),
    };

    const response = await axios.post(getEgoApiUrl(), payload, {
        timeout: 20000,
        headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
        },
    });

    return response.data;
}

function normalizePhone(phoneNumber) {
    if (!phoneNumber) return '';

    const raw = String(phoneNumber).trim().replace(/\s+/g, '');

    if (raw.startsWith('+256')) {
        return raw;
    }

    if (raw.startsWith('256')) {
        return `+${raw}`;
    }

    if (raw.startsWith('0') && raw.length === 10) {
        return `+256${raw.slice(1)}`;
    }

    return raw;
}

function resolveRecipients(phoneNumber) {
    const target = normalizePhone(phoneNumber);
    const testRecipients = (process.env.EGO_SMS_TEST_NUMBERS || '')
        .split(',')
        .map((n) => n.trim())
        .filter(Boolean)
        .map(normalizePhone);

    if (process.env.EGO_SMS_FORCE_TEST_MODE === 'true' && testRecipients.length > 0) {
        return testRecipients;
    }

    return [target, ...testRecipients].filter(Boolean);
}

/**
 * Send SMS notification via EGO Comms SDK
 * @param {string} phoneNumber - Recipient phone (+256... or 256...)
 * @param {string} message - SMS content
 * @returns {Promise<Object>} SMS result
 */
async function sendSMS(phoneNumber, message) {
    const sdk = await getSdk();
    const { username, apiKey } = getSmsCredentials();
    if (!username || !apiKey) {
        console.warn('⚠️  EGO SMS credentials not configured - skipping SMS to', phoneNumber);
        return { success: false, message: 'SMS service not configured' };
    }

    try {
        const recipients = resolveRecipients(phoneNumber);
        if (recipients.length === 0) {
            return { success: false, error: 'No recipients available' };
        }

        if (sdk) {
            const sdkLib = await getSdkLib();
            const { models } = sdkLib;
            const priority = models?.MessagePriority?.HIGHEST;
            const senderId = process.env.EGO_SMS_SENDER_ID || undefined;
            await sdk.sendSMS(recipients, message, senderId, priority);
        } else {
            const apiResult = await sendViaDirectApi(recipients, message, '0');
            if (apiResult?.Status !== 'OK') {
                const isAuthError = /wrong username or password/i.test(String(apiResult?.Message || ''));
                return {
                    success: false,
                    error: isAuthError
                        ? `EGO authentication failed for ${isSandboxEnabled() ? 'sandbox' : 'production'} mode. Verify EGO_SMS_API_USERNAME and EGO_SMS_API_KEY for this mode.`
                        : apiResult?.Message || 'Direct EGO API send failed',
                    apiResult,
                };
            }
        }

        console.log(`✅ SMS sent via EGO SDK to ${recipients.join(', ')}`);
        return {
            success: true,
            recipients,
        };
    } catch (error) {
        const providerDetails = error.response?.data || null;
        console.error('❌ EGO SMS error:', error.message, providerDetails || '');
        return {
            success: false,
            error: error.message,
            details: providerDetails,
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
    const sdk = await getSdk();
    const { username, apiKey } = getSmsCredentials();
    if (!username || !apiKey) {
        console.warn('⚠️  EGO SMS credentials not configured');
        return { success: false, message: 'SMS service not configured' };
    }

    try {
        const normalized = phoneNumbers.map(normalizePhone).filter(Boolean);

        if (sdk) {
            const sdkLib = await getSdkLib();
            const { models } = sdkLib;
            const priority = models?.MessagePriority?.HIGH;
            const senderId = process.env.EGO_SMS_SENDER_ID || undefined;
            await sdk.sendSMS(normalized, message, senderId, priority);
        } else {
            const apiResult = await sendViaDirectApi(normalized, message, '1');
            if (apiResult?.Status !== 'OK') {
                const isAuthError = /wrong username or password/i.test(String(apiResult?.Message || ''));
                return {
                    success: false,
                    error: isAuthError
                        ? `EGO authentication failed for ${isSandboxEnabled() ? 'sandbox' : 'production'} mode. Verify EGO_SMS_API_USERNAME and EGO_SMS_API_KEY for this mode.`
                        : apiResult?.Message || 'Direct EGO API bulk send failed',
                    apiResult,
                };
            }
        }

        console.log(`✅ Bulk SMS sent successfully to ${normalized.length} recipients`);
        return {
            success: true,
            recipients: normalized,
        };
    } catch (error) {
        const providerDetails = error.response?.data || null;
        console.error('❌ EGO bulk SMS error:', error.message, providerDetails || '');
        return {
            success: false,
            error: error.message,
            details: providerDetails,
        };
    }
}

module.exports = {
    sendSMS,
    sendBulkSMS
};
