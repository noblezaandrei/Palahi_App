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
await must('username claim', () => setDoc(doc(A, 'usernames/alice'), { uid: 'A', email: 'A@example.com' }));
await must('breeder B edits own farm (set = update)', () => setDoc(doc(B, 'breeders/B'), { userId: 'B', farmName: 'B Farm 2', availableDates: ['2026-10-01'] }));
await must('breeder B adds stud pig', () => setDoc(doc(B, 'stud_pigs/p1'), { breederId: 'B', name: 'Boar', price: 1500, isAvailable: true }));
await must('breeder B edits stud pig', () => setDoc(doc(B, 'stud_pigs/p1'), { breederId: 'B', name: 'Boar', price: 1800, isAvailable: true }));
await must('farmer A pins own farm', () => setDoc(doc(A, 'farmer_locations/A'), { latitude: 13.1, longitude: 123.7, name: 'A' }));
await must('farmer C pins own farm', () => setDoc(doc(C, 'farmer_locations/C'), { latitude: 13.2, longitude: 123.8, name: 'C' }));
await must('farmer A reads own pin', () => getDoc(doc(A, 'farmer_locations/A')));
await must('farmer favorites breeder', () => addDoc(collection(A, 'favorites'), { userId: 'A', breederId: 'B', timestamp: serverTimestamp() }));
await must('farmer lists own favorites', () => getDocs(query(collection(A, 'favorites'), where('userId', '==', 'A'))));

// ---- Legit booking lifecycle (mirrors BreedingRequestRepository) ----
const bk = { farmerId: 'A', farmerName: 'A', breederId: 'B', breederName: 'B Farm', studPigId: 'p1', studPigName: 'Boar',
  status: 'pending', breedingType: 'Manual Breeding', bookingDate: '2026-10-01', bookingTime: '08:00 AM', notes: '', createdAt: serverTimestamp() };
// Mirrors BreedingRequestRepository.sendRequest: booking + slot mirror +
// slot lock in one batch. Returns the new booking id.
const lockId = (b) => `${b.breederId}_${b.bookingDate}_${b.bookingTime}`;
async function book(db, fields = {}, { withLock = true, lockDoc } = {}) {
  const data = { ...bk, ...fields };
  const ref = doc(collection(db, 'bookings'));
  const batch = writeBatch(db);
  batch.set(ref, data);
  batch.set(doc(db, 'booking_slots', ref.id), { breederId: data.breederId, studPigId: data.studPigId, bookingDate: data.bookingDate, bookingTime: data.bookingTime, status: data.status });
  if (withLock) batch.set(doc(db, 'slot_locks', lockDoc ?? lockId(data)), { bookingId: ref.id });
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
await must('breeder starts trip', () => setDoc(doc(B, 'trip_locations', bid), { breederId: 'B', farmerId: 'A', active: true, arrivedAt: null }, { merge: true }));
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
await must('(setup) farmer C books breeder B', async () => { b2 = await book(C, { farmerId: 'C', bookingTime: '09:00 AM' }); });
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
await mustNot('EXPLOIT 4e booking to a non-breeder uid (C)', () => book(A, { breederId: 'C', bookingTime: '10:00 AM' }));
await mustNot('EXPLOIT 4f breeder D books breeder B', () => book(D, { farmerId: 'D', bookingTime: '11:00 AM' }));
await mustNot('EXPLOIT 4g role switch farmer->breeder', () => updateDoc(doc(A, 'users/A'), { role: 'breeder' }));
// 5. Farmer location privacy
await mustNot('EXPLOIT 5a farmer lists all farmer pins', () => getDocs(collection(A, 'farmer_locations')));
await mustNot('EXPLOIT 5b breeder lists all farmer pins', () => getDocs(collection(B, 'farmer_locations')));
await mustNot('EXPLOIT 5c farmer A reads farmer C pin', () => getDoc(doc(A, 'farmer_locations/C')));
await mustNot('EXPLOIT 5d farmer A overwrites C pin', () => setDoc(doc(A, 'farmer_locations/C'), { latitude: 0, longitude: 0 }));
await mustNot('EXPLOIT 5e farmer reads other user profile', () => getDoc(doc(A, 'users/C')));

// 6. Double booking (slot locks)
await mustNot('SLOT: C books the slot A holds (08:00 AM)', () => book(C, { farmerId: 'C' }));
await must('SLOT: C re-books the 09:00 slot freed by cancelling', () => book(C, { farmerId: 'C', bookingTime: '09:00 AM' }));
await mustNot('SLOT: booking without a lock', () => book(A, { bookingTime: '01:00 PM' }, { withLock: false }));
await mustNot('SLOT: lock id that doesn\'t match the booking', () => book(A, { bookingTime: '01:00 PM' }, { lockDoc: 'B_2026-10-01_02:00 PM' }));
await mustNot('SLOT: overwrite a lock held by an active booking', () =>
  setDoc(doc(C, 'slot_locks', 'B_2026-10-01_08:00 AM'), { bookingId: b2 }));
await must('SLOT: read one lock', () => getDoc(doc(C, 'slot_locks', 'B_2026-10-01_08:00 AM')));
await mustNot('SLOT: list all locks', () => getDocs(collection(C, 'slot_locks')));
{
  // Two farmers submit the same free slot at the same moment.
  const race = await Promise.allSettled([
    book(A, { bookingTime: '03:00 PM' }),
    book(C, { farmerId: 'C', bookingTime: '03:00 PM' }),
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
  const race = await Promise.allSettled(racers.map((db, i) => book(db, { farmerId: `F${i}`, bookingTime: '04:00 PM' })));
  const winners = race.filter((r) => r.status === 'fulfilled').length;
  results.push({ pass: winners === 1 ? 'PASS' : '** FAIL **', expect: '1 winner', outcome: `${winners} winner(s)`, name: 'SLOT: 10-way booking race' });
}

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
