import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, getDoc, setDoc, addDoc, updateDoc, deleteDoc, deleteField, collection, getDocs, writeBatch, serverTimestamp, query, where } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-palahi',
  firestore: { rules: readFileSync(process.env.RULES || '../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
});

// Legacy data the rules must still cope with.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'usernames/victim'), { uid: 'C', email: 'victim@example.com' });
});

const ctx = (id) => env.authenticatedContext(id, { email: `${id}@example.com` }).firestore();
const A = ctx('A'), B = ctx('B'), C = ctx('C'), D = ctx('D'), NP = ctx('NOPROFILE');

const results = [];
async function check(name, expect, fn) {
  let outcome, err = '';
  try { await fn(); outcome = 'ALLOWED'; } catch (e) { outcome = 'DENIED'; err = e.code || e.message; }
  results.push({ pass: outcome === expect ? 'PASS' : '** FAIL **', expect, outcome, name });
}
const must = (name, fn) => check(name, 'ALLOWED', fn);
const mustNot = (name, fn) => check(name, 'DENIED', fn);

// ---- Legit sign-up flows (mirrors AuthRepository._createUserProfile order) ----
await must('signup: farmer A creates users/A', () => setDoc(doc(A, 'users/A'), { id: 'A', role: 'farmer', name: 'A' }));
await must('signup: farmer C creates users/C', () => setDoc(doc(C, 'users/C'), { id: 'C', role: 'farmer', name: 'C' }));
await must('signup: breeder B creates users/B', () => setDoc(doc(B, 'users/B'), { id: 'B', role: 'breeder', name: 'B' }));
await must('signup: breeder B creates breeders/B', () => setDoc(doc(B, 'breeders/B'), { userId: 'B', farmName: 'B Farm', rating: 0, reviewCount: 0 }));
await must('signup: breeder D (users + breeders)', async () => {
  await setDoc(doc(D, 'users/D'), { id: 'D', role: 'breeder' });
  await setDoc(doc(D, 'breeders/D'), { userId: 'D', farmName: 'D Farm' });
});
await must('PUSH: user saves own device token', () => updateDoc(doc(A, 'users/A'), { fcmTokens: ['tokenA'] }));
await mustNot('PUSH: user adds a token to someone else', () => updateDoc(doc(C, 'users/A'), { fcmTokens: ['tokenC'] }));
await mustNot('PUSH: user reads another user tokens', () => getDoc(doc(C, 'users/A')));
await must('username claim', () => setDoc(doc(A, 'usernames/alice'), { uid: 'A', email: 'A@example.com' }));
await must('breeder B edits own farm (set = update)', () => setDoc(doc(B, 'breeders/B'), { userId: 'B', farmName: 'B Farm 2', availableDates: ['2026-10-01'] }));
await must('breeder B adds stud pig', () => setDoc(doc(B, 'stud_pigs/p1'), { breederId: 'B', name: 'Boar', price: 1500, isAvailable: true }));
await must('breeder B adds a second stud pig', () => setDoc(doc(B, 'stud_pigs/p3'), { breederId: 'B', name: 'Boar 3', price: 1500, isAvailable: true }));
await must('breeder D adds stud pig', () => setDoc(doc(D, 'stud_pigs/dp0'), { breederId: 'D', name: 'D Boar', price: 1000, isAvailable: true }));
await must('PROFILE: breeder adds 4 extra photos and health records', () => setDoc(doc(B, 'stud_pigs/p1'), { breederId: 'B', name: 'Boar', price: 1500, isAvailable: true, photoUrls: ['a', 'b', 'c', 'd'], vaccinations: 'Hog cholera', lastHealthCheck: '2026-09-01', pedigree: 'PIC Duroc' }));
await mustNot('PROFILE: more than 4 extra photos', () => setDoc(doc(B, 'stud_pigs/p1'), { breederId: 'B', name: 'Boar', price: 1500, isAvailable: true, photoUrls: ['a', 'b', 'c', 'd', 'e'] }));
await must('breeder B edits stud pig',() => setDoc(doc(B, 'stud_pigs/p1'), { breederId: 'B', name: 'Boar', price: 1800, isAvailable: true }));
await must('farmer A pins own farm', () => setDoc(doc(A, 'farmer_locations/A'), { latitude: 13.1, longitude: 123.7, name: 'A' }));
await must('farmer C pins own farm', () => setDoc(doc(C, 'farmer_locations/C'), { latitude: 13.2, longitude: 123.8, name: 'C' }));
await must('farmer A reads own pin', () => getDoc(doc(A, 'farmer_locations/A')));
await must('farmer favorites breeder', () => addDoc(collection(A, 'favorites'), { userId: 'A', breederId: 'B', timestamp: serverTimestamp() }));
await must('farmer lists own favorites', () => getDocs(query(collection(A, 'favorites'), where('userId', '==', 'A'))));

// ---- Legit booking lifecycle (mirrors BreedingRequestRepository) ----
const bk = { farmerId: 'A', farmerName: 'A', breederId: 'B', breederName: 'B Farm', studPigId: 'p1', studPigName: 'Boar',
  status: 'pending', breedingType: 'Manual Breeding', bookingDate: '2026-10-01', bookingTime: '08:00 AM', notes: '', createdAt: serverTimestamp() };
// Mirrors BreedingRequestRepository.sendRequest: booking + slot mirror +
// pig/day lock + breeder/time lock in one batch. Returns the new booking id.
const lockId = (b) => `${b.studPigId}_${b.bookingDate}`;
const timeLockId = (b) => `${b.breederId}_${b.bookingDate}_${b.bookingTime.replace(/[: ]/g, '')}`;
async function book(db, fields = {}, { withLock = true, lockDoc, withTimeLock = true, timeLockDoc } = {}) {
  const data = { ...bk, ...fields };
  const ref = doc(collection(db, 'bookings'));
  const batch = writeBatch(db);
  batch.set(ref, data);
  batch.set(doc(db, 'booking_slots', ref.id), { breederId: data.breederId, studPigId: data.studPigId, bookingDate: data.bookingDate, bookingTime: data.bookingTime, status: data.status });
  if (withLock) batch.set(doc(db, 'slot_locks', lockDoc ?? lockId(data)), { bookingId: ref.id });
  if (withTimeLock) batch.set(doc(db, 'time_locks', timeLockDoc ?? timeLockId(data)), { bookingId: ref.id });
  await batch.commit();
  return ref.id;
}
// Mirrors updateRequestStatus: booking + slot mirror in one batch.
async function setStatus(db, id, status) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'bookings', id), { status, ...(status === 'completed' ? { completedAt: serverTimestamp() } : {}) });
  batch.set(doc(db, 'booking_slots', id), { breederId: 'B', status }, { merge: true });
  await batch.commit();
}
let bid;
await must('farmer A books breeder B (booking + slot + lock, one batch)', async () => { bid = await book(A); });
const notif = (userId, type, referenceId, extra = {}) => ({ userId, title: 't', body: 'b', type, referenceId, isRead: false, createdAt: serverTimestamp(), ...extra });
await must('farmer notifies breeder of new booking', () => addDoc(collection(A, 'notifications'), notif('B', 'booking', bid)));
await must('any user checks slot conflicts', () => getDocs(query(collection(C, 'booking_slots'), where('breederId', '==', 'B'))));
await mustNot('farmer cannot review a PENDING booking', () => setDoc(doc(A, 'reviews', bid), { farmerId: 'A', breederId: 'B', bookingId: bid, rating: 1, studPigRating: 1, review: '' }));
await must('breeder accepts (booking + slot batch)', () => setStatus(B, bid, 'accepted'));
await must('breeder notifies farmer', () => addDoc(collection(B, 'notifications'), notif('A', 'booking', bid)));
await must('breeder reads farmer A pin (trip directions)', () => getDoc(doc(B, 'farmer_locations/A')));
await must('breeder starts trip', () => setDoc(doc(B, 'trip_locations', bid), { breederId: 'B', farmerId: 'A', active: true, arrivedAt: null, latitude: deleteField(), longitude: deleteField() }, { merge: true }));
await must('breeder phone reports its position and route progress', () => setDoc(doc(B, 'trip_locations', bid), { breederId: 'B', farmerId: 'A', latitude: 13.1, longitude: 123.7, onRouteLatitude: 13.1, onRouteLongitude: 123.7, active: true, arrivedAt: null }, { merge: true }));
await mustNot('farmer cannot move the breeder along the route', () => setDoc(doc(A, 'trip_locations', bid), { breederId: 'B', farmerId: 'A', onRouteLatitude: 0, onRouteLongitude: 0 }, { merge: true }));
await must('breeder restarts trip (clears the old position)', () => setDoc(doc(B, 'trip_locations', bid), { breederId: 'B', farmerId: 'A', active: true, arrivedAt: null, latitude: deleteField(), longitude: deleteField() }, { merge: true }));
await must('farmer watches trip', () => getDoc(doc(A, 'trip_locations', bid)));
await must('breeder ends trip (merge, no ids)', () => setDoc(doc(B, 'trip_locations', bid), { active: false, arrivedAt: serverTimestamp() }, { merge: true }));
await must('farmer marks done_breeding', () => setStatus(A, bid, 'done_breeding'));
await mustNot('SLOT: done_breeding slot still blocks a new booking', () => book(C, { farmerId: 'C' }));
await must('breeder completes', () => setStatus(B, bid, 'completed'));
const review = { bookingId: bid, breederId: 'B', farmerId: 'A', farmerName: 'A', rating: 4, review: 'good', studPigId: 'p1', studPigName: 'Boar', studPigRating: 5, studPigReview: '', createdAt: new Date() };
await mustNot('review under a random id is rejected', () => addDoc(collection(A, 'reviews'), review));
await must('farmer reviews completed booking (id = bookingId)', () => setDoc(doc(A, 'reviews', bid), review));
await must('duplicate-check query (legacy ids) still works', () => getDocs(query(collection(A, 'reviews'), where('bookingId', '==', bid))));
await must('anyone signed in reads reviews', () => getDocs(query(collection(C, 'reviews'), where('breederId', '==', 'B'))));

// ---- Legit chat (mirrors ChatRepository; id = sorted uids) ----
const room = { farmerId: 'A', farmerName: 'A', farmerImageUrl: '', breederId: 'B', breederName: 'B Farm', breederImageUrl: '', lastMessage: 'Chat started.', lastMessageTime: new Date(), participants: ['A', 'B'] };
await must('probe missing room before creating (get)', () => getDoc(doc(A, 'chat_rooms/A_B')));
await must('farmer creates room A_B', () => setDoc(doc(A, 'chat_rooms/A_B'), room));
await must('breeder D creates room with farmer C (breeder-initiated)', () => setDoc(doc(D, 'chat_rooms/C_D'), { ...room, farmerId: 'C', breederId: 'D', participants: ['C', 'D'] }));
await must('send message + bump room (batch)', async () => {
  const batch = writeBatch(A);
  batch.set(doc(collection(A, 'chat_rooms/A_B/messages')), { senderId: 'A', senderName: 'A', text: 'hi', timestamp: serverTimestamp() });
  batch.update(doc(A, 'chat_rooms/A_B'), { lastMessage: 'hi', lastMessageTime: serverTimestamp() });
  await batch.commit();
});
await must('chat notification to other participant', () => addDoc(collection(A, 'notifications'), notif('B', 'chat', 'A_B')));
await must('markSeen', () => updateDoc(doc(B, 'chat_rooms/A_B'), { 'seenBy.B': serverTimestamp() }));

// Reactions (mirrors ChatRepository.setReaction)
// A is the farmer, B the breeder; one message from each.
const msg = await addDoc(collection(A, 'chat_rooms/A_B/messages'), { senderId: 'A', senderName: 'A', text: 'hello', timestamp: serverTimestamp() });
const bMsg = await addDoc(collection(B, 'chat_rooms/A_B/messages'), { senderId: 'B', senderName: 'B Farm', text: 'hi farmer', timestamp: serverTimestamp() });
await must('REACT: breeder reacts 👍 to farmer\'s message', () => updateDoc(doc(B, msg.path), { 'reactions.B': '👍' }));
await must('REACT: farmer reacts ❤️ to breeder\'s message', () => updateDoc(doc(A, bMsg.path), { 'reactions.A': '❤️' }));
await mustNot('REACT: farmer reacts to OWN message', () => updateDoc(doc(A, msg.path), { 'reactions.A': '❤️' }));
await mustNot('REACT: breeder reacts to OWN message', () => updateDoc(doc(B, bMsg.path), { 'reactions.B': '❤️' }));
await must('REACT: reaction notifies the message sender', () => addDoc(collection(B, 'notifications'),
  { userId: 'A', title: 'B Farm reacted 👍 to your message', body: '"hello"', type: 'chat', referenceId: 'A_B', isRead: false, createdAt: serverTimestamp() }));
await must('REACT: breeder changes reaction to 😂', () => updateDoc(doc(B, msg.path), { 'reactions.B': '😂' }));
await must('REACT: breeder removes own reaction', () => updateDoc(doc(B, msg.path), { 'reactions.B': deleteField() }));
await mustNot('REACT: breeder changes farmer\'s reaction on own message', () => updateDoc(doc(B, bMsg.path), { 'reactions.A': '😢' }));
await mustNot('REACT: breeder removes farmer\'s reaction on own message', () => updateDoc(doc(B, bMsg.path), { 'reactions.A': deleteField() }));
await mustNot('REACT: emoji not in the app\'s list', () => updateDoc(doc(B, msg.path), { 'reactions.B': '💩' }));
await mustNot('REACT: long text as a "reaction"', () => updateDoc(doc(B, msg.path), { 'reactions.B': 'x'.repeat(5000) }));
await mustNot('REACT: reaction plus editing the text', () => updateDoc(doc(B, msg.path), { 'reactions.B': '👍', text: 'edited by B' }));
await mustNot('REACT: outsider C reacts', () => updateDoc(doc(C, msg.path), { 'reactions.C': '👍' }));
await must('(setup) breeder reacts again', () => updateDoc(doc(B, msg.path), { 'reactions.B': '🙏' }));
await mustNot('REACT: sender wipes the other\'s reaction', () => updateDoc(doc(A, msg.path), { reactions: {} }));
await must('REACT: farmer removes own reaction on breeder\'s message', () => updateDoc(doc(A, bMsg.path), { 'reactions.A': deleteField() }));
await must('REACT: sender can still edit own text', () => updateDoc(doc(A, msg.path), { text: 'hello!' }));
await must('participant syncs own picture onto the room', () => updateDoc(doc(B, 'chat_rooms/A_B'), { breederImageUrl: 'https://img/farm.jpg' }));
await must('other participant reads the picture', async () => {
  const snap = await getDoc(doc(A, 'chat_rooms/A_B'));
  if (snap.data().breederImageUrl !== 'https://img/farm.jpg') throw new Error('picture not saved');
});
await mustNot('outsider cannot change pictures on a room', () => updateDoc(doc(C, 'chat_rooms/A_B'), { farmerImageUrl: 'x' }));
await must('recipient marks notification read', async () => {
  const snap = await getDocs(query(collection(B, 'notifications'), where('userId', '==', 'B')));
  await updateDoc(snap.docs[0].ref, { isRead: true });
});

// ---- Exploits from the audit: all must now be DENIED ----
// 1. Review bombing
let b2;
await must('(setup) farmer C books breeder B', async () => { b2 = await book(C, { farmerId: 'C', bookingDate: '2026-10-02' }); });
await mustNot('EXPLOIT 1a review on pending booking', () => setDoc(doc(C, 'reviews', b2), { ...review, bookingId: b2, farmerId: 'C', rating: 1 }));
await setStatus(C, b2, 'cancelled');
await mustNot('EXPLOIT 1b review on cancelled booking', () => setDoc(doc(C, 'reviews', b2), { ...review, bookingId: b2, farmerId: 'C', rating: 1 }));
await mustNot('EXPLOIT 1c 2nd review on completed booking (new id)', () => addDoc(collection(A, 'reviews'), { ...review, rating: 1 }));
await mustNot('EXPLOIT 1d review for booking under a different id', () => setDoc(doc(A, 'reviews/other'), { ...review, rating: 1 }));
await mustNot('EXPLOIT 1e review with 1MB text', () => updateDoc(doc(A, 'reviews', bid), { studPigReview: 'x'.repeat(3000) }));
// 2. Chat squatting
await mustNot('EXPLOIT 2a C squats room B_D (breeders pair) with self', () => setDoc(doc(C, 'chat_rooms/B_D'), { ...room, farmerId: 'C', breederId: 'B', participants: ['B', 'C'] }));
await mustNot('EXPLOIT 2b C squats room A_D id with participants [C,D]', () => setDoc(doc(C, 'chat_rooms/A_D'), { ...room, farmerId: 'C', breederId: 'D', participants: ['C', 'D'] }));
await mustNot('EXPLOIT 2c room with unsorted participants', () => setDoc(doc(C, 'chat_rooms/C_B'), { ...room, farmerId: 'C', breederId: 'B', participants: ['C', 'B'] }));
await mustNot('EXPLOIT 2d farmer-farmer room', () => setDoc(doc(A, 'chat_rooms/A_C'), { ...room, farmerId: 'A', breederId: 'C', participants: ['A', 'C'] }));
await mustNot('EXPLOIT 2e outsider reads A_B', () => getDoc(doc(C, 'chat_rooms/A_B')));
// 3. Notifications
await mustNot('EXPLOIT 3a phishing notification, no reference', () => addDoc(collection(A, 'notifications'), notif('C', 'booking', '', { title: 'Account suspended' })));
await mustNot('EXPLOIT 3b notify C citing A\'s own booking with B', () => addDoc(collection(A, 'notifications'), notif('C', 'booking', bid)));
await mustNot('EXPLOIT 3c notify D citing chat A_B', () => addDoc(collection(A, 'notifications'), notif('D', 'chat', 'A_B')));
await mustNot('EXPLOIT 3d outsider C notifies B citing chat A_B', () => addDoc(collection(C, 'notifications'), notif('B', 'chat', 'A_B')));
await mustNot('EXPLOIT 3e type trip/review (unused by app)', () => addDoc(collection(A, 'notifications'), notif('B', 'trip', bid)));
await mustNot('EXPLOIT 3f notification body > 2000', () => addDoc(collection(A, 'notifications'), notif('B', 'chat', 'A_B', { body: 'x'.repeat(2001) })));
// 4. Farmers posing as breeders
await mustNot('EXPLOIT 4a farmer A creates breeders/A', () => setDoc(doc(A, 'breeders/A'), { userId: 'A', farmName: 'Fake' }));
await mustNot('EXPLOIT 4b farmer A lists a stud pig', () => setDoc(doc(A, 'stud_pigs/fake'), { breederId: 'A', name: 'x', price: 100 }));
await mustNot('EXPLOIT 4c negative stud fee', () => setDoc(doc(B, 'stud_pigs/p2'), { breederId: 'B', name: 'x', price: -5 }));
await mustNot('EXPLOIT 4d account with no profile creates breeder', () => setDoc(doc(NP, 'breeders/NOPROFILE'), { userId: 'NOPROFILE' }));
await mustNot('EXPLOIT 4e booking to a non-breeder uid (C)', () => book(A, { breederId: 'C', bookingDate: '2026-10-03' }));
await mustNot('EXPLOIT 4f breeder D books breeder B', () => book(D, { farmerId: 'D', bookingDate: '2026-10-03' }));
await mustNot('EXPLOIT 4g role switch farmer->breeder', () => updateDoc(doc(A, 'users/A'), { role: 'breeder' }));
// 5. Farmer location privacy
await mustNot('EXPLOIT 5a farmer lists all farmer pins', () => getDocs(collection(A, 'farmer_locations')));
await mustNot('EXPLOIT 5b breeder lists all farmer pins', () => getDocs(collection(B, 'farmer_locations')));
await mustNot('EXPLOIT 5c farmer A reads farmer C pin', () => getDoc(doc(A, 'farmer_locations/C')));
await mustNot('EXPLOIT 5d farmer A overwrites C pin', () => setDoc(doc(A, 'farmer_locations/C'), { latitude: 0, longitude: 0 }));
await mustNot('EXPLOIT 5e farmer reads other user profile', () => getDoc(doc(A, 'users/C')));

// 6. Double booking (slot locks)
await mustNot('SLOT: C books the pig A holds that day', () => book(C, { farmerId: 'C' }));
await mustNot('SLOT: same pig, same day, different time', () => book(C, { farmerId: 'C', bookingTime: '04:00 PM' }));
await must('SLOT: C re-books the pig/day/time freed by cancelling', () => book(C, { farmerId: 'C', bookingDate: '2026-10-02' }));
// A breeder can only be at one farm at a time, across all their pigs.
await mustNot('TIME: a different pig of the same breeder at the same time', () => book(C, { farmerId: 'C', studPigId: 'p3', studPigName: 'Boar 3' }));
await must('SLOT: a different pig on the same day at another time', () => book(C, { farmerId: 'C', studPigId: 'p3', studPigName: 'Boar 3', bookingTime: '10:00 AM' }));
await must('TIME: another breeder at the same time', () => book(C, { farmerId: 'C', breederId: 'D', studPigId: 'dp0', studPigName: 'D Boar' }));
await mustNot('TIME: booking without a time lock', () => book(A, { bookingDate: '2026-10-10' }, { withTimeLock: false }));
await mustNot('TIME: time lock id that doesn\'t match the booking', () => book(A, { bookingDate: '2026-10-10' }, { timeLockDoc: 'B_2026-10-10_0900AM' }));
await mustNot('TIME: overwrite a time lock held by an active booking', () =>
  setDoc(doc(C, 'time_locks', 'B_2026-10-01_0800AM'), { bookingId: b2 }));
await must('TIME: read one time lock', () => getDoc(doc(C, 'time_locks', 'B_2026-10-01_0800AM')));
await mustNot('TIME: list all time locks', () => getDocs(collection(C, 'time_locks')));
await mustNot('SLOT: pig from another breeder under breeder B', () => book(C, { farmerId: 'C', studPigId: 'dp0', bookingDate: '2026-10-04' }));
await mustNot('SLOT: booking without a lock', () => book(A, { bookingDate: '2026-10-04' }, { withLock: false }));
await mustNot('SLOT: lock id that doesn\'t match the booking', () => book(A, { bookingDate: '2026-10-04' }, { lockDoc: 'p1_2026-10-05' }));
await mustNot('SLOT: old breeder/date/time lock id', () => book(A, { bookingDate: '2026-10-04' }, { lockDoc: 'B_2026-10-04_08:00 AM' }));
await mustNot('SLOT: overwrite a lock held by an active booking', () =>
  setDoc(doc(C, 'slot_locks', 'p1_2026-10-01'), { bookingId: b2 }));
await must('SLOT: read one lock', () => getDoc(doc(C, 'slot_locks', 'p1_2026-10-01')));
// Daytime hours only: 08:00 AM to 05:00 PM.
await mustNot('HOURS: 07:59 AM', () => book(A, { bookingDate: '2026-10-08', bookingTime: '07:59 AM' }));
await mustNot('HOURS: 05:01 PM', () => book(A, { bookingDate: '2026-10-08', bookingTime: '05:01 PM' }));
await mustNot('HOURS: 09:00 PM (night)', () => book(A, { bookingDate: '2026-10-08', bookingTime: '09:00 PM' }));
await mustNot('HOURS: 12:30 AM (midnight)', () => book(A, { bookingDate: '2026-10-08', bookingTime: '12:30 AM' }));
await mustNot('HOURS: not a time', () => book(A, { bookingDate: '2026-10-08', bookingTime: 'morning' }));
await mustNot('HOURS: 12:45 PM (not on the hour)', () => book(A, { bookingDate: '2026-10-08', bookingTime: '12:45 PM' }));
await must('HOURS: 12:00 PM', () => book(A, { bookingDate: '2026-10-08', bookingTime: '12:00 PM' }));
await must('HOURS: 05:00 PM (last)', () => book(A, { bookingDate: '2026-10-09', bookingTime: '05:00 PM' }));
await mustNot('SLOT: list all locks', () => getDocs(collection(C, 'slot_locks')));
{
  // Two farmers submit the same free slot at the same moment.
  const race = await Promise.allSettled([
    // Same pig and day, different times: still only one may win (pig lock).
    book(A, { bookingDate: '2026-10-06', bookingTime: '09:00 AM' }),
    book(C, { farmerId: 'C', bookingDate: '2026-10-06', bookingTime: '03:00 PM' }),
  ]);
  const winners = race.filter((r) => r.status === 'fulfilled').length;
  results.push({ pass: winners === 1 ? 'PASS' : '** FAIL **', expect: '1 winner', outcome: `${winners} winner(s)`, name: 'SLOT: simultaneous booking race' });
}
{
  // 10 farmers racing for one slot.
  const racers = await Promise.all(Array.from({ length: 10 }, async (_, i) => {
    const id = `F${i}`;
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'users', id), { id, role: 'farmer' }));
    return ctx(id);
  }));
  const race = await Promise.allSettled(racers.map((db, i) => book(db, { farmerId: `F${i}`, bookingDate: '2026-10-07', bookingTime: `0${1 + (i % 4)}:00 PM` })));
  const winners = race.filter((r) => r.status === 'fulfilled').length;
  results.push({ pass: winners === 1 ? 'PASS' : '** FAIL **', expect: '1 winner', outcome: `${winners} winner(s)`, name: 'SLOT: 10-way booking race' });

  // Two farmers grab the same breeder and time for different pigs.
  const timeRace = await Promise.allSettled([
    book(racers[0], { farmerId: 'F0', bookingDate: '2026-10-12', bookingTime: '02:00 PM' }),
    book(racers[1], { farmerId: 'F1', studPigId: 'p3', studPigName: 'Boar 3', bookingDate: '2026-10-12', bookingTime: '02:00 PM' }),
  ]);
  const timeWinners = timeRace.filter((r) => r.status === 'fulfilled').length;
  results.push({ pass: timeWinners === 1 ? 'PASS' : '** FAIL **', expect: '1 winner', outcome: `${timeWinners} winner(s)`, name: 'TIME: same-time race for two pigs' });
}

// 6b. Rescheduling (mirrors BreedingRequestRepository.rescheduleRequest)
async function reschedule(db, id, b, { withLocks = true, extra = {} } = {}) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'bookings', id), { bookingDate: b.bookingDate, bookingTime: b.bookingTime, status: 'pending', ...extra });
  batch.set(doc(db, 'booking_slots', id), { breederId: b.breederId, studPigId: b.studPigId, bookingDate: b.bookingDate, bookingTime: b.bookingTime, status: 'pending' }, { merge: true });
  if (withLocks) {
    batch.set(doc(db, 'slot_locks', lockId(b)), { bookingId: id });
    batch.set(doc(db, 'time_locks', timeLockId(b)), { bookingId: id });
  }
  await batch.commit();
}
let rs;
const moved = { ...bk, bookingDate: '2026-10-21', bookingTime: '10:00 AM' };
await must('(setup) farmer A books Oct 20 9 AM', async () => { rs = await book(A, { bookingDate: '2026-10-20', bookingTime: '09:00 AM' }); });
await mustNot('RESCHEDULE: without claiming the new locks', () => reschedule(A, rs, moved, { withLocks: false }));
await mustNot('RESCHEDULE: by the breeder', () => reschedule(B, rs, moved));
await mustNot('RESCHEDULE: changing the notes too', () => reschedule(A, rs, moved, { extra: { notes: 'hacked' } }));
await mustNot('RESCHEDULE: to a night time', () => reschedule(A, rs, { ...moved, bookingTime: '09:00 PM' }));
await must('RESCHEDULE: farmer moves it to Oct 21 10 AM', () => reschedule(A, rs, moved));
await must('RESCHEDULE: the old Oct 20 9 AM slot is free for farmer C', () => book(C, { farmerId: 'C', bookingDate: '2026-10-20', bookingTime: '09:00 AM' }));
await mustNot('RESCHEDULE: into the slot C now holds', () => reschedule(A, rs, { ...bk, bookingDate: '2026-10-20', bookingTime: '09:00 AM' }));
await mustNot('RESCHEDULE: into a time the breeder is booked (other pig)', async () => {
  await book(C, { farmerId: 'C', studPigId: 'p3', studPigName: 'Boar 3', bookingDate: '2026-10-22', bookingTime: '08:00 AM' });
  await reschedule(A, rs, { ...bk, bookingDate: '2026-10-22', bookingTime: '08:00 AM' });
});
await must('RESCHEDULE: another time on the same day (keeps the day lock)', () => reschedule(A, rs, { ...moved, bookingTime: '02:00 PM' }));
await must('(setup) breeder accepts the rescheduled booking', () => setStatus(B, rs, 'accepted'));
await must('RESCHEDULE: an accepted booking goes back to pending', async () => {
  await reschedule(A, rs, { ...bk, bookingDate: '2026-10-23', bookingTime: '03:00 PM' });
  const snap = await getDoc(doc(A, 'bookings', rs));
  if (snap.data().status !== 'pending') throw new Error('still ' + snap.data().status);
});
await mustNot('RESCHEDULE: a completed booking', () => reschedule(A, bid, { ...bk, bookingDate: '2026-10-24', bookingTime: '08:00 AM' }));

// 6c. Breeding tracker records (mirrors BreedingRecordRepository.saveOutcome)
const rec = (extra = {}) => ({ farmerId: 'A', breederId: 'B', studPigId: 'p1', outcome: 'pregnant', updatedAt: serverTimestamp(), ...extra });
await must('TRACKER: farmer records pregnant after a completed booking', () => setDoc(doc(A, 'breeding_records', bid), rec()));
await must('TRACKER: farmer records the farrowing and litter', () => setDoc(doc(A, 'breeding_records', bid), rec({ outcome: 'farrowed', litterSize: 11, farrowedOn: '2027-01-22' })));
await must('TRACKER: the boar breeder reads it (conception rate)', () => getDocs(query(collection(B, 'breeding_records'), where('breederId', '==', 'B'))));
await must('TRACKER: the farmer lists their own records', () => getDocs(query(collection(A, 'breeding_records'), where('farmerId', '==', 'A'))));
await mustNot('TRACKER: another farmer reads it', () => getDoc(doc(C, 'breeding_records', bid)));
await mustNot('TRACKER: record for a booking not bred yet (pending)', () => setDoc(doc(A, 'breeding_records', rs), rec()));
await mustNot('TRACKER: breeder writes the farmer record', () => setDoc(doc(B, 'breeding_records', bid), rec()));
await mustNot('TRACKER: record naming a different boar', () => setDoc(doc(A, 'breeding_records', bid), rec({ studPigId: 'p3' })));
await mustNot('TRACKER: impossible litter size', () => setDoc(doc(A, 'breeding_records', bid), rec({ outcome: 'farrowed', litterSize: 99 })));
await mustNot('TRACKER: unknown outcome', () => setDoc(doc(A, 'breeding_records', bid), rec({ outcome: 'twins' })));

// 7. Account deletion (mirrors AccountDeletionRepository.deleteAccount)
await mustNot('DELETE: someone else frees your username', () => deleteDoc(doc(C, 'usernames/alice')));
async function deleteAccount(db, uid, username) {
  for (const side of ['farmerId', 'breederId']) {
    const bookings = await getDocs(query(collection(db, 'bookings'), where(side, '==', uid)));
    for (const b of bookings.docs) {
      if (['pending', 'accepted'].includes(b.data().status)) {
        const batch = writeBatch(db);
        batch.update(b.ref, { status: 'cancelled' });
        batch.set(doc(db, 'booking_slots', b.id), { breederId: b.data().breederId, status: 'cancelled' }, { merge: true });
        await batch.commit();
      }
    }
  }
  const rooms = await getDocs(query(collection(db, 'chat_rooms'), where('participants', 'array-contains', uid)));
  for (const room of rooms.docs) {
    const mine = await getDocs(query(collection(db, `chat_rooms/${room.id}/messages`), where('senderId', '==', uid)));
    for (const m of mine.docs) await deleteDoc(m.ref);
    const side = room.data().farmerId === uid ? 'farmer' : 'breeder';
    await updateDoc(room.ref, { [`${side}Name`]: 'Deleted user', [`${side}ImageUrl`]: '', lastMessage: 'This account was deleted.' });
  }
  const reviews = await getDocs(query(collection(db, 'reviews'), where('farmerId', '==', uid)));
  for (const r of reviews.docs) await updateDoc(r.ref, { farmerName: 'Deleted user' });
  const refs = [];
  for (const [col, field] of [['stud_pigs', 'breederId'], ['favorites', 'userId'], ['notifications', 'userId']]) {
    const snap = await getDocs(query(collection(db, col), where(field, '==', uid)));
    refs.push(...snap.docs.map((d) => d.ref));
  }
  refs.push(doc(db, 'breeders', uid), doc(db, 'farmer_locations', uid));
  const batch = writeBatch(db);
  refs.forEach((r) => batch.delete(r));
  await batch.commit();
  if (username) await deleteDoc(doc(db, 'usernames', username));
  await deleteDoc(doc(db, 'users', uid));
}
await must('DELETE: farmer A deletes their whole account', () => deleteAccount(A, 'A', 'alice'));
await must('DELETE: breeder B still sees the review, anonymized', async () => {
  const snap = await getDoc(doc(B, 'reviews', bid));
  if (snap.data().farmerName !== 'Deleted user') throw new Error('name kept');
});
await must('DELETE: breeder B sees "Deleted user" in the chat', async () => {
  const snap = await getDoc(doc(B, 'chat_rooms/A_B'));
  if (snap.data().farmerName !== 'Deleted user') throw new Error('name kept');
});
await must('DELETE: username "alice" is free for someone else', () => setDoc(doc(C, 'usernames/alice'), { uid: 'C', email: 'C@example.com' }));
await must('(setup) breeder D lists a stud pig', () => setDoc(doc(D, 'stud_pigs/dpig'), { breederId: 'D', name: 'x', price: 1 }));
await must('DELETE: breeder D deletes their whole account', () => deleteAccount(D, 'D'));
await must('DELETE: D\'s listing is gone', async () => {
  const snap = await getDoc(doc(C, 'stud_pigs/dpig'));
  if (snap.exists()) throw new Error('listing kept');
});

console.table(results);
const failed = results.filter((r) => r.pass !== 'PASS').length;
console.log(`${results.length - failed}/${results.length} passed`);
await env.cleanup();
process.exit(failed ? 1 : 0);
