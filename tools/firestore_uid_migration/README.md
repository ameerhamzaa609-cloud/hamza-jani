# Firestore UID migration (admin-only)

This migration adds immutable Firebase Authentication UIDs to legacy Hamza Jani
chat, message, call, and status documents so the UID-based Firestore rules can
authorize the correct participants.

## Safety

- The script is **dry-run by default**. It does not write unless `--apply` is supplied.
- Back up Firestore before applying.
- Review the dry-run output. Any unresolved or conflicting document must be
  investigated; do not deploy the UID-based rules while required records remain
  unmigrated.
- Run this only with a trusted Firebase Admin service account. Never put the
  service-account JSON in this repository or share it in chat.
- The Admin SDK bypasses Firestore rules. Keep the credential private and remove
  it from the machine when finished.

## Windows PowerShell

1. Install Node.js 18 or newer.
2. In this folder, run:

   ```powershell
   npm install
   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\secure\hamza-jani-admin.json"
   npm run dry-run
   ```

3. Review the report and unresolved records. Make a Firestore backup.
4. Only after review, apply the migration:

   ```powershell
   npm run apply
   ```

5. Run `npm run dry-run` again. It should report no further UID updates
   (unresolved records still need investigation).

## Collections handled

- `chats/{chatId}`: maps the two legacy participant names to
  `participantUids`.
- `chats/{chatId}/messages/{messageId}`: fills `senderUid` and
  `recipientUid` from the legacy `from` and `to` names.
- `calls/{callId}`: fills `callerUid`, `calleeUid`, and
  `participantUids`.
- `statuses/{statusId}`: fills `ownerUid`.

The mapping is based on the existing `users` collection's `uid`,
`username`, and `phoneNumber` fields. Ambiguous identities are not guessed;
affected records are skipped and reported.

This script does not deploy Firestore rules, delete data, change user accounts,
or change app binaries.
