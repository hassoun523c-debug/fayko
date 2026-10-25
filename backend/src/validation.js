import { z } from 'zod';

const passwordSchema = z
  .string()
  .min(10, 'Password must contain at least 10 characters.')
  .max(72, 'Password is too long.')
  .refine(
    (value) => Buffer.byteLength(value, 'utf8') <= 72,
    'Password is too long when encoded.',
  );

export const registerSchema = z.object({
  username: z
    .string()
    .trim()
    .min(3)
    .max(24)
    .regex(/^[a-zA-Z0-9_]+$/)
    .transform((value) => value.toLowerCase()),
  email: z
    .string()
    .trim()
    .email()
    .max(254)
    .transform((value) => value.toLowerCase()),
  password: passwordSchema,
  displayName: z.string().trim().min(1).max(60).optional(),
});

export const loginSchema = z.object({
  identifier: z
    .string()
    .trim()
    .min(3)
    .max(254)
    .transform((value) => value.toLowerCase()),
  password: passwordSchema,
});

export const profileUpdateSchema = z
  .object({
    displayName: z.string().trim().min(1).max(60).optional(),
    bio: z.string().trim().max(160).optional(),
    avatarUrl: z.union([z.string().url().max(2048), z.null()]).optional(),
  })
  .strict()
  .refine(
    (value) => Object.values(value).some((field) => field !== undefined),
    'At least one profile field must be supplied.',
  );

export const postSchema = z.object({
  body: z.string().trim().min(1).max(2000),
});

export const commentSchema = z.object({
  body: z.string().trim().min(1).max(1000),
});

export const messageSchema = z.object({
  body: z.string().trim().min(1).max(4000),
});

export const uuidSchema = z.string().uuid().transform((value) => value.toLowerCase());

export function sendValidationError(res, error) {
  return res.status(400).json({
    error: {
      code: 'validation_error',
      message: 'تحقق من البيانات المدخلة.',
      fields: error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message,
      })),
    },
  });
}

export const reportSchema = z
  .object({
    targetType: z.enum(['user', 'post', 'comment', 'message']),
    targetId: z.string().uuid(),
    reason: z.enum([
      'spam',
      'harassment',
      'hate_or_discrimination',
      'sexual_content',
      'violence',
      'scam_or_fraud',
      'impersonation',
      'other',
    ]),
    details: z.string().trim().max(1000).optional().transform((value) => value ?? ''),
  })
  .strict();
