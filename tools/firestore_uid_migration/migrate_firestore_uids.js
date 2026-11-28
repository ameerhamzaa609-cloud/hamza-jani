/**
 * One-time Admin SDK backfill for legacy Hamza Jani Firestore documents.
 *
 * Safety: dry-run is the default. Run with --apply only after reviewing the
 * preview. Uses Application Default Credentials; never commit service keys.
 *
 * Setup (from this folder):
 *   npm install
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\\secure\\service-account.json
 *   node migrate_firestore_uids.js
 *   node migrate_firestore_uids.js --apply
 */
const admin = require('firebase-admin');

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();
const apply = process.argv.includes('--apply');

function key(value) {
  return String(value ?? '').trim().toLowerCase();
}

async function main() {
  const usersSnap = await db.collection('users').get();
  const identity = new Map();
  const ambiguous = new Set();

  function addIdentity(value, uid) {
    const k = key(value);
    if (!k) return;
    if (identity.has(k) && identity.get(k) !== uid) {
      identity.delete(k);
      ambiguous.add(k);
    } else if (!ambiguous.has(k)) {
      identity.set(k, uid);
    }
  }

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    if (typeof data.uid !== 'string' || !data.uid) continue;
    addIdentity(doc.id, data.uid);
    addIdentity(data.username, data.uid);
    addIdentity(data.phoneNumber, data.uid);
  }

  const resolve = (value) => {
    const k = key(value);
    return k && !ambiguous.has(k) ? identity.get(k) : undefined;
  };

  let planned = 0;
  let skipped = 0;
  async function update(ref, existing, patch, label) {
    const changed = Object.entries(patch).some(([k, v]) => {
      const old = existing[k];
      return JSON.stringify(old ?? null) !== JSON.stringify(v ?? null);
    });
    if (!changed) return;
    planned++;
    console.log((apply ? 'UPDATE ' : 'DRY-RUN ') + label, patch);
    if (apply) await ref.set(patch, { merge: true });
  }

  const chats = await db.collection('chats').get();
  for (const doc of chats.docs) {
    const data = doc.data();
    const names = Array.isArray(data.participants) ? data.participants : [];
    const uids = [...new Set(names.map(resolve).filter(Boolean))];
    if (names.length !== 2 || uids.length !== 2) {
      skipped++;
      console.warn('SKIP chat (participant identity unresolved):', doc.id, names);
      continue;
    }
    if (Array.isArray(data.participantUids) &&
        data.participantUids.some((uid) => !uids.includes(uid))) {
      skipped++;
      console.warn('SKIP chat (existing UID mismatch):', doc.id);
      continue;
    }
    await update(doc.ref, data, { participantUids: uids }, 'chat/' + doc.id);

    const messages = await doc.ref.collection('messages').get();
    for (const message of messages.docs) {
      const m = message.data();
      const senderUid = m.senderUid || resolve(m.from);
      const recipientUid = m.recipientUid || resolve(m.to);
      if (!senderUid || !recipientUid || !uids.includes(senderUid) ||
          !uids.includes(recipientUid)) {
        skipped++;
        console.warn('SKIP message (identity unresolved):', doc.id, message.id);
        continue;
      }
      await update(message.ref, m, {
        senderUid,
        recipientUid,
      }, 'chat/' + doc.id + '/messages/' + message.id);
    }
  }

  const calls = await db.collection('calls').get();
  for (const doc of calls.docs) {
    const data = doc.data();
    const names = Array.isArray(data.participants)
      ? data.participants
      : [data.caller, data.callee];
    const uids = [...new Set(names.map(resolve).filter(Boolean))];
    const callerUid = data.callerUid || resolve(data.caller);
    const calleeUid = data.calleeUid || resolve(data.callee);
    if (uids.length !== 2 || !callerUid || !calleeUid ||
        !uids.includes(callerUid) || !uids.includes(calleeUid)) {
      skipped++;
      console.warn('SKIP call (participant identity unresolved):', doc.id, names);
      continue;
    }
    if (Array.isArray(data.participantUids) &&
        data.participantUids.some((uid) => !uids.includes(uid))) {
      skipped++;
      console.warn('SKIP call (existing UID mismatch):', doc.id);
      continue;
    }
    await update(doc.ref, data, {
      callerUid,
      calleeUid,
      participantUids: uids,
    }, 'call/' + doc.id);
  }

  // Remove E.164 phone numbers from publicly readable profile usernames
  // when the owner has disabled phone discovery. Private users records retain
  // the verified number; public profile cards use a non-phone UID handle.
  const publicProfiles = await db.collection('publicProfiles').get();
  let hiddenPhoneProfiles = 0;
  for (const profile of publicProfiles.docs) {
    const data = profile.data();
    if (data.discoverableByPhone === true) continue;
    const privateRecord = usersSnap.docs.find((u) => u.data().uid === profile.id);
    const privateData = privateRecord ? privateRecord.data() : {};
    const identity = String(data.username || privateData.phoneNumber || privateRecord?.id || '');
    if (!/^\\+[1-9][0-9]{7,14}$/.test(identity)) continue;
    const patch = {
      username: 'user_' + profile.id.substring(0, 8),
      phoneNumber: admin.firestore.FieldValue.delete(),
      phoneSearch: admin.firestore.FieldValue.delete(),
    };
    planned++;
    hiddenPhoneProfiles++;
    console.log((apply ? 'UPDATE ' : 'DRY-RUN ') + 'publicProfile/' + profile.id,
      { username: patch.username, phoneNumber: '[DELETE]', phoneSearch: '[DELETE]' });
    if (apply) await profile.ref.set(patch, { merge: true });
  }

  const statuses = await db.collection('statuses').get();
  for (const doc of statuses.docs) {
    const data = doc.data();
    const ownerUid = data.ownerUid || resolve(data.owner);
    if (!ownerUid) {
      skipped++;
      console.warn('SKIP status (owner identity unresolved):', doc.id, data.owner);
      continue;
    }
    await update(doc.ref, data, { ownerUid }, 'status/' + doc.id);
  }

  console.log(JSON.stringify({
    mode: apply ? 'APPLY' : 'DRY-RUN',
    usersScanned: usersSnap.size,
    chatsScanned: chats.size,
    callsScanned: calls.size,
    statusesScanned: statuses.size,
    publicProfilesScanned: publicProfiles.size,
    hiddenPhoneProfilesPlanned: hiddenPhoneProfiles,
    updatesPlanned: planned,
    unresolvedOrConflictingDocuments: skipped,
    ambiguousIdentityKeys: ambiguous.size,
  }, null, 2));
  if (!apply) {
    console.log('No data was changed. Review this report, then rerun with --apply to write the UID fields.');
  }
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
