# GFC Backend API Documentation

## Base URLs

1. Production API base: `https://gabbagefreecity.onrender.com/api`
2. Development API base: `http://localhost:3000/api`

Health endpoint (outside `/api`):
1. Production: `https://gabbagefreecity.onrender.com/health`
2. Development: `http://localhost:3000/health`

## Authentication Model

Authenticated endpoints require:

```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

JWT is issued after successful register/login. Middleware validates token and user active status.

## Response Shape

Success responses generally follow:

```json
{
  "success": true,
  "message": "optional message",
  "data": {}
}
```

Error responses follow:

```json
{
  "success": false,
  "message": "Error description"
}
```

## 1. Authentication Endpoints

### 1.1 Register User

1. Method: `POST`
2. Path: `/auth/register`
3. Auth: none

Request body:

```json
{
  "username": "john.mukasa",
  "password": "StrongPass123",
  "phone_number": "+256700123456",
  "full_name": "John Mukasa",
  "user_type": "resident",
  "email": "john@example.com",
  "area": "Nakawa",
  "latitude": 0.3476,
  "longitude": 32.6169
}
```

Validation notes:
1. `username`: 3-30 chars, lowercase/uppercase letters, numbers, `_ . -`.
2. `password`: 8-128 chars.
3. `phone_number`: must match `+256XXXXXXXXX`.
4. `user_type`: `resident` or `collector`.

### 1.2 Login

1. Method: `POST`
2. Path: `/auth/login`
3. Auth: none

Request body:

```json
{
  "username": "john.mukasa",
  "password": "StrongPass123"
}
```

### 1.3 Set/Reset Password

1. Method: `POST`
2. Path: `/auth/set-password`
3. Auth: none

Request body:

```json
{
  "username": "john.mukasa",
  "phone_number": "+256700123456",
  "new_password": "NewStrongPass123"
}
```

## 2. Garbage Report Endpoints

### 2.1 Create Report (Resident)

1. Method: `POST`
2. Path: `/garbage-reports`
3. Auth: resident

Request body:

```json
{
  "latitude": 0.3476,
  "longitude": 32.6169,
  "address_description": "Near Nakawa Market",
  "garbage_type": "mixed",
  "estimated_volume": "medium",
  "photo_url": "https://example.com/photo.jpg"
}
```

Notes:
1. `garbage_type` values: `mixed`, `plastic`, `organic`, `electronic`, `hazardous`.
2. `estimated_volume` values: `small`, `medium`, `large`.
3. Backend sets `payment_required=true` and `payment_amount` from `DEFAULT_COLLECTION_FEE`.

### 2.2 Get My Reports (Resident)

1. Method: `GET`
2. Path: `/garbage-reports/my-reports`
3. Auth: resident

Response includes report rows plus:
1. Nested payments array.
2. Assigned collector details when available.
3. Extracted `latitude` and `longitude` values.

### 2.3 Get Nearby Reports (Collector)

1. Method: `GET`
2. Path: `/garbage-reports/nearby`
3. Auth: collector

Query parameters:
1. `latitude` (required)
2. `longitude` (required)
3. `radius` (optional, default 5000 meters)

### 2.4 Assign Report (Collector)

1. Method: `PATCH`
2. Path: `/garbage-reports/:id/assign`
3. Auth: collector

Server-side checks:
1. Report exists and status is `pending`.
2. Related payment exists and is `successful`.

### 2.5 Update Report Status

1. Method: `PATCH`
2. Path: `/garbage-reports/:id/status`
3. Auth: authenticated user

Request body:

```json
{
  "status": "in_progress"
}
```

Valid statuses:
1. `pending`
2. `assigned`
3. `in_progress`
4. `completed`
5. `cancelled`

## 3. Payment Endpoints (MarzPay)

### 3.1 Initiate Payment (Resident)

1. Method: `POST`
2. Path: `/payments/initiate`
3. Auth: resident

Request body:

```json
{
  "orderId": "2762eaf0-b179-4cc0-b2b6-1d595de2cdb5",
  "method": "marzpay",
  "phone": "0783858472"
}
```

Validation/behavior:
1. `orderId` must be UUID and owned by authenticated resident.
2. Phone must normalize to Uganda MTN/Airtel format.
3. Amount must be between 500 and 10000000 UGX.
4. Successful initiation creates pending payment and sets report payment status to `processing`.

### 3.2 MarzPay Callback

1. Method: `POST`
2. Path: `/payments/marzpay/callback`
3. Auth: none

Callback requirement:
1. Must contain reference in one of: `reference`, `transactionRef`, `transaction_ref`.

Behavior:
1. Callback payload is mapped and sent to SQL function `apply_marzpay_callback`.
2. Function updates both payment status and garbage report payment status.
3. Resident notification is created and can trigger SMS for success/failure.

### 3.3 Validate Mobile Number

1. Method: `POST`
2. Path: `/payments/validate-phone`
3. Auth: none

Request body:

```json
{
  "phone": "0783858472"
}
```

Response includes:
1. `valid`
2. `provider` (`MTN` or `AIRTEL`)
3. `message`
4. `formattedPhone`

### 3.4 Wallet Balance (Admin)

1. Method: `GET`
2. Path: `/payments/wallet-balance`
3. Auth: admin

Admin check:
1. `req.user.is_admin === true` OR
2. user id included in `ADMIN_USER_IDS` env variable.

### 3.5 MarzPay Transactions (Admin)

1. Method: `GET`
2. Path: `/payments/marzpay-transactions`
3. Auth: admin

Pass-through query parameters are forwarded to MarzPay transaction history endpoint.

## 4. Collector Endpoints

### 4.1 Update Collector Location

1. Method: `PATCH`
2. Path: `/collectors/location`
3. Auth: collector

Request body:

```json
{
  "latitude": 0.3476,
  "longitude": 32.6169
}
```

### 4.2 Get Collector Assignments

1. Method: `GET`
2. Path: `/collectors/my-assignments`
3. Auth: collector

Returns reports assigned to collector with statuses `assigned` and `in_progress`.

### 4.3 Verify Collection

1. Method: `POST`
2. Path: `/collectors/verify-collection`
3. Auth: collector

Request body:

```json
{
  "report_id": "uuid",
  "latitude": 0.3476,
  "longitude": 32.6169,
  "qr_code_data": "scanned-data"
}
```

Behavior:
1. Confirms report is assigned to collector.
2. Inserts `collection_logs` row.
3. Marks report as `completed`.
4. Creates collector and resident notifications (resident path can trigger SMS).

### 4.4 Generate Report QR Code

1. Method: `GET`
2. Path: `/collectors/qr-code/:reportId`
3. Auth: authenticated user

Returns:
1. `qr_code` (data URL image)
2. `qr_data` (JSON payload string)

## 5. Notification Endpoints

### 5.1 List Notifications

1. Method: `GET`
2. Path: `/notifications`
3. Auth: authenticated user

Query parameters:
1. `limit` (default 50, max 100)
2. `offset` (default 0)

Response data:
1. `notifications` array
2. `unread_count`

### 5.2 Mark One Notification as Read

1. Method: `PATCH`
2. Path: `/notifications/:id/read`
3. Auth: authenticated user

### 5.3 Mark All Notifications as Read

1. Method: `PATCH`
2. Path: `/notifications/read-all`
3. Auth: authenticated user

## 6. Health Endpoint

1. Method: `GET`
2. Path: `/health`
3. Auth: none

Returns server status, timestamp, and environment.

## 7. Common HTTP Status Codes

1. `200` OK
2. `201` Created
3. `400` Bad Request
4. `401` Unauthorized
5. `403` Forbidden
6. `404` Not Found
7. `409` Conflict
8. `500` Server Error
