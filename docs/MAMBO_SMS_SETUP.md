# Mambo SMS Setup Guide

## Overview

Mambo SMS is a Ugandan SMS gateway that will handle all SMS notifications in the GFC system, including:
- Payment confirmations
- Collector assignments
- Collection completion alerts
- Login verification codes

---

## Step 1: Create Mambo SMS Account

1. Go to [https://mambosms.com](https://mambosms.com)
2. Click **Sign Up** or **Register**
3. Fill in your details:
   - Business Name: `Kampala Capital City Authority`
   - Email
   - Phone Number
   - Password
4. Verify your email address
5. Login to your dashboard

---

## Step 2: Get Your Credentials

After logging in to your Mambo SMS dashboard:

1. **Username**: Found in your account settings/profile
2. **Password**: Your account password OR API password (check documentation)
3. **Sender ID**: Request approval for `KCCA-GFC` as your sender name

### Important Notes:
- Sender ID approval may take 1-3 business days
- You may need to contact Mambo SMS support to approve `KCCA-GFC`
- Some systems use API key instead of password - check your dashboard

---

## Step 3: Configure Environment Variables

### Local Development (.env file)

Add to `backend/.env`:

```env
# Mambo SMS Configuration (Uganda)
MAMBO_SMS_USERNAME=your-mambo-username
MAMBO_SMS_PASSWORD=your-mambo-password
MAMBO_SMS_SENDER_ID=KCCA-GFC
```

### Production (Render Dashboard)

1. Go to your Render dashboard
2. Navigate to `gfc-backend` service
3. Go to **Environment** tab
4. Add these variables:
   - `MAMBO_SMS_USERNAME` = your Mambo SMS username
   - `MAMBO_SMS_PASSWORD` = your Mambo SMS password
   - `MAMBO_SMS_SENDER_ID` = KCCA-GFC

---

## Step 4: Test SMS Functionality

### Using Postman or cURL:

```bash
# Test registration endpoint (should send SMS)
curl -X POST https://gabbagefreecity.onrender.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+256700123456",
    "full_name": "Test User",
    "user_type": "resident",
    "area": "Nakawa"
  }'
```

Check your backend logs for:
```
📱 Sending SMS to +256700123456 via Mambo SMS...
✅ SMS sent successfully to +256700123456
```

---

## Step 5: Top Up Your Account

1. Login to Mambo SMS dashboard
2. Go to **Add Credits** or **Top Up**
3. Use Mobile Money (MTN/Airtel) to add credits
4. Typical SMS cost: UGX 30-60 per message

### Recommended Starting Balance:
- **Development/Testing**: UGX 10,000 (160-330 SMS)
- **Production**: UGX 50,000+ (830-1,600 SMS)

---

## Troubleshooting

### SMS Not Sending

1. **Check credentials in logs**:
   ```
   ⚠️  Mambo SMS credentials not configured - skipping SMS
   ```
   - Solution: Add credentials to `.env` or Render dashboard

2. **Check account balance**:
   - Login to Mambo SMS dashboard
   - Check credit balance
   - Top up if needed

3. **Check sender ID approval**:
   - Ensure `KCCA-GFC` is approved
   - May take 1-3 business days
   - Contact Mambo SMS support if delayed

4. **Check phone number format**:
   - Must start with `+256` or `256`
   - Example: `+256700123456` or `256700123456`

### API Errors

If you see errors like:
```
❌ SMS error: Request failed with status code 401
```

- Check username/password are correct
- Some accounts use API password different from login password
- Check Mambo SMS documentation for correct API endpoint

---

## SMS Templates Used in GFC

### Payment Success
```
Webale nyo {name}! Payment of UGX {amount} received. Collector assigned soon. -KCCA GFC
```

### Payment Failed
```
Sorry {name}, payment of UGX {amount} failed. Please try again. -KCCA GFC
```

### Collector Assignment
```
Hello {name}, collector {collector} is on the way to {location}. -KCCA GFC
```

### Collection Completed
```
Collection completed at {location}. Thank you for using GFC! -KCCA GFC
```

---

## Contact & Support

- **Mambo SMS Website**: https://mambosms.com
- **Support Email**: support@mambosms.com
- **Phone**: Check website for current support number

---

## Cost Estimates

Based on typical usage:

| Activity | SMS Sent | Monthly Volume | Cost (UGX/month) |
|----------|----------|----------------|------------------|
| 100 reports/month | 300-400 | Low | 12,000 - 24,000 |
| 500 reports/month | 1,500-2,000 | Medium | 60,000 - 120,000 |
| 1,000 reports/month | 3,000-4,000 | High | 120,000 - 240,000 |

**Note**: Costs assume UGX 40-60 per SMS

---

## Alternative: Sandbox/Testing Mode

For development, you can:

1. **Disable SMS temporarily**:
   - Don't set `MAMBO_SMS_USERNAME` in `.env`
   - SMS calls will be logged but not sent
   
2. **Use test phone numbers**:
   - Send SMS only to your own number for testing
   - Modify code to check for test environment

3. **Mock SMS service**:
   - Create a mock SMS service that logs instead of sending
   - Useful for development without costs
