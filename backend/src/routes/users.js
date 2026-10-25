import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { uuidSchema } from '../validation.js';

function invalidUserId(res) {
  return res.status(400).json({
    error: { code: 'invalid_user_id', message: 'معرّف المستخدم غير صالح.' },
  });
}

function publicProfile(row) {
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    bio: row.bio,
    avatarUrl: row.avatar_url,
    createdAt: row.created_at,
    postsCount: row.posts_count,
    followersCount: row.followers_count,
    followingCount: row.following_count,
    isFollowing: row.is_following,
  };
}

const profileQuery = [
  'SELECT u.id, u.username, u.display_name, u.bio, u.avatar_url, u.created_at,',
  '(SELECT COUNT(*)::int FROM posts p WHERE p.author_id = u.id) AS posts_count,',
  '(SELECT COUNT(*)::int FROM follows f WHERE f.following_id = u.id) AS followers_count,',
  '(SELECT COUNT(*)::int FROM follows f WHERE f.follower_id = u.id) AS following_count,',
  'EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $2',
  'AND f.following_id = u.id) AS is_following',
  'FROM users u WHERE u.id = $1',
].join(' ');

export function createUsersRouter({ pool, jwtSecret }) {
  const router = express.Router();
  router.use(requireAuth(jwtSecret));

  router.get('/search', async (req, res) => {
    const rawQuery = req.query.q;
    const query = typeof rawQuery === 'string' ? rawQuery.trim().toLowerCase() : '';
    const rawLimit = req.query.limit ?? '20';
    const limit = typeof rawLimit === 'string' ? Number(rawLimit) : NaN;

    if (query.length < 2 || query.length > 40) {
      return res.status(400).json({
        error: {
          code: 'invalid_search_query',
          message: 'اكتب حرفين على الأقل وبحد أقصى 40 حرفاً.',
        },
      });
    }
    if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
      return res.status(400).json({
        error: {
          code: 'invalid_limit',
          message: 'الحد الأقصى للنتائج من 1 إلى 50.',
        },
      });
    }

    const result = await pool.query(
      'SELECT u.id, u.username, u.display_name, u.bio, u.avatar_url, u.created_at, ' +
        '(SELECT COUNT(*)::int FROM posts p WHERE p.author_id = u.id) AS posts_count, ' +
        '(SELECT COUNT(*)::int FROM follows f WHERE f.following_id = u.id) AS followers_count, ' +
        '(SELECT COUNT(*)::int FROM follows f WHERE f.follower_id = u.id) AS following_count, ' +
        'EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $3 AND f.following_id = u.id) AS is_following ' +
        'FROM users u WHERE POSITION($1 IN LOWER(u.username)) > 0 ' +
        'OR POSITION($1 IN LOWER(u.display_name)) > 0 ' +
        'ORDER BY followers_count DESC, u.username ASC LIMIT $2',
      [query, limit, req.auth.userId],
    );

    return res.status(200).json({
      users: result.rows.map(publicProfile),
    });
  });

  router.get('/:userId', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.userId);
    if (!parsedId.success) return invalidUserId(res);

    const result = await pool.query(profileQuery, [
      parsedId.data,
      req.auth.userId,
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'user_not_found', message: 'المستخدم غير موجود.' },
      });
    }

    return res.status(200).json({ user: publicProfile(result.rows[0]) });
  });

  router.post('/:userId/follow', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.userId);
    if (!parsedId.success) return invalidUserId(res);

    if (parsedId.data === req.auth.userId) {
      return res.status(400).json({
        error: { code: 'cannot_follow_self', message: 'ما تگدر تتابع حسابك.' },
      });
    }

    const target = await pool.query(
      'SELECT id FROM users WHERE id = $1',
      [parsedId.data],
    );
    if (target.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'user_not_found', message: 'المستخدم غير موجود.' },
      });
    }

    await pool.query(
      'INSERT INTO follows (follower_id, following_id) VALUES ($1, $2) ' +
        'ON CONFLICT (follower_id, following_id) DO NOTHING',
      [req.auth.userId, parsedId.data],
    );

    return res.status(200).json({ following: true });
  });

  router.delete('/:userId/follow', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.userId);
    if (!parsedId.success) return invalidUserId(res);

    const target = await pool.query(
      'SELECT id FROM users WHERE id = $1',
      [parsedId.data],
    );
    if (target.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'user_not_found', message: 'المستخدم غير موجود.' },
      });
    }

    await pool.query(
      'DELETE FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.auth.userId, parsedId.data],
    );

    return res.status(200).json({ following: false });
  });

  return router;
}
