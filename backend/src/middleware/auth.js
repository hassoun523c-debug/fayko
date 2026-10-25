import { verifyAccessToken } from '../security.js';

export function requireAuth(jwtSecret, pool) {
  return async (req, res, next) => {
    const authorization = req.get('authorization') ?? '';
    const match = authorization.match(/^Bearer\s+(\S+)$/i);

    if (!match) {
      return res.status(401).json({
        error: {
          code: 'authentication_required',
          message: 'سجّل الدخول للمتابعة.',
        },
      });
    }

    let principal;
    try {
      principal = verifyAccessToken(match[1], jwtSecret);
    } catch {
      return res.status(401).json({
        error: {
          code: 'invalid_access_token',
          message: 'انتهت صلاحية الجلسة أو أن رمز الدخول غير صالح.',
        },
      });
    }

    try {
      const result = await pool.query(
        'SELECT 1 FROM user_sessions WHERE id = $1 AND user_id = $2 ' +
          'AND revoked_at IS NULL AND expires_at > NOW() LIMIT 1',
        [principal.sessionId, principal.userId],
      );

      if (result.rows.length === 0) {
        return res.status(401).json({
          error: {
            code: 'session_revoked_or_expired',
            message: 'انتهت الجلسة أو تم تسجيل الخروج. سجّل الدخول مجدداً.',
          },
        });
      }

      req.auth = principal;
      return next();
    } catch (error) {
      return next(error);
    }
  };
}
