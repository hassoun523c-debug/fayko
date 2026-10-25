import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import {
  commentSchema,
  postSchema,
  sendValidationError,
  uuidSchema,
} from '../validation.js';

function encodeCursor(row) {
  return Buffer.from(
    JSON.stringify({
      createdAt: new Date(row.created_at).toISOString(),
      id: row.id,
    }),
  ).toString('base64url');
}

function decodeCursor(value) {
  if (typeof value !== 'string' || value.length > 512) {
    return { invalid: true };
  }

  try {
    const decoded = JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
    const parsedId = uuidSchema.safeParse(decoded.id);
    const date = new Date(decoded.createdAt);

    if (!parsedId.success || !Number.isFinite(date.getTime())) {
      return { invalid: true };
    }

    return { createdAt: date.toISOString(), id: parsedId.data };
  } catch {
    return { invalid: true };
  }
}

function respondNotFound(res, resource = 'post') {
  const message = resource === 'comment'
    ? 'التعليق أو المنشور غير موجود.'
    : 'المنشور غير موجود.';
  return res.status(404).json({
    error: { code: 'not_found', message },
  });
}

export function createPostsRouter({ pool, jwtSecret }) {
  const router = express.Router();
  router.use(requireAuth(jwtSecret, pool));

  router.get('/', async (req, res) => {
    const rawLimit = req.query.limit ?? '20';
    const limit = typeof rawLimit === 'string' ? Number(rawLimit) : NaN;
    if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
      return res.status(400).json({
        error: {
          code: 'invalid_limit',
          message: 'الحد الأقصى للصفحة من 1 إلى 50 منشوراً.',
        },
      });
    }

    let cursor = null;
    if (req.query.cursor !== undefined) {
      cursor = decodeCursor(req.query.cursor);
      if (cursor.invalid) {
        return res.status(400).json({
          error: { code: 'invalid_cursor', message: 'مؤشر الصفحة غير صالح.' },
        });
      }
    }

    const query = [
      'SELECT p.id, p.body, p.created_at, p.updated_at,',
      "json_build_object('id', u.id, 'username', u.username,",
      "'displayName', u.display_name, 'avatarUrl', u.avatar_url) AS author,",
      '(SELECT COUNT(*)::int FROM post_likes pl WHERE pl.post_id = p.id) AS likes_count,',
      '(SELECT COUNT(*)::int FROM comments c WHERE c.post_id = p.id) AS comments_count,',
      'EXISTS (SELECT 1 FROM post_likes mine WHERE mine.post_id = p.id',
      'AND mine.user_id = $4) AS liked_by_me',
      'FROM posts p JOIN users u ON u.id = p.author_id',
      'WHERE ($2::timestamptz IS NULL OR',
      '(p.created_at, p.id) < ($2::timestamptz, $3::uuid))',
      'ORDER BY p.created_at DESC, p.id DESC LIMIT $1',
    ].join(' ');

    const result = await pool.query(query, [
      limit + 1,
      cursor?.createdAt ?? null,
      cursor?.id ?? null,
      req.auth.userId,
    ]);

    const hasMore = result.rows.length > limit;
    const rows = result.rows.slice(0, limit);
    const posts = rows.map((row) => ({
      id: row.id,
      body: row.body,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      author: row.author,
      likesCount: row.likes_count,
      commentsCount: row.comments_count,
      likedByMe: row.liked_by_me,
    }));

    return res.status(200).json({
      posts,
      nextCursor: hasMore && rows.length > 0
        ? encodeCursor(rows[rows.length - 1])
        : null,
    });
  });

  router.post('/', async (req, res) => {
    const parsed = postSchema.safeParse(req.body);
    if (!parsed.success) {
      return sendValidationError(res, parsed.error);
    }

    const inserted = await pool.query(
      'INSERT INTO posts (author_id, body) VALUES ($1, $2) ' +
        'RETURNING id, body, created_at, updated_at',
      [req.auth.userId, parsed.data.body],
    );
    const row = inserted.rows[0];

    const result = await pool.query(
      'SELECT p.id, p.body, p.created_at, p.updated_at, ' +
        "json_build_object('id', u.id, 'username', u.username, " +
        "'displayName', u.display_name, 'avatarUrl', u.avatar_url) AS author " +
        'FROM posts p JOIN users u ON u.id = p.author_id WHERE p.id = $1',
      [row.id],
    );

    const post = result.rows[0];
    return res.status(201).json({
      post: {
        id: post.id,
        body: post.body,
        createdAt: post.created_at,
        updatedAt: post.updated_at,
        author: post.author,
        likesCount: 0,
        commentsCount: 0,
        likedByMe: false,
      },
    });
  });

  router.post('/:postId/like', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.postId);
    if (!parsedId.success) {
      return res.status(400).json({
        error: { code: 'invalid_post_id', message: 'معرّف المنشور غير صالح.' },
      });
    }

    const postId = parsedId.data;
    const exists = await pool.query('SELECT 1 FROM posts WHERE id = $1', [postId]);
    if (exists.rows.length === 0) {
      return respondNotFound(res);
    }

    await pool.query(
      'INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2) ' +
        'ON CONFLICT (post_id, user_id) DO NOTHING',
      [postId, req.auth.userId],
    );

    return res.status(200).json({ liked: true });
  });

  router.delete('/:postId/like', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.postId);
    if (!parsedId.success) {
      return res.status(400).json({
        error: { code: 'invalid_post_id', message: 'معرّف المنشور غير صالح.' },
      });
    }

    const postId = parsedId.data;
    const exists = await pool.query('SELECT 1 FROM posts WHERE id = $1', [postId]);
    if (exists.rows.length === 0) {
      return respondNotFound(res);
    }

    await pool.query(
      'DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2',
      [postId, req.auth.userId],
    );

    return res.status(200).json({ liked: false });
  });

  router.get('/:postId/comments', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.postId);
    if (!parsedId.success) {
      return res.status(400).json({
        error: { code: 'invalid_post_id', message: 'معرّف المنشور غير صالح.' },
      });
    }

    const postId = parsedId.data;
    const exists = await pool.query('SELECT 1 FROM posts WHERE id = $1', [postId]);
    if (exists.rows.length === 0) {
      return respondNotFound(res, 'comment');
    }

    const result = await pool.query(
      'SELECT c.id, c.body, c.created_at, ' +
        "json_build_object('id', u.id, 'username', u.username, " +
        "'displayName', u.display_name, 'avatarUrl', u.avatar_url) AS author " +
        'FROM (SELECT * FROM comments WHERE post_id = $1 ' +
        'ORDER BY created_at DESC, id DESC LIMIT 100) c ' +
        'JOIN users u ON u.id = c.author_id ' +
        'ORDER BY c.created_at ASC, c.id ASC',
      [postId],
    );

    return res.status(200).json({
      comments: result.rows.map((row) => ({
        id: row.id,
        body: row.body,
        createdAt: row.created_at,
        author: row.author,
      })),
    });
  });

  router.post('/:postId/comments', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.postId);
    if (!parsedId.success) {
      return res.status(400).json({
        error: { code: 'invalid_post_id', message: 'معرّف المنشور غير صالح.' },
      });
    }

    const parsedBody = commentSchema.safeParse(req.body);
    if (!parsedBody.success) {
      return sendValidationError(res, parsedBody.error);
    }

    const inserted = await pool.query(
      'INSERT INTO comments (post_id, author_id, body) ' +
        'SELECT p.id, $2, $3 FROM posts p WHERE p.id = $1 ' +
        'RETURNING id, body, created_at, author_id',
      [parsedId.data, req.auth.userId, parsedBody.data.body],
    );

    if (inserted.rows.length === 0) {
      return respondNotFound(res, 'comment');
    }

    const row = inserted.rows[0];
    const authorResult = await pool.query(
      'SELECT id, username, display_name, avatar_url FROM users WHERE id = $1',
      [row.author_id],
    );
    const user = authorResult.rows[0];

    return res.status(201).json({
      comment: {
        id: row.id,
        body: row.body,
        createdAt: row.created_at,
        author: {
          id: user.id,
          username: user.username,
          displayName: user.display_name,
          avatarUrl: user.avatar_url,
        },
      },
    });
  });

  router.delete('/:postId', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.postId);
    if (!parsedId.success) {
      return res.status(400).json({
        error: { code: 'invalid_post_id', message: 'معرّف المنشور غير صالح.' },
      });
    }

    const result = await pool.query(
      'DELETE FROM posts WHERE id = $1 AND author_id = $2 RETURNING id',
      [parsedId.data, req.auth.userId],
    );

    if (result.rows.length === 0) {
      return respondNotFound(res);
    }

    return res.status(204).send();
  });

  return router;
}
