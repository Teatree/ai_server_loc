# AI Server Remote Gateway — Render setup

Prepared September 14, 2026. This is a separate project at
`C:\AI\AI-Server-Remote-Gateway`. Your existing control center and AI services are unchanged.
The connector runs on Windows, beside the existing dashboard. Ubuntu runs the AI workloads.

## What is ready

The gateway supports ComfyUI, Unsloth, llama.cpp, Ollama, InvokeAI, Open WebUI, and OpenClaw equally.
It preserves each app's root URL, HTTP APIs, uploads, downloads, streaming, and WebSockets.
The dashboard reuses your existing controls through an allowlisted local API.
Terminal, Windows Remote Desktop, shutdown, and the Windows OpenClaw launcher are local-only.
Opening a remote app does not start it. Start/Stop/Restart remain explicit actions.

Mock security and transport tests are included and run during every Render build.
Real GitHub login, Render deployment, and full native-app compatibility require the setup below.
OpenClaw's public-origin/device-pairing check is explicitly deferred; see step 8.
Nothing here installs, restarts, or changes an AI app automatically.

## Free Render layout

The ready-made `render.yaml` creates EIGHT free web services: dashboard plus seven app addresses.
This isolates app cookies/scripts and avoids rewriting fragile application URL paths.
One OAuth registration supports all eight exact callback URLs.

**750 free hours are shared across the entire Render workspace, not per service.**
Keeping eight services connected continuously can consume the allowance in about 94 hours
(just under four days). The connector's keepalives may keep services awake.
Close the connector when it is not needed, or connect a selected subset with `-Apps` below.
Even disconnected services may remain awake for Render's 15-minute idle period.
The free allowance does not promise unlimited bandwidth or uninterrupted availability.
No paid plan or database is required. [Render's current free limits](https://render.com/docs/free).

If you already own a domain, one Free compute service can serve all eight isolated subdomains.
That optional configuration can incur custom-domain charges; it is explained at the end.
The prepared onrender.com configuration requires no custom domains.

## 1. Review the prepared files

Open PowerShell:

```powershell
Set-Location C:\AI\AI-Server-Remote-Gateway
.\Validate.ps1
```

The prepared name prefix is `garry-ai-remote-0913`. `render.yaml` and `callback-urls.txt`
contain public configuration. The `private` folder contains the connector credentials and
local machine addresses. **Never upload `private`, `.venv`, or your old control-center folder.**
`private` has restricted Windows permissions and is excluded by `.gitignore`.

## 2. Git setup is prepared in your existing repository

Use repository **Teatree/ai_server_loc**, deployment branch **codex/render-gateway**.
This dedicated branch contains the gateway at its root. The existing `master` branch
retains your other project files. Render must use `codex/render-gateway` for both the
Blueprint and all eight services; each service's branch is explicit in `render.yaml`.

Local Git checkout: `C:\AI\AI-Server-Remote-Gateway`. To inspect its status:

```powershell
Set-Location C:\AI\AI-Server-Remote-Gateway
git status --short
git log -1 --oneline
```

No repository creation, merge into `master`, or further Git commands are needed for deployment.
The `private/`, `.venv/`, `.env`, and connector JSON files are excluded from Git.
Do not change repository visibility or upload those files to make deployment work.

## 3. Create the GitHub sign-in application

1. Enable two-factor authentication on your GitHub account. This gateway checks for it at login.
2. Open GitHub Settings → Developer settings → OAuth Apps → New OAuth App.
3. Name it `Private AI Gateway`.
4. Set Homepage URL to `https://garry-ai-remote-0913-dashboard.onrender.com`.
5. Add all EIGHT URLs from `callback-urls.txt` as exact authorization callback URLs.
   Use **Add callback URL** for each. Leave wildcard matching and device flow disabled.
6. Register the app; keep the **Client ID** and generate a **Client Secret**.
7. Find your numeric account ID with this read-only command:

```powershell
(Invoke-RestMethod https://api.github.com/users/Teatree).id
```

Use that number, not your username, for `GITHUB_OWNER_ID`. No repository scopes are requested
by this login. The gateway requests `read:user` to verify identity and two-factor status.
Your browser may already be signed in to GitHub; the gateway still validates the returned identity.
[GitHub OAuth registration instructions](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app).

## 4. Add the shared login settings in Render

Sign in at Render and enable MFA for the Render account too. Connect the existing GitHub
repository `Teatree/ai_server_loc` when Render requests access. In **Environment Groups**, create
`garry-ai-remote-0913-login` with these three variables:

| Variable | Value |
|---|---|
| `GITHUB_CLIENT_ID` | OAuth Client ID from step 3 |
| `GITHUB_CLIENT_SECRET` | OAuth Client Secret from step 3 |
| `GITHUB_OWNER_ID` | Your numeric GitHub account ID |

Save the environment group **before** creating the Blueprint. The secret stays in Render's
environment settings; do not put it in the repository or send it in chat.
For strictly free usage, avoid adding a payment method: Render suspends free services at
the bandwidth limit if none is on file; with a payment method, overage can be billed.

## 5. Deploy the Blueprint

1. In Render choose **New → Blueprint** and select **Teatree/ai_server_loc**.
2. Select branch **codex/render-gateway** and Blueprint Path **render.yaml**.
   Leave Root Directory blank: this branch has the gateway at its root.
3. Review the plan: eight web services, each explicitly **Free**, and no databases or disks.
4. Render asks for `CONNECTOR_TOKEN` for each service. For each matching service, open
   `private\SERVICE-NAME.env` locally and copy only the value after `CONNECTOR_TOKEN=`.
   Each service has its own token. Do not interchange them or choose a new value in Render.
5. Apply/deploy the Blueprint. The build installs pinned dependencies and runs mock tests.
6. Wait for the services to become Live. This does not start any local AI workload.
7. In Blueprint settings turn **Auto Sync** off. Service auto-deploy is already disabled.
   Updates can then be reviewed and deployed deliberately.

Confirm each service's actual Render URL matches `callback-urls.txt` without the callback suffix.
If Render adds a suffix because a name is taken, correct the affected URLs in `GATEWAY_ORIGINS`,
all services' `APP_LINKS`, `private\connector.json`, and the GitHub callback list before connecting.
Also update `render.yaml` so a later manual sync does not restore the old addresses.
Never work around a URL mismatch by allowing arbitrary Host headers or wildcard OAuth callbacks.
[Render Blueprint reference](https://render.com/docs/blueprint-spec).

## 6. Start the existing local dashboard, then the connector

Open your normal **AI Server Control Center** desktop shortcut. This provides the existing
loopback control API. Do not click an app's Start, Stop, Restart, or old OpenClaw Open button
while jobs must remain untouched. Starting this connector does not launch the dashboard for you.

In a separate PowerShell window:

```powershell
Set-Location C:\AI\AI-Server-Remote-Gateway
.\Start-Connector.ps1
```

It should print `Connected` for the configured apps. Keep this window open.
To save shared free hours, you can instead connect a chosen set (all apps support this equally):

```powershell
.\Start-Connector.ps1 -Apps "dashboard,comfy,unsloth,llm,ollama,invoke,openwebui,openclaw"
```

Remove IDs you do not currently need. Stop the existing connector before starting a different set.
No automatic scheduled task or background startup was installed.
Windows and Ubuntu must remain on; this implementation also needs their existing private link.
The connector opens one additional loopback SSH forward for OpenClaw only when it is accessed.
It does not start OpenClaw or Ollama, and removes only its own SSH forward on shutdown.

## 7. Sign in remotely and check without changing workloads

Open `https://garry-ai-remote-0913-dashboard.onrender.com` from your phone or another browser.
Sign in with the approved GitHub account. Check live status/logs first.
Each app's **Open** link leads to its separate protected address; sign in there as needed.
Unsloth, Open WebUI, and OpenClaw retain their own application login/pairing requirements.
Keep using the credentials you already use locally. No app password was reset.

The Windows-specific buttons show a local-only popup. Their backend routes are rejected too.
Start/Stop/Restart asks for confirmation because the existing workload controller may stop
another GPU app. Do not test those actions while a job must remain running.
Ollama's Open API link displays JSON; use its Chat link to open Open WebUI.
Visit `/_gateway` on any app address to sign out of that app and close its active connections.
To cut **all** remote access immediately, press Ctrl+C in the Windows connector window.

## 8. Separate app-compatibility check when you are ready

**Do not change/restart an app during your current jobs.** The gateway transport has been
tested against mocks, not by running training, generation, or agent actions on your machine.
The read-only OpenClaw check found `bind: loopback`, token authentication enabled, and
an empty `gateway.controlUi.allowedOrigins` list. Its public browser origin may be rejected.

When you arrange a safe test window:

1. Back up `~/.openclaw/openclaw.json` on Ubuntu before editing anything.
2. Add `https://garry-ai-remote-0913-openclaw.onrender.com` to
   `gateway.controlUi.allowedOrigins`, preserving any existing allowed origins.
   Preserve/add the exact localhost origins you use locally so existing local access still works.
3. Keep token authentication, loopback binding, and device authentication enabled.
   Do not enable insecure-auth, Host-header fallback, or disable-device-auth flags.
4. Use the installed OpenClaw version's supported reload/restart procedure only when safe.
5. Open its protected remote page, enter your existing gateway token in the native connection
   settings, and approve the new browser device locally if OpenClaw requests pairing.
6. Run `openclaw security audit` locally and review any proxy/origin findings.
   Trust only the actual loopback connector if proxy configuration is needed; never trust all proxies.

For the other apps, open the actual interfaces and verify their existing login, streaming,
and upload flows. If an app rejects its new origin, configure only that exact app URL using its
supported setting in the same safe test window. Do not blanket-disable CORS/authentication.
No passwords, gateway tokens, allowed origins, or app services were changed by this implementation.

## Troubleshooting and recovery

- `401`: open `/_gateway/login` on that app address. A restart discards gateway sessions.
- `403` at login: check numeric GitHub owner ID and GitHub MFA. Other accounts are intentionally rejected.
- `421`: the actual hostname differs from `GATEWAY_ORIGINS`; fix the exact mapping.
- `503 Local connector offline`: run the connector for that app. Commands are not queued.
- `502`: check the app is already running and its native login/origin rules. Verify local access first.
- SSH-forward failure: check existing passwordless SSH and that local port 32148 is unused.
  The connector refuses unknown SSH host keys and never kills an existing listener.
- Render cold starts can take about a minute. The connector reconnects with backoff; it never retries actions.
- After a failed mutation, check actual job/service state before retrying. It may have executed before disconnect.
- To revoke credentials, stop the connector, rotate the affected token in its local JSON and Render,
  and redeploy that service to close existing connections. Do not rerun setup over existing secrets.
- Security updates: review pinned dependency updates, run `Validate.ps1`, then manually deploy.

## Optional: one Free compute service with your own domain

Use this only if you own a domain and can edit its DNS. Each app still needs its own hostname,
for example `dashboard.ai.example.com`, `unsloth.ai.example.com`, and so on.
This is **not guaranteed to be entirely free**: Render's Hobby workspace includes two
custom domains and charges $0.25/month for each additional domain. Eight explicit domains
can therefore cost $1.50/month, plus your domain registration, assuming no other domains.
See [Render's custom-domain limits](https://render.com/docs/custom-domains).
Use a fresh copy of this source package without a `private` folder, then run:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe setup.py --prefix YOUR-UNIQUE-PREFIX --domain ai.example.com
```

The generator produces one service with eight custom domains, one connector token, and the same
eight OAuth callback URLs on those domains. Create `YOUR-UNIQUE-PREFIX-login` in Render and follow
the same deployment steps. Add/verify each generated custom domain in Render and create the DNS
records Render specifies. Do not substitute a wildcard that accepts unrelated hosts.
The default onrender.com address will serve only the minimal health endpoint unless explicitly mapped.
After switching, update native app allowed origins during a safe test window.

## Development and maintenance

- `gateway/server.py`: public routing; `security.py` and `oauth.py`: access control.
- `gateway/relay.py`, `transfer.py`: authenticated streaming transport.
- `gateway/connector.py`, `upstream.py`: local outbound connection and app forwarding.
- `gateway/policy.py`: shared dashboard route restrictions.
- `web/`: independent snapshot of the existing dashboard, with remote-only safeguards.
- `setup.py`: local configuration generator; never contacts Ubuntu or Render.
- `tests/`: mock transport, authentication, lifecycle, and frontend checks.

The local `.venv` was created only inside this new folder. No global Python installation or
Ubuntu package environment was modified. No Godot story files or PRD records were edited.
The normal desktop dashboard continues to use its original files.
