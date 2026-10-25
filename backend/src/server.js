import 'dotenv/config';
import { createApp } from './app.js';
import { validateRuntimeConfig } from './config.js';
import { pool } from './db.js';
import { runMigrations } from './migrations.js';

async function start() {
  const { port } = validateRuntimeConfig();
  await runMigrations(pool);
  await pool.query('SELECT 1');

  const app = createApp({
    pool,
    jwtSecret: process.env.JWT_SECRET,
  });
  const host = process.env.HOST ?? '0.0.0.0';
  const server = app.listen(port, host, () => {
    console.log('Fayko API listening on ' + host + ':' + port);
  });

  let shuttingDown = false;
  const shutdown = (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log('Received ' + signal + '; shutting down.');
    server.close(() => {
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
