import assert from 'node:assert/strict';
import test from 'node:test';
import {
  hashPassword,
  signAccessToken,
  verifyAccessToken,
  verifyPassword,
} from '../src/security.js';

const secret = 'test-only-secret-that-is-long-enough-2026';
const userId = 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1';

test('password hashes verify only the matching password', async () => {
  const password = 'A-strong-passphrase-2026';
  const hash = await hashPassword(password);

  assert.notEqual(hash, password);
  assert.equal(await verifyPassword(password, hash), true);
  assert.equal(await verifyPassword('not-the-password', hash), false);
});

test('access tokens verify expected subject and reject wrong secrets', () => {
  const token = signAccessToken(userId, secret);
  assert.deepEqual(verifyAccessToken(token, secret), { userId });
  assert.throws(() => verifyAccessToken(token, 'different-secret-that-is-long-enough'));
  assert.throws(() => verifyAccessToken('not-a-token', secret));
});
