import assert from 'node:assert/strict';
import test from 'node:test';
import {
  commentSchema,
  loginSchema,
  messageSchema,
  postSchema,
  profileUpdateSchema,
  registerSchema,
} from '../src/validation.js';

test('registration trims and normalizes account identifiers', () => {
  const result = registerSchema.parse({
    username: ' Fayko_User ',
    email: ' USER@EXAMPLE.COM ',
    password: 'A-strong-passphrase-2026',
    displayName: ' Fayko User ',
  });

  assert.equal(result.username, 'fayko_user');
  assert.equal(result.email, 'user@example.com');
  assert.equal(result.displayName, 'Fayko User');
});

test('registration rejects short passwords and non-ASCII passwords over bcrypt limit', () => {
  assert.equal(
    registerSchema.safeParse({
      username: 'valid_user',
      email: 'user@example.com',
      password: 'short',
    }).success,
    false,
  );

  assert.equal(
    registerSchema.safeParse({
      username: 'valid_user',
      email: 'user@example.com',
      password: 'ع'.repeat(40),
    }).success,
    false,
  );
});

test('login identifier is normalized', () => {
  const result = loginSchema.parse({
    identifier: ' USER@EXAMPLE.COM ',
    password: 'a password',
  });
  assert.equal(result.identifier, 'user@example.com');
});

test('profile updates require at least one supported field', () => {
  assert.equal(profileUpdateSchema.safeParse({}).success, false);
  assert.equal(profileUpdateSchema.safeParse({ bio: 'مهتم بالتقنية' }).success, true);
  assert.equal(profileUpdateSchema.safeParse({ unknown: 'value' }).success, false);
});

test('post and comment bodies are trimmed and bounded', () => {
  assert.deepEqual(postSchema.parse({ body: '  أهلاً بفايكو  ' }), {
    body: 'أهلاً بفايكو',
  });
  assert.equal(postSchema.safeParse({ body: '   ' }).success, false);
  assert.equal(postSchema.safeParse({ body: 'x'.repeat(2001) }).success, false);
  assert.equal(commentSchema.safeParse({ body: 'x'.repeat(1001) }).success, false);
  assert.equal(messageSchema.parse({ body: '  رسالة  ' }).body, 'رسالة');
  assert.equal(messageSchema.safeParse({ body: '   ' }).success, false);
  assert.equal(messageSchema.safeParse({ body: 'x'.repeat(4001) }).success, false);
});
