const { supabase } = require('../config/supabase');
const { sendSMS } = require('../config/smsService');

async function createNotification({
    userId,
    title,
    message,
    type = 'system',
    data = null,
    sendSms = false,
}) {
    if (!userId || !title || !message) {
        return { success: false, message: 'userId, title and message are required' };
    }

    try {
        const payload = {
            user_id: userId,
            title,
            message,
            type,
            data,
            is_read: false,
            created_at: new Date().toISOString(),
        };

        const { data: notification, error } = await supabase
            .from('notifications')
            .insert([payload])
            .select()
            .single();

        if (error) {
            return { success: false, message: error.message };
        }

        if (sendSms) {
            const { data: user } = await supabase
                .from('users')
                .select('phone_number')
                .eq('id', userId)
                .single();

            if (user?.phone_number) {
                await sendSMS(user.phone_number, message);
            }
        }

        return { success: true, data: notification };
    } catch (error) {
        return { success: false, message: error.message };
    }
}

module.exports = {
    createNotification,
};
