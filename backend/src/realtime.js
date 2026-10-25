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

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (typeof token !== 'string' || token.length > 4096) {
      return next(new Error('authentication_required'));
    }

    try {
      const principal = verifyAccessToken(token, jwtSecret);
      socket.data.userId = principal.userId;
      socket.data.sessionId = principal.sessionId;
      return next();
    } catch {
      return next(new Error('invalid_access_token'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId;
    socket.join('user:' + userId);
    socket.join('session:' + socket.data.sessionId);

    socket.on('conversation:join', async (payload, acknowledge) => {
      const ack = typeof acknowledge === 'function' ? acknowledge : () => {};
      const parsed = uuidSchema.safeParse(payload?.conversationId);
      if (!parsed.success) {
        ack({ ok: false, code: 'invalid_conversation_id' });
        return;
      }

      try {
        const result = await pool.query(
          'SELECT 1 FROM conversation_members WHERE conversation_id = $1 AND user_id = $2',
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
