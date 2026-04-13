const request = require('supertest');
const express = require('express');

jest.mock('../middleware/auth', () => ({
    authenticateToken: (req, res, next) => {
        req.user = { id: '9a5f16f5-5cf8-4dbf-9a13-7af176e6e8ef', user_type: 'resident' };
        return next();
    },
    requireUserType: () => (req, res, next) => next(),
    requireAdmin: (req, res, next) => next(),
}));

jest.mock('../config/supabase', () => ({
    supabase: {
        from: jest.fn(),
        rpc: jest.fn(),
    },
}));

jest.mock('../services/marzpayService', () => ({
    formatPhoneNumber: jest.fn(),
    validateMobileNumber: jest.fn(),
    collectMoney: jest.fn(),
    checkTransactionStatus: jest.fn(),
    getWalletBalance: jest.fn(),
    getTransactionHistory: jest.fn(),
}));

const paymentRoutes = require('../routes/paymentRoutes');
const { supabase } = require('../config/supabase');
const marzpayService = require('../services/marzpayService');

function createApp() {
    const app = express();
    app.use(express.json());
    app.use('/payments', paymentRoutes);
    return app;
}

describe('POST /payments/initiate', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('returns success response for valid marzpay initiation', async () => {
        marzpayService.formatPhoneNumber.mockReturnValue('+256783858472');
        marzpayService.validateMobileNumber.mockReturnValue({
            valid: true,
            provider: 'MTN',
            message: 'Valid mobile money number',
        });
        marzpayService.collectMoney.mockResolvedValue({
            message: 'Collection initiated successfully.',
            data: {
                status: 'pending',
                providerRef: 'MP-REF-1',
            },
        });

        const reportSelectBuilder = {
            select: jest.fn().mockReturnThis(),
            eq: jest
                .fn()
                .mockReturnThis(),
            single: jest.fn().mockResolvedValue({
                data: {
                    id: '2762eaf0-b179-4cc0-b2b6-1d595de2cdb5',
                    payment_amount: 5000,
                },
                error: null,
            }),
        };

        const existingPaymentBuilder = {
            select: jest.fn().mockReturnThis(),
            eq: jest.fn().mockReturnThis(),
            maybeSingle: jest.fn().mockResolvedValue({ data: null, error: null }),
        };

        const insertBuilder = {
            insert: jest.fn().mockResolvedValue({ error: null }),
        };

        const updateBuilder = {
            update: jest.fn().mockReturnThis(),
            eq: jest.fn().mockResolvedValue({ error: null }),
        };

        supabase.from
            .mockReturnValueOnce(reportSelectBuilder)
            .mockReturnValueOnce(existingPaymentBuilder)
            .mockReturnValueOnce(insertBuilder)
            .mockReturnValueOnce(updateBuilder);

        const app = createApp();
        const response = await request(app).post('/payments/initiate').send({
            orderId: '2762eaf0-b179-4cc0-b2b6-1d595de2cdb5',
            method: 'marzpay',
            phone: '0783858472',
        });

        expect(response.status).toBe(200);
        expect(response.body.success).toBe(true);
        expect(response.body.data).toEqual(
            expect.objectContaining({
                transactionRef: expect.any(String),
                providerRef: 'MP-REF-1',
                status: 'pending',
            })
        );
    });

    it('returns failure when phone validation fails', async () => {
        marzpayService.formatPhoneNumber.mockReturnValue(null);
        marzpayService.validateMobileNumber.mockReturnValue({
            valid: false,
            provider: null,
            message: 'Only MTN and Airtel Uganda numbers are supported',
        });

        const app = createApp();
        const response = await request(app).post('/payments/initiate').send({
            orderId: '2762eaf0-b179-4cc0-b2b6-1d595de2cdb5',
            method: 'marzpay',
            phone: '0712345678',
        });

        expect(response.status).toBe(400);
        expect(response.body.success).toBe(false);
        expect(response.body.message).toMatch(/supported/i);
        expect(supabase.from).not.toHaveBeenCalled();
    });
});
