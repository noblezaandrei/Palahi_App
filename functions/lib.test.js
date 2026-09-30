const test = require('node:test');
const assert = require('node:assert');
const { manilaDateKey, displayTime, remindersFor, deadTokens, addDays, breedingReminderFor } = require('./lib');

test('tomorrow is worked out in Manila time, not UTC', () => {
  // 6 PM Manila on Sep 30 is 10 AM UTC the same day.
  assert.strictEqual(manilaDateKey(new Date('2026-09-30T10:00:00Z'), 1), '2026-10-01');
  // 7 AM Manila on Oct 1 is still Sep 30 in UTC.
  assert.strictEqual(manilaDateKey(new Date('2026-09-30T23:00:00Z')), '2026-10-01');
  // Across a month end.
  assert.strictEqual(manilaDateKey(new Date('2026-10-31T10:00:00Z'), 1), '2026-11-01');
});

test('booking times drop the leading zero', () => {
  assert.strictEqual(displayTime('09:00 AM'), '9:00 AM');
  assert.strictEqual(displayTime('12:00 PM'), '12:00 PM');
});

const booking = {
  farmerId: 'F',
  farmerName: 'Juan',
  breederId: 'B',
  breederName: 'Green Valley Farm',
  studPigName: 'Duroc King',
  bookingTime: '09:00 AM',
};

test('an accepted booking reminds both the farmer and the breeder', () => {
  const r = remindersFor({ ...booking, status: 'accepted' });
  assert.deepStrictEqual(r.map((x) => x.userId), ['F', 'B']);
  assert.match(r[0].body, /Duroc King from Green Valley Farm .* tomorrow at 9:00 AM/);
  assert.match(r[1].body, /bringing Duroc King to Juan tomorrow at 9:00 AM/);
});

test('a request still pending the day before nudges only the breeder', () => {
  const r = remindersFor({ ...booking, status: 'pending' });
  assert.deepStrictEqual(r.map((x) => x.userId), ['B']);
});

test('finished or cancelled bookings get no reminder', () => {
  for (const status of ['cancelled', 'rejected', 'completed', 'done_breeding']) {
    assert.deepStrictEqual(remindersFor({ ...booking, status }), []);
  }
});

test('only tokens FCM says are gone are removed', () => {
  const response = {
    responses: [
      { success: true },
      { success: false, error: { code: 'messaging/registration-token-not-registered' } },
      { success: false, error: { code: 'messaging/internal-error' } },
    ],
  };
  assert.deepStrictEqual(deadTokens(['a', 'b', 'c'], response), ['b']);
});

const bred = { ...booking, bookingDate: '2026-10-01', status: 'completed' };

test('breeding reminders go out on day 18, 3 days before and on the due date', () => {
  assert.strictEqual(addDays('2026-10-01', 114), '2027-01-23');
  const heat = breedingReminderFor(bred, undefined, '2026-10-19');
  assert.strictEqual(heat.kind, 'heat');
  assert.match(heat.body, /from today until Oct 25/);
  assert.strictEqual(breedingReminderFor(bred, undefined, '2027-01-20').kind, 'farrow3');
  assert.match(breedingReminderFor(bred, { outcome: 'pregnant' }, '2027-01-20').body, /around Jan 23/);
  assert.strictEqual(breedingReminderFor(bred, { outcome: 'pregnant' }, '2027-01-23').kind, 'farrow');
  assert.strictEqual(breedingReminderFor(bred, undefined, '2026-10-20'), null);
});

test('no tracker reminders once the farmer has the answer', () => {
  // Already reported at the heat check, or she didn't conceive, or farrowed.
  assert.strictEqual(breedingReminderFor(bred, { outcome: 'pregnant' }, '2026-10-19'), null);
  assert.strictEqual(breedingReminderFor(bred, { outcome: 'not_pregnant' }, '2027-01-20'), null);
  assert.strictEqual(breedingReminderFor(bred, { outcome: 'farrowed' }, '2027-01-23'), null);
  // Bookings where breeding never happened.
  assert.strictEqual(breedingReminderFor({ ...bred, status: 'cancelled' }, undefined, '2026-10-19'), null);
});
