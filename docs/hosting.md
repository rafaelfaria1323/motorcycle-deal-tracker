# Hosting the web app

The app is built and published to Cloudflare Pages by
`.github/workflows/deploy-web.yml` on every merge to `main` that touches
`app/` or adds a migration, and from the Actions tab ("Deploy web app" →
"Run workflow"). Tests must pass before anything is published.

Database migrations are applied by the same workflow, before the app: the
`migrate` job asks Supabase which migrations it is missing; if any, it tests
every migration and SQL test again on an empty Postgres, then applies them
with `tool/apply_migrations.sh` (psql through the Session pooler, each
migration in one transaction with its record in the same history table
`supabase db push` uses). It asks the database rather than looking at what
the merge added because a deploy waiting in the queue is replaced by the
next merge's: the merge that added a migration may never get its own run.
With nothing missing it skips to the app. A failure stops the app deploy (fix it with a new migration; "Run
workflow" applies whatever is missing). `make db-push` still works by hand.

Every pull request that changes `app/` also gets a preview
(`preview-web.yml`): the same build published to
`https://pr-<number>.motorcycle-deal-tracker.pages.dev`, linked in a
comment on the PR, to try on the iPhone before merging. It uses the real
database; the PR's migrations are applied only when it is merged. Each
push removes the PR's older builds, and closing or merging the PR removes
its preview (`tool/pages_previews.py`). Previews cost nothing.

## One-time setup

1. **Cloudflare account** (free plan) at dash.cloudflare.com.
2. **Account ID**: Workers & Pages → Overview, right-hand column
   ("Account ID").
3. **API token**: My Profile → API Tokens → Create Token → "Create Custom
   Token", permission *Account · Cloudflare Pages · Edit*, limited to your
   account.
4. **GitHub secrets** (repo → Settings → Secrets and variables → Actions):
   - `CLOUDFLARE_ACCOUNT_ID`
   - `CLOUDFLARE_API_TOKEN`
   - `SUPABASE_PUBLISHABLE_KEY` — Supabase dashboard → Project Settings →
     API Keys, the publishable key (the same value as in `app/env/dev.json`).
   - `SUPABASE_URL` already exists for the collector.
   - `SUPABASE_DB_URL` and `SUPABASE_DB_PASSWORD` — for the migrations:
     the URL is Supabase dashboard → Connect → "Session pooler" connection
     string, copied **exactly as shown, `[YOUR-PASSWORD]` included**
     (GitHub's runners have no IPv6, so not the direct one); the password
     is the database password as you type it (Project Settings → Database;
     reset it there if unknown). The workflow puts the password into the
     URL and encodes it (`tool/db_url.py`), so characters such as `! * ? @
     #` need nothing special. A URL with the password already in it, encoded,
     also works without `SUPABASE_DB_PASSWORD`.
5. Run "Deploy web app" once. The first run creates the Pages project
   `motorcycle-deal-tracker`; the log ends with the address
   (`https://motorcycle-deal-tracker.pages.dev`, or with a suffix if the
   name was taken).

## Scheduled runs (Supabase starts them)

GitHub's own scheduler never started `collect.yml`, so Supabase does:
pg_cron jobs `collect-listings` (at 00:40, 08:40 and every 2 hours from
12:40 to 20:40, Lisbon time) and
`weekly-summary` (Mondays 07:52 UTC; each account's summary to its devices)
call GitHub's "Run workflow" API.
They need one token, created once:

1. GitHub → Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate new token. Repository access: *Only
   select repositories* → `motorcycle-deal-tracker`. Permissions:
   *Actions: Read and write* (nothing else). Pick the longest expiry you
   are comfortable with and note the date.
2. Supabase → SQL Editor, run (with your token in place of the dots):
   `select vault.create_secret('github_pat_...', 'github_dispatch_token');`
3. Check it: `select public.dispatch_workflow('collect.yml');` starts a
   run (Actions tab), and
   `select status_code from net._http_response order by created desc limit 1;`
   shows 204.

When the token expires, make a new one and replace it:
`select vault.update_secret(id, 'github_pat_...') from vault.secrets where name = 'github_dispatch_token';`.
The app's "Mais" shows a warning when no run happened recently.
Admins' "Recolher agora" in Mais uses the same token (an expired one
shows "O GitHub recusou o pedido"). Mais › "Estado da recolha" shows the
token's expiry date, and from 14 days before it Telegram reminds you once
a day (pg_cron `github-token-check`).

### Space: old listings of models nobody follows

The free plan allows 500 MB. Every night (03:37 UTC) the pg_cron job
`prune-unfollowed-listings` checks the database's size; only from 400 MB
does it delete listings of models no account follows that left the sites
30+ days ago (never favourites, alerted ones or the earlier ad of a
relist), and says so on Telegram. Postgres reuses the freed space without
shrinking the file, so the size shown in "Estado da recolha" stops growing
rather than falling.

### Warning on Telegram when no run starts

Every hour (minute 20) the pg_cron job `collection-watchdog` checks the
last recorded run. When none started in 9 hours (an expired token, for
example) it sends a Telegram message, again once a day while it lasts,
and "As recolhas de anúncios voltaram a começar" after the next run. It
needs the bot's token and chat id in the Vault too (the same values as the
`TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` repository secrets), saved once
in the SQL Editor:

```sql
select vault.create_secret('<bot token>', 'telegram_bot_token');
select vault.create_secret('<chat id>', 'telegram_chat_id');
```

Check it with `select public.send_telegram('Teste');` (the message arrives
on the phone). If pg_cron itself stops, this check stops too; the app's
warning is then the only sign.

## On the iPhone

Open the address in Safari → Share → "Adicionar ao ecrã principal". The app
opens full screen with its own icon. Every deploy is picked up the next time
it opens.

The home-screen app keeps its own storage, separate from Safari, so it starts
as a new anonymous user: sign in from the account sheet to see your saved
searches.

## Android app

Every deploy also builds the Android app (`deploy-web.yml`, job
`android`) and puts it on the GitHub release `android`, replacing the
previous one:
`https://github.com/rafaelfaria1323/motorcycle-deal-tracker/releases/download/android/motorcycle-deal-tracker.apk`.
On an Android phone, Mais shows "App Android". In Chrome it downloads the
app the first time; Android asks once to allow installs from Chrome. After
that the app updates itself: Mais › "App Android" says "Há uma versão
nova" when a deploy published a newer build (it reads `android.json`,
published next to the APK), and a tap downloads it inside the app and
opens Android's installer, with no browser. The first time Android asks to
allow installs from Deal Tracker (Definições › "Instalar apps
desconhecidas"); after that only its "Atualizar?" confirmation, which
Android always shows for apps not from the Play Store. The update installs
over the app: the session and data stay.

It needs a signing key, made once and kept: every version must be signed
with the same one, or Android refuses to install it over the app (losing
the key means uninstalling the app once). On the Mac, in Terminal:

```
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem \
  -days 10000 -subj "/CN=Deal Tracker"
openssl pkcs12 -export -inkey key.pem -in cert.pem -name upload \
  -out deal-tracker-android.p12      # asks for a password: remember it
rm key.pem cert.pem
base64 -i deal-tracker-android.p12 | pbcopy
```

Then in GitHub › Settings › Secrets and variables › Actions add
`ANDROID_KEYSTORE_BASE64` (paste) and `ANDROID_KEYSTORE_PASSWORD` (the
password), keep `deal-tracker-android.p12` and its password somewhere safe
(e.g. a password manager), and run "Deploy web app" once (Actions › Run
workflow) for the first APK. Without the secrets the job only warns and the
tile stays hidden.

The app's shared links (invites, "Partilhar a app") point to
`https://motorcycle-deal-tracker.pages.dev`; if Cloudflare gave the
project another address, set the repository variable `WEB_APP_URL` to it.
### Notifications in the Android app

Web Push lives in browsers, so the Android app gets its notifications
through Firebase Cloud Messaging (free, no usage limits for this). Set up
once:

1. [console.firebase.google.com](https://console.firebase.google.com) →
   "Criar projeto" / "Create a project" (any name, e.g. `deal-tracker`;
   Google Analytics not needed).
2. In the project: add an app → Android. Package name
   `io.github.rafaelfaria1323.motorcycle_deal_tracker` (exactly), nickname
   "Deal Tracker"; skip the SHA-1 and the SDK steps. Download
   `google-services.json`.
3. GitHub › Settings › Secrets and variables › Actions → new secret
   `FIREBASE_ANDROID_CONFIG`: paste the whole content of
   `google-services.json`.
4. Firebase › Project settings (gear) › Service accounts → "Generate new
   private key". Paste the whole downloaded JSON as the secret
   `FIREBASE_SERVICE_ACCOUNT`, then delete the file (it lets anyone send
   notifications as the project). Cloud Messaging's API (V1) is on by
   default for new projects (Project settings › Cloud Messaging).
5. Run "Deploy web app" (or merge anything touching `app/`) for an APK with
   Firebase in it, update the app from Mais › "App Android", then turn on
   Mais › "Notificações neste aparelho" in the app (Android 13+ asks to
   allow them).

The collector (collect, weekly summary and test workflows) sends to the
app's devices with the service account; without the secret those devices
get nothing, and an APK built without `FIREBASE_ANDROID_CONFIG` says it
receives no notifications (keep them on in Chrome then).

## Privacy

The address is public: anyone who has it can browse the listings (as on the
listing sites themselves) but saved searches and alerts stay per user under
row-level security. Cloudflare Access (free for up to 50 users) can put an
email login in front of the whole site if that is ever needed.

The API keys (publishable key) can only read, apart from the app's own
writes on the caller's rows (roadmap S.1); `app/web/_headers` makes Pages
send HSTS, `nosniff`, a no-framing policy, a referrer policy and a
permissions policy (no camera, microphone, location or payment).

## Replacing secrets

Replace a secret at once if it may have leaked (pasted somewhere, a lost
laptop, a log that showed it), and otherwise once a year, in January,
together with the IUC check. The GitHub dispatch token has its own
expiry; Telegram and "Estado da recolha" warn 14 days before it.

Rules for every one: make the new value first, put it everywhere it is
used, check that it works, and only then revoke the old one. Repository
secrets are in GitHub › Settings › Secrets and variables › Actions;
Vault secrets are replaced in Supabase › SQL Editor with
`select vault.update_secret(id, '<new value>') from vault.secrets where name = '<name>';`.
Never paste a value in a chat, an issue or a commit; on the Mac, also
update `collector/.env` if you run the collector there.

| Secret | Where it is used | How to replace it |
|---|---|---|
| GitHub dispatch token | Vault `github_dispatch_token` | See "Scheduled runs" above: new fine-grained token, `vault.update_secret`, check with `select public.dispatch_workflow('collect.yml');` (or "Recolher agora" in Mais), then delete the old token in GitHub. |
| Supabase secret key | Repository secret `SUPABASE_SERVICE_ROLE_KEY`; the collector copies it into Vault `service_role_key` on each run (invites use it) | Supabase › Project Settings › API Keys › Secret keys: create a new one, put it in the repository secret, run "Collect listings" (Actions › Run workflow), check the run is green and an invite can be made, then delete the old key. A project still on the legacy `service_role` JWT can't replace it alone (a new JWT secret also changes the publishable key and signs everyone out): move to the new API keys first (the same page). |
| Database password | Repository secret `SUPABASE_DB_PASSWORD` (migrations) | Supabase › Project Settings › Database › Reset database password, then the repository secret. Check with "Deploy web app" › Run workflow (the `migrate` job connects even when nothing is missing). |
| Telegram bot token | Repository secret `TELEGRAM_BOT_TOKEN` and Vault `telegram_bot_token` | In Telegram, @BotFather › `/revoke` › the bot: the old token stops at once, so put the new one in both places straight away. Check with `select public.send_telegram('Teste');`. The chat id never changes. |
| Cloudflare API token | Repository secret `CLOUDFLARE_API_TOKEN` | Cloudflare › My Profile › API Tokens › the token › "Roll", then the repository secret; check with "Deploy web app" › Run workflow. |
| Firebase service account | Repository secret `FIREBASE_SERVICE_ACCOUNT` | Firebase › Project settings › Service accounts › "Generate new private key", paste it as the secret, delete the file; check with "Enviar notificação de teste" in the Android app; then delete the old key in Google Cloud › IAM › Service accounts › the account › Keys. `FIREBASE_ANDROID_CONFIG` is not a secret worth replacing (it is inside every APK). |
| Claude token | Repository secret `CLAUDE_CODE_OAUTH_TOKEN` (backlog passes) | `claude setup-token` on the Mac, paste it as the secret (these tokens last a year, so this one also has its own date). |

Not replaced:

- **Android signing key** (`ANDROID_KEYSTORE_BASE64`, `..._PASSWORD`):
  never; a new key means everyone uninstalls the app once. Kept in a
  password manager and the repository secrets only. A leak alone does
  not reach a phone: the app installs updates only from this
  repository's release.
- **Web Push key pair** (`push_config`, Vault `vapid_private_key`): made
  by the collector, never typed anywhere. Only if it leaked: in the SQL
  Editor `delete from public.push_config where true;`,
  `delete from vault.secrets where name = 'vapid_private_key';` and
  `delete from public.push_subscriptions where endpoint not like 'fcm:%';`;
  the next collection makes a new pair, and each browser or iPhone turns
  on Mais › "Notificações neste aparelho" again.
- **Publishable key** (`SUPABASE_PUBLISHABLE_KEY`): public by design,
  inside the app; row-level security and the grants protect the data.
