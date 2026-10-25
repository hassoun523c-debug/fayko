import { readdir, readFile } from 'node:fs/promises';

const migrationPattern = /^\d+_[a-z0-9_]+\.sql$/i;

export async function runMigrations(pool) {
  await pool.query(
    'CREATE TABLE IF NOT EXISTS schema_migrations (' +
      'filename TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW())',
  );

  const migrationDirectory = new URL('../db/', import.meta.url);
  const entries = await readdir(migrationDirectory);
  const files = entries.filter((name) => migrationPattern.test(name)).sort();
  const client = await pool.connect();

  try {
    for (const filename of files) {
      const applied = await client.query(
        'SELECT 1 FROM schema_migrations WHERE filename = $1',
        [filename],
      );
      if (applied.rows.length > 0) continue;

      const sql = await readFile(
        new URL(filename, migrationDirectory),
        'utf8',
      );

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO schema_migrations (filename) VALUES ($1)',
          [filename],
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }
  } finally {
    client.release();
  }
}
