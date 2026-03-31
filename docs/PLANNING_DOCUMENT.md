# Garbage Free City (GFC) Planning Document

## 1. Project Overview
Garbage Free City is a smart waste management platform for Kampala. It connects residents, collectors, and KCCA operations with geolocation-based reporting, payment processing, assignment management, and collection verification.

## 2. Current System Status (March 2026)
The current implementation state includes:

1. Backend API with Express and Supabase integration.
2. Username and password authentication.
3. Resident and collector role separation.
4. Garbage report creation and status lifecycle.
5. MarzPay payment initiation and callback handling.
6. Notifications API with unread and read state support.
7. Collector location update and collection verification flow.
8. Mobile app with resident and collector user journeys.

## 3. Vision and Goals
### Vision
Deliver an efficient and traceable garbage collection system for Kampala residents and KCCA operations.

### Goals
1. Reduce response time from report creation to collection.
2. Ensure payment status and order status are synchronized.
3. Improve visibility of operations for residents and collectors.
4. Provide a scalable backend foundation for future KCCA dashboard features.

## 4. Scope
### In Scope
1. Mobile user authentication and role-based navigation.
2. Resident garbage reporting and report tracking.
3. MarzPay mobile money request and callback reconciliation.
4. Collector assignment and completion operations.
5. Notifications and optional SMS trigger integration.

### Out of Scope for Current Phase
1. Full KCCA web dashboard frontend.
2. Advanced analytics and forecasting.
3. Multi-city support.
4. Offline-first mobile synchronization.

## 5. Stakeholders
1. Residents
2. Garbage collectors
3. KCCA operations team
4. Project development team
5. Payment provider (MarzPay)
6. SMS provider

## 6. Assumptions and Constraints
### Assumptions
1. Users have internet access for transaction flows.
2. MarzPay callback endpoint remains publicly reachable.
3. Geolocation permissions are granted by mobile users.

### Constraints
1. Third-party API reliability affects payment finalization.
2. SMS costs and provider limits may affect messaging strategy.
3. Current admin operations are API-level, not dashboard-level.

## 7. Risk Register
1. Callback failures or delayed status updates.
Mitigation: database callback function and status mapping logic.

2. Invalid phone numbers for mobile money.
Mitigation: payment phone validation endpoint before initiation.

3. Environment configuration mismatch across deployments.
Mitigation: documented environment variable checklist and startup checks.

4. Documentation drift during rapid changes.
Mitigation: update docs at sprint close as mandatory deliverable.

## 8. Success Metrics
1. Payment initiation success rate.
2. Callback processing success rate.
3. Average report completion time.
4. Assignment acceptance rate.
5. Notification delivery and read rates.

## 9. Deliverables
1. Production-ready backend APIs.
2. Mobile app resident and collector flows.
3. Updated database schema and migrations.
4. Documentation set: SRS, architecture, sprint plan, walkthrough.

## 10. Approval
Prepared by: __________________

Reviewed by: __________________

Approved by: __________________

Date: __________________
