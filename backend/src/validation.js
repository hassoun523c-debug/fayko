import { z } from 'zod';

const passwordSchema = z
  .string()
  .min(10, 'Password must contain at least 10 characters.')
  .max(72, 'Password is too long.')
  .refine(
    (value) => Buffer.byteLength(value, 'utf8') <= 72,
    'Password is too long when encoded.',
  );

export const interestValues = [
  'sports',
  'gaming',
  'entertainment',
  'religion',
  'education',
  'design',
  'technology',
  'news',
  'fashion',
  'cooking',
  'travel',
  'science',
  'comedy',
  'art',
  'global_trends',
];

export const interestsSchema = z
  .array(z.enum(interestValues))
  .max(15)
  .refine((values) => new Set(values).size === values.length, 'Interests must be unique.');

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
    interests: interestsSchema.optional(),
  })
  .strict()
  .refine(
    (value) => Object.values(value).some((field) => field !== undefined),
    'At least one profile field must be supplied.',
  );

export const postCategoryValues = ['general', ...interestValues];

export const postSchema = z.object({
  body: z.string().trim().min(1).max(2000),
  category: z.enum(postCategoryValues).optional(),
});

const maxReelBytes = 150 * 1024 * 1024;

export const reelUploadSchema = z.object({
  category: z.enum(interestValues),
  contentType: z.literal('video/mp4'),
  fileSizeBytes: z.number().int().min(1).max(maxReelBytes),
});

export const reelCreateSchema = z.object({
  objectKey: z.string().trim().min(1).max(512),
  caption: z.string().trim().max(2000).optional().transform((value) => value ?? ''),
  category: z.enum(interestValues),
  contentType: z.literal('video/mp4'),
  fileSizeBytes: z.number().int().min(1).max(maxReelBytes),
  durationSeconds: z.number().int().min(1).max(180).optional(),
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
    targetType: z.enum(['user', 'post', 'comment', 'message', 'reel']),
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
