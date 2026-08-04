// limitsService.js
// Tier Limits & Resource Usage Service

const ENABLE_LIMITS = process.env.ENABLE_LIMITS === 'true'; // Default: false for testing mode

const TIER_LIMITS = {
  free: {
    maxSavedLessons: 20,
    maxMonthlySessions: 5,
    mp4ExportAllowed: false
  },
  premium: {
    maxSavedLessons: Infinity,
    maxMonthlySessions: Infinity,
    mp4ExportAllowed: true
  }
};

/**
  * Calculate current resource usage for a user.
  */
async function getUserStats(pool, userId) {
  const userRes = await pool.query('SELECT account_type FROM users WHERE id = $1', [userId]);
  const accountType = userRes.rows.length > 0 ? (userRes.rows[0].account_type || 'free') : 'free';

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

  const limits = TIER_LIMITS[accountType] || TIER_LIMITS.free;

  return {
    account_type: accountType,
    savedLessonsCount,
    monthlySessionsCount,
    totalRecordingsCount,
    limits: {
      maxSavedLessons: limits.maxSavedLessons === Infinity ? -1 : limits.maxSavedLessons,
      maxMonthlySessions: limits.maxMonthlySessions === Infinity ? -1 : limits.maxMonthlySessions,
      mp4ExportAllowed: limits.mp4ExportAllowed
    },
    limitsEnabled: ENABLE_LIMITS
  };
}

/**
  * Check if user is allowed to perform action based on tier limits.
  * @param {Object} pool - PG database pool
  * @param {number} userId - User ID
  * @param {'save_lesson' | 'create_room' | 'export_mp4'} actionType
  * @returns {Promise<{ allowed: boolean, reason?: string }>}
  */
async function checkUserLimits(pool, userId, actionType) {
  if (!ENABLE_LIMITS) {
    return { allowed: true };
  }

  const stats = await getUserStats(pool, userId);
  const accountType = stats.account_type;

  if (accountType === 'premium') {
    return { allowed: true };
  }

  if (actionType === 'save_lesson') {
    if (stats.savedLessonsCount >= TIER_LIMITS.free.maxSavedLessons) {
      return {
        allowed: false,
        reason: `Dostigli ste maksimalan broj sačuvanih lekcija za besplatan nalog (${TIER_LIMITS.free.maxSavedLessons}). Pređite na Premium za neograničeno skladištenje.`
      };
    }
  } else if (actionType === 'create_room') {
    if (stats.monthlySessionsCount >= TIER_LIMITS.free.maxMonthlySessions) {
      return {
        allowed: false,
        reason: `Popunili ste mesečnu kvotu kreiranja sesija za besplatan nalog (${TIER_LIMITS.free.maxMonthlySessions}/mesečno). Pređite na Premium za neograničen broj sesija.`
      };
    }
  } else if (actionType === 'export_mp4') {
    if (!TIER_LIMITS.free.mp4ExportAllowed) {
      return {
        allowed: false,
        reason: 'Izvoz časova u MP4 video format je ekskluzivna funkcija Premium naloga.'
      };
    }
  }

  return { allowed: true };
}

module.exports = {
  ENABLE_LIMITS,
  TIER_LIMITS,
  getUserStats,
  checkUserLimits
};
