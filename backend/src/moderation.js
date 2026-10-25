export async function isBlockedBetween(pool, userA, userB) {
  const result = await pool.query(
    'SELECT 1 FROM user_blocks WHERE ' +
      '(blocker_id = $1 AND blocked_id = $2) OR ' +
      '(blocker_id = $2 AND blocked_id = $1) LIMIT 1',
    [userA, userB],
  );
  return result.rows.length > 0;
}

export async function getAccessibleTarget(pool, targetType, targetId, reporterId) {
  if (targetType === 'user') {
    if (targetId === reporterId) return { self: true };
    const result = await pool.query('SELECT id FROM users WHERE id = $1', [targetId]);
    return result.rows[0] ? { accessible: true } : { accessible: false };
  }

  if (targetType === 'post') {
    const result = await pool.query(
      'SELECT p.id, p.author_id FROM posts p WHERE p.id = $1',
      [targetId],
    );
    if (!result.rows[0]) return { accessible: false };
    const blocked = await isBlockedBetween(pool, reporterId, result.rows[0].author_id);
    return { accessible: !blocked };
  }

  if (targetType === 'comment') {
    const result = await pool.query(
      'SELECT c.id, c.author_id FROM comments c WHERE c.id = $1',
      [targetId],
    );
    if (!result.rows[0]) return { accessible: false };
    const blocked = await isBlockedBetween(pool, reporterId, result.rows[0].author_id);
    return { accessible: !blocked };
  }

  const result = await pool.query(
    'SELECT m.id, m.sender_id, m.conversation_id FROM messages m ' +
      'JOIN conversation_members cm ON cm.conversation_id = m.conversation_id ' +
      'AND cm.user_id = $2 WHERE m.id = $1 AND m.deleted_at IS NULL',
    [targetId, reporterId],
  );
  if (!result.rows[0]) return { accessible: false };

  const blocked = await pool.query(
    'SELECT 1 FROM conversation_members cm ' +
      'JOIN user_blocks b ON ' +
      '((b.blocker_id = $2 AND b.blocked_id = cm.user_id) OR ' +
      '(b.blocker_id = cm.user_id AND b.blocked_id = $2)) ' +
      'WHERE cm.conversation_id = $1 LIMIT 1',
    [result.rows[0].conversation_id, reporterId],
  );
  return { accessible: blocked.rows.length === 0 };
}
