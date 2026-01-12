# GFC Backend API Documentation

Base URL: `http://localhost:3000/api` (Development)

## Authentication

All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <token>
```

---

## Authentication Endpoints

### Register User
**POST** `/auth/register`

**Body:**
```json
{
  "phone_number": "+256700123456",
  "full_name": "John Mukasa",
  "user_type": "resident",
  "email": "john@example.com",
  "area": "Nakawa",
  "latitude": 0.3476,
  "longitude": 32.6169
}
```

**Response:**
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": {
      "id": "uuid",
      "phone_number": "+256700123456",
      "full_name": "John Mukasa",
      "user_type": "resident",
      "area": "Nakawa"
    },
    "token": "jwt-token"
  }
}
```

### Login
**POST** `/auth/login`

**Body:**
```json
{
  "phone_number": "+256700123456"
}
```

---

## Garbage Reports

### Create Report (Residents)
**POST** `/garbage-reports`
**Auth Required:** Yes (Resident)

**Body:**
```json
{
  "latitude": 0.3476,
  "longitude": 32.6169,
  "address_description": "Near Nakawa Market, behind MTN shop",
  "garbage_type": "mixed",
  "estimated_volume": "medium",
  "photo_url": "https://..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Garbage report created successfully",
  "data": {
    "report_id": "uuid",
    "status": "pending",
    "payment_amount": 5000,
    "currency": "UGX"
  }
}
```

### Get My Reports
**GET** `/garbage-reports/my-reports`
**Auth Required:** Yes (Resident)

### Get Nearby Reports (Collectors)
**GET** `/garbage-reports/nearby?latitude=0.3476&longitude=32.6169&radius=5000`
**Auth Required:** Yes (Collector)

### Assign to Collector
**PATCH** `/garbage-reports/:id/assign`
**Auth Required:** Yes (Collector)

---

## Payments

### Initiate Payment
**POST** `/payments/initiate`
**Auth Required:** Yes (Resident)

**Body:**
```json
{
  "report_id": "uuid",
  "phone_number": "+256700123456",
  "amount": 5000
}
```

### Check Payment Status
**GET** `/payments/status/:txRef`
**Auth Required:** Yes

---

## Collector Operations

### Update Location
**PATCH** `/collectors/location`
**Auth Required:** Yes (Collector)

**Body:**
```json
{
  "latitude": 0.3476,
  "longitude": 32.6169
}
```

### Get Assignments
**GET** `/collectors/my-assignments`
**Auth Required:** Yes (Collector)

### Verify Collection
**POST** `/collectors/verify-collection`
**Auth Required:** Yes (Collector)

**Body:**
```json
{
  "report_id": "uuid",
  "latitude": 0.3476,
  "longitude": 32.6169,
  "qr_code_data": "scanned-data"
}
```

---

## Error Responses

All errors follow this format:
```json
{
  "success": false,
  "message": "Error description"
}
```

**Status Codes:**
- 200: Success
- 201: Created
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 500: Server Error
