import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { getAccessibleTarget } from '../moderation.js';
import { reportSchema, sendValidationError } from '../validation.js';

export function createReportsRouter({ pool, jwtSecret }) {
  const router = express.Router();
  router.use(requireAuth(jwtSecret, pool));

  router.post('/', async (req, res) => {
    const parsed = reportSchema.safeParse(req.body);
    if (!parsed.success) return sendValidationError(res, parsed.error);

    const { targetType, targetId, reason, details } = parsed.data;
    const target = await getAccessibleTarget(
      pool,
      targetType,
      targetId,
      req.auth.userId,
    );

    if (target.self) {
      return res.status(400).json({
        error: { code: 'cannot_report_self', message: 'ما تگدر تبلّغ عن حسابك.' },
      });
    }
    if (!target.accessible) {
      return res.status(404).json({
        error: {
          code: 'report_target_not_found',
          message: 'المحتوى غير موجود أو غير متاح لهذا الحساب.',
        },
      });
    }

    try {
      const result = await pool.query(
        'INSERT INTO content_reports ' +
          '(reporter_id, target_type, target_id, reason, details) ' +
          'VALUES ($1, $2, $3, $4, $5) ' +
          'RETURNING id, target_type, target_id, reason, status, created_at',
        [req.auth.userId, targetType, targetId, reason, details],
      );
      const report = result.rows[0];
      return res.status(201).json({
        report: {
          id: report.id,
          targetType: report.target_type,
          targetId: report.target_id,
          reason: report.reason,
          status: report.status,
          createdAt: report.created_at,
        },
      });
    } catch (error) {
      if (error.code === '23505') {
        return res.status(409).json({
          error: {
            code: 'report_already_submitted',
            message: 'تم استلام بلاغ سابق عن هذا المحتوى من حسابك.',
          },
        });
      }
      throw error;
    }
  });

  return router;
}
