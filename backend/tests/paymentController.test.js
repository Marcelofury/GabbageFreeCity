jest.mock('../config/supabase', () => ({
    supabase: {},
}));

const { mapMarzPayStatus } = require('../controllers/paymentController');

describe('paymentController status mapping', () => {
    it('maps callback statuses to internal order payment statuses', () => {
        expect(mapMarzPayStatus('successful')).toBe('completed');
        expect(mapMarzPayStatus('completed')).toBe('completed');
        expect(mapMarzPayStatus('failed')).toBe('failed');
        expect(mapMarzPayStatus('cancelled')).toBe('failed');
        expect(mapMarzPayStatus('pending')).toBe('pending');
        expect(mapMarzPayStatus('processing')).toBe('pending');
        expect(mapMarzPayStatus('unknown')).toBe('pending');
    });
});
