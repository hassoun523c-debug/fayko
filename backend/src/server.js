import 'dotenv/config';
import { createServer } from 'node:http';
import { createApp } from './app.js';
import { validateRuntimeConfig } from './config.js';
import { pool } from './db.js';
import { runMigrations } from './migrations.js';
import { attachRealtimeGateway } from './realtime.js';

async function start() {
  const { port } = validateRuntimeConfig();
  await runMigrations(pool);
  await pool.query('SELECT 1');

  let realtimeServer;
  const ioBridge = {
    to(room) {
      return realtimeServer
        ? realtimeServer.to(room)
        : { emit: () => false };
    },
  };

  const app = createApp({
    pool,
    jwtSecret: process.env.JWT_SECRET,
    io: ioBridge,
  });
  const host = process.env.HOST ?? '0.0.0.0';
  const httpServer = createServer(app);
  realtimeServer = attachRealtimeGateway({
    httpServer,
    pool,
    jwtSecret: process.env.JWT_SECRET,
  });

  httpServer.listen(port, host, () => {
    console.log('Fayko API listening on ' + host + ':' + port);
  });

  let shuttingDown = false;
  const shutdown = (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log('Received ' + signal + '; shutting down.');
    realtimeServer.close(() => {
      pool
        .end()
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
    });
    setTimeout(() => process.exit(1), 10000).unref();
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start().catch(async (error) => {
  console.error('Fayko API startup failed:', error.message);
  await pool.end().catch(() => {});
  process.exitCode = 1;
});
