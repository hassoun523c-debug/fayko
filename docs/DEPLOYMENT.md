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


## 4. Optional: enable real reel video uploads

Reel categories and the feed API work without a media bucket, but uploading real video is intentionally disabled until object storage is configured.

1. In the Cloudflare dashboard, open **R2 Object Storage** and create a private bucket for Fayko. Do not enable public access for this test.
2. Under **R2 → Manage API Tokens**, create an S3 API token with Object Read & Write permissions scoped to that bucket only. Save the Access Key ID and Secret Access Key securely; Cloudflare does not show the secret again. Official setup guide: [Cloudflare R2 S3 API](https://developers.cloudflare.com/r2/get-started/s3/).
3. Copy the account S3 endpoint, in this form: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`, along with the exact bucket name. R2 uses region `auto`. Official guide to temporary signed URLs: [Cloudflare R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/).
4. In Render, open the `fayko-api` service's **Environment** page and set `R2_ENDPOINT`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, and `R2_SECRET_ACCESS_KEY`; keep `R2_REGION=auto`. Never commit credentials to GitHub or share them in chat. The service will restart and the reel screen's upload indicator should change after the API is redeployed.
5. Test with a short, non-private MP4 video first. The app currently allows MP4 up to 150 MiB and up to three minutes. Video playback is delivered using temporary signed URLs, not a public bucket.

If any of the four required R2 values are missing, the server either leaves reel upload disabled (all blank) or fails startup (partially configured). Keep the bucket private and the credentials restricted to that bucket.

## Limitations of this free test setup

Render's free web service can go idle and take about a minute to wake up. Its free PostgreSQL database expires after 30 days; this setup is temporary and must not be used for data that needs long-term preservation. Do not upload private photos, confidential messages, or information you would not want exposed during testing. Use test account details, and tell your brother not to share the test password.
