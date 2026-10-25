import { randomUUID } from 'node:crypto';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { requireAuth } from '../middleware/auth.js';
import { reelCreateSchema, reelUploadSchema, interestValues, sendValidationError, uuidSchema } from '../validation.js';

const MAX_REEL_BYTES = 150 * 1024 * 1024;

function respondNotFound(res) {
  return res.status(404).json({
    error: { code: 'reel_not_found', message: 'الريل غير موجود أو غير متاح.' },
  });
}

function mediaNotConfigured(res) {
  return res.status(503).json({
    error: {
      code: 'media_storage_not_configured',
      message: 'رفع الفيديوهات لم يُفعّل على خادم فايكو بعد.',
    },
  });
}

function formatReel(row, videoUrl) {
  return {
    id: row.id,
    caption: row.caption,
    category: row.category,
    contentType: row.content_type,
    sizeBytes: Number(row.size_bytes),
    durationSeconds: row.duration_seconds,
    createdAt: row.created_at,
    author: row.author ?? {
      id: row.author_id,
      username: row.username,
      displayName: row.display_name,
      avatarUrl: row.avatar_url,
    },
    videoUrl,
  };
}

export function createReelsRouter({ pool, jwtSecret, mediaStorage = null }) {
  const router = express.Router();
  router.use(requireAuth(jwtSecret, pool));

  const uploadRateLimit = rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 10,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => res.status(429).json({
      error: {
        code: 'too_many_uploads',
        message: 'طلبات رفع كثيرة. انتظر قليلاً ثم حاول مجدداً.',
      },
    }),
  });

  router.get('/', async (req, res) => {
    let category = null;
    if (req.query.category !== undefined) {
      if (typeof req.query.category !== 'string' || !interestValues.includes(req.query.category)) {
        return res.status(400).json({
          error: { code: 'invalid_category', message: 'تصنيف الريل غير صالح.' },
        });
      }
      category = req.query.category;
    }

    const rawLimit = req.query.limit ?? '20';
    const limit = typeof rawLimit === 'string' ? Number(rawLimit) : NaN;
    if (!Number.isInteger(limit) || limit < 1 || limit > 30) {
      return res.status(400).json({
        error: { code: 'invalid_limit', message: 'الحد من 1 إلى 30 ريل.' },
      });
    }

    const result = await pool.query(
      [
        'SELECT r.id, r.author_id, r.object_key, r.caption, r.category,',
        'r.content_type, r.size_bytes, r.duration_seconds, r.created_at,',
        "json_build_object('id', u.id, 'username', u.username,",
        "'displayName', u.display_name, 'avatarUrl', u.avatar_url) AS author",
        'FROM reels r JOIN users u ON u.id = r.author_id',
        'WHERE ($2::text IS NULL OR r.category = $2)',
        'AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE',
        '(b.blocker_id = $1 AND b.blocked_id = r.author_id) OR',
        '(b.blocker_id = r.author_id AND b.blocked_id = $1))',
        'ORDER BY CASE WHEN r.category = ANY(COALESCE(',
        '(SELECT interests FROM users WHERE id = $1), ARRAY[]::text[]))',
        'THEN 0 ELSE 1 END, r.created_at DESC, r.id DESC LIMIT $3',
      ].join(' '),
      [req.auth.userId, category, limit],
    );

    const reels = await Promise.all(result.rows.map(async (row) => ({
      ...formatReel(
        row,
        mediaStorage ? await mediaStorage.createDownloadUrl({ key: row.object_key }) : null,
      ),
    })));

    return res.status(200).json({
      reels,
      uploadEnabled: Boolean(mediaStorage),
    });
  });

  router.post('/upload-url', uploadRateLimit, async (req, res) => {
    if (!mediaStorage) return mediaNotConfigured(res);

    const parsed = reelUploadSchema.safeParse(req.body);
    if (!parsed.success) return sendValidationError(res, parsed.error);

    const extension = parsed.data.contentType === 'video/mp4' ? 'mp4' : null;
    if (extension === null) {
      return res.status(400).json({
        error: { code: 'unsupported_video_type', message: 'ارفع فيديو بصيغة MP4.' },
      });
    }

    const objectKey = req.auth.userId + '/' + randomUUID() + '.' + extension;
    const uploadUrl = await mediaStorage.createUploadUrl({
      key: objectKey,
      contentType: parsed.data.contentType,
    });

    return res.status(201).json({
      uploadUrl,
      objectKey,
      contentType: parsed.data.contentType,
      fileSizeBytes: parsed.data.fileSizeBytes,
      expiresInSeconds: 900,
    });
  });

  router.post('/', async (req, res) => {
    if (!mediaStorage) return mediaNotConfigured(res);

    const parsed = reelCreateSchema.safeParse(req.body);
    if (!parsed.success) return sendValidationError(res, parsed.error);

    const input = parsed.data;
    if (!input.objectKey.startsWith(req.auth.userId + '/') ||
        input.objectKey.length > 512 ||
        input.objectKey.includes('..')) {
      return res.status(400).json({
        error: { code: 'invalid_upload_key', message: 'ملف الفيديو لا يتبع جلسة الرفع الحالية.' },
      });
    }

    const storedObject = await mediaStorage.headObject({ key: input.objectKey });
    if (!storedObject ||
        storedObject.sizeBytes < 1 ||
        storedObject.sizeBytes > MAX_REEL_BYTES ||
        storedObject.sizeBytes !== input.fileSizeBytes ||
        storedObject.contentType !== input.contentType) {
      return res.status(422).json({
        error: { code: 'uploaded_video_mismatch', message: 'ملف الفيديو غير مكتمل أو لا يطابق البيانات المطلوبة.' },
      });
    }

    const result = await pool.query(
      'INSERT INTO reels (author_id, object_key, caption, category, content_type, ' +
        'size_bytes, duration_seconds) VALUES ($1, $2, $3, $4, $5, $6, $7) ' +
        'RETURNING id, author_id, object_key, caption, category, content_type, ' +
        'size_bytes, duration_seconds, created_at',
      [
        req.auth.userId,
        input.objectKey,
        input.caption,
        input.category,
        input.contentType,
        storedObject.sizeBytes,
        input.durationSeconds ?? null,
      ],
    );
    const row = result.rows[0];
    const authorResult = await pool.query(
      'SELECT id, username, display_name, avatar_url FROM users WHERE id = $1',
      [req.auth.userId],
    );
    row.author = {
      id: authorResult.rows[0].id,
      username: authorResult.rows[0].username,
      displayName: authorResult.rows[0].display_name,
      avatarUrl: authorResult.rows[0].avatar_url,
    };

    return res.status(201).json({
      reel: formatReel(
        row,
        await mediaStorage.createDownloadUrl({ key: row.object_key }),
      ),
    });
  });

  router.delete('/:reelId', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.reelId);
    if (!parsedId.success) {
      return res.status(400).json({
        error: { code: 'invalid_reel_id', message: 'معرّف الريل غير صالح.' },
      });
    }
    if (!mediaStorage) return mediaNotConfigured(res);

    const result = await pool.query(
      'SELECT id, object_key FROM reels WHERE id = $1 AND author_id = $2',
      [parsedId.data, req.auth.userId],
    );
    if (result.rows.length === 0) return respondNotFound(res);

    await mediaStorage.deleteObject({ key: result.rows[0].object_key });
    await pool.query('DELETE FROM reels WHERE id = $1 AND author_id = $2', [
      parsedId.data,
      req.auth.userId,
    ]);
    return res.status(204).send();
  });

  return router;
}
