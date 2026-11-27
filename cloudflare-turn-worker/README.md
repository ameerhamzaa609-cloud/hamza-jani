# Hamza Jani TURN Worker

This Worker validates a signed-in Firebase user and issues one-hour Cloudflare
Realtime TURN credentials. The Cloudflare API token remains server-side.

## Configure Worker variables/secrets

- `FIREBASE_WEB_API_KEY`: Firebase project's Web API key.
- `TURN_KEY_ID`: Cloudflare Realtime TURN key ID.
- `TURN_API_TOKEN`: Cloudflare API token allowed to generate TURN credentials (store as a secret).

Deploy `worker.js` as a Cloudflare Worker. Never commit the TURN API token.

## Build Android with the deployed Worker URL

```sh
flutter build apk --release --dart-define=TURN_CONFIG_URL=https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev
```

The app sends the current Firebase ID token to the Worker. If the Worker URL is
not configured or credentials cannot be obtained, the app falls back to STUN-only;
calls may still fail on restrictive networks until TURN is active.
