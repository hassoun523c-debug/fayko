import assert from 'node:assert/strict';
import test from 'node:test';
import {
  commentSchema,
  loginSchema,
  messageSchema,
  postSchema,
  profileUpdateSchema,
  registerSchema,
  reportSchema,
  interestsSchema,
  postSchema,
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

test('content reports require supported target and reason values', () => {
  const valid = reportSchema.parse({
    targetType: 'post',
    targetId: '18347b23-45c6-4c5f-8d6c-1e010f001c6a',
    reason: 'spam',
    details: '  إعلان مزعج  ',
  });
  assert.equal(valid.details, 'إعلان مزعج');
  assert.equal(
    reportSchema.safeParse({
      targetType: 'invalid',
      targetId: 'not-a-uuid',
      reason: 'bad-reason',
      extra: true,
    }).success,
    false,
  );
  assert.equal(
    reportSchema.safeParse({
      targetType: 'post',
      targetId: '18347b23-45c6-4c5f-8d6c-1e010f001c6a',
      reason: 'spam',
      details: 'x'.repeat(1001),
    }).success,
    false,
  );
});

test('interest preferences accept supported unique categories only', () => {
  assert.deepEqual(interestsSchema.parse(['sports', 'gaming', 'global_trends']), [
    'sports',
    'gaming',
    'global_trends',
  ]);
  assert.equal(interestsSchema.safeParse(['sports', 'sports']).success, false);
  assert.equal(interestsSchema.safeParse(['unknown_category']).success, false);
  assert.equal(interestsSchema.safeParse(Array(16).fill('sports')).success, false);
});

test('posts accept an optional supported category', () => {
  assert.deepEqual(postSchema.parse({ body: '  مرحباً  ', category: 'sports' }), {
    body: 'مرحباً',
    category: 'sports',
  });
  assert.equal(postSchema.safeParse({ body: 'منشور', category: 'unknown' }).success, false);
});
