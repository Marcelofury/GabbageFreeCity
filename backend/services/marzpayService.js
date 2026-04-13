const axios = require('axios');

const DEFAULT_API_URL = 'https://wallet.wearemarz.com/api/v1';
const REQUEST_TIMEOUT_MS = 30000;

function buildAuthHeader() {
    const key = process.env.MARZPAY_API_KEY;
    const secret = process.env.MARZPAY_API_SECRET;

    if (!key || !secret) {
        const err = new Error('MarzPay credentials are not configured');
        err.statusCode = 500;
        throw err;
    }

    return `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}`;
}

function getClient() {
    return axios.create({
        baseURL: process.env.MARZPAY_API_URL || DEFAULT_API_URL,
        timeout: REQUEST_TIMEOUT_MS,
        headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            Authorization: buildAuthHeader(),
        },
    });
}

async function request(config) {
    const client = getClient();

    try {
        const response = await client.request(config);
        return response.data;
    } catch (error) {
        const status = error.response?.status || 502;
        const providerMessage =
            error.response?.data?.message ||
            error.response?.data?.error ||
            'Failed to communicate with MarzPay';

        const wrapped = new Error(providerMessage);
        wrapped.statusCode = status;
        wrapped.details = error.response?.data || null;
        throw wrapped;
    }
}

function formatPhoneNumber(phone) {
    if (!phone || typeof phone !== 'string') {
        return null;
    }

    const normalized = phone.replace(/[\s-]/g, '');

    if (/^\+256\d{9}$/.test(normalized)) {
        return normalized;
    }

    if (/^256\d{9}$/.test(normalized)) {
        return `+${normalized}`;
    }

    if (/^0\d{9}$/.test(normalized)) {
        return `+256${normalized.slice(1)}`;
    }

    return null;
}

function getProvider(phone) {
    const formatted = formatPhoneNumber(phone);
    if (!formatted) {
        return null;
    }

    const prefix = formatted.slice(4, 6);

    if (['77', '78', '76'].includes(prefix)) {
        return 'MTN';
    }

    if (['70', '75', '74'].includes(prefix)) {
        return 'AIRTEL';
    }

    return null;
}

function validateMobileNumber(phone) {
    const formatted = formatPhoneNumber(phone);

    if (!formatted) {
        return {
            valid: false,
            provider: null,
            message: 'Phone number must be a valid Uganda number',
        };
    }

    if (formatted.length !== 13) {
        return {
            valid: false,
            provider: null,
            message: 'Phone number must normalize to +256XXXXXXXXX',
        };
    }

    const provider = getProvider(formatted);
    if (!provider) {
        return {
            valid: false,
            provider: null,
            message: 'Only MTN and Airtel Uganda numbers are supported',
        };
    }

    return {
        valid: true,
        provider,
        message: 'Valid mobile money number',
    };
}

async function collectMoney({ reference, phoneNumber, country = 'UG', amount, description, callbackUrl }) {
    const payload = {
        amount,
        phone_number: phoneNumber,
        country,
        reference,
        description,
    };

    if (callbackUrl) {
        payload.callback_url = callbackUrl;
    }

    return request({
        method: 'post',
        url: '/collect-money',
        data: payload,
    });
}

async function sendMoney({ reference, phoneNumber, country = 'UG', amount, description, callbackUrl }) {
    const payload = {
        amount,
        phone_number: phoneNumber,
        country,
        reference,
        description,
    };

    if (callbackUrl) {
        payload.callback_url = callbackUrl;
    }

    return request({
        method: 'post',
        url: '/send-money',
        data: payload,
    });
}

async function getCollectionDetails(uuid) {
    return request({
        method: 'get',
        url: `/collections/${uuid}`,
    });
}

async function getSendMoneyDetails(uuid) {
    return request({
        method: 'get',
        url: `/disbursements/${uuid}`,
    });
}

async function checkTransactionStatus(uuid) {
    return request({
        method: 'get',
        url: `/transactions/${uuid}/status`,
    });
}

async function getWalletBalance() {
    try {
        return await request({
            method: 'get',
            url: '/wallet/balance',
        });
    } catch (error) {
        if (error?.statusCode !== 404) {
            throw error;
        }

        return request({
            method: 'get',
            url: '/wallet',
        });
    }
}

async function getTransactionHistory(params = {}) {
    return request({
        method: 'get',
        url: '/transactions',
        params,
    });
}

async function getCollectionServices() {
    return request({
        method: 'get',
        url: '/services/collections',
    });
}

async function getSendMoneyServices() {
    return request({
        method: 'get',
        url: '/services/disbursements',
    });
}

module.exports = {
    collectMoney,
    sendMoney,
    getCollectionDetails,
    getSendMoneyDetails,
    checkTransactionStatus,
    getWalletBalance,
    getTransactionHistory,
    getCollectionServices,
    getSendMoneyServices,
    formatPhoneNumber,
    getProvider,
    validateMobileNumber,
};
