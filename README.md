# simple-chat-bubble

A production-ready chat bubble widget with:

- React + TypeScript frontend widget (Fluent UI v9)
- Python 3.13 FastAPI backend
- Prompty-based agent definition (`Agent Plane Talk`)
- AI Horde (`oai.aihorde.net`) OpenAI-compatible backend
- Azure App Service deployment via `azd` + Bicep
- GitHub Actions CI/CD for quality checks and deployment

## Architecture

- `frontend/`: Embeddable widget bundle (`chat-bubble.iife.js`) and CSS.
- `backend/`: FastAPI API (`/api/chat`) + static hosting for test page.
- `backend/prompts/agent-plane-talk.prompty`: Default humorous aviation assistant profile.
- `infra/`: Azure Bicep for App Service Plan + App Service.
- `azure.yaml`: Azure Developer CLI project definition.

## Local Development

### 1. Configure environment

Set the API key in your shell:

```bash
export AIHORDE_API_KEY="your_ai_horde_key"
```

Optional settings:

```bash
export AIHORDE_BASE_URL="https://oai.aihorde.net/v1"
export AIHORDE_MODEL="openai/gpt-oss-20b"
```

### 2. Build widget assets

```bash
./scripts/build_frontend.sh
```

### 3. Run backend

```bash
cd backend
python3 -m pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Open:

- `http://localhost:8000/static/test-host.html`

## Embedding the Bubble on Any HTML Page

Include the generated assets and mount:

```html
<link rel="stylesheet" href="/static/chat-bubble.css" />
<script src="/static/chat-bubble.iife.js"></script>
<script>
	window.SimpleChatBubble.mount({
		apiBaseUrl: "https://your-backend-hostname",
		title: "Agent Plane Talk"
	});
</script>
```

## Prompty Agent

The agent is defined in:

- `backend/prompts/agent-plane-talk.prompty`

The backend reads this file and injects it as the system prompt for every chat completion.

## Azure Deployment (azd + Bicep)

Prerequisites:

- `az login`
- `azd auth login`

Set required azd environment values:

```bash
azd env new production
azd env set AZURE_LOCATION eastus
azd env set AIHORDE_API_KEY "your_ai_horde_key"
```

Preview and deploy:

```bash
azd provision --preview
azd provision
azd deploy
```

The App Service startup command is configured for ASGI/FastAPI:

```text
gunicorn --worker-class uvicorn.workers.UvicornWorker --bind=0.0.0.0:8000 app.main:app
```

## CI/CD

Workflow file:

- `.github/workflows/production-cicd.yml`

Required GitHub Secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AIHORDE_API_KEY`

Optional GitHub Variables:

- `AZURE_LOCATION` (defaults to `eastus` in workflow)

## Important Azure Note

This template targets App Service Plan `F1` and Python `3.13` as requested. In some regions or configurations, Python on Linux App Service may require a paid SKU. If deployment validation reports SKU/runtime incompatibility, switch `infra/main.bicep` to `B1`.
