# Fayko API

This directory contains the first backend implementation for Fayko. It is a real HTTP API with PostgreSQL persistence; the Flutter app is not connected to it yet.

## Local setup

1. Install Docker Desktop or Docker Engine with the Compose plugin.
2. Copy .env.example to .env.
3. Replace JWT_SECRET with a random secret of at least 32 characters. One option is to run openssl rand -hex 32.
4. Start from this directory with docker compose up --build.
5. Check http://127.0.0.1:4000/healthz and http://127.0.0.1:4000/readyz.

The database schema is initialized automatically on the first creation of the PostgreSQL volume. Existing volumes are not modified by the initialization script; back up data before applying later migrations. The compose configuration binds the API to 127.0.0.1 by default. Do not expose the API publicly until HTTPS, production secrets, deployment networking, monitoring, and operational controls are configured.

## Implemented API routes

- GET /healthz — process health.
- GET /readyz — database readiness check.
- POST /api/v1/auth/register — create a user and return a short-lived bearer access token.
- POST /api/v1/auth/login — authenticate by username or email.
- GET /api/v1/auth/me — return the current user's profile.
- PATCH /api/v1/auth/me — update display name, bio, or avatar URL.
- GET /api/v1/posts — authenticated, cursor-paginated public post feed.
- POST /api/v1/posts — create a text post.
- POST /api/v1/posts/:postId/like — like a post; duplicate likes are idempotent.
- DELETE /api/v1/posts/:postId/like — remove the current user's like.
- GET /api/v1/posts/:postId/comments — read up to the latest 100 comments.
- POST /api/v1/posts/:postId/comments — add a comment.
- DELETE /api/v1/posts/:postId — delete a post owned by the current user.

All authenticated routes require an Authorization header in the form Bearer access-token. Request bodies are validated and bounded; passwords are hashed with bcrypt; SQL access uses parameterized queries. Registration and login share an in-memory rate limit, which must be replaced by a shared store before running multiple API replicas.

## Not implemented yet

The Flutter client has not been wired to these endpoints. This backend does not yet include refresh-token rotation or server-side session revocation, email verification, password recovery, user search/follow endpoints, image/video uploads, push notifications, realtime messaging, voice/video calls, end-to-end encryption, moderation tooling, production deployment, or a full security review. These must not be treated as complete.
