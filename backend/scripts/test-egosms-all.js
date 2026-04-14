require('dotenv').config();

const { sendSMS } = require('../config/smsService');

function pickTargetNumber() {
    const cliArg = process.argv[2];
    if (cliArg && cliArg.trim()) {
        return cliArg.trim();
    }

    const firstTest = String(process.env.EGO_SMS_TEST_NUMBERS || '')
        .split(',')
        .map((n) => n.trim())
        .filter(Boolean)[0];

    if (firstTest) {
        return firstTest;
    }

    return '+256783858472';
}

function formatTemplate(template, values) {
    return String(template || '').replace(/\{(\w+)\}/g, (_, key) => String(values?.[key] ?? ''));
}

async function run() {
    const target = pickTargetNumber();
    const sample = {
        name: 'Resident',
        amount: 500,
        collector: 'Leekaleer',
        location: 'Nakawa Market',
    };

    const scenarios = [
        {
            key: 'WELCOME',
            message: 'Welcome to GFC Resident! Your account is ready. Start reporting garbage pile-ups in Kampala. -KCCA GFC',
        },
        {
            key: 'PASSWORD_UPDATED',
            message: 'Your GFC account password was updated successfully. If this was not you, contact KCCA support immediately.',
        },
        {
            key: 'PAYMENT_SUCCESS',
            message: formatTemplate(process.env.SMS_PAYMENT_SUCCESS || 'Webale nyo {name}! Payment of UGX {amount} received. Collector assigned soon. -KCCA GFC', sample),
        },
        {
            key: 'PAYMENT_FAILED',
            message: formatTemplate(process.env.SMS_PAYMENT_FAILED || 'Sorry {name}, payment of UGX {amount} failed. Please try again. -KCCA GFC', sample),
        },
        {
            key: 'COLLECTION_ASSIGNED',
            message: formatTemplate(process.env.SMS_COLLECTION_ASSIGNED || 'Hello {name}, collector {collector} is on the way to {location}. -KCCA GFC', sample),
        },
        {
            key: 'COLLECTION_COMPLETED',
            message: formatTemplate(process.env.SMS_COLLECTION_COMPLETED || 'Collection completed at {location}. Thank you for using GFC! -KCCA GFC', sample),
        },
    ];

    console.log('Testing EGO SMS scenarios');
    console.log(`Target number: ${target}`);
    console.log(`Sandbox mode: ${String(process.env.EGO_SMS_USE_SANDBOX || '')}`);
    console.log(`Force test mode: ${String(process.env.EGO_SMS_FORCE_TEST_MODE || '')}`);

    let failures = 0;

    for (const scenario of scenarios) {
        // Send each event-style message to validate all SMS paths from one script.
        // eslint-disable-next-line no-await-in-loop
        const result = await sendSMS(target, `[${scenario.key}] ${scenario.message}`);
        const ok = result?.success === true;

        if (!ok) {
            failures += 1;
        }

        console.log(`${ok ? 'OK' : 'FAIL'} ${scenario.key}`, result);
    }

    if (failures > 0) {
        process.exitCode = 1;
        console.log(`Completed with ${failures} failed scenario(s).`);
        return;
    }

    console.log('All EGO SMS scenarios sent successfully.');
}

run().catch((error) => {
    console.error('EGO SMS test script failed:', error);
    process.exitCode = 1;
});
