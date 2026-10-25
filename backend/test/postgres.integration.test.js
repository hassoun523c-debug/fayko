import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import pg from 'pg';
import { createApp } from '../src/app.js';

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const jwtSecret = 'integration-tests-use-a-secret-long-enough-for-hs256';

test(
  'account, profile, follow, post, like and comment flow against PostgreSQL',
  { skip: !databaseUrl },
  async () => {
    const pool = new Pool({ connectionString: databaseUrl });
    const schema = await readFile(
      new URL('../db/001_init.sql', import.meta.url),
      'utf8',
    );
    await pool.query(schema);

    const app = createApp({ pool, jwtSecret });
    const server = app.listen(0, '127.0.0.1');
    await once(server, 'listening');

    const baseUrl = 'http://127.0.0.1:' + server.address().port;
    const accountIds = [];

    async function request(path, {
      method = 'GET',
      token,
      body,
    } = {}) {
      const headers = { accept: 'application/json' };
      if (token) headers.authorization = 'Bearer ' + token;
      if (body !== undefined) headers['content-type'] = 'application/json';

      return fetch(baseUrl + path, {
        method,
        headers,
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    }

    try {
      const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
      const firstRegistration = await request('/api/v1/auth/register', {
        method: 'POST',
        body: {
          username: 'it_' + suffix,
          email: 'first_' + suffix + '@example.test',
          password: 'integration-test-password-2026',
          displayName: 'حساب اختبار',
        },
      });
      assert.equal(firstRegistration.status, 201);
      const first = await firstRegistration.json();
      accountIds.push(first.user.id);
      assert.ok(first.accessToken);
      assert.equal(first.user.displayName, 'حساب اختبار');

      const secondRegistration = await request('/api/v1/auth/register', {
        method: 'POST',
        body: {
          username: 'it2_' + suffix,
          email: 'second_' + suffix + '@example.test',
          password: 'integration-test-password-2026',
          displayName: 'حساب ثان',
        },
      });
      assert.equal(secondRegistration.status, 201);
      const second = await secondRegistration.json();
      accountIds.push(second.user.id);

      const updatedProfileResponse = await request('/api/v1/auth/me', {
        method: 'PATCH',
        token: first.accessToken,
        body: { displayName: 'فايكو محدث', bio: 'نبذة اختبار' },
      });
      assert.equal(updatedProfileResponse.status, 200);
      assert.equal((await updatedProfileResponse.json()).user.bio, 'نبذة اختبار');

      const createPostResponse = await request('/api/v1/posts', {
        method: 'POST',
        token: first.accessToken,
        body: { body: 'منشور تكامل حقيقي' },
      });
      assert.equal(createPostResponse.status, 201);
      const createdPost = (await createPostResponse.json()).post;
      assert.equal(createdPost.body, 'منشور تكامل حقيقي');

      const likeResponse = await request(
        '/api/v1/posts/' + createdPost.id + '/like',
        { method: 'POST', token: first.accessToken },
      );
      assert.equal(likeResponse.status, 200);
      assert.equal((await likeResponse.json()).liked, true);

      const commentResponse = await request(
        '/api/v1/posts/' + createdPost.id + '/comments',
        {
          method: 'POST',
          token: second.accessToken,
          body: { body: 'تعليق من حساب ثان' },
        },
      );
      assert.equal(commentResponse.status, 201);
      assert.equal(
        (await commentResponse.json()).comment.body,
        'تعليق من حساب ثان',
      );

      const feedResponse = await request('/api/v1/posts?limit=10', {
        token: first.accessToken,
      });
      assert.equal(feedResponse.status, 200);
      const feed = await feedResponse.json();
      const feedPost = feed.posts.find((post) => post.id === createdPost.id);
      assert.ok(feedPost);
      assert.equal(feedPost.likesCount, 1);
      assert.equal(feedPost.commentsCount, 1);
      assert.equal(feedPost.likedByMe, true);

      const searchResponse = await request(
        '/api/v1/users/search?q=' + encodeURIComponent('it2_' + suffix.slice(0, 6)),
        { token: first.accessToken },
      );
      assert.equal(searchResponse.status, 200);

      const followResponse = await request(
        '/api/v1/users/' + second.user.id + '/follow',
        { method: 'POST', token: first.accessToken },
      );
      assert.equal(followResponse.status, 200);
      assert.equal((await followResponse.json()).following, true);

      const profileResponse = await request(
        '/api/v1/users/' + second.user.id,
        { token: first.accessToken },
      );
      assert.equal(profileResponse.status, 200);
      const profile = (await profileResponse.json()).user;
      assert.equal(profile.isFollowing, true);
      assert.equal(profile.followersCount, 1);
    } finally {
      if (accountIds.length > 0) {
        await pool.query(
          'DELETE FROM users WHERE id = ANY($1::uuid[])',
          [accountIds],
        );
      }
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve));
      await pool.end();
    }
  },
);
