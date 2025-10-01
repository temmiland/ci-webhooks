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

```sh
ci-webhooks/
├── docker-compose.yml         # Main configuration
├── Dockerfile                 # Webhook server container
├── entrypoint.sh              # Container entrypoint script
├── start.sh                   # Startup script
├── ci/
│   ├── hooks.tpl.json         # Webhook configuration template
│   ├── deploy.sh              # Deployment starter script
│   ├── _deploy.sh             # Actual deployment worker
│   └── status.sh              # Status checker
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
  "main_webhook_dir": "/srv/ci-main",
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

#### Trigger Deployment

```
POST https://ci.yourdomain.com/hooks/deploy-project?key=YOUR_CI_KEY&repo=REPO_NAME
```

#### Check Status

```
GET https://ci.yourdomain.com/hooks/status-project?key=YOUR_CI_KEY&repo=REPO_NAME
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
| `MAIN_WEBHOOK_DIR`     | Path to webhook directory | `/srv/projects/main-webhook` |
| `TRAEFIK_NETWORK_NAME` | Traefik network           | `proxy`                      |

## 🔧 Usage

### Trigger Deployment

#### Using cURL

```bash
curl -X POST "https://ci.yourdomain.com/hooks/deploy-project?key=YOUR_CI_KEY&repo=my-app"
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
          DEPLOY_RESPONSE=$(curl -s -X POST "https://ci.yourdomain.com/hooks/deploy-project?key=${{ secrets.CI_KEY }}&repo=my-app")
          echo "Deploy response: $DEPLOY_RESPONSE"

      - name: Wait for deployment status
        run: |
          MAX_RETRIES=60
          SLEEP=5
          COUNT=0

          while true; do
            STATUS_RESPONSE=$(curl -s -X GET "https://ci.yourdomain.com/hooks/status-project?key=${{ secrets.CI_KEY }}&repo=my-app")

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

**Deployment started:**

```json
{
  "status": "started",
  "message": "Deployment started for my-app"
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
# Container logs
docker logs ci-web

# Deployment logs per repository
docker exec ci-web cat /opt/webhook/logs/deploy_my-app.log

# List all deployment logs
docker exec ci-web ls -la /opt/webhook/logs/
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Repository not found

```json
{"status":"error","message":"Repo my-app not found in repos.json"}
```

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

**Solution:** Check SSH keys and Git configuration:

```bash
ssh -T git@github.com
git config --list
```

#### 4. Traefik routing not working

**Solution:** Check Traefik labels in `docker-compose.yml` and ensure the `proxy` network exists.

### Analyzing Logs

```bash
# Webhook server logs
docker logs -f ci-web

# Deployment status
    docker exec ci-web find /opt/webhook/status -name "*.json" -exec cat {} \;

# Deployment logs
    docker exec ci-web find /opt/webhook/logs -name "*.log" -exec tail -n 20 {} \;
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
