export function validateRuntimeConfig(env = process.env) {
  if (!env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required.');
  }

  try {
    const parsed = new URL(env.DATABASE_URL);
    if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
      throw new Error('Unsupported protocol');
    }
  } catch {
    throw new Error('DATABASE_URL must be a valid PostgreSQL connection URL.');
  }

  const secret = env.JWT_SECRET ?? '';
  if (secret.length < 32) {
    throw new Error('JWT_SECRET must contain at least 32 characters.');
  }

  if (
    env.NODE_ENV === 'production' &&
    /replace|change[-_ ]?me|dev[-_ ]?only|example|placeholder/i.test(secret)
  ) {
    throw new Error('JWT_SECRET must be replaced with a strong production secret.');
  }

  const port = Number(env.PORT ?? 4000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  return { port };
}
