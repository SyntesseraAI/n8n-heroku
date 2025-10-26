# What Needs to be Configured in GCP

This document explains everything that needs to be set up in Google Cloud Platform for Cloud Run to work.

## TL;DR - What Gets Created

### 1. GCP APIs (Enabled)
- Cloud Run API
- Container Registry API
- Artifact Registry API
- Cloud Build API
- Cloud Resource Manager API

### 2. Service Account
- Name: `claude-runner`
- Email: `claude-runner@{YOUR_PROJECT}.iam.gserviceaccount.com`
- JSON Key: Downloaded and base64-encoded for Heroku

### 3. IAM Roles (Permissions)
- `roles/run.admin` - Create and manage Cloud Run jobs
- `roles/storage.admin` - Access Container Registry
- `roles/iam.serviceAccountUser` - Run jobs as service account
- `roles/artifactregistry.writer` - Push container images
- `roles/logging.logWriter` - Write logs

### 4. Container Image
- Location: `gcr.io/{YOUR_PROJECT}/claude-code-runner`
- Built from: `cloudrun/Dockerfile`
- Uploaded to: Google Container Registry (GCR)

## Detailed Breakdown

### Step 1: Enable GCP APIs

**What:** Enable services that Cloud Run depends on

**Why:** GCP requires explicit API activation before use

**APIs Needed:**
```
cloudresourcemanager.googleapis.com  # Project management
run.googleapis.com                   # Cloud Run service
containerregistry.googleapis.com     # Store Docker images
artifactregistry.googleapis.com      # Alternative image storage
cloudbuild.googleapis.com            # Build containers
```

**Automated:**
```bash
./setup-gcp.sh  # Enables all automatically
```

**Manual:**
```bash
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
# ... etc
```

**Time:** 3-5 minutes for all APIs to activate

---

### Step 2: Create Service Account

**What:** A bot account that the Cloud Run job runs as

**Why:**
- Heroku needs credentials to launch Cloud Run jobs
- Service accounts are safer than using personal credentials
- Allows fine-grained permission control

**What Gets Created:**
- Service account name: `claude-runner`
- Email: `claude-runner@{PROJECT_ID}.iam.gserviceaccount.com`
- JSON key file: `gcp-key.json` (keep secret!)
- Base64 version: `gcp-key-base64.txt` (for Heroku env var)

**Automated:**
```bash
./setup-gcp.sh  # Creates and downloads key
```

**Manual:**
```bash
gcloud iam service-accounts create claude-runner \
  --description="Service account for Claude Code Cloud Run" \
  --display-name="Claude Runner"

gcloud iam service-accounts keys create gcp-key.json \
  --iam-account=claude-runner@{PROJECT}.iam.gserviceaccount.com
```

---

### Step 3: Grant IAM Permissions

**What:** Give the service account permission to do its job

**Why:** Service accounts start with zero permissions

**Roles Needed:**

#### Cloud Run Admin (`roles/run.admin`)
- Create Cloud Run jobs
- Execute jobs
- Delete jobs after completion

#### Storage Admin (`roles/storage.admin`)
- Push container images to GCR
- Pull images when running jobs

#### Service Account User (`roles/iam.serviceAccountUser`)
- Run Cloud Run jobs as the service account
- Required for job execution

#### Artifact Registry Writer (`roles/artifactregistry.writer`)
- Write to Artifact Registry (modern GCR alternative)
- Future-proofing

#### Logging Log Writer (`roles/logging.logWriter`)
- Write job logs to Cloud Logging
- View logs in GCP Console

**Automated:**
```bash
./setup-gcp.sh  # Grants all automatically
```

**Manual:**
```bash
gcloud projects add-iam-policy-binding {PROJECT_ID} \
  --member="serviceAccount:claude-runner@{PROJECT}.iam.gserviceaccount.com" \
  --role="roles/run.admin"
# Repeat for each role
```

---

### Step 4: Build and Upload Container Image

**What:** Create a Docker image and upload to Google Container Registry

**Why:** Cloud Run runs containers - it needs the image to exist first

**What Happens:**
1. Docker builds image from `cloudrun/Dockerfile`
2. Image includes:
   - Node.js 18
   - Claude Code CLI (`@anthropic-ai/claude-code`)
   - expect (for running opusplan.sh)
   - Your opusplan.sh script
   - All MCP server configurations
3. Image is pushed to `gcr.io/{PROJECT}/claude-code-runner`
4. Cloud Run jobs pull this image when they execute

**Image Size:** ~500MB

**Automated:**
```bash
./setup-gcp.sh  # Builds and pushes automatically
```

**Manual:**
```bash
# Authenticate Docker
gcloud auth configure-docker

# Build
docker build -t gcr.io/{PROJECT}/claude-code-runner ./cloudrun/

# Push
docker push gcr.io/{PROJECT}/claude-code-runner
```

**When to Rebuild:**
- After changing `cloudrun/Dockerfile`
- After modifying `cloudrun/startup.sh`
- After updating `cloudrun/opusplan.sh`
- To update Claude Code CLI version

```bash
./rebuild-image.sh  # Quick rebuild and push
```

---

### Step 5: Configure Heroku

**What:** Set environment variables in Heroku

**Why:** Your n8n container needs credentials to launch Cloud Run jobs

**Variables to Set:**

```bash
# Required
heroku config:set GCP_PROJECT_ID="your-project-id"
heroku config:set GCP_SERVICE_ACCOUNT_KEY="$(cat cloudrun/gcp-key-base64.txt)"
heroku config:set CLAUDE_CODE_OAUTH_TOKEN="your-claude-token"

# Optional
heroku config:set GCP_REGION="us-central1"
heroku config:set CLOUDRUN_SERVICE_NAME="claude-code-runner"
heroku config:set GITHUB_TOKEN="your-github-token"
```

**What Happens:**
- On container startup, `entrypoint.sh` decodes the service account key
- Authenticates gcloud CLI with the key
- Sets default project
- Configures Docker to push/pull from GCR

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Heroku Container (n8n)                                       │
│                                                               │
│  ┌─────────────────┐                                        │
│  │ entrypoint.sh   │  Decodes service account key           │
│  │                 │  Authenticates gcloud                   │
│  └─────────────────┘                                        │
│         │                                                     │
│         ▼                                                     │
│  ┌─────────────────┐                                        │
│  │ launch-cloudrun │  Calls gcloud to create job            │
│  │                 │  Passes PROMPT env var                  │
│  └─────────────────┘                                        │
│         │                                                     │
└─────────┼─────────────────────────────────────────────────────┘
          │
          │ gcloud run jobs create/execute
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│ Google Cloud Platform                                        │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Cloud Run Job                                          │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────┐           │ │
│  │  │ Container: gcr.io/.../claude-runner │           │ │
│  │  │                                      │           │ │
│  │  │  1. startup.sh runs                 │           │ │
│  │  │  2. Installs Claude Code CLI        │           │ │
│  │  │  3. Configures MCP servers          │           │ │
│  │  │  4. Runs opusplan.sh with PROMPT    │           │ │
│  │  │  5. Returns output to logs          │           │ │
│  │  └──────────────────────────────────────┘           │ │
│  │                                                        │ │
│  │  Resources: 4GB RAM, 2 vCPU, 1hr timeout             │ │
│  └────────────────────────────────────────────────────────┘ │
│         │                                                     │
│         ▼                                                     │
│  ┌────────────────┐                                         │
│  │ Cloud Logging  │  Job output and logs                    │
│  └────────────────┘                                         │
│                                                               │
│  ┌────────────────┐                                         │
│  │ Container      │  Stores Docker images                   │
│  │ Registry (GCR) │  gcr.io/{PROJECT}/...                   │
│  └────────────────┘                                         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Checklist

Use this to verify everything is set up:

### GCP Setup
- [ ] GCP Project created
- [ ] Billing enabled on project
- [ ] gcloud CLI installed locally
- [ ] Docker installed locally
- [ ] All APIs enabled (run, registry, build, etc.)
- [ ] Service account created (`claude-runner`)
- [ ] All IAM roles granted to service account
- [ ] Service account key downloaded (`gcp-key.json`)
- [ ] Key base64-encoded (`gcp-key-base64.txt`)

### Container Image
- [ ] Docker authenticated with GCR
- [ ] Container image built
- [ ] Container image pushed to GCR
- [ ] Image visible in GCP Console → Container Registry

### Heroku Configuration
- [ ] `GCP_PROJECT_ID` set
- [ ] `GCP_SERVICE_ACCOUNT_KEY` set (base64 encoded)
- [ ] `CLAUDE_CODE_OAUTH_TOKEN` set
- [ ] `GITHUB_TOKEN` set (optional)
- [ ] `GCP_REGION` set (optional)
- [ ] `CLOUDRUN_SERVICE_NAME` set (optional)

### Testing
- [ ] Heroku container deployed
- [ ] Can run `launch-cloudrun -p "test"`
- [ ] Cloud Run job executes successfully
- [ ] Can see output in logs
- [ ] Job cleans up after completion

---

## Costs

### Free Tier (Monthly)
- 2 million requests
- 360,000 GB-seconds of memory
- 180,000 vCPU-seconds
- 1 GB Container Registry storage

### Typical Usage
**Per 10-minute job (4GB RAM, 2 vCPU):**
- CPU cost: 600 seconds × 2 vCPU × $0.000024 = $0.029
- Memory cost: 600 seconds × 4GB × $0.0000025 = $0.006
- **Total: ~$0.035 per job**

**Storage:**
- Container image (~500MB) = $0.013/month

### Staying in Free Tier
- ~5,000 jobs/month would fit in free tier
- Monitor usage in GCP Console → Billing

---

## Security Best Practices

### DO:
✓ Use service accounts (not personal credentials)
✓ Grant minimum required permissions
✓ Rotate service account keys regularly
✓ Keep `gcp-key.json` secret (never commit)
✓ Use base64 encoding for environment variables
✓ Enable billing alerts in GCP Console
✓ Review Cloud Run job logs regularly
✓ Delete old container images

### DON'T:
✗ Commit `gcp-key.json` or `gcp-key-base64.txt`
✗ Share service account keys
✗ Grant `Owner` or `Editor` roles
✗ Use personal gcloud credentials in production
✗ Leave old jobs running
✗ Ignore billing alerts

---

## Troubleshooting

See [GCP_SETUP.md](GCP_SETUP.md) for detailed troubleshooting.

Quick checks:
```bash
# Verify APIs enabled
gcloud services list --enabled

# Verify service account exists
gcloud iam service-accounts list

# Verify container image exists
gcloud container images list

# Test gcloud auth
gcloud auth list

# View recent Cloud Run jobs
gcloud run jobs list --region=us-central1
```

---

## Summary

**What you need to configure in GCP:**

1. **Enable 5 APIs** (Cloud Run, Container Registry, Build, etc.)
2. **Create 1 service account** with 5 IAM roles
3. **Build & upload 1 container image** to Container Registry
4. **Set 3-6 environment variables** in Heroku

**Easiest way:**
```bash
cd cloudrun && ./setup-gcp.sh
```

**Time:** 5-10 minutes total

**Cost:** Free tier covers most use cases, ~$0.03-0.10 per job beyond that
