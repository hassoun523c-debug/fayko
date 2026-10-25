import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const TOKEN_ISSUER = 'fayko-api';
const TOKEN_AUDIENCE = 'fayko-app';
const TOKEN_LIFETIME = '1h';

export async function hashPassword(password) {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(password, passwordHash) {
  return bcrypt.compare(password, passwordHash);
}

export function signAccessToken(userId, secret, sessionId = randomUUID()) {
  return jwt.sign({}, secret, {
    subject: userId,
    jwtid: sessionId,
    issuer: TOKEN_ISSUER,
    audience: TOKEN_AUDIENCE,
    expiresIn: TOKEN_LIFETIME,
    algorithm: 'HS256',
  });
}

export function verifyAccessToken(token, secret) {
  const decoded = jwt.verify(token, secret, {
    issuer: TOKEN_ISSUER,
    audience: TOKEN_AUDIENCE,
    algorithms: ['HS256'],
  });

  if (
    typeof decoded !== 'object' ||
    typeof decoded.sub !== 'string' ||
    typeof decoded.jti !== 'string'
  ) {
    throw new Error('Invalid access-token payload.');
  }

  return { userId: decoded.sub, sessionId: decoded.jti };
}

export const accessTokenLifetimeSeconds = 3600;
