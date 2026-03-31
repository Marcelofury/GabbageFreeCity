# Software Requirements Specification (SRS)
## Garbage Free City (GFC)

## 1. Introduction
### 1.1 Purpose
This document defines the functional and non-functional requirements for the Garbage Free City system based on current implementation status.

### 1.2 Scope
GFC is a mobile-first waste management system that enables:
1. User authentication and role-based access.
2. Garbage report creation and tracking.
3. Mobile money payment through MarzPay.
4. Collector assignment and completion workflows.
5. Notification delivery and read tracking.

### 1.3 Definitions
1. Resident: end user who reports garbage and initiates payment.
2. Collector: field user who accepts assignments and completes collections.
3. Admin: privileged user for financial and operational APIs.
4. Callback: asynchronous payment status update from MarzPay.

## 2. Overall Description
### 2.1 Product Perspective
The system consists of:
1. Flutter mobile application.
2. Node.js and Express backend.
3. Supabase PostgreSQL with PostGIS.
4. MarzPay integration.
5. Notifications and SMS integration.

### 2.2 User Classes
1. Resident
2. Collector
3. Admin

### 2.3 Operating Environment
1. Android and iOS (Flutter app).
2. Cloud-hosted backend.
3. HTTPS REST APIs.

## 3. Functional Requirements
### FR-1 Authentication
1. The system shall register users with username, password, phone number, full name, and user type.
2. The system shall authenticate users using username and password.
3. The system shall allow password reset through username and phone number verification.

### FR-2 Report Management
1. Residents shall create garbage reports with location coordinates and details.
2. Residents shall retrieve their own reports.
3. Collectors shall retrieve nearby reports.
4. Collectors shall assign eligible reports.
5. The system shall support report status updates.

### FR-3 Payment Management
1. Residents shall initiate payment using orderId, method, and phone.
2. The system shall validate Uganda mobile money numbers.
3. The system shall request collection from MarzPay.
4. The system shall process callback payload and update payment and order statuses.

### FR-4 Notifications
1. The system shall create notifications for key events.
2. Users shall list notifications with unread count.
3. Users shall mark one notification as read.
4. Users shall mark all notifications as read.

### FR-5 Collector Operations
1. Collectors shall update their current location.
2. Collectors shall retrieve assignments.
3. Collectors shall verify collection completion.

### FR-6 Admin Operations
1. Admin shall retrieve MarzPay wallet balance.
2. Admin shall retrieve MarzPay transaction history.

## 4. External Interface Requirements
### 4.1 User Interface
1. Mobile screens for resident and collector flows.
2. No KCCA dashboard frontend is implemented yet.

### 4.2 API Interfaces
1. REST JSON request and response format.
2. Bearer token authentication for protected routes.
3. Callback endpoint for MarzPay status updates.

## 5. Non-Functional Requirements
### 5.1 Security
1. Password hashing using bcrypt.
2. JWT-based access control.
3. Input validation using Joi.
4. Role checks for resident, collector, and admin paths.

### 5.2 Performance
1. API response times suitable for mobile usage.
2. Geospatial indexes for location queries.
3. Efficient payment callback processing.

### 5.3 Reliability
1. Callback handling shall be resilient to status mapping variations.
2. Failures shall return structured error responses.

### 5.4 Maintainability
1. Modular route-controller-service architecture.
2. Migration-based database evolution.
3. Provider-based state management in Flutter.

## 6. Data Requirements
Main entities:
1. users
2. garbage_reports
3. payments
4. collection_logs
5. notifications

Key data rules:
1. Username uniqueness must be enforced.
2. Payment transaction references must be trackable and indexed.
3. Payment and report status transitions must remain consistent.

## 7. Assumptions and Dependencies
1. MarzPay API credentials are correctly configured.
2. Callback URL is publicly reachable.
3. Supabase credentials and schema are valid.
4. SMS provider credentials are available for notification escalation.

## 8. Acceptance Criteria
1. User registration and login work with username and password.
2. Resident can submit report and initiate payment.
3. Callback updates payment and report status.
4. Collector can complete assignment workflow.
5. Notifications can be listed and marked read.
6. Admin-protected endpoints reject non-admin users.

## 9. Sign-off
Prepared by: __________________

Reviewed by: __________________

Approved by: __________________
