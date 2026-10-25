# Private test deployment for Fayko

This guide creates a shared API and PostgreSQL database so two Android phones can use the same accounts and messages. The deployment is a **private test environment, not production**.

## 1. Create the backend

1. Sign in to Render and open **New → Blueprint**.
2. Connect the GitHub repository `hassoun523c-debug/fayko` and select its `main` branch.
3. Review the services in `render.yaml` and apply the Blueprint.
4. Wait until both the `fayko-api` web service and `fayko-db` database show a successful first deploy.

The Blueprint generates `JWT_SECRET` for the service and connects the API to PostgreSQL. Never replace the generated secret with a secret committed to GitHub.

## 2. Check that the API is awake

Open these paths using the actual service hostname shown in the Render dashboard:

- `https://YOUR-SERVICE.onrender.com/healthz` should return JSON with `"status":"ok"`.
- `https://YOUR-SERVICE.onrender.com/readyz` should return JSON with `"status":"ready"` and `"database":"ok"`.

Replace `YOUR-SERVICE` with the hostname Render gives the service; it is not pre-created by this repository.

## 3. Use the same API URL on both phones

The Android package must be built with this base URL (including `/api/v1`):

```text
https://YOUR-SERVICE.onrender.com/api/v1
```

The APK should be built with Flutter's `--dart-define=FAYKO_API_BASE_URL=...` value for this exact URL. Both devices must use the same URL to see each other's accounts, posts, and messages. The default `10.0.2.2` address is for the Android emulator only; it does not work on normal phones.

## Limitations of this free test setup

Render's free web service can go idle and take about a minute to wake up. Its free PostgreSQL database expires after 30 days; this setup is temporary and must not be used for data that needs long-term preservation. Do not upload private photos, confidential messages, or information you would not want exposed during testing. Use test account details, and tell your brother not to share the test password.
