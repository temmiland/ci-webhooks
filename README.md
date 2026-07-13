# CI Webhooks

[![License](https://img.shields.io/github/license/temmiland/ci-webhooks)](./LICENSE.md)
[![Stars](https://img.shields.io/github/stars/temmiland/ci-webhooks?style=social)](https://github.com/temmiland/ci-webhooks/stargazers)

A containerized webhook system for automated CI/CD deployments based on the [adnanh/webhook](https://github.com/adnanh/webhook) server.

## 📖 Overview

This tool provides a complete Docker-based solution for automated deployment of Git repositories via webhooks. It uses Traefik as a reverse proxy and supports SSL termination with Let's Encrypt.

### Features

* 🐳 **Fully containerized** using Docker and Docker Compose
* 🔒 **Secure webhook authentication** via API keys
* 📊 **Deployment status tracking**
* 📝 **Detailed logs** for each deployment
* 🔄 **Automatic Git updates** with configurable branches
* 🚀 **Traefik integration** with SSL support
* ⚙️ **Template-based configuration** for multiple environments

## 🏗️ Architecture

The system is split into two containers with different trust levels:

* **`webhook`** (public, reachable via Traefik) — validates the API key and
  drops a job file into a shared queue. It holds no `docker.sock`, no SSH
  keys, and cannot read `repos.json`.
* **`deploy-agent`** (private, no published port, not on the `proxy`
  network) — watches the queue, updates the Git checkout and runs the
  repo's own deploy script (which typically runs `docker compose build/up`
  for that project). This is the only container with `docker.sock` and SSH
  access.

Both containers only share filesystem volumes (queue + status dir) — there is
no network path from `webhook` to `deploy-agent`, so compromising the public
HTTP endpoint alone does not grant Docker or Git access.

```sh
ci-webhooks/
├── docker-compose.yml         # Main configuration (webhook + deploy-agent)
├── Dockerfile                 # webhook (control plane) container
├── entrypoint.sh              # webhook container entrypoint script
├── start.sh                   # Startup script
├── ci/
│   ├── hooks.tpl.json         # Webhook configuration template
│   ├── trigger-deploy.sh      # Validates request, enqueues a deploy job
│   ├── status.sh              # Status checker (reads status dir)
│   ├── _deploy.sh             # Actual deployment worker (runs in deploy-agent)
│   └── agent/
│       ├── Dockerfile         # deploy-agent container
│       └── watch.sh           # Queue watcher, calls _deploy.sh per job
├── config/
│   ├── environment.tpl.json   # Environment variables template
│   └── repos.tpl.json         # Repository configuration template
└── startup/
    ├── Dockerfile             # Init container for configuration
    └── generate_env.sh        # .env file generator
```

## 🚀 Installation

### Prerequisites

* Docker & Docker Compose
* Running Traefik reverse proxy
* Git repository with SSH access

### 1. Clone the repository

```bash
git clone git@github.com:temmiland/ci-webhooks.git ci-webhooks
cd ci-webhooks
```

### 2. Create configuration

Copy and edit the template files:

```bash
cp config/environment.tpl.json config/environment.json
cp config/repos.tpl.json config/repos.json
```

### 3. Configure environment variables

Edit `config/environment.json`:

```json
{
  "network": "proxy",
  "ci_port": 9001,
  "ci_domain": "ci.yourdomain.com",
  "projects_root": "/srv/projects",
  "ci_key": "null"
}
```

If `ci_key` is `null`, it will be generated automatically.

### 4. Configure repositories

Edit `config/repos.json`:

```json
{
  "repos": [
    {
      "name": "my-app",
      "path": "/srv/projects/my-app",
      "branch": "main",
      "deploy_script": "deploy.sh"
    },
    {
      "name": "api-backend",
      "path": "/srv/projects/api-backend",
      "branch": "production",
      "deploy_script": "scripts/deploy.sh"
    }
  ]
}
```

### 5. Set up SSH access

Ensure SSH keys for Git access are available and mounted into the container:

```bash
# SSH keys should be available at:
~/.ssh/id_rsa
~/.ssh/id_rsa.pub
~/.gitconfig
```

### 6. Start the app

```bash
./start.sh
```

## ⚙️ Configuration

### Webhook Endpoints

The system provides two main endpoints:

The API key is sent as a header, not a URL parameter, so it never ends up in
server access logs, browser history, or `Referer` headers.

#### Trigger Deployment

```
POST https://ci.yourdomain.com/hooks/deploy-project?repo=REPO_NAME
X-Api-Key: YOUR_CI_KEY
```

This only enqueues the deploy — it returns immediately with `"status":"queued"`.
Poll the status endpoint to see when the `deploy-agent` container has picked it
up and finished.

#### Check Status

```
GET https://ci.yourdomain.com/hooks/status-project?repo=REPO_NAME
X-Api-Key: YOUR_CI_KEY
```

### Deployment Scripts

Each repository to be automatically updated requires a deployment script:

```bash
#!/bin/bash
# deploy.sh

echo "Starting deployment..."

# Install dependencies
npm install --production

# Build application
npm run build

# Restart services
docker-compose down
docker-compose up -d

echo "Deployment completed successfully"
```

Make the script executable:

```bash
chmod +x deploy.sh
```

The path can be defined in the `deploy_script` property in `repos.json`. Use a relative path from the repo root.

### Environment Variables

| Variable               | Description               | Example                      |
| ---------------------- | ------------------------- | ---------------------------- |
| `CI_DOMAIN`            | Domain for webhook server | `ci.example.com`             |
| `CI_PORT`              | Port for webhook server   | `9001`                       |
| `CI_KEY`               | Authentication key        | `secret-key-123`             |
| `PROJECTS_ROOT`        | Path to projects          | `/srv/projects`              |
| `TRAEFIK_NETWORK_NAME` | Traefik network           | `proxy`                      |

`PROJECTS_ROOT` is mounted into the `deploy-agent` container **at the same
path as on the host**, so the `path` entries in `repos.json` are plain host
paths. This also keeps bind mounts in your projects' own compose files
working (docker-outside-of-docker: the host daemon resolves those paths).

## 🔧 Usage

### Trigger Deployment

#### Using cURL

```bash
curl -X POST "https://ci.yourdomain.com/hooks/deploy-project?repo=my-app" \
  -H "X-Api-Key: YOUR_CI_KEY"
```

#### Using GitHub Actions

```yml
name: Deploy via Webhook

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Trigger deployment
        run: |
          DEPLOY_RESPONSE=$(curl -s -X POST "https://ci.yourdomain.com/hooks/deploy-project?repo=my-app" \
            -H "X-Api-Key: ${{ secrets.CI_KEY }}")
          echo "Deploy response: $DEPLOY_RESPONSE"

      - name: Wait for deployment status
        run: |
          MAX_RETRIES=60
          SLEEP=5
          COUNT=0

          while true; do
            STATUS_RESPONSE=$(curl -s -X GET "https://ci.yourdomain.com/hooks/status-project?repo=my-app" \
              -H "X-Api-Key: ${{ secrets.CI_KEY }}")

            if echo "$STATUS_RESPONSE" | jq empty >/dev/null 2>&1; then
              STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
              echo "Status: $STATUS_RESPONSE"
            else
              echo "⚠️ $STATUS_RESPONSE"
              STATUS="unknown"
            fi

            if [[ "$STATUS" == "success" ]]; then
              echo "✅ Deployment successful!"
              exit 0
            elif [[ "$STATUS" == "error" || "$STATUS" == "failed" ]]; then
              echo "❌ Deployment failed!"
              exit 1
            fi

            COUNT=$((COUNT+1))
            if [[ $COUNT -ge $MAX_RETRIES ]]; then
              echo "⏱ Timeout: Deployment took too long."
              exit 1
            fi

            sleep $SLEEP
          done
```

### Example Responses

**Deployment queued** (returned immediately by `deploy-project`; the
`deploy-agent` container has not necessarily picked it up yet):

```json
{
  "status": "queued",
  "message": "Deployment queued for my-app"
}
```

**Deployment running:**

```json
{
  "status": "running",
  "message": "Deployment is running"
}
```

**Deployment successful:**

```json
{
  "status": "success",
  "message": "Deployment successful"
}
```

**Deployment failed:**

```json
{
  "status": "error",
  "message": "Deployment failed"
}
```

### Viewing Logs

```bash
# HTTP-facing webhook server logs (request handling, auth)
docker logs ci-web

# Deploy-agent logs (queue processing, git, docker compose output)
docker logs ci-deploy-agent

# Deployment logs per repository per day (held by the deploy-agent container)
# — one file per calendar day, e.g. deploy_my-app_2026_07_13.log
docker exec ci-deploy-agent cat /opt/webhook/logs/deploy_my-app_2026_07_13.log

# Today's log, without knowing the exact date
docker exec ci-deploy-agent sh -c 'cat /opt/webhook/logs/deploy_my-app_$(date +%Y_%m_%d).log'

# List all deployment logs
docker exec ci-deploy-agent ls -la /opt/webhook/logs/
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Repository not found

```json
{"status":"error","message":"Repo my-app not found in repos.json"}
```

This is written by `_deploy.sh` running inside `ci-deploy-agent`, so it shows
up when you poll the **status** endpoint (`deploy-project` itself always
returns `"status":"queued"` immediately, regardless of whether the repo
exists).

**Solution:** Check `config/repos.json` and ensure the repository is configured.

#### 2. Deployment script not executable

```bash
Deployment script deploy.sh not found or not executable
```

**Solution:**

```bash
chmod +x /path/to/repo/deploy.sh
```

#### 3. Git authentication failed

SSH keys and `docker.sock` are only mounted into `ci-deploy-agent`, not `ci-web`.

**Solution:** Check SSH keys and Git configuration inside the agent container:

```bash
docker exec ci-deploy-agent ssh -T git@github.com
docker exec ci-deploy-agent git config --list
```

#### 4. Traefik routing not working

**Solution:** Check Traefik labels in `docker-compose.yml` and ensure the `proxy` network exists.
Note that `ci-deploy-agent` is intentionally not on the `proxy` network and has no Traefik labels.

#### 5. Deployment stuck on "queued"

**Solution:** Check that the `ci-deploy-agent` container is running and watching the queue:

```bash
docker logs ci-deploy-agent
docker exec ci-web ls -la /opt/webhook/queue/
```

#### 6. Getting `429 Too Many Requests`

The `ci-web-secure` Traefik router has a rate limit (10 req/min, burst 5) to
blunt brute-force/abuse against the API key. If a legitimate integration hits
this, raise `ci-web-ratelimit.ratelimit.average`/`burst` in `docker-compose.yml`.

#### 7. Debugging webhook request/trigger matching

`-verbose` is intentionally left off the default `webhook` command since it can
log request headers (including `X-Api-Key`) to `docker logs`. To debug
temporarily, add `-verbose` back to the `command:` of the `webhook` service in
`docker-compose.yml`, redeploy, and remove it again afterwards.

#### 8. Deployment reported as "failed" but the log looks fine / build just takes long

`ci-deploy-agent` kills a deploy after `DEPLOY_TIMEOUT` seconds (default
`120`) so a hung `git fetch` or deploy script can't block the queue forever.
If your deploy script legitimately runs longer (e.g. a slow `docker compose
build`), raise it by setting `DEPLOY_TIMEOUT` (seconds) as an environment
variable on the `deploy-agent` service in `docker-compose.yml`.

#### 9. A deploy log I wanted to look at is gone

Each repo gets one log file per calendar day
(`deploy_<repo>_<year>_<month>_<day>.log`). `ci-deploy-agent` deletes those
files once they're older than `LOG_RETENTION_DAYS` (default `7`). Raise it via
the `LOG_RETENTION_DAYS` environment variable on the `deploy-agent` service if
you need longer history.

### Analyzing Logs

```bash
# Webhook server logs (auth, request handling)
docker logs -f ci-web

# Deploy agent logs (queue processing, git, deploy script output)
docker logs -f ci-deploy-agent

# Deployment status
docker exec ci-deploy-agent find /opt/webhook/status -name "*.json" -exec cat {} \;

# Deployment logs
docker exec ci-deploy-agent find /opt/webhook/logs -name "*.log" -exec tail -n 20 {} \;
```

## 🔒 Security

### Best Practices

1. **Use strong CI keys:**

```bash
openssl rand -hex 32
```

2. **Keep containers updated:**

```bash
docker compose pull
docker compose up -d
```

3. **Trust boundary:** only `ci-deploy-agent` holds `docker.sock` and SSH keys;
   it is not published and has no Traefik labels, so it should never be
   reachable directly from the internet. Don't add `ports:` or Traefik labels
   to that service, and don't move `docker.sock`/SSH mounts back onto `ci-web`.

4. **Repo trust:** anything in a repo's `deploy_script` runs with full
   `docker.sock` access via `ci-deploy-agent`. Only add repositories to
   `config/repos.json` whose branch and deploy script you trust — this is
   equivalent to giving push access to that branch root-level Docker control
   on the host.

5. **`ci-web` runs hardened:** the `webhook` service is started with
   `read_only: true`, `cap_drop: [ALL]` and `no-new-privileges:true` in
   `docker-compose.yml` — it never needs to write outside the mounted queue
   dir or escalate privileges.

6. **Use a dedicated deploy key instead of your full `~/.ssh`:** by default
   `docker-compose.yml` mounts your entire `~/.ssh` read-only into
   `ci-deploy-agent`, which means every `deploy_script` in every repo listed
   in `repos.json` can read *all* your private keys, not just the one needed
   for that repo. On a production host, replace it with a key generated
   just for this purpose:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh-ci-webhooks/id_ed25519 -N "" -C "ci-webhooks-deploy"
   # add ~/.ssh-ci-webhooks/id_ed25519.pub as a read-only deploy key on each
   # Git host/repo that ci-webhooks needs to pull, and copy your existing
   # ~/.ssh/config entries for those hosts into ~/.ssh-ci-webhooks/config if needed
   ```

   Then point the bind mount at that directory instead of your real `~/.ssh`
   in `docker-compose.yml`:

   ```yaml
       - ~/.ssh-ci-webhooks:/root/.ssh:ro
   ```

   This is a manual step on purpose — it touches host SSH configuration on a
   production system, so it isn't applied automatically.

See [docs/security-architecture-review.md](docs/security-architecture-review.md)
for the full review and remaining open items.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see [LICENSE.md](LICENSE.md) for details.

## 🙏 Acknowledgments

* [adnanh/webhook](https://github.com/adnanh/webhook) for the awesome webhook server
* [Traefik](https://traefik.io/) for the reverse proxy
* Docker Community for the container ecosystem

## 💖 Support

If you like this project and want to support it:

* ⭐ Star it on GitHub
* 🔄 Share it with friends or colleagues
* 🐞 Report issues or suggest features
* 💡 Contribute code or improvements

[![Buy Me A Coffee](https://raw.githubusercontent.com/temmiland/temmiland/refs/heads/main/assets/bmc-button.png)](https://www.buymeacoffee.com/temmiland)
