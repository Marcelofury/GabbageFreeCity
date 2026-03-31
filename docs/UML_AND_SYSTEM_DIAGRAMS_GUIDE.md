# GFC UML and System Diagrams Guide

This guide explains all diagram types used for Garbage Free City in plain steps and analysis notes.

Notes:
1. DFD and ERD are system modeling diagrams, not strict UML.
2. This guide is aligned to current implementation status: username and password authentication, MarzPay payments, notifications, and collector workflows.
3. This document intentionally explains diagrams and does not include PlantUML code blocks.

## 1. Use Case Diagram

### Purpose
The Use Case diagram shows who uses the system and what each actor can do.

### Actors
1. Resident
2. Collector
3. Admin
4. MarzPay Gateway
5. SMS Provider

### Main Use Cases by Actor

Resident:
1. Register account.
2. Login.
3. Set password.
4. Create garbage report.
5. View own reports.
6. Initiate payment.
7. View notifications.
8. Mark one notification as read.
9. Mark all notifications as read.

Collector:
1. Login.
2. Update location.
3. View nearby reports.
4. Assign report.
5. Update report status.
6. Verify collection.
7. View notifications.
8. Mark notifications as read.

Admin:
1. View wallet balance.
2. View provider transactions.

External systems:
1. MarzPay sends callback updates.
2. SMS provider receives optional SMS dispatches.

### Dependency Notes
1. Payment initiation includes phone validation.
2. Callback handling includes status mapping and status update.
3. Notification creation may extend to optional SMS sending.

## 2. Flowchart (Activity Diagram)

### Purpose
The flowchart explains end-to-end operational flow and decisions.

### Resident Branch Steps
1. User opens app.
2. If no account, user registers.
3. User logs in.
4. Resident creates report.
5. Resident initiates payment.
6. System validates phone.
7. System requests payment and stores transaction reference.
8. System waits for callback.
9. Callback updates payment and report statuses.
10. System creates notification.

### Collector Branch Steps
1. Collector logs in.
2. Collector updates location.
3. Collector requests nearby reports.
4. Collector assigns report.
5. Collector updates status to in_progress.
6. Collector verifies collection.
7. System marks report as completed and notifies users.

### Key Decision Points
1. Registration input valid or invalid.
2. Authentication success or failure.
3. Phone valid or invalid.
4. Callback contains transaction reference or not.
5. Payment successful or failed.

## 3. ERD (Entity Relationship Diagram)

### Purpose
The ERD explains database structure, ownership, and relationships.

### Core Entities
1. users
2. garbage_reports
3. payments
4. collection_logs
5. notifications

### Relationship Summary
1. One user can create many garbage reports as a resident.
2. One user can be assigned many reports as a collector.
3. One report can have payment records.
4. One report can have collection logs.
5. One user can have many notifications.

### Data Integrity Concepts
1. Primary keys identify each entity row.
2. Foreign keys enforce ownership links.
3. Payment and report statuses must remain synchronized through callback processing.

## 4. DFD Level 0 (Context Only)

### Purpose
DFD Level 0 shows the system as one process and how data moves between external actors and the system boundary.

### External Entities
1. Resident App
2. Collector App
3. Admin Client
4. MarzPay Gateway
5. SMS Provider

### Context Data Flows
1. Resident sends auth, report, payment, and notification requests to GFC.
2. GFC returns tokens, report status, payment status, and notifications to Resident.
3. Collector sends location and assignment actions to GFC.
4. GFC returns assignments, status updates, and notifications to Collector.
5. Admin sends wallet and transaction queries to GFC.
6. GFC returns wallet and provider transaction data to Admin.
7. GFC sends payment collection requests to MarzPay.
8. MarzPay sends callback status updates to GFC.
9. GFC sends optional SMS dispatches to SMS Provider.

## 5. Sequence Diagrams

### Purpose
Sequence diagrams explain message order between actors, APIs, services, and databases for specific scenarios.

### 5.1 Sequence: Register User
1. Resident sends registration details.
2. Auth API validates input.
3. System checks username and phone uniqueness.
4. System hashes password and inserts user.
5. System generates token.
6. Notification service creates welcome notification.
7. Optional SMS is sent.
8. API returns success and token.

### 5.2 Sequence: Login User
1. User sends username and password.
2. Auth API validates payload.
3. System loads user by username.
4. System compares password hash.
5. System generates token if valid.
6. Notification service records login event.
7. API returns authenticated profile and token.

### 5.3 Sequence: Set Password
1. User sends username, phone, and new password.
2. API validates payload.
3. System verifies account by username and phone.
4. System hashes new password.
5. System updates user password_hash.
6. Notification service logs password update.
7. API returns success.

### 5.4 Sequence: Create Report
1. Resident sends report payload with coordinates.
2. Auth middleware validates token and role.
3. Report API validates report fields.
4. Report is inserted into garbage_reports.
5. Notification is created for report submission.
6. API returns report_id and payment amount.

### 5.5 Sequence: Get My Reports
1. Resident requests own reports.
2. Auth middleware validates token and role.
3. Report API queries reports and related payment data.
4. API returns report list.

### 5.6 Sequence: Get Nearby Reports
1. Collector sends location and radius.
2. Auth middleware validates collector token.
3. Report API performs nearby query (or fallback query).
4. API returns nearby reports.

### 5.7 Sequence: Assign Report
1. Collector requests assignment of report.
2. Auth middleware validates collector token.
3. System checks report availability.
4. System checks payment success state.
5. System updates assigned_collector_id and status.
6. Notification service alerts resident.
7. API returns assignment success.

### 5.8 Sequence: Update Collector Location
1. Collector sends coordinates.
2. Auth middleware validates collector token.
3. Collector API updates user current_location.
4. API returns location update success.

### 5.9 Sequence: Initiate Payment
1. Resident sends orderId, method, and phone.
2. Payment API validates payload and method.
3. System validates phone number and provider.
4. System validates order ownership and amount.
5. MarzPay service sends collect-money request.
6. System stores payment record and references.
7. System updates report payment_status to processing.
8. Notification service records initiation event.
9. API returns transactionRef and pending status.

### 5.10 Sequence: Process MarzPay Callback
1. MarzPay sends callback payload.
2. Callback API extracts transaction reference and status.
3. System maps provider status.
4. DB callback function updates payment and report status.
5. Notification service records success or failure update.
6. Optional SMS is sent for key outcomes.
7. API returns callback processed response.

### 5.11 Sequence: Notifications List and Read Actions
1. User requests notifications list.
2. Auth middleware validates token.
3. Notification API queries notifications and unread count.
4. API returns list and unread_count.
5. User marks one notification as read.
6. API updates one row and returns success.
7. User marks all notifications as read.
8. API updates all unread rows and returns success.

### 5.12 Sequence: Verify Collection
1. Collector sends report_id and location data.
2. Auth middleware validates collector token.
3. System verifies report assignment ownership.
4. System inserts collection log.
5. System updates report status to completed.
6. Notification service alerts collector and resident.
7. Optional SMS is sent to resident.
8. API returns verification success.

### 5.13 Sequence: Admin Wallet Balance
1. Admin sends wallet balance request.
2. Auth middleware validates token.
3. Admin guard validates admin access.
4. Payment service requests wallet balance from MarzPay.
5. API returns balance response.

### 5.14 Sequence: Admin Provider Transactions
1. Admin sends transaction history request.
2. Auth middleware validates token.
3. Admin guard validates admin access.
4. Payment service requests transaction list from MarzPay.
5. API returns provider transaction data.

## 6. How to Choose the Right Diagram

1. Use Use Case to explain actor capabilities.
2. Use Activity Flowchart to explain process logic and branching.
3. Use ERD to explain data model and relationships.
4. Use DFD Level 0 to explain external data movement.
5. Use Sequence diagrams to explain exact runtime interactions.

## 7. Suggested Presentation Order

1. Use Case Diagram
2. Flowchart (Activity)
3. ERD
4. DFD Level 0
5. Sequence Diagrams
