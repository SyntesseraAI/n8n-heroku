# Cloud Run Claude Code Launcher

This directory contains the necessary files to launch Google Cloud Run containers that execute Claude Code with the opusplan model.

## Quick Start

**New to Cloud Run?** Start here:

1. **[QUICKSTART.md](QUICKSTART.md)** - Get running in 5 minutes
2. **[GCP_SETUP.md](GCP_SETUP.md)** - Detailed setup guide

**TL;DR:**
```bash
cd cloudrun
./setup-gcp.sh
# Follow the prompts, then configure Heroku with the output commands
```

## Files

- **setup-gcp.sh** - Automated GCP setup script (recommended)
- **rebuild-image.sh** - Rebuild and push container image
- **Dockerfile** - Container image definition for Cloud Run jobs
- **startup.sh** - Startup script that runs inside the Cloud Run container
- **opusplan.sh** - Expect script that executes Claude Code with opusplan model
- **QUICKSTART.md** - 5-minute getting started guide
- **GCP_SETUP.md** - Comprehensive setup documentation
- **README.md** - This file

## What You Need

### Required:
1. **Google Cloud Project** - Create at https://console.cloud.google.com
2. **gcloud CLI** - Install from https://cloud.google.com/sdk/docs/install
3. **Docker** - Install from https://docs.docker.com/get-docker/
4. **Claude Code OAuth Token** - Get from https://claude.ai

### Optional:
- **GitHub Token** - For GitHub MCP server integration

## Automated Setup (Recommended)

Run the setup script - it handles everything:

```bash
cd cloudrun
./setup-gcp.sh
```

The script configures:
- ✓ All required GCP APIs
- ✓ Service account with proper IAM roles
- ✓ Authentication keys (local and base64 for Heroku)
- ✓ Container image built and uploaded to GCR

**See [QUICKSTART.md](QUICKSTART.md) for a quick guide or [GCP_SETUP.md](GCP_SETUP.md) for detailed documentation.**

## Manual Setup

If you prefer manual setup, see the detailed guide in [GCP_SETUP.md](GCP_SETUP.md).

### Quick Reference for Manual Setup

1. Create a service account in your GCP project:
```bash
gcloud iam service-accounts create claude-runner \
  --description="Service account for Claude Code Cloud Run" \
  --display-name="Claude Runner"
```

2. Grant necessary roles:
```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:claude-runner@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:claude-runner@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:claude-runner@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

3. Create and download the key:
```bash
gcloud iam service-accounts keys create ~/gcp-key.json \
  --iam-account=claude-runner@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

4. Base64 encode the key for Heroku:
```bash
# On macOS/Linux
cat ~/gcp-key.json | base64 > ~/gcp-key-base64.txt

# On Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("gcp-key.json")) > gcp-key-base64.txt
```

5. Set the environment variable in Heroku:
```bash
heroku config:set GCP_SERVICE_ACCOUNT_KEY=$(cat ~/gcp-key-base64.txt)
```

## Setup

### 1. Build and Push the Cloud Run Image

```bash
# From the project root
cd cloudrun
docker build -t gcr.io/YOUR_PROJECT_ID/claude-code-runner .
docker push gcr.io/YOUR_PROJECT_ID/claude-code-runner
```

### 2. Set Environment Variables

```bash
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"  # Optional, defaults to us-central1
export CLAUDE_CODE_OAUTH_TOKEN="your-claude-token"
export GITHUB_TOKEN="your-github-token"  # Optional
```

## Usage

### From the Main Docker Container

The `launch-cloudrun` command is available in the main container:

```bash
# Basic usage
launch-cloudrun -p "Your prompt here"

# Build image before running
launch-cloudrun -p "Your prompt here" -b

# Specify custom project and region
launch-cloudrun -p "Your prompt here" -P my-project -r us-west1
```

### Command Line Options

```
-p, --prompt PROMPT           The prompt to send to Claude Code (required)
-P, --project PROJECT_ID      GCP Project ID (default: $GCP_PROJECT_ID)
-r, --region REGION           GCP Region (default: us-central1)
-n, --name SERVICE_NAME       Service name (default: claude-code-runner)
-b, --build                   Build and push Docker image before running
-h, --help                    Show help message
```

### Direct Usage (Outside Container)

```bash
./launch-cloudrun.sh -p "Create a new feature for user authentication" -b
```

## How It Works

1. The launcher script (`launch-cloudrun.sh`) creates a Cloud Run job
2. The job uses the Docker image built from this directory
3. The container starts with `startup.sh`, which:
   - Configures Claude Code authentication
   - Sets up MCP servers (like GitHub)
   - Executes the opusplan.sh script with your prompt
4. The opusplan.sh script uses `expect` to interact with Claude Code CLI
5. Output is captured and logged
6. The job is automatically cleaned up after completion

## Features

- Runs Claude Code with opusplan model in isolated Cloud Run environment
- Supports MCP server integration (GitHub)
- Automatic authentication with Claude Code OAuth token
- 4GB memory, 2 CPU allocation for complex tasks
- 1-hour timeout for long-running operations
- Automatic job cleanup after execution
- Full logging with gcloud logging

## Troubleshooting

### Authentication Errors

If you get authentication errors:
```bash
# Re-authenticate with gcloud
gcloud auth login
gcloud auth configure-docker

# Verify Claude Code token
echo $CLAUDE_CODE_OAUTH_TOKEN
```

### Image Not Found

If the Cloud Run job can't find the image:
```bash
# Rebuild and push the image
launch-cloudrun -p "test" -b
```

### Viewing Logs

To view logs for a specific job:
```bash
gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=JOB_NAME" \
  --project=YOUR_PROJECT_ID \
  --limit=100
```

## Cost Considerations

Cloud Run jobs are billed based on:
- CPU and memory allocation (4GB RAM, 2 CPU)
- Execution time (up to 1 hour max)
- Network egress

Each job execution will incur costs. Monitor your usage in the GCP console.

## Security Notes

- OAuth tokens are passed as environment variables to Cloud Run jobs
- Jobs are ephemeral and deleted after completion
- Ensure your GCP project has appropriate IAM permissions
- Keep your `CLAUDE_CODE_OAUTH_TOKEN` secure and never commit it to version control
