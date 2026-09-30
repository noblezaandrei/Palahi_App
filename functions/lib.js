// Pure helpers for index.js, kept separate so they can be unit tested
// without Firebase (see lib.test.js).

const MANILA_OFFSET_HOURS = 8; // Asia/Manila has no daylight saving time.

/** "yyyy-MM-dd" in Manila time, [addDays] days after [now]. */
function manilaDateKey(now, addDays = 0) {
  const manila = new Date(now.getTime() + MANILA_OFFSET_HOURS * 3600 * 1000);
  manila.setUTCDate(manila.getUTCDate() + addDays);
  return manila.toISOString().slice(0, 10);
}

/** A stored booking time like "09:00 AM" as "9:00 AM". */
function displayTime(time) {
  return typeof time === 'string' && time.startsWith('0') ? time.slice(1) : time || '';
}

/**
 * The reminder notifications for a booking happening tomorrow, as
 * [{userId, title, body}]. Accepted bookings remind both sides; a request
 * still pending the day before nudges the breeder to answer it.
 */
function remindersFor(booking) {
  const pig = booking.studPigName || 'your stud pig';
  const at = displayTime(booking.bookingTime);
  if (booking.status === 'accepted') {
    return [
      {
        userId: booking.farmerId,
        title: 'Booking tomorrow',
        body: `${pig} from ${booking.breederName || 'the breeder'} is booked for tomorrow at ${at}.`,
      },
      {
        userId: booking.breederId,
        title: 'Booking tomorrow',
        body: `You're bringing ${pig} to ${booking.farmerName || 'a farmer'} tomorrow at ${at}.`,
      },
    ].filter((r) => r.userId);
  }
  if (booking.status === 'pending') {
    return booking.breederId
      ? [
          {
            userId: booking.breederId,
            title: 'Request waiting for you',
            body: `${booking.farmerName || 'A farmer'} wants ${pig} tomorrow at ${at}. Accept or reject it so they can plan.`,
          },
        ]
      : [];
  }
  return [];
}

// FCM errors meaning the token will never work again (app uninstalled,
// data cleared, token rotated), so it should be removed from the profile.
const DEAD_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** The tokens from [tokens] that [response] (sendEachForMulticast) says are dead. */
function deadTokens(tokens, response) {
  return response.responses
    .map((r, i) => (!r.success && r.error && DEAD_TOKEN_ERRORS.has(r.error.code) ? tokens[i] : null))
    .filter(Boolean);
}

// Pig reproduction timings, counted from the breeding day — the same
// numbers as lib/features/tracker/models/breeding_record.dart.
const HEAT_CHECK_START_DAY = 18;
const HEAT_CHECK_END_DAY = 24;
const GESTATION_DAYS = 114;

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** The "yyyy-MM-dd" [days] after [key]. */
function addDays(key, days) {
  const d = new Date(`${key}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** "yyyy-MM-dd" as "Oct 25". */
function shortDate(key) {
  const [, m, d] = key.split('-').map(Number);
  return `${MONTHS[m - 1]} ${d}`;
}

/** Whole days from [fromKey] to [toKey]. */
function daysBetween(fromKey, toKey) {
  return Math.round((Date.parse(`${toKey}T00:00:00Z`) - Date.parse(`${fromKey}T00:00:00Z`)) / 86400000);
}

/** How many days after breeding each tracker reminder goes out. */
const BREEDING_REMINDER_DAYS = [HEAT_CHECK_START_DAY, GESTATION_DAYS - 3, GESTATION_DAYS];

/**
 * The Breeding Tracker reminder due today for a farmer's bred sow, as
 * {kind, userId, title, body}, or null. [record] is her /breeding_records
 * doc (or undefined if the farmer hasn't reported anything yet).
 */
function breedingReminderFor(booking, record, todayKey) {
  if (!['done_breeding', 'completed'].includes(booking.status) || !booking.farmerId) return null;
  const outcome = (record && record.outcome) || 'waiting';
  const pig = booking.studPigName || 'the boar';
  const day = daysBetween(booking.bookingDate, todayKey);
  const due = shortDate(addDays(booking.bookingDate, GESTATION_DAYS));

  if (day === HEAT_CHECK_START_DAY && outcome === 'waiting') {
    return {
      kind: 'heat',
      userId: booking.farmerId,
      title: 'Time for the heat check',
      body: `After breeding with ${pig}, your sow may come back into heat from today until ${shortDate(addDays(booking.bookingDate, HEAT_CHECK_END_DAY))}. Check her daily and record it in the Breeding Tracker.`,
    };
  }
  if (!['waiting', 'pregnant'].includes(outcome)) return null;
  if (day === GESTATION_DAYS - 3) {
    return {
      kind: 'farrow3',
      userId: booking.farmerId,
      title: 'Farrowing in 3 days',
      body: `After breeding with ${pig}, your sow is due to farrow around ${due}. Get a clean, dry, warm farrowing pen ready.`,
    };
  }
  if (day === GESTATION_DAYS) {
    return {
      kind: 'farrow',
      userId: booking.farmerId,
      title: 'Farrowing due today',
      body: `After breeding with ${pig}, your sow is due to farrow today. Keep an eye on her, and record the litter in the Breeding Tracker.`,
    };
  }
  return null;
}

module.exports = {
  manilaDateKey,
  displayTime,
  remindersFor,
  deadTokens,
  addDays,
  BREEDING_REMINDER_DAYS,
  breedingReminderFor,
};
