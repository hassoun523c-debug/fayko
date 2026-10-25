# Fayko Master Plan — Implementation Roadmap

This is the living engineering checklist. Items are not considered complete until implemented and tested.

## 0. Product decisions and safety foundations
- [x] Add initial competitor research and strategy document: [COMPETITIVE_ANALYSIS.md](COMPETITIVE_ANALYSIS.md).
- [ ] Validate the first target audience and the single most important problem Fayko should solve.
- [ ] Confirm minimum supported Android/iOS versions and release targets.
- [ ] Define community rules, reporting, blocking, and abuse-response flows.
- [ ] Define data retention, account deletion, export, and privacy policy.
- [ ] Never commit secrets, signing keys, API keys, or production credentials.

## 1. Flutter foundation
- [x] Add initial Flutter package manifest.
- [x] Add an Arabic RTL app shell with dark theme and initial navigation.
- [ ] Generate and verify full Android platform files with Flutter tooling.
- [ ] Add Cairo or Tajawal font assets and configure typography.
- [ ] Add localization using Flutter's generated localization workflow.
- [ ] Adopt feature-first Clean Architecture and a state-management standard.
- [ ] Verify widget tests, formatting, analysis, and CI checks (test source added; CI result pending).

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

Each feature should separate data, domain, and presentation layers where complexity warrants it.

## 3. Backend and data
- [x] Choose Node.js 22 / Express 5 and PostgreSQL for the first backend iteration.
- [x] Add versioned API routes for authentication, profile updates, posts, likes, and comments.
- [x] Add an initial PostgreSQL schema for users, posts, likes, comments, and follows.
- [ ] Apply and verify the migration against a live PostgreSQL instance; define a controlled migration process for updates.
- [ ] Evaluate whether a second message store is needed; start simple until scale requires it.
- [ ] Add session revocation/refresh-token rotation, audit logging, shared rate limiting, backups, and monitoring.
- [ ] Connect Flutter authentication, profile, and feed to the API.
- [ ] Add user search and follow/unfollow API endpoints.
- [ ] Add WebSocket events for presence, typing, delivery, and read receipts.

## 4. Media and delivery
- [ ] Object storage with private-by-default access and signed uploads/downloads.
- [ ] Image resizing and thumbnail generation.
- [ ] Video transcoding and HLS/DASH delivery for stories/reels.
- [ ] Upload limits, content-type validation, malware scanning where appropriate, and quotas.
- [ ] CDN configuration and cost controls.

## 5. Social feed and stories
- [ ] Text posts and multiple image attachments.
- [ ] Likes, nested comments, reposts, and polls.
- [ ] Story expiry after 24 hours and story replies.
- [ ] Pagination, feed ranking, moderation, reporting, and blocking.

## 6. Chat and calls
- [ ] Message model, delivery states, pagination, and retry/offline queue.
- [ ] End-to-end encryption design review before implementation; use audited protocol libraries.
- [ ] Disappearing-message semantics and clear limits for backups/screenshots.
- [ ] Original-file sending with size limits and secure signed URLs.
- [ ] Voice-note recording, preview, waveform, playback speed, and noise suppression.
- [ ] WebRTC or managed calling provider, network adaptation, permissions, and call lifecycle.
- [ ] Push notifications that avoid leaking sensitive message content.

## 7. Reels and saved folders
- [ ] Vertical video feed with preloading and lifecycle handling.
- [ ] Likes, comments, share-to-chat, reporting, and moderation.
- [ ] User-created saved folders and organization of saved content.

## 8. Profile, privacy, and settings
- [ ] Profile photo, cover, bio, links, and counters.
- [ ] Account privacy controls and block/mute lists.
- [ ] Local biometric lock with secure device APIs.
- [ ] Session/device management and remote logout.
- [ ] Storage/cache controls and account deletion.

## 9. Release readiness
- [ ] Accessibility, RTL review, low-bandwidth testing, and performance profiling.
- [ ] Security review and dependency updates.
- [ ] Automated tests and CI passing.
- [ ] Android internal testing, crash reporting, and staged rollout.
- [ ] iOS signing and TestFlight when an appropriate Apple build environment is available.

## Current status
The repository contains an early Flutter shell and an initial Node.js/Express API with PostgreSQL schema and unit tests. The API includes registration/login, profile updates, text posts, likes, comments, and a paginated feed. The Flutter client is not yet connected to it. CI workflows have been added for Flutter validation and API tests, but their success must be verified before treating checks as passed. No APK is being built in this stage.
