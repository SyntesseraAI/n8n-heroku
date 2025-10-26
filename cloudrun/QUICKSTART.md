# Cloud Run Quick Start Guide

Get up and running with Cloud Run in 5 minutes!

## What You Need

1. **GCP Account** - https://cloud.google.com (new users get $300 free credits)
2. **GCP Project ID** - Create at https://console.cloud.google.com/projectcreate
3. **gcloud CLI** - https://cloud.google.com/sdk/docs/install
4. **Docker** - https://docs.docker.com/get-docker/

## One-Command Setup

```bash
cd cloudrun
./setup-gcp.sh
```

That's it! The script will:
- ✓ Enable all required GCP APIs
- ✓ Create service account with permissions
- ✓ Generate authentication keys
- ✓ Build and upload container image
- ✓ Give you Heroku config commands to run

**Time:** ~5 minutes

## Configure Heroku

After the script completes, run the commands it provides:

```bash
# The script will output these - just copy and paste:
heroku config:set GCP_PROJECT_ID="your-project-id"
heroku config:set GCP_SERVICE_ACCOUNT_KEY="$(cat cloudrun/gcp-key-base64.txt)"
heroku config:set CLAUDE_CODE_OAUTH_TOKEN="your-claude-token"
heroku config:set GITHUB_TOKEN="your-github-token"
```

## Test It

From your Heroku container:

```bash
launch-cloudrun -p "Hello Claude, list your MCP servers"
```

## What Gets Created

### In GCP:
- Service account: `claude-runner@{PROJECT_ID}.iam.gserviceaccount.com`
- Container image: `gcr.io/{PROJECT_ID}/claude-code-runner`
- Enabled APIs: Cloud Run, Container Registry, Cloud Build

### Locally:
- `gcp-key.json` - Service account key (keep secret!)
- `gcp-key-base64.txt` - Base64 encoded for Heroku

**Important:** Never commit these files! They're in `.gitignore`.

## Common Commands

### Rebuild container after changes:
```bash
cd cloudrun
./rebuild-image.sh
```

### Launch a Cloud Run job:
```bash
launch-cloudrun -p "Your prompt here"
```

### Launch with fresh build:
```bash
launch-cloudrun -p "Your prompt here" -b
```

### View Cloud Run logs:
```bash
gcloud logging read "resource.type=cloud_run_job" --limit=50
```

## Cost

Typical 10-minute job with 4GB RAM, 2 vCPU:
- **~$0.05-$0.10 per execution**
- Generous free tier: 2M vCPU-seconds/month free

## Troubleshooting

### "Permission denied" when pushing
```bash
gcloud auth configure-docker
gcloud auth login
```

### "API not enabled"
Run setup script again:
```bash
./setup-gcp.sh
```

### Update container image
```bash
./rebuild-image.sh
```

## Next Steps

- Read [GCP_SETUP.md](GCP_SETUP.md) for detailed manual setup
- Read [README.md](README.md) for full documentation
- Set up billing alerts in GCP Console
- Explore Cloud Run logs in GCP Console

## Support

- **Cloud Run Docs:** https://cloud.google.com/run/docs
- **Pricing:** https://cloud.google.com/run/pricing
- **Free Tier:** https://cloud.google.com/free

---

**Ready to go?** Run `./setup-gcp.sh` now!
