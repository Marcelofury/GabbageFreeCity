jest.mock('axios', () => ({
    create: jest.fn(),
}));

const axios = require('axios');
const service = require('../services/marzpayService');

describe('marzpayService', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.MARZPAY_API_KEY = 'key';
        process.env.MARZPAY_API_SECRET = 'secret';
        process.env.MARZPAY_API_URL = 'https://wallet.wearemarz.com/api/v1';
    });

    it('formats phones and detects provider', () => {
        expect(service.formatPhoneNumber('0783858472')).toBe('+256783858472');
        expect(service.formatPhoneNumber('256783858472')).toBe('+256783858472');
        expect(service.formatPhoneNumber('+256783858472')).toBe('+256783858472');
        expect(service.formatPhoneNumber('1234')).toBeNull();

        expect(service.getProvider('0783858472')).toBe('MTN');
        expect(service.getProvider('0751234567')).toBe('AIRTEL');

        const validation = service.validateMobileNumber('0791234567');
        expect(validation.valid).toBe(false);
        expect(validation.provider).toBeNull();
    });

    it('sends collectMoney payload with phone_number and description', async () => {
        const requestMock = jest.fn().mockResolvedValue({
            data: {
                success: true,
                message: 'Collection initiated successfully.',
                data: {
                    transactionRef: 'TXN-123',
                    status: 'pending',
                    providerRef: 'PROV-1',
                },
            },
        });

        axios.create.mockReturnValue({ request: requestMock });

        await service.collectMoney({
            reference: 'TXN-123',
            phoneNumber: '+256783858472',
            country: 'UG',
            amount: 500,
            description: 'Order #123 payment',
        });

        expect(requestMock).toHaveBeenCalledWith({
            method: 'post',
            url: '/collect-money',
            data: {
                amount: 500,
                phone_number: '+256783858472',
                country: 'UG',
                reference: 'TXN-123',
                description: 'Order #123 payment',
            },
        });
    });
});
