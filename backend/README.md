# Fayko API

This directory contains the first backend implementation for Fayko: a Node.js/Express HTTP API with PostgreSQL persistence. Flutter client code now calls the authentication and text-feed endpoints, but the end-to-end setup has not yet been verified against a running database and Android build.

## Local setup

1. Install Docker Desktop or Docker Engine with the Compose plugin.
2. Copy `.env.example` to `.env`.
3. Replace `JWT_SECRET` with a random secret of at least 32 characters. One option is `openssl rand -hex 32`.
4. Start from this directory with `docker compose up --build`.
5. Check `http://127.0.0.1:4000/healthz` and `http://127.0.0.1:4000/readyz`.

The database schema is initialized automatically only when the PostgreSQL data volume is created for the first time. Existing volumes are not modified by the initialization script; back up data before applying future migrations. The compose configuration binds the API to 127.0.0.1 by default. Do not expose the API publicly until HTTPS, production secrets, deployment networking, monitoring, backups, and operational controls are configured.

For an Android emulator, Flutter's default API URL is `http://10.0.2.2:4000/api/v1`. A physical phone needs a reachable host address on the same network, and a production release needs a properly secured HTTPS endpoint.

## Implemented API routes

- GET `/healthz` — process health.
- GET `/readyz` — database readiness.
- POST `/api/v1/auth/register` — create a user and return a short-lived bearer access token.
- POST `/api/v1/auth/login` — authenticate by username or email.
- GET `/api/v1/auth/me` — return the current user's profile.
- PATCH `/api/v1/auth/me` — update display name, bio, or avatar URL.
- GET `/api/v1/posts` — authenticated, cursor-paginated public post feed.
- POST `/api/v1/posts` — create a text post.
- POST / DELETE `/api/v1/posts/:postId/like` — like or unlike a post.
- GET / POST `/api/v1/posts/:postId/comments` — read/add comments.
- DELETE `/api/v1/posts/:postId` — delete a post owned by the current user.
- GET `/api/v1/users/search?q=term&limit=20` — search public profiles.
- GET `/api/v1/users/:userId` — read a public profile and counters.
- POST / DELETE `/api/v1/users/:userId/follow` — follow or unfollow an account.
- POST `/api/v1/conversations/direct` — create or reuse a one-to-one conversation.
- GET `/api/v1/conversations` — list conversations and unread counts.
- GET / POST `/api/v1/conversations/:conversationId/messages` — read history or send a text message; only members can access it.
- POST `/api/v1/conversations/:conversationId/read` — advance the member read marker.

Socket.IO uses the same HTTP server. Connect with the access token in the handshake auth object (`token`). After connection, `conversation:join` accepts a conversation ID and acknowledges only current members. `message:new` is emitted to subscribed conversation rooms after an HTTP message has been persisted; `conversation:updated` is emitted to each member's user room. These events do not provide end-to-end encryption and should only be deployed behind HTTPS/WSS.

The Flutter client currently connects to register/login/session restore, profile updates, text posts, likes, comments, user search/follow, and basic one-to-one text messaging. It can create direct conversations, send/read messages, and display unread counts. These paths are implemented in source. Socket.IO now authenticates the same access tokens, checks conversation membership before joining rooms, broadcasts persisted messages, and notifies users to refresh their inbox. End-to-end checks still need to pass in CI and on Android.

## Tests and security baseline

Node's built-in test runner includes validation, password/token and HTTP route tests using a mocked database pool, plus an end-to-end test against PostgreSQL and Socket.IO when TEST_DATABASE_URL is configured. CI is set up with a PostgreSQL service; the latest run still needs verification. Authenticated routes require an `Authorization: Bearer <access-token>` header. Request bodies are validated and bounded; passwords are bcrypt-hashed; SQL uses parameterized queries. Registration/login use an in-memory rate limiter, which must be replaced with a shared store before running multiple API replicas.

## Not implemented yet

The backend does not yet include presence/typing/read-receipt Socket.IO events, refresh-token rotation or server-side session revocation, email verification, password recovery, media uploads/storage, push notifications, voice/video calls, end-to-end encryption, group conversations, message attachments/voice notes, a complete moderation/report/block system, production deployment, or a full security review. These must not be treated as complete.
