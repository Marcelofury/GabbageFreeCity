# GFC Sprint Plan

## Sprint Model
Sprint duration: 2 weeks

Planning horizon: from December to project completion

## Sprint 1: Foundation and Alignment
1. Confirm updated requirements and architecture.
2. Align database schema and migration strategy.
3. Stabilize development environments and deployment variables.
4. Validate core auth and report APIs.

Deliverables:
1. Baseline environment and schema consistency.
2. Updated technical documentation.

## Sprint 2: Authentication Completion
1. Complete username and password flows in backend and mobile.
2. Complete set-password flow in mobile.
3. Add and validate auth-related tests.

Deliverables:
1. End-to-end auth flow ready for UAT.

## Sprint 3: Resident Reporting Flow Hardening
1. Improve resident report creation UX and validation.
2. Improve report list reliability and error handling.
3. Verify geolocation consistency from mobile to backend.

Deliverables:
1. Stable resident reporting journey.

## Sprint 4: MarzPay Payment Stabilization
1. Finalize payment initiation flow with validation.
2. Validate callback transition mapping and persistence.
3. Improve failure handling and user-facing messages.

Deliverables:
1. Reliable payment status lifecycle.

## Sprint 5: Notifications and Messaging
1. Integrate notifications display in mobile flows.
2. Add mark-read and read-all UX in app.
3. Validate optional SMS trigger behavior.

Deliverables:
1. Notification flow integrated and tested.

## Sprint 6: Collector Flow API Integration
1. Replace remaining mock collector data with API-backed data.
2. Finalize nearby reports and assignment actions.
3. Finalize completion and verification actions.

Deliverables:
1. Collector workflow end-to-end.

## Sprint 7: Admin Operations and Monitoring Preparation
1. Harden admin guards and admin endpoint behavior.
2. Define API contracts for future KCCA dashboard.
3. Add operational metrics queries and logs.

Deliverables:
1. Admin API readiness for dashboard phase.

## Sprint 8: QA, Security, and Release Readiness
1. Full regression testing.
2. Performance and security verification.
3. Production deployment checklist and runbook update.

Deliverables:
1. Release candidate build and final documentation.

## Cross-Sprint Practices
1. Daily standups and weekly demos.
2. Definition of done includes tests and docs updates.
3. End-of-sprint retrospective and risk review.

## Risk and Dependency Watchlist
1. MarzPay callback reliability.
2. SMS provider credentials and environment parity.
3. Mobile network variability during payment prompts.
4. Time required to replace all collector mock data.
