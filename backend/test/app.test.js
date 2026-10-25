import assert from 'node:assert/strict';
import { once } from 'node:events';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { signAccessToken } from '../src/security.js';

const jwtSecret = 'api-tests-use-a-secret-long-enough-for-hs256';
const userId = 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1';
const postId = '18347b23-45c6-4c5f-8d6c-1e010f001c6a';

function makePool() {
  const queries = [];

  return {
    queries,
    async query(sql, values = []) {
      queries.push({ sql, values });

      if (sql.includes('INSERT INTO posts (author_id, body)')) {
        return {
          rows: [{
            id: postId,
            body: values[1],
            created_at: new Date('2026-01-01T10:00:00Z'),
            updated_at: new Date('2026-01-01T10:00:00Z'),
          }],
          rowCount: 1,
        };
      }

      if (sql.includes('FROM posts p JOIN users u ON u.id = p.author_id WHERE p.id = $1')) {
        return {
          rows: [{
            id: postId,
            body: 'منشور اختبار',
            created_at: new Date('2026-01-01T10:00:00Z'),
            updated_at: new Date('2026-01-01T10:00:00Z'),
            author: {
              id: userId,
              username: 'fayko_user',
              displayName: 'Fayko User',
              avatarUrl: null,
            },
          }],
          rowCount: 1,
        };
      }

      if (sql.includes('SELECT 1 FROM posts WHERE id = $1')) {
        return { rows: [{ '?column?': 1 }], rowCount: 1 };
      }

      return { rows: [], rowCount: 0 };
    },
  };
}

async function startTestServer(t, pool = makePool()) {
  const server = createApp({ pool, jwtSecret }).listen(0, '127.0.0.1');
  await once(server, 'listening');

  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  });

  const address = server.address();
  return {
    baseUrl: 'http://127.0.0.1:' + address.port,
    pool,
    token: signAccessToken(userId, jwtSecret),
  };
}

test('health endpoint responds without a database query', async (t) => {
  const { baseUrl, pool } = await startTestServer(t);
  const response = await fetch(baseUrl + '/healthz');

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: 'ok',
    service: 'fayko-api',
  });
  assert.equal(pool.queries.length, 0);
});

test('registration rejects malformed input before database access', async (t) => {
  const { baseUrl, pool } = await startTestServer(t);
  const response = await fetch(baseUrl + '/api/v1/auth/register', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      username: 'x',
      email: 'not-an-email',
      password: 'short',
    }),
  });

  assert.equal(response.status, 400);
  const payload = await response.json();
  assert.equal(payload.error.code, 'validation_error');
  assert.equal(pool.queries.length, 0);
});

test('private feed rejects requests without a bearer token', async (t) => {
  const { baseUrl, pool } = await startTestServer(t);
  const response = await fetch(baseUrl + '/api/v1/posts');

  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'authentication_required');
  assert.equal(pool.queries.length, 0);
});

test('authenticated user can create a text post through the HTTP API', async (t) => {
  const { baseUrl, token } = await startTestServer(t);
  const response = await fetch(baseUrl + '/api/v1/posts', {
    method: 'POST',
    headers: {
      authorization: 'Bearer ' + token,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ body: '  منشور اختبار  ' }),
  });

  assert.equal(response.status, 201);
  const payload = await response.json();
  assert.equal(payload.post.id, postId);
  assert.equal(payload.post.body, 'منشور اختبار');
  assert.equal(payload.post.author.username, 'fayko_user');
  assert.equal(payload.post.likesCount, 0);
});

test('user cannot follow their own account', async (t) => {
  const { baseUrl, token, pool } = await startTestServer(t);
  const response = await fetch(baseUrl + '/api/v1/users/' + userId + '/follow', {
    method: 'POST',
    headers: { authorization: 'Bearer ' + token },
  });

  assert.equal(response.status, 400);
  assert.equal((await response.json()).error.code, 'cannot_follow_self');
  assert.equal(pool.queries.length, 0);
});
