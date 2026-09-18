# CubeFore AI assistant

An upgrade of the existing Flutter chatbot. The local transaction engine, income/expense/purchase flows, restore actions, voice input, and horizontally scrollable quick options remain available without an AI connection.

## Experience

- Theme-aware teal branding with system light/dark mode.
- Breathing assistant orb with typing, listening, thinking, generating, completion, and error states; respects reduced-motion settings.
- Welcome suggestions, animated message cards, multiline composer, and option navigation arrows.
- Selectable Markdown responses: headings, lists, tables, code blocks, and browser links. Tables and code scroll horizontally.
- AI-only regeneration and retry for failed AI responses. Transaction actions are never regenerated.
- Summary cards display only values from the existing local data service, labeled as sample data.

## Run locally

```powershell
flutter pub get
flutter run
```

Without an AI endpoint, the app uses the existing local engine. This repository has no production database, login, or persistent conversation storage. Its pre-existing sample totals and transactions are held in memory and reset when the app restarts. No fabricated trends or employee data are added.

## GPT Astra connection

The server adapter in `server/` uses `gpt-6-astra` via the OpenAI Responses API. The Flutter client never receives an OpenAI API key. Existing supported commands continue through the local engine; unmatched messages go to the AI endpoint when configured. Up to 24 recent messages and clearly labeled local sample summaries are sent for context.

### Local development only

Requires Node.js 22 or newer and an API key with access to GPT Astra.

1. Copy `server/.env.example` to `server/.env`.
2. Set `OPENAI_API_KEY` in that server-only file.
3. Set `ALLOW_LOCAL_DEMO=true` for local testing. This bypasses user authentication and forces loopback binding. Do not expose or tunnel this mode to the internet.
4. Start the server:

```powershell
cd server
npm start
```

5. From the repository root, start the web app with the matching fixed origin:

```powershell
flutter run -d chrome --web-port=7357 --dart-define=CUBEFORE_AI_ENDPOINT=http://localhost:8787/api/chat
```

The example server permits `http://localhost:7357` as its browser origin. Android release builds should use an HTTPS backend; global cleartext traffic is not enabled.

### Production integration required

- Deploy the server behind HTTPS. Set `ALLOW_LOCAL_DEMO=false`, server-only `OPENAI_API_KEY`, and the exact `ALLOWED_ORIGIN` for a web client.
- Set `AUTH_USERINFO_URL` to a trusted HTTPS endpoint that validates the application's user token, including issuer, audience, expiry, and app access, and returns a nonempty `sub` identifier. Requests fail closed without valid authentication.
- Construct `ChatbotAiService(endpoint: yourHttpsEndpoint, accessToken: yourSessionTokenProvider)` in the authenticated host application and inject it into `CubeforeAssistantScreen(aiService: service)`. The caller owns and disposes this injected service. Never embed a shared server token or OpenAI key in Dart or `--dart-define`.
- Replace demo context with server-authorized business data scoped to the verified user before using this for real business analysis. The included adapter treats all client context as unverified sample data and has no tools that can modify records.
- The included per-user rate and concurrency limits are in memory. Multi-instance deployment needs shared rate limits and application monitoring.
- Add durable history only through the host application's authenticated storage. The current session history remains in memory.

The server uses a 60-second generation deadline, bounded request sizes, sanitized errors, and explicit stream completion markers. Retry is user initiated. Interrupted responses are not recorded as completed answers. API access, billing, live streaming, and production authentication still require testing against your configured deployment.

Official model reference: https://developers.openai.com/api/docs/models/gpt-6-astra

## Verification

```powershell
flutter analyze --no-pub
flutter test
node --test server/server.test.mjs
flutter build web --no-pub
```

Tests cover transaction preservation, voice confirmation, small-screen option navigation, keyboard layout, rich responses in dark mode, streamed completion/retry/regeneration, proxy authentication, rate limits, and interrupted streams. Automated tests use mocks; they do not make paid OpenAI requests. Physical-device microphone testing remains necessary.
