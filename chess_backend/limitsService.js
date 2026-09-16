// limitsService.js
// What an account has used: saved tutorials, sessions this month, recordings.
//
// Until 16.9.2026 this file also held a model of a free account's ceilings
// (20 tutorials, 5 sessions a month, no MP4), an `ENABLE_LIMITS` switch and
// `checkUserLimits` to enforce them. Nothing ever called it, so the switch
// changed nothing while the account card drew „n / 20" and the Premium dialog
// sold „unlimited" against a limit the server did not hold. The owner chose to
// delete the model rather than wire it (audit, `docs/audit/server.md`, 12).
// Paid features are gated where every other gate lives: `requireEntitlement`
// and `requireQuota`.

const { resolveTier } = require('./services/entitlementService');

/**
  * Calculate current resource usage for a user.
  */
async function getUserStats(pool, userId) {
  // The tier comes from entitlementService rather than users.account_type
  // directly, so a paid subscription and a manual admin grant both count and
  // there is only one place that decides what a user is entitled to.
  const accountType = await resolveTier(pool, userId);

  const lessonsRes = await pool.query(
    'SELECT COUNT(*)::int as count FROM saved_lessons WHERE user_id = $1 OR trainer_id = $1',
    [userId]
  );
  const savedLessonsCount = lessonsRes.rows[0]?.count || 0;

  const sessionsRes = await pool.query(
    `SELECT COUNT(*)::int as count FROM rooms 
     WHERE creator_id = $1 
     AND (created_at IS NULL OR created_at >= DATE_TRUNC('month', CURRENT_TIMESTAMP))`,
    [userId]
  );
  const monthlySessionsCount = sessionsRes.rows[0]?.count || 0;

  const recordingsRes = await pool.query(
    'SELECT COUNT(*)::int as count FROM session_recordings WHERE host_id = $1',
    [userId]
  );
  const totalRecordingsCount = recordingsRes.rows[0]?.count || 0;

  return {
    account_type: accountType,
    savedLessonsCount,
    monthlySessionsCount,
    totalRecordingsCount,
  };
}

module.exports = {
  getUserStats,
};
