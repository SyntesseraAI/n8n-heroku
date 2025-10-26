# Google Cloud Platform Setup Guide for Cloud Run

This guide will help you set up everything needed to run Claude Code on Google Cloud Run.

## Prerequisites

Before you begin, make sure you have:

1. **A Google Cloud Platform account** with billing enabled
   - Sign up at https://cloud.google.com
   - Set up billing (new accounts get $300 free credits)

2. **Google Cloud SDK (gcloud)** installed
   - Download from https://cloud.google.com/sdk/docs/install
   - Verify with: `gcloud --version`

3. **Docker** installed and running
   - Download from https://docs.docker.com/get-docker/
   - Verify with: `docker --version`

4. **A GCP Project**
   - Create one at https://console.cloud.google.com/projectcreate
   - Note your Project ID (not the project name)

## Automatic Setup (Recommended)

We've created a setup script that handles everything automatically.

### Run the Setup Script

```bash
cd cloudrun
chmod +x setup-gcp.sh
./setup-gcp.sh
```

The script will:
1. ✓ Enable required GCP APIs
2. ✓ Create a service account with proper permissions
3. ✓ Generate and encode authentication keys
4. ✓ Build and push the Cloud Run container image
5. ✓ Provide Heroku configuration commands

**Estimated time:** 5-10 minutes

### After Setup

The script will output commands like this:

```bash
heroku config:set GCP_PROJECT_ID="your-project-id"
heroku config:set GCP_REGION="us-central1"
heroku config:set CLOUDRUN_SERVICE_NAME="claude-code-runner"
heroku config:set GCP_SERVICE_ACCOUNT_KEY="$(cat cloudrun/gcp-key-base64.txt)"
heroku config:set CLAUDE_CODE_OAUTH_TOKEN="your-claude-token"
heroku config:set GITHUB_TOKEN="your-github-token"
```

Run these commands to configure your Heroku app.

## Manual Setup (Advanced)

If you prefer to set things up manually or need to troubleshoot, follow these steps:

### Step 1: Set Up Your GCP Project

```bash
# Set your project ID
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"

# Configure gcloud
gcloud config set project $GCP_PROJECT_ID
```

### Step 2: Enable Required APIs

```bash
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

**Note:** This may take 3-5 minutes.

### Step 3: Create Service Account

```bash
# Create the service account
gcloud iam service-accounts create claude-runner \
  --description="Service account for Claude Code Cloud Run" \
  --display-name="Claude Runner"

# Set the service account email
export SERVICE_ACCOUNT_EMAIL="claude-runner@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
```

### Step 4: Grant Permissions

```bash
# Cloud Run Admin
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin"

# Storage Admin (for container registry)
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/storage.admin"

# Service Account User
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# Artifact Registry Writer
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/artifactregistry.writer"

# Logging
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/logging.logWriter"
```

### Step 5: Generate Service Account Key

```bash
# Create and download the key
gcloud iam service-accounts keys create gcp-key.json \
  --iam-account=$SERVICE_ACCOUNT_EMAIL

# Base64 encode for Heroku
cat gcp-key.json | base64 > gcp-key-base64.txt
```

**Important:** Keep these files secure and never commit them to Git!

### Step 6: Build and Push Container Image

```bash
# Authenticate Docker with GCR
gcloud auth configure-docker

# Build the image
export IMAGE_NAME="gcr.io/${GCP_PROJECT_ID}/claude-code-runner"
docker build -t $IMAGE_NAME .

# Push to Google Container Registry
docker push $IMAGE_NAME
```

### Step 7: Configure Heroku

```bash
heroku config:set GCP_PROJECT_ID="$GCP_PROJECT_ID"
heroku config:set GCP_REGION="$GCP_REGION"
heroku config:set GCP_SERVICE_ACCOUNT_KEY="$(cat gcp-key-base64.txt)"
heroku config:set CLOUDRUN_SERVICE_NAME="claude-code-runner"
```

## What Gets Created in GCP

### APIs Enabled
- **Cloud Resource Manager API** - Project management
- **Cloud Run API** - Run containerized applications
- **Container Registry API** - Store Docker images
- **Artifact Registry API** - Alternative to Container Registry
- **Cloud Build API** - Build container images

### Service Account
- **Name:** `claude-runner`
- **Email:** `claude-runner@{PROJECT_ID}.iam.gserviceaccount.com`
- **Roles:**
  - Cloud Run Admin - Create and manage Cloud Run jobs
  - Storage Admin - Push/pull container images
  - Service Account User - Run jobs as service account
  - Artifact Registry Writer - Write to Artifact Registry
  - Logging Log Writer - Write logs

### Container Image
- **Location:** `gcr.io/{PROJECT_ID}/claude-code-runner`
- **Size:** ~500MB (includes Node.js, Claude CLI, expect)
- **Updates:** Run `setup-gcp.sh` again or rebuild manually

## Cost Estimates

### Cloud Run Pricing (as of 2024)
- **CPU:** $0.00002400/vCPU-second
- **Memory:** $0.00000250/GB-second
- **Container Registry Storage:** $0.026/GB/month

### Example Job Cost
- 4GB RAM, 2 vCPU, 10-minute job
- Cost: ~$0.05-$0.10 per execution
- First 2 million vCPU-seconds free per month

**Free tier:** Generous free tier available - https://cloud.google.com/run/pricing

## Updating the Container Image

When you make changes to the Cloud Run container:

```bash
cd cloudrun

# Rebuild and push
docker build -t gcr.io/$GCP_PROJECT_ID/claude-code-runner .
docker push gcr.io/$GCP_PROJECT_ID/claude-code-runner
```

Or use the setup script again:
```bash
./setup-gcp.sh
```

## Troubleshooting

### "Permission denied" when pushing to GCR

```bash
gcloud auth configure-docker
gcloud auth login
```

### "API not enabled" errors

Make sure all APIs are enabled:
```bash
gcloud services list --enabled
```

Enable missing APIs:
```bash
gcloud services enable run.googleapis.com
```

### "Service account already exists"

This is fine - the setup script will use the existing account.

### Testing the Setup

Once everything is configured, test it:

```bash
# From your Heroku container
launch-cloudrun -p "Hello, test the MCP servers" -b
```

## Security Best Practices

1. **Never commit sensitive files:**
   - `gcp-key.json`
   - `gcp-key-base64.txt`
   - These are in `.gitignore`

2. **Rotate service account keys regularly:**
   ```bash
   gcloud iam service-accounts keys list \
     --iam-account=$SERVICE_ACCOUNT_EMAIL

   gcloud iam service-accounts keys delete KEY_ID \
     --iam-account=$SERVICE_ACCOUNT_EMAIL
   ```

3. **Use least privilege:**
   - The service account only has permissions it needs
   - Consider narrowing scopes for production

4. **Monitor usage:**
   - Check GCP Console for Cloud Run job executions
   - Set up billing alerts
   - Review logs regularly

## Support

- **GCP Documentation:** https://cloud.google.com/run/docs
- **Cloud Run Quickstart:** https://cloud.google.com/run/docs/quickstarts
- **Pricing Calculator:** https://cloud.google.com/products/calculator

For issues with this setup, check the main repository README.
