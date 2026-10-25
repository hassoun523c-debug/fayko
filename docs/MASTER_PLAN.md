# Fayko Master Plan — Implementation Roadmap

This is the living engineering checklist. Items are not considered complete until implemented and tested.

## 0. Product decisions and safety foundations
- [x] Add initial competitor research and strategy document: [COMPETITIVE_ANALYSIS.md](COMPETITIVE_ANALYSIS.md).
- [ ] Validate the first target audience and the single most important problem Fayko should solve.
- [ ] Confirm minimum supported Android version and release target.
- [ ] Define community rules, reporting, blocking, and abuse-response flows.
- [ ] Define data retention, account deletion, export, and privacy policy.
- [ ] Never commit secrets, signing keys, API keys, or production credentials.

## 1. Flutter foundation
- [x] Add Flutter package manifest and Arabic RTL shell.
- [x] Add authentication screens and repository code for register/login/session restore.
- [x] Add remote feed repository code for text posts, likes, and comments.
- [x] Add profile read view and local logout.
- [ ] Generate and verify full Android platform files with Flutter tooling.
- [ ] Run formatting, analyzer and widget tests successfully in CI.
- [ ] Add Cairo or Tajawal font assets and generated localization.
- [ ] Formalize feature-first architecture and state-management approach.

## 2. App architecture
Planned feature modules:
- auth
- feed
- posts
- stories
- reels
- chat
- calls
- profile
- settings
- media
- notifications
- moderation

## 3. Backend and data
- [x] Choose Node.js 22 / Express 5 and PostgreSQL for the first backend iteration.
- [x] Add versioned routes for authentication, profile updates, posts, likes, and comments.
- [x] Add an initial PostgreSQL schema for users, posts, likes, comments, and follows.
- [x] Add API routes for public profile search, profiles and follow/unfollow.
- [ ] Apply the schema to a running PostgreSQL instance and verify it with integration tests.
- [ ] Define and test a repeatable migration process for future schema changes.
- [ ] Add refresh-token rotation, server-side session revocation, audit logging, shared rate limiting, backups, and monitoring.
- [ ] Verify Flutter authentication and feed against a running API end-to-end.
- [ ] Connect Flutter user search and follow/unfollow UI.
- [ ] Add WebSocket events for presence, typing, delivery, and read receipts.

## 4. Media and delivery
- [ ] Add object storage with private-by-default access and signed uploads/downloads.
- [ ] Add image resizing and thumbnail generation.
- [ ] Add video transcoding and HLS/DASH delivery for stories/reels.
- [ ] Add upload limits, content-type validation, malware scanning where appropriate, and quotas.
- [ ] Configure CDN and cost controls.

## 5. Social feed and stories
- [ ] Add multiple image attachments.
- [x] Implement basic text posts, likes/unlikes and comments in API/client code (pending end-to-end verification).
- [ ] Add nested comments, reposts and polls.
- [ ] Add stories, 24-hour expiry and replies.
- [ ] Add feed ranking, moderation, reporting and blocking.
- [ ] Add robust cursor pagination in Flutter (API supports cursor paging; client currently loads the first page).

## 6. Chat and calls
- [ ] Add message model, delivery states, pagination, and offline queue.
- [ ] Review end-to-end encryption design; use audited protocol libraries.
- [ ] Define disappearing-message semantics and limitations.
- [ ] Add file sending and secure signed URLs.
- [ ] Add voice notes and audio playback controls.
- [ ] Add WebRTC or managed calling provider, network adaptation, permissions and lifecycle.
- [ ] Add push notifications that avoid leaking message content.

## 7. Reels and saved folders
- [ ] Add vertical video feed, preloading and lifecycle handling.
- [ ] Add likes, comments, share-to-chat and moderation.
- [ ] Add user-created saved folders.

## 8. Profile, privacy, and settings
- [ ] Add editable profile screen and profile photo upload.
- [ ] Add account privacy controls and block/mute lists.
- [ ] Add local biometric lock with secure device APIs.
- [ ] Add session/device management and remote logout.
- [ ] Add cache controls and account deletion.

## 9. Release readiness
- [ ] Accessibility, RTL review, low-bandwidth testing, performance profiling.
- [ ] Security review and dependency updates.
- [ ] Automated tests and CI checks passing.
- [ ] Android internal testing, crash reporting, staged rollout.
- [ ] iOS signing and TestFlight when an appropriate Apple build environment is available.

## Current status
The repository now contains Flutter authentication and text-feed integration code plus an initial Node.js/Express API and PostgreSQL schema. The API/client combination has not yet been run end-to-end against a real database, and CI results are pending. Android platform files have not been generated and validated. No APK is being built in this stage, by design.
