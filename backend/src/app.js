import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { createAuthRouter } from './routes/auth.js';
import { createPostsRouter } from './routes/posts.js';
import { createUsersRouter } from './routes/users.js';
import { createConversationsRouter } from './routes/conversations.js';

export function createApp({ pool, jwtSecret, io = null }) {
  const app = express();
  const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        if (!origin || allowedOrigins.includes(origin)) {
          return callback(null, true);
        }
        return callback(null, false);
      },
      optionsSuccessStatus: 204,
    }),
  );
  app.use(express.json({ limit: '32kb', strict: true }));

  app.get('/healthz', (_req, res) => {
    return res.status(200).json({ status: 'ok', service: 'fayko-api' });
  });

  app.get('/readyz', async (_req, res) => {
    try {
      await pool.query('SELECT 1');
      return res.status(200).json({ status: 'ready', database: 'ok' });
    } catch {
      return res.status(503).json({
        status: 'not_ready',
        error: { code: 'database_unavailable' },
      });
    }
  });

  const authRateLimit = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      return res.status(429).json({
        error: {
          code: 'too_many_auth_attempts',
          message: 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.',
        },
      });
    },
  });

  app.use(
    '/api/v1/auth',
    createAuthRouter({ pool, jwtSecret, authRateLimit, io }),
  );
  app.use('/api/v1/posts', createPostsRouter({ pool, jwtSecret }));
  app.use('/api/v1/users', createUsersRouter({ pool, jwtSecret }));
  app.use('/api/v1/conversations', createConversationsRouter({ pool, jwtSecret, io }));

  app.use((_req, res) => {
    return res.status(404).json({
      error: { code: 'route_not_found', message: 'المسار غير موجود.' },
    });
  });

  app.use((error, _req, res, next) => {
    if (res.headersSent) {
      return next(error);
    }

    if (error?.type === 'entity.too.large') {
      return res.status(413).json({
        error: { code: 'request_too_large', message: 'حجم الطلب أكبر من المسموح.' },
      });
    }

    if (error instanceof SyntaxError && Object.hasOwn(error, 'body')) {
      return res.status(400).json({
        error: { code: 'invalid_json', message: 'صيغة JSON غير صالحة.' },
      });
    }

    console.error('Unhandled API error:', error?.message ?? 'unknown error');
    return res.status(500).json({
      error: {
        code: 'internal_error',
        message: 'حدث خطأ داخلي. حاول مجدداً لاحقاً.',
      },
    });
  });

  return app;
}
