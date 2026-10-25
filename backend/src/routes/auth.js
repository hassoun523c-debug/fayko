import express from 'express';
import {
  accessTokenLifetimeSeconds,
  hashPassword,
  signAccessToken,
  verifyPassword,
} from '../security.js';
import { requireAuth } from '../middleware/auth.js';
import {
  loginSchema,
  profileUpdateSchema,
  registerSchema,
  sendValidationError,
} from '../validation.js';

const publicUserColumns =
  'id, username, email, display_name, bio, avatar_url, created_at, updated_at';

function formatUser(row) {
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    displayName: row.display_name,
    bio: row.bio,
    avatarUrl: row.avatar_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function sendInvalidCredentials(res) {
  return res.status(401).json({
    error: {
      code: 'invalid_credentials',
      message: 'اسم المستخدم أو كلمة المرور غير صحيحة.',
    },
  });
}

export function createAuthRouter({ pool, jwtSecret, authRateLimit }) {
  const router = express.Router();

  router.post('/register', authRateLimit, async (req, res) => {
    const parsed = registerSchema.safeParse(req.body);
    if (!parsed.success) {
      return sendValidationError(res, parsed.error);
    }

    const { username, email, password, displayName } = parsed.data;
    const passwordHash = await hashPassword(password);

    try {
      const result = await pool.query(
        'INSERT INTO users (username, email, display_name, password_hash) ' +
          'VALUES ($1, $2, $3, $4) RETURNING ' +
          publicUserColumns,
        [username, email, displayName ?? username, passwordHash],
      );
      const user = formatUser(result.rows[0]);
      const accessToken = signAccessToken(user.id, jwtSecret);

      return res.status(201).json({
        user,
        accessToken,
        tokenType: 'Bearer',
        expiresInSeconds: accessTokenLifetimeSeconds,
      });
    } catch (error) {
      if (error.code === '23505') {
        return res.status(409).json({
          error: {
            code: 'account_already_exists',
            message: 'اسم المستخدم أو البريد الإلكتروني مستخدم بالفعل.',
          },
        });
      }
      throw error;
    }
  });

  router.post('/login', authRateLimit, async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      return sendValidationError(res, parsed.error);
    }

    const { identifier, password } = parsed.data;
    const result = await pool.query(
      'SELECT ' + publicUserColumns + ', password_hash FROM users ' +
        'WHERE LOWER(email) = $1 OR LOWER(username) = $1 LIMIT 1',
      [identifier],
    );

    if (result.rows.length === 0) {
      return sendInvalidCredentials(res);
    }

    const row = result.rows[0];
    const passwordMatches = await verifyPassword(password, row.password_hash);
    if (!passwordMatches) {
      return sendInvalidCredentials(res);
    }

    const user = formatUser(row);
    const accessToken = signAccessToken(user.id, jwtSecret);

    return res.status(200).json({
      user,
      accessToken,
      tokenType: 'Bearer',
      expiresInSeconds: accessTokenLifetimeSeconds,
    });
  });

  router.get('/me', requireAuth(jwtSecret), async (req, res) => {
    const result = await pool.query(
      'SELECT ' + publicUserColumns + ' FROM users WHERE id = $1',
      [req.auth.userId],
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        error: {
          code: 'account_not_available',
          message: 'الحساب غير متاح. سجّل الدخول من جديد.',
        },
      });
    }

    return res.status(200).json({ user: formatUser(result.rows[0]) });
  });

  router.patch('/me', requireAuth(jwtSecret), async (req, res) => {
    const parsed = profileUpdateSchema.safeParse(req.body);
    if (!parsed.success) {
      return sendValidationError(res, parsed.error);
    }

    const data = parsed.data;
    const result = await pool.query(
      'UPDATE users SET ' +
        'display_name = CASE WHEN $2::boolean THEN $3 ELSE display_name END, ' +
        'bio = CASE WHEN $4::boolean THEN $5 ELSE bio END, ' +
        'avatar_url = CASE WHEN $6::boolean THEN $7 ELSE avatar_url END, ' +
        'updated_at = NOW() WHERE id = $1 RETURNING ' +
        publicUserColumns,
      [
        req.auth.userId,
        Object.hasOwn(data, 'displayName'),
        data.displayName ?? null,
        Object.hasOwn(data, 'bio'),
        data.bio ?? null,
        Object.hasOwn(data, 'avatarUrl'),
        data.avatarUrl ?? null,
      ],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: 'account_not_found', message: 'الحساب غير موجود.' },
      });
    }

    return res.status(200).json({ user: formatUser(result.rows[0]) });
  });

  return router;
}
