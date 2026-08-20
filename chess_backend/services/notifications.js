// The one place a user_notification is written.
//
// There were five copies of this INSERT — three in relationshipService, two in
// the social routes — and they had already drifted: some set `kind` and `ref_id`
// and some left the columns to their defaults, so the client's `switch (kind)`
// silently fell through to a generic star for half of them.
//
// Writing the row is only half of telling someone. The client fetches
// `/notifications` when it starts and on a socket event, never on a timer, so a
// row written while the app is open used to sit there until the next launch.
// Every notification therefore nudges its recipient as well.

const logger = require('./logger');
const realtime = require('./realtime');

/// Writes one notification and nudges the recipient if they are connected.
///
/// Best effort, like everything that only *tells* someone about an action: the
/// action already happened, and it must not be undone because the note about it
/// failed. Returns whether the row was written.
async function notify(pool, {
  recipientId,
  senderId = null,
  roomCode = null,
  title,
  message,
  kind = 'room',
  refId = null,
}) {
  try {
    await pool.query(
      `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message, kind, ref_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [recipientId, senderId, roomCode, title, message, kind, refId]
    );
  } catch (err) {
    logger.error(`Could not create '${kind}' notification:`, err);
    return false;
  }

  realtime.emitToUser(recipientId, 'notifications_changed', { kind });
  return true;
}

module.exports = { notify };
