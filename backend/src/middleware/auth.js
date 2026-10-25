import { verifyAccessToken } from '../security.js';

export function requireAuth(jwtSecret) {
  return (req, res, next) => {
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

    try {
      req.auth = verifyAccessToken(match[1], jwtSecret);
      return next();
    } catch {
      return res.status(401).json({
        error: {
          code: 'invalid_access_token',
          message: 'انتهت صلاحية الجلسة أو أن رمز الدخول غير صالح.',
        },
      });
    }
  };
}
