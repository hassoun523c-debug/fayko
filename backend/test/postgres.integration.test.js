import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { once } from 'node:events';
import test from 'node:test';
import pg from 'pg';
import { io as createSocketClient } from 'socket.io-client';
import { createApp } from '../src/app.js';
import { attachRealtimeGateway } from '../src/realtime.js';
import { runMigrations } from '../src/migrations.js';

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const jwtSecret = 'integration-tests-use-a-secret-long-enough-for-hs256';

test(
  'auth, social and private direct-message flow against PostgreSQL',
  { skip: !databaseUrl },
  async () => {
    const pool = new Pool({ connectionString: databaseUrl });
    const accountIds = [];
    let server;
    let realtimeServer;
    let firstSocket;
    let secondSocket;
    let outsiderSocket;

    try {
      await runMigrations(pool);
      let realtimeServerRef;
      const ioBridge = {
        to(room) {
          return realtimeServerRef
            ? realtimeServerRef.to(room)
            : { emit: () => false };
        },
        in(room) {
          return realtimeServerRef
            ? realtimeServerRef.in(room)
            : { disconnectSockets: () => false };
        },
      };
      const app = createApp({ pool, jwtSecret, io: ioBridge });
      server = createServer(app);
      realtimeServer = attachRealtimeGateway({ httpServer: server, pool, jwtSecret });
      realtimeServerRef = realtimeServer;
      server.listen(0, '127.0.0.1');
      await once(server, 'listening');

      const baseUrl = 'http://127.0.0.1:' + server.address().port;

      async function connectSocket(token) {
        const socket = createSocketClient(baseUrl, {
          transports: ['websocket'],
          auth: { token },
          reconnection: false,
          timeout: 5000,
        });
        try {
          await new Promise((resolve, reject) => {
            const timeout = setTimeout(
              () => reject(new Error('Socket connect timeout')),
              6000,
            );
            socket.once('connect', () => {
              clearTimeout(timeout);
              resolve();
            });
            socket.once('connect_error', (error) => {
              clearTimeout(timeout);
              reject(error);
            });
          });
          return socket;
        } catch (error) {
          socket.disconnect();
          throw error;
        }
      }

      async function joinSocketConversation(socket, conversationId) {
        return new Promise((resolve) => {
          socket.emit('conversation:join', { conversationId }, resolve);
        });
      }

      async function request(path, { method = 'GET', token, body } = {}) {
        const headers = { accept: 'application/json' };
        if (token) headers.authorization = 'Bearer ' + token;
        if (body !== undefined) headers['content-type'] = 'application/json';

        return fetch(baseUrl + path, {
          method,
          headers,
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
      }

      const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
      const password = 'integration-test-password-2026';
      const firstRegistration = await request('/api/v1/auth/register', {
        method: 'POST',
        body: {
          username: 'it_' + suffix,
          email: 'first_' + suffix + '@example.test',
          password,
          displayName: 'حساب اختبار',
        },
      });
      assert.equal(firstRegistration.status, 201);
      const first = await firstRegistration.json();
      accountIds.push(first.user.id);
      assert.ok(first.accessToken);
      assert.equal(first.user.displayName, 'حساب اختبار');

      const initialFeedResponse = await request('/api/v1/posts?limit=20', {
        token: first.accessToken,
      });
      assert.equal(initialFeedResponse.status, 200);
      const initialFeed = await initialFeedResponse.json();
      assert.ok(initialFeed.posts.some((post) => post.author.username === 'fayko_official'));

      const secondRegistration = await request('/api/v1/auth/register', {
        method: 'POST',
        body: {
          username: 'it2_' + suffix,
          email: 'second_' + suffix + '@example.test',
          password,
          displayName: 'حساب ثان',
        },
      });
      assert.equal(secondRegistration.status, 201);
      const second = await secondRegistration.json();
      accountIds.push(second.user.id);

      const thirdRegistration = await request('/api/v1/auth/register', {
        method: 'POST',
        body: {
          username: 'it3_' + suffix,
          email: 'third_' + suffix + '@example.test',
          password,
          displayName: 'حساب ثالث',
        },
      });
      assert.equal(thirdRegistration.status, 201);
      const third = await thirdRegistration.json();
      accountIds.push(third.user.id);

      const updatedProfileResponse = await request('/api/v1/auth/me', {
        method: 'PATCH',
        token: first.accessToken,
        body: {
          displayName: 'فايكو محدث',
          bio: 'نبذة اختبار',
          interests: ['sports', 'gaming', 'global_trends'],
        },
      });
      assert.equal(updatedProfileResponse.status, 200);
      const updatedProfile = (await updatedProfileResponse.json()).user;
      assert.equal(updatedProfile.bio, 'نبذة اختبار');
      assert.deepEqual(updatedProfile.interests, ['sports', 'gaming', 'global_trends']);

      const createPostResponse = await request('/api/v1/posts', {
        method: 'POST',
        token: first.accessToken,
        body: { body: 'منشور تكامل حقيقي', category: 'sports' },
      });
      assert.equal(createPostResponse.status, 201);
      const createdPost = (await createPostResponse.json()).post;
      assert.equal(createdPost.body, 'منشور تكامل حقيقي');
      assert.equal(createdPost.category, 'sports');

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
      const search = await searchResponse.json();
      assert.ok(search.users.some((user) => user.username === 'it2_' + suffix));

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

      const reportResponse = await request('/api/v1/reports', {
        method: 'POST',
        token: second.accessToken,
        body: {
          targetType: 'post',
          targetId: createdPost.id,
          reason: 'spam',
          details: 'بلاغ تكامل اختبار',
        },
      });
      assert.equal(reportResponse.status, 201);
      assert.equal((await reportResponse.json()).report.reason, 'spam');

      const duplicateReportResponse = await request('/api/v1/reports', {
        method: 'POST',
        token: second.accessToken,
        body: {
          targetType: 'post',
          targetId: createdPost.id,
          reason: 'spam',
        },
      });
      assert.equal(duplicateReportResponse.status, 409);

      const directResponse = await request('/api/v1/conversations/direct', {
        method: 'POST',
        token: first.accessToken,
        body: { userId: second.user.id },
      });
      assert.equal(directResponse.status, 201);
      const conversationId = (await directResponse.json()).conversation.id;

      const duplicateDirectResponse = await request('/api/v1/conversations/direct', {
        method: 'POST',
        token: second.accessToken,
        body: { userId: first.user.id },
      });
      assert.equal(duplicateDirectResponse.status, 200);
      assert.equal(
        (await duplicateDirectResponse.json()).conversation.id,
        conversationId,
      );

      const outsiderResponse = await request(
        '/api/v1/conversations/' + conversationId + '/messages',
        { token: third.accessToken },
      );
      assert.equal(outsiderResponse.status, 404);

      firstSocket = await connectSocket(first.accessToken);
      secondSocket = await connectSocket(second.accessToken);
      outsiderSocket = await connectSocket(third.accessToken);
      assert.deepEqual(
        await joinSocketConversation(firstSocket, conversationId),
        { ok: true, conversationId },
      );
      assert.deepEqual(
        await joinSocketConversation(secondSocket, conversationId),
        { ok: true, conversationId },
      );
      assert.deepEqual(
        await joinSocketConversation(outsiderSocket, conversationId),
        { ok: false, code: 'conversation_not_found' },
      );

      const realtimeMessagePromise = new Promise((resolve, reject) => {
        const timeout = setTimeout(
          () => reject(new Error('Timed out waiting for message:new')),
          6000,
        );
        secondSocket.once('message:new', (event) => {
          clearTimeout(timeout);
          resolve(event);
        });
      });

      const messageResponse = await request(
        '/api/v1/conversations/' + conversationId + '/messages',
        {
          method: 'POST',
          token: first.accessToken,
          body: { body: 'رسالة مباشرة محفوظة في قاعدة البيانات' },
        },
      );
      assert.equal(messageResponse.status, 201);
      const postedMessage = (await messageResponse.json()).message;
      assert.equal(postedMessage.body, 'رسالة مباشرة محفوظة في قاعدة البيانات');

      const realtimeMessage = await realtimeMessagePromise;
      assert.equal(realtimeMessage.conversationId, conversationId);
      assert.equal(realtimeMessage.id, postedMessage.id);
      assert.equal(realtimeMessage.body, postedMessage.body);

      const inboxResponse = await request('/api/v1/conversations', {
        token: second.accessToken,
      });
      assert.equal(inboxResponse.status, 200);
      const inbox = await inboxResponse.json();
      const conversation = inbox.conversations.find(
        (item) => item.id === conversationId,
      );
      assert.ok(conversation);
      assert.equal(conversation.unreadCount, 1);
      assert.equal(
        conversation.lastMessage.body,
        'رسالة مباشرة محفوظة في قاعدة البيانات',
      );

      const messagesResponse = await request(
        '/api/v1/conversations/' + conversationId + '/messages',
        { token: second.accessToken },
      );
      assert.equal(messagesResponse.status, 200);
      const messages = await messagesResponse.json();
      assert.equal(messages.messages.length, 1);
      assert.equal(messages.messages[0].isMine, false);
      assert.equal(messages.messages[0].senderId, first.user.id);

      const readInboxResponse = await request('/api/v1/conversations', {
        token: second.accessToken,
      });
      const readInbox = await readInboxResponse.json();
      assert.equal(
        readInbox.conversations.find((item) => item.id === conversationId).unreadCount,
        0,
      );

      const firstSocketDisconnected = new Promise((resolve) => {
        firstSocket.once('disconnect', resolve);
      });
      const logoutResponse = await request('/api/v1/auth/logout', {
        method: 'POST',
        token: first.accessToken,
      });
      assert.equal(logoutResponse.status, 204);
      await firstSocketDisconnected;
      assert.equal(firstSocket.connected, false);

      await assert.rejects(
        connectSocket(first.accessToken),
        /session_revoked_or_expired/,
      );

      const revokedSessionResponse = await request('/api/v1/auth/me', {
        token: first.accessToken,
      });
      assert.equal(revokedSessionResponse.status, 401);
      assert.equal(
        (await revokedSessionResponse.json()).error.code,
        'session_revoked_or_expired',
      );

      const thirdConversationResponse = await request(
        '/api/v1/conversations/direct',
        {
          method: 'POST',
          token: third.accessToken,
          body: { userId: second.user.id },
        },
      );
      assert.equal(thirdConversationResponse.status, 201);
      const thirdConversationId = (await thirdConversationResponse.json()).conversation.id;

      const blockResponse = await request(
        '/api/v1/users/' + second.user.id + '/block',
        { method: 'POST', token: third.accessToken },
      );
      assert.equal(blockResponse.status, 200);
      assert.equal((await blockResponse.json()).blocked, true);

      const blockedMessageResponse = await request(
        '/api/v1/conversations/' + thirdConversationId + '/messages',
        {
          method: 'POST',
          token: third.accessToken,
          body: { body: 'يجب رفض هذه الرسالة بعد الحظر' },
        },
      );
      assert.equal(blockedMessageResponse.status, 404);

      const blockedSocketJoin = await joinSocketConversation(
        outsiderSocket,
        thirdConversationId,
      );
      assert.deepEqual(blockedSocketJoin, {
        ok: false,
        code: 'conversation_not_found',
      });
    } finally {
      firstSocket?.disconnect();
      secondSocket?.disconnect();
      outsiderSocket?.disconnect();
      try {
        if (realtimeServer) {
          await new Promise((resolve) => realtimeServer.close(resolve));
        } else if (server?.listening) {
          await new Promise((resolve) => server.close(resolve));
        }
      } finally {
        try {
          if (accountIds.length > 0) {
            await pool.query(
              'DELETE FROM users WHERE id = ANY($1::uuid[])',
              [accountIds],
            );
          }
        } finally {
          await pool.end();
        }
      }
    }
  },
);
