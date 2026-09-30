// PALAHI Cloud Functions: phone push notifications.
//
// The app already writes an in-app notification document (/notifications)
// for every event — booking requests and status changes, chat messages,
// reactions, trips. pushOnNotification sends each one to the recipient's
// phones as a push, so they hear about it even with the app closed.
// bookingReminders adds a reminder the evening before each booking, and
// breedingReminders the Breeding Tracker's heat check and farrowing dates.
//
// NOT deployed: Cloud Functions need the paid Blaze plan, so for now the
// app shows reminders and alerts on the phone itself instead
// (lib/core/services/local_notification_service.dart). To switch to real
// server pushes later:
//   1. upgrade the Firebase project to Blaze,
//   2. add back to firebase.json:
//        "functions":[{"source":"functions","codebase":"default",
//                      "ignore":["node_modules",".git","*.test.js"]}]
//   3. firebase deploy --only functions
//   4. set serverPushEnabled = true in push_notification_service.dart

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const {
  manilaDateKey,
  remindersFor,
  deadTokens,
  addDays,
  BREEDING_REMINDER_DAYS,
  breedingReminderFor,
} = require('./lib');

admin.initializeApp();

// The Firestore database is in nam5, whose triggers run in us-central1.
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

const db = admin.firestore();

exports.pushOnNotification = onDocumentCreated('notifications/{notificationId}', async (event) => {
  const n = event.data && event.data.data();
  if (!n || !n.userId) return;

  const userRef = db.collection('users').doc(n.userId);
  const user = await userRef.get();
  const tokens = (user.exists && user.get('fcmTokens')) || [];
  if (!Array.isArray(tokens) || tokens.length === 0) return;

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: String(n.title || 'PALAHI').slice(0, 200),
      body: String(n.body || '').slice(0, 500),
    },
    // Read by the app when the push is tapped, to open the right screen.
    data: {
      type: String(n.type || ''),
      referenceId: String(n.referenceId || ''),
      notificationId: event.params.notificationId,
    },
    android: {
      priority: 'high',
      notification: {
        icon: 'ic_stat_palahi',
        color: '#2E7D32',
        // One notification per chat on the phone (the newest message),
        // instead of a pile-up; other kinds each show on their own.
        tag: n.type === 'chat' ? `chat_${n.referenceId}` : event.params.notificationId,
      },
    },
  });

  const dead = deadTokens(tokens, response);
  if (dead.length > 0) {
    await userRef.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead) });
    logger.info(`Removed ${dead.length} dead token(s) for ${n.userId}`);
  }
});

/**
 * Writes one reminder as an in-app notification (which pushOnNotification
 * then sends to the phone) under a fixed [id], so a retried run can't send
 * it twice. Returns whether it was new.
 */
async function sendReminderOnce(id, { userId, title, body, type, referenceId }) {
  try {
    await db.collection('notifications').doc(id).create({
      userId,
      title,
      body,
      type,
      referenceId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    // ALREADY_EXISTS: this reminder went out on an earlier attempt.
    if (e.code === 6) return false;
    throw e;
  }
}

// Every evening at 6 PM Manila time, remind both sides of tomorrow's
// bookings.
exports.bookingReminders = onSchedule(
  { schedule: '0 18 * * *', timeZone: 'Asia/Manila' },
  async () => {
    const tomorrow = manilaDateKey(new Date(), 1);
    const bookings = await db.collection('bookings').where('bookingDate', '==', tomorrow).get();

    let sent = 0;
    for (const doc of bookings.docs) {
      for (const r of remindersFor(doc.data())) {
        const isNew = await sendReminderOnce(`reminder_${doc.id}_${r.userId}`, {
          ...r,
          type: 'booking',
          referenceId: doc.id,
        });
        if (isNew) sent++;
      }
    }
    logger.info(`Sent ${sent} reminder(s) for ${tomorrow}`);
  },
);

// Every morning at 7 AM Manila time: Breeding Tracker reminders for sows
// bred 18 days ago (heat check starts), 111 days ago (farrowing in 3 days)
// and 114 days ago (farrowing due) — unless the farmer already reported she
// didn't conceive or has farrowed.
exports.breedingReminders = onSchedule(
  { schedule: '0 7 * * *', timeZone: 'Asia/Manila' },
  async () => {
    const today = manilaDateKey(new Date());
    let sent = 0;
    for (const days of BREEDING_REMINDER_DAYS) {
      const bredOn = addDays(today, -days);
      const bookings = await db.collection('bookings').where('bookingDate', '==', bredOn).get();
      for (const doc of bookings.docs) {
        const record = await db.collection('breeding_records').doc(doc.id).get();
        const r = breedingReminderFor(doc.data(), record.exists ? record.data() : undefined, today);
        if (!r) continue;
        const isNew = await sendReminderOnce(`reminder_${r.kind}_${doc.id}`, {
          ...r,
          type: 'breeding',
          referenceId: doc.id,
        });
        if (isNew) sent++;
      }
    }
    logger.info(`Sent ${sent} breeding reminder(s) for ${today}`);
  },
);
