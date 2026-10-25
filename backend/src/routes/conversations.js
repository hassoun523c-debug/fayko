import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { isBlockedBetween } from '../moderation.js';
import { messageSchema, sendValidationError, uuidSchema } from '../validation.js';

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

function errorResponse(res, status, code, message) {
  return res.status(status).json({ error: { code, message } });
}

async function requireMembership(pool, conversationId, userId) {
  const result = await pool.query(
    'SELECT 1 FROM conversation_members mine ' +
      'WHERE mine.conversation_id = $1 AND mine.user_id = $2 ' +
      'AND NOT EXISTS (SELECT 1 FROM conversation_members peer ' +
      'JOIN user_blocks b ON ' +
      '((b.blocker_id = $2 AND b.blocked_id = peer.user_id) OR ' +
      '(b.blocker_id = peer.user_id AND b.blocked_id = $2)) ' +
      'WHERE peer.conversation_id = mine.conversation_id AND peer.user_id <> $2)',
    [conversationId, userId],
  );
  return result.rows.length > 0;
}

export function createConversationsRouter({ pool, jwtSecret, io = null }) {
  const router = express.Router();
  router.use(requireAuth(jwtSecret, pool));

  router.get('/', async (req, res) => {
    const result = await pool.query(
      [
        'SELECT c.id, c.created_at, mine.last_read_at,',
        'other.participant, last.id AS last_message_id,',
        'last.body AS last_message_body, last.created_at AS last_message_at,',
        'last.sender_id AS last_message_sender_id,',
        'COALESCE(unread.count, 0)::int AS unread_count',
        'FROM conversation_members mine',
        'JOIN conversations c ON c.id = mine.conversation_id',
        'LEFT JOIN LATERAL (',
        'SELECT json_build_object(',
        "'id', u.id, 'username', u.username, 'displayName', u.display_name,",
        "'avatarUrl', u.avatar_url) AS participant",
        'FROM conversation_members cm JOIN users u ON u.id = cm.user_id',
        'WHERE cm.conversation_id = c.id AND cm.user_id <> $1 LIMIT 1',
        ') other ON true',
        'LEFT JOIN LATERAL (',
        'SELECT m.id, m.body, m.created_at, m.sender_id',
        'FROM messages m WHERE m.conversation_id = c.id AND m.deleted_at IS NULL',
        'ORDER BY m.created_at DESC, m.id DESC LIMIT 1',
        ') last ON true',
        'LEFT JOIN LATERAL (',
        'SELECT COUNT(*) AS count FROM messages m',
        'WHERE m.conversation_id = c.id AND m.sender_id <> $1',
        'AND m.created_at > mine.last_read_at AND m.deleted_at IS NULL',
        ') unread ON true',
        'WHERE mine.user_id = $1 AND NOT EXISTS (' +
        'SELECT 1 FROM conversation_members peer JOIN user_blocks b ON ' +
        '((b.blocker_id = $1 AND b.blocked_id = peer.user_id) OR ' +
        '(b.blocker_id = peer.user_id AND b.blocked_id = $1)) ' +
        'WHERE peer.conversation_id = c.id AND peer.user_id <> $1)',
        'ORDER BY COALESCE(last.created_at, c.created_at) DESC, c.id DESC',
      ].join(' '),
      [req.auth.userId],
    );

    return res.status(200).json({
      conversations: result.rows.map((row) => ({
        id: row.id,
        createdAt: row.created_at,
        lastReadAt: row.last_read_at,
        participant: row.participant,
        lastMessage: row.last_message_id
          ? {
              id: row.last_message_id,
              body: row.last_message_body,
              createdAt: row.last_message_at,
              senderId: row.last_message_sender_id,
            }
          : null,
        unreadCount: row.unread_count,
      })),
    });
  });

  router.post('/direct', async (req, res) => {
    const parsed = uuidSchema.safeParse(req.body?.userId);
    if (!parsed.success) {
      return errorResponse(
        res,
        400,
        'invalid_user_id',
        'معرّف المستخدم غير صالح.',
      );
    }

    const recipientId = parsed.data.toLowerCase();
    const currentUserId = req.auth.userId;
    if (recipientId === currentUserId) {
      return errorResponse(
        res,
        400,
        'cannot_message_self',
        'ما تگدر تفتح محادثة مباشرة ويا حسابك.',
      );
    }

    if (await isBlockedBetween(pool, currentUserId, recipientId)) {
      return errorResponse(res, 403, 'blocked_relationship', 'لا يمكن فتح محادثة مع هذا الحساب.');
    }

    const client = await pool.connect();
    let transactionOpen = false;
    try {
      await client.query('BEGIN');
      transactionOpen = true;

      const recipient = await client.query(
        'SELECT id FROM users WHERE id = $1',
        [recipientId],
      );
      if (recipient.rows.length === 0) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return errorResponse(
          res,
          404,
          'user_not_found',
          'المستخدم غير موجود.',
        );
      }

      const directKey = [currentUserId, recipientId].sort().join(':');
      const inserted = await client.query(
        'INSERT INTO conversations (direct_key) VALUES ($1) ' +
          'ON CONFLICT (direct_key) DO NOTHING RETURNING id',
        [directKey],
      );
      const created = inserted.rows.length > 0;
      let conversationId = inserted.rows[0]?.id;

      if (!conversationId) {
        const existing = await client.query(
          'SELECT id FROM conversations WHERE direct_key = $1',
          [directKey],
        );
        conversationId = existing.rows[0]?.id;
      }

      if (!conversationId) {
        throw new Error('Unable to create or retrieve direct conversation.');
      }

      await client.query(
        'INSERT INTO conversation_members (conversation_id, user_id) ' +
          'VALUES ($1, $2), ($1, $3) ON CONFLICT DO NOTHING',
        [conversationId, currentUserId, recipientId],
      );

      await client.query('COMMIT');
      transactionOpen = false;
      return res.status(created ? 201 : 200).json({
        conversation: {
          id: conversationId,
          participantId: recipientId,
        },
      });
    } catch (error) {
      if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
      throw error;
    } finally {
      client.release();
    }
  });

  router.get('/:conversationId/messages', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.conversationId);
    if (!parsedId.success) {
      return errorResponse(
        res,
        400,
        'invalid_conversation_id',
        'معرّف المحادثة غير صالح.',
      );
    }

    const conversationId = parsedId.data;
    const isMember = await requireMembership(
      pool,
      conversationId,
      req.auth.userId,
    );
    if (!isMember) {
      return errorResponse(
        res,
        404,
        'conversation_not_found',
        'المحادثة غير موجودة أو غير متاحة لهذا الحساب.',
      );
    }

    const rawLimit = req.query.limit ?? '50';
    const limit = typeof rawLimit === 'string' ? Number(rawLimit) : NaN;
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      return errorResponse(
        res,
        400,
        'invalid_limit',
        'عدد الرسائل في الصفحة يجب أن يكون من 1 إلى 100.',
      );
    }

    let cursor = null;
    if (req.query.before !== undefined) {
      cursor = decodeCursor(req.query.before);
      if (cursor.invalid) {
        return errorResponse(
          res,
          400,
          'invalid_cursor',
          'مؤشر الرسائل غير صالح.',
        );
      }
    }

    // Opening the message history advances this member's read marker.
    await pool.query(
      'UPDATE conversation_members SET last_read_at = GREATEST(last_read_at, NOW()) ' +
        'WHERE conversation_id = $1 AND user_id = $2',
      [conversationId, req.auth.userId],
    );

    const result = await pool.query(
      [
        'SELECT m.id, m.body, m.created_at, m.sender_id,',
        "json_build_object('id', u.id, 'username', u.username,",
        "'displayName', u.display_name, 'avatarUrl', u.avatar_url) AS sender",
        'FROM (',
        'SELECT id, body, created_at, sender_id FROM messages',
        'WHERE conversation_id = $1 AND deleted_at IS NULL',
        'AND ($2::timestamptz IS NULL OR (created_at, id) < ($2::timestamptz, $3::uuid))',
        'ORDER BY created_at DESC, id DESC LIMIT $4',
        ') m JOIN users u ON u.id = m.sender_id',
        'ORDER BY m.created_at ASC, m.id ASC',
      ].join(' '),
      [
        conversationId,
        cursor?.createdAt ?? null,
        cursor?.id ?? null,
        limit + 1,
      ],
    );

    const hasMore = result.rows.length > limit;
    const selectedRows = hasMore
      ? result.rows.slice(result.rows.length - limit)
      : result.rows;
    const messages = selectedRows.map((row) => ({
      id: row.id,
      body: row.body,
      createdAt: row.created_at,
      senderId: row.sender_id,
      sender: row.sender,
      isMine: row.sender_id === req.auth.userId,
    }));

    return res.status(200).json({
      messages,
      nextCursor: hasMore && selectedRows.length > 0
        ? encodeCursor(selectedRows[0])
        : null,
    });
  });

  router.post('/:conversationId/messages', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.conversationId);
    if (!parsedId.success) {
      return errorResponse(
        res,
        400,
        'invalid_conversation_id',
        'معرّف المحادثة غير صالح.',
      );
    }

    const parsedBody = messageSchema.safeParse(req.body);
    if (!parsedBody.success) {
      return sendValidationError(res, parsedBody.error);
    }

    const conversationId = parsedId.data;
    const isMember = await requireMembership(
      pool,
      conversationId,
      req.auth.userId,
    );
    if (!isMember) {
      return errorResponse(
        res,
        404,
        'conversation_not_found',
        'المحادثة غير موجودة أو غير متاحة لهذا الحساب.',
      );
    }

    const inserted = await pool.query(
      'INSERT INTO messages (conversation_id, sender_id, body) ' +
        'VALUES ($1, $2, $3) RETURNING id, body, created_at, sender_id',
      [conversationId, req.auth.userId, parsedBody.data.body],
    );
    const message = inserted.rows[0];
    const senderResult = await pool.query(
      'SELECT id, username, display_name, avatar_url FROM users WHERE id = $1',
      [req.auth.userId],
    );
    const sender = senderResult.rows[0];
    const messagePayload = {
      conversationId,
      id: message.id,
      body: message.body,
      createdAt: message.created_at,
      senderId: message.sender_id,
      sender: {
        id: sender.id,
        username: sender.username,
        displayName: sender.display_name,
        avatarUrl: sender.avatar_url,
      },
      isMine: true,
    };

    const members = await pool.query(
      'SELECT user_id FROM conversation_members WHERE conversation_id = $1',
      [conversationId],
    );

    // HTTP persists the message first; Socket.IO distributes only committed records.
    io?.to(conversationId).emit('message:new', messagePayload);
    for (const member of members.rows) {
      io?.to('user:' + member.user_id).emit('conversation:updated', {
        conversationId,
      });
    }

    return res.status(201).json({ message: messagePayload });
  });

  router.post('/:conversationId/read', async (req, res) => {
    const parsedId = uuidSchema.safeParse(req.params.conversationId);
    if (!parsedId.success) {
      return errorResponse(
        res,
        400,
        'invalid_conversation_id',
        'معرّف المحادثة غير صالح.',
      );
    }

    const result = await pool.query(
      'UPDATE conversation_members SET last_read_at = GREATEST(last_read_at, NOW()) ' +
        'WHERE conversation_id = $1 AND user_id = $2 RETURNING conversation_id',
      [parsedId.data, req.auth.userId],
    );
    if (result.rows.length === 0) {
      return errorResponse(
        res,
        404,
        'conversation_not_found',
        'المحادثة غير موجودة أو غير متاحة لهذا الحساب.',
      );
    }

    return res.status(200).json({ read: true });
  });

  return router;
}
