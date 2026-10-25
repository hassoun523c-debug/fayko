import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { isBlockedBetween } from '../moderation.js';
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
  'FROM users u WHERE u.id = $1 AND NOT EXISTS (' +
    'SELECT 1 FROM user_blocks b WHERE ' +
    '(b.blocker_id = $2 AND b.blocked_id = u.id) OR ' +
    '(b.blocker_id = u.id AND b.blocked_id = $2))',
].join(' ');

export function createUsersRouter({ pool, jwtSecret, io = null }) {
  const router = express.Router();
  router.use(requireAuth(jwtSecret, pool));

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
        'FROM users u WHERE (POSITION($1 IN LOWER(u.username)) > 0 ' +
        'OR POSITION($1 IN LOWER(u.display_name)) > 0) ' +
        'AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE ' +
        '(b.blocker_id = $3 AND b.blocked_id = u.id) OR ' +
        '(b.blocker_id = u.id AND b.blocked_id = $3)) ' +
        'ORDER BY followers_count DESC, u.username ASC LIMIT $2',
      [query, limit, req.auth.userId],
    );

    return res.status(200).json({
      users: result.rows.map(publicProfile),
    });
  });

  router.get('/blocked', async (req, res) => {
    const result = await pool.query(
      'SELECT u.id, u.username, u.display_name, u.bio, u.avatar_url, u.created_at, ' +
        '(SELECT COUNT(*)::int FROM posts p WHERE p.author_id = u.id) AS posts_count, ' +
        '(SELECT COUNT(*)::int FROM follows f WHERE f.following_id = u.id) AS followers_count, ' +
        '(SELECT COUNT(*)::int FROM follows f WHERE f.follower_id = u.id) AS following_count, ' +
        'EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $1 AND f.following_id = u.id) AS is_following ' +
        'FROM user_blocks b JOIN users u ON u.id = b.blocked_id ' +
        'WHERE b.blocker_id = $1 ORDER BY b.created_at DESC LIMIT 200',
      [req.auth.userId],
    );
    return res.status(200).json({ users: result.rows.map(publicProfile) });
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
    if (await isBlockedBetween(pool, req.auth.userId, parsedId.data)) {
      return res.status(403).json({
        error: { code: 'blocked_relationship', message: 'لا يمكن متابعة هذا الحساب.' },
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

  router.post('/:userId/block', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.userId);
    if (!parsedId.success) return invalidUserId(res);
    const targetId = parsedId.data;

    if (targetId === req.auth.userId) {
      return res.status(400).json({
        error: { code: 'cannot_block_self', message: 'ما تگدر تحظر حسابك.' },
      });
    }

    const target = await pool.query('SELECT id FROM users WHERE id = $1', [targetId]);
    if (target.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'user_not_found', message: 'المستخدم غير موجود.' },
      });
    }

    await pool.query(
      'INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2) ' +
        'ON CONFLICT (blocker_id, blocked_id) DO NOTHING',
      [req.auth.userId, targetId],
    );
    await pool.query(
      'DELETE FROM follows WHERE (follower_id = $1 AND following_id = $2) ' +
        'OR (follower_id = $2 AND following_id = $1)',
      [req.auth.userId, targetId],
    );

    const sharedConversations = await pool.query(
      'SELECT a.conversation_id FROM conversation_members a ' +
        'JOIN conversation_members b ON b.conversation_id = a.conversation_id ' +
        'WHERE a.user_id = $1 AND b.user_id = $2',
      [req.auth.userId, targetId],
    );
    for (const item of sharedConversations.rows) {
      io?.in(item.conversation_id).socketsLeave(item.conversation_id);
      io?.to('user:' + req.auth.userId).emit('conversation:updated', {
        conversationId: item.conversation_id,
      });
      io?.to('user:' + targetId).emit('conversation:updated', {
        conversationId: item.conversation_id,
      });
    }

    return res.status(200).json({ blocked: true });
  });

  router.delete('/:userId/block', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.userId);
    if (!parsedId.success) return invalidUserId(res);
    const targetId = parsedId.data;

    await pool.query(
      'DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2',
      [req.auth.userId, targetId],
    );
    return res.status(200).json({ blocked: false });
  });

  return router;
}
