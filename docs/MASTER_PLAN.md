# Fayko Master Plan — Implementation Roadmap

This is the living engineering checklist. Items are not considered complete until implemented and tested.

## 0. Product decisions and safety foundations
- [ ] Confirm minimum supported Android/iOS versions and release targets.
- [ ] Define community rules, reporting, blocking, and abuse-response flows.
- [ ] Define data retention, account deletion, export, and privacy policy.
- [ ] Never commit secrets, signing keys, API keys, or production credentials.

## 1. Flutter foundation
- [x] Add initial Flutter package manifest.
- [x] Add an Arabic RTL app shell with dark/light themes.
- [x] Add first navigation destinations and placeholder states.
- [ ] Generate and verify full Android/iOS platform folders with Flutter tooling.
- [ ] Add Cairo or Tajawal font assets and configure typography.
- [ ] Add localization using Flutter's generated localization workflow.
- [ ] Adopt feature-first Clean Architecture and a state-management standard.
- [ ] Add unit/widget tests, formatting, and CI checks.

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
- [ ] Choose NestJS or Go based on deployment and team capability.
- [ ] Define API contracts and versioning.
- [ ] PostgreSQL schema and migrations for accounts, follows, posts, reactions, comments, and settings.
- [ ] Evaluate whether a second message store is needed; start simple until scale requires it.
- [ ] Authentication, rate limits, input validation, audit logging, backups, and monitoring.
- [ ] WebSocket events for presence, typing, delivery, and read receipts.

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
- [ ] Automated tests and CI build.
- [ ] Android internal testing, crash reporting, and staged rollout.
- [ ] iOS signing and TestFlight when an appropriate Apple build environment is available.

## Current status
Only the initial source shell and roadmap have been added. This repository is not yet a complete or runnable generated Flutter platform project until Flutter tooling creates the platform folders and the app is built and tested.
