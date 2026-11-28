const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, collection, addDoc } = require('firebase/firestore');

const projectId = 'demo-hamza-jani';
const rules = fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8');

async function main() {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });

  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/alice'), { uid: 'alice', username: 'alice' });
      await setDoc(doc(db, 'users/legacy-phone'), {
        username: '+971501234567',
        phoneNumber: '+971501234567',
      });
      await setDoc(doc(db, 'chats/alice-bob'), {
        participants: ['alice', 'bob'],
        participantUids: ['alice', 'bob'],
      });
      await setDoc(doc(db, 'calls/call-1'), {
        caller: 'alice',
        callee: 'bob',
        callerUid: 'alice',
        calleeUid: 'bob',
        participants: ['alice', 'bob'],
        participantUids: ['alice', 'bob'],
        status: 'calling',
      });
      await setDoc(doc(db, 'statuses/status-1'), {
        ownerUid: 'alice',
        owner: 'alice',
        expiresAt: new Date(Date.now() + 3600000),
      });
      await setDoc(doc(db, 'communities/community-1'), {
        createdByUid: 'alice',
        memberUids: ['alice'],
      });
    });

    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const outsider = env.authenticatedContext('outsider').firestore();
    const phoneUser = env.authenticatedContext('phone-user', {
      phone_number: '+971501234567',
    }).firestore();

    // Private account records: owner-only; verified legacy claim is one-time.
    await assertSucceeds(getDoc(doc(alice, 'users/alice')));
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertSucceeds(updateDoc(doc(phoneUser, 'users/legacy-phone'), { uid: 'phone-user' }));
    await assertFails(getDoc(doc(outsider, 'users/legacy-phone')));

    // Public profile cannot leak an E.164 phone in a hidden username or fields.
    await assertSucceeds(setDoc(doc(alice, 'publicProfiles/alice'), {
      uid: 'alice',
      username: 'user_alice12',
      displayName: 'Alice',
      discoverableByPhone: false,
    }));
    await assertFails(setDoc(doc(alice, 'publicProfiles/alice-hidden-phone'), {
      uid: 'alice',
      username: '+971501234567',
      discoverableByPhone: false,
    }));
    await assertFails(setDoc(doc(alice, 'publicProfiles/alice-hidden-fields'), {
      uid: 'alice',
      username: 'user_alice12',
      discoverableByPhone: false,
      phoneNumber: '+971501234567',
    }));

    // Chats and messages: only the two recorded UIDs can access them.
    await assertSucceeds(getDoc(doc(alice, 'chats/alice-bob')));
    await assertFails(getDoc(doc(outsider, 'chats/alice-bob')));
    await assertFails(updateDoc(doc(alice, 'chats/alice-bob'), {
      participantUids: ['alice', 'outsider'],
    }));
    await assertSucceeds(setDoc(doc(alice, 'chats/alice-bob/messages/message-1'), {
      senderUid: 'alice',
      recipientUid: 'bob',
      from: 'alice',
      to: 'bob',
      text: 'hello',
      type: 'text',
    }));
    await assertFails(setDoc(doc(alice, 'chats/alice-bob/messages/message-2'), {
      senderUid: 'bob',
      recipientUid: 'alice',
      text: 'spoofed sender',
    }));

    // Calls and ICE candidates are limited to call participants and true sender.
    await assertSucceeds(getDoc(doc(bob, 'calls/call-1')));
    await assertFails(getDoc(doc(outsider, 'calls/call-1')));
    await assertSucceeds(setDoc(doc(alice, 'calls/call-1/candidates/ice-1'), {
      fromUid: 'alice',
      candidate: 'candidate',
    }));
    await assertFails(setDoc(doc(alice, 'calls/call-1/candidates/ice-2'), {
      fromUid: 'bob',
      candidate: 'spoofed',
    }));

    // Status ownership and community membership are enforced.
    await assertSucceeds(setDoc(doc(alice, 'statuses/status-2'), { ownerUid: 'alice', text: 'hello' }));
    await assertFails(setDoc(doc(bob, 'statuses/status-3'), { ownerUid: 'alice', text: 'spoofed' }));
    await assertSucceeds(getDoc(doc(bob, 'statuses/status-1')));
    await assertSucceeds(getDoc(doc(alice, 'communities/community-1')));
    await assertFails(getDoc(doc(bob, 'communities/community-1')));

    console.log('PASS: Firestore security rules tests completed.');
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
