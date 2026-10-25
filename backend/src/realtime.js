import { Server as SocketIOServer } from 'socket.io';
import { verifyAccessToken } from './security.js';
import { uuidSchema } from './validation.js';

export function attachRealtimeGateway({ httpServer, pool, jwtSecret }) {
  const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  const io = new SocketIOServer(httpServer, {
    cors: {
      origin(origin, callback) {
        if (!origin || allowedOrigins.includes(origin)) {
          return callback(null, true);
        }
        return callback(new Error('Origin not allowed'));
      },
      methods: ['GET', 'POST'],
    },
    maxHttpBufferSize: 100_000,
    pingInterval: 25_000,
    pingTimeout: 20_000,
  });

  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (typeof token !== 'string' || token.length > 4096) {
      return next(new Error('authentication_required'));
    }

    let principal;
    try {
      principal = verifyAccessToken(token, jwtSecret);
    } catch {
      return next(new Error('invalid_access_token'));
    }

    try {
      const result = await pool.query(
        'SELECT expires_at FROM user_sessions WHERE id = $1 AND user_id = $2 ' +
          'AND revoked_at IS NULL AND expires_at > NOW() LIMIT 1',
        [principal.sessionId, principal.userId],
      );
      if (result.rows.length === 0) {
        return next(new Error('session_revoked_or_expired'));
      }

      socket.data.userId = principal.userId;
      socket.data.sessionId = principal.sessionId;
      socket.data.sessionExpiresAt = new Date(result.rows[0].expires_at).getTime();
      return next();
    } catch {
      return next(new Error('authentication_unavailable'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId;
    socket.join('user:' + userId);
    socket.join('session:' + socket.data.sessionId);
    const expiryDelay = Math.max(0, socket.data.sessionExpiresAt - Date.now());
    const expiryTimer = setTimeout(() => socket.disconnect(true), expiryDelay);
    expiryTimer.unref();
    socket.on('disconnect', () => clearTimeout(expiryTimer));

    socket.on('conversation:join', async (payload, acknowledge) => {
      const ack = typeof acknowledge === 'function' ? acknowledge : () => {};
      const parsed = uuidSchema.safeParse(payload?.conversationId);
      if (!parsed.success) {
        ack({ ok: false, code: 'invalid_conversation_id' });
        return;
      }

      try {
        const result = await pool.query(
          'SELECT 1 FROM conversation_members mine ' +
            'WHERE mine.conversation_id = $1 AND mine.user_id = $2 ' +
            'AND NOT EXISTS (SELECT 1 FROM conversation_members peer JOIN user_blocks b ON ' +
            '((b.blocker_id = $2 AND b.blocked_id = peer.user_id) OR ' +
            '(b.blocker_id = peer.user_id AND b.blocked_id = $2)) ' +
            'WHERE peer.conversation_id = mine.conversation_id AND peer.user_id <> $2)',
          [parsed.data, userId],
        );
        if (result.rows.length === 0) {
          ack({ ok: false, code: 'conversation_not_found' });
          return;
        }

        await socket.join(parsed.data);
        ack({ ok: true, conversationId: parsed.data });
      } catch (error) {
        console.error('Socket conversation join failed:', error.message);
        ack({ ok: false, code: 'internal_error' });
      }
    });

    socket.on('conversation:leave', (payload) => {
      const parsed = uuidSchema.safeParse(payload?.conversationId);
      if (parsed.success) socket.leave(parsed.data);
    });
  });

  return io;
}
