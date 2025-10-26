#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  GCP Cloud Run Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command_exists gcloud; then
  echo -e "${RED}Error: gcloud CLI is not installed.${NC}"
  echo "Install it from: https://cloud.google.com/sdk/docs/install"
  exit 1
fi

if ! command_exists docker; then
  echo -e "${RED}Error: Docker is not installed.${NC}"
  echo "Install it from: https://docs.docker.com/get-docker/"
  exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}\n"

# Get or validate project ID
if [ -z "${GCP_PROJECT_ID:-}" ]; then
  read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
fi

if [ -z "$GCP_PROJECT_ID" ]; then
  echo -e "${RED}Error: GCP Project ID is required${NC}"
  exit 1
fi

export GCP_PROJECT_ID

# Get region (use environment variable as default if set)
DEFAULT_REGION="${GCP_REGION:-us-central1}"
read -p "Enter GCP Region [${DEFAULT_REGION}]: " INPUT_REGION
GCP_REGION=${INPUT_REGION:-$DEFAULT_REGION}

# Get service name (use environment variable as default if set)
DEFAULT_SERVICE_NAME="${CLOUDRUN_SERVICE_NAME:-claude-code-runner}"
read -p "Enter Cloud Run service name [${DEFAULT_SERVICE_NAME}]: " INPUT_SERVICE_NAME
SERVICE_NAME=${INPUT_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID: $GCP_PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  Service Name: $SERVICE_NAME"
echo ""

read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Setup cancelled."
  exit 1
fi

echo ""
echo -e "${YELLOW}Step 1: Setting up GCP project...${NC}"
gcloud config set project "$GCP_PROJECT_ID"

echo ""
echo -e "${YELLOW}Step 2: Enabling required APIs...${NC}"
echo "This may take a few minutes..."

gcloud services enable cloudresourcemanager.googleapis.com --project="$GCP_PROJECT_ID"
gcloud services enable run.googleapis.com --project="$GCP_PROJECT_ID"
gcloud services enable containerregistry.googleapis.com --project="$GCP_PROJECT_ID"
gcloud services enable artifactregistry.googleapis.com --project="$GCP_PROJECT_ID"
gcloud services enable cloudbuild.googleapis.com --project="$GCP_PROJECT_ID"

echo -e "${GREEN}✓ APIs enabled${NC}"

echo ""
echo -e "${YELLOW}Step 3: Creating service account...${NC}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-claude-runner}"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Check if service account already exists
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
  echo -e "${YELLOW}Service account already exists: $SERVICE_ACCOUNT_EMAIL${NC}"
else
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --description="Service account for Claude Code Cloud Run" \
    --display-name="Claude Runner" \
    --project="$GCP_PROJECT_ID"
  echo -e "${GREEN}✓ Service account created${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Granting IAM permissions...${NC}"

# Grant necessary roles
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin" \
  --condition=None

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/storage.admin" \
  --condition=None

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/artifactregistry.writer" \
  --condition=None

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/logging.logWriter" \
  --condition=None

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/logging.viewer" \
  --condition=None

echo -e "${GREEN}✓ IAM permissions granted${NC}"

echo ""
echo -e "${YELLOW}Step 5: Creating and downloading service account key...${NC}"
KEY_FILE="${KEY_FILE:-gcp-key.json}"
if [ -f "$KEY_FILE" ]; then
  echo -e "${YELLOW}Warning: $KEY_FILE already exists.${NC}"
  read -p "Overwrite? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping key creation."
  else
    gcloud iam service-accounts keys create "$KEY_FILE" \
      --iam-account="$SERVICE_ACCOUNT_EMAIL" \
      --project="$GCP_PROJECT_ID"
    echo -e "${GREEN}✓ Service account key created: $KEY_FILE${NC}"
  fi
else
  gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SERVICE_ACCOUNT_EMAIL" \
    --project="$GCP_PROJECT_ID"
  echo -e "${GREEN}✓ Service account key created: $KEY_FILE${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Encoding key for Heroku...${NC}"
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # macOS and Linux
  base64 -i "$KEY_FILE" > gcp-key-base64.txt
else
  # Windows (Git Bash/WSL)
  base64 -w 0 "$KEY_FILE" > gcp-key-base64.txt
fi
echo -e "${GREEN}✓ Base64 encoded key saved to: gcp-key-base64.txt${NC}"

echo ""
echo -e "${YELLOW}Step 7: Authenticating Docker with GCR...${NC}"
gcloud auth configure-docker --quiet

echo ""
echo -e "${YELLOW}Step 8: Building and pushing Cloud Run container image...${NC}"
IMAGE_NAME="gcr.io/${GCP_PROJECT_ID}/${SERVICE_NAME}"

echo "Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

echo "Pushing to Google Container Registry..."
docker push "$IMAGE_NAME"

echo -e "${GREEN}✓ Container image pushed successfully${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Set these environment variables in Heroku:"
echo ""
echo "   heroku config:set GCP_PROJECT_ID=\"$GCP_PROJECT_ID\""
echo "   heroku config:set GCP_REGION=\"$GCP_REGION\""
echo "   heroku config:set CLOUDRUN_SERVICE_NAME=\"$SERVICE_NAME\""
echo "   heroku config:set GCP_SERVICE_ACCOUNT_KEY=\"\$(cat cloudrun/gcp-key-base64.txt)\""
echo ""
echo "2. Don't forget to also set:"
echo "   heroku config:set CLAUDE_CODE_OAUTH_TOKEN=\"your-claude-token\""
echo "   heroku config:set GITHUB_TOKEN=\"your-github-token\""
echo ""
echo "3. The Cloud Run container image is now available at:"
echo "   $IMAGE_NAME"
echo ""
echo -e "${YELLOW}Security Notes:${NC}"
echo "  - Keep gcp-key.json and gcp-key-base64.txt secure"
echo "  - Do NOT commit these files to version control"
echo "  - They are already in .gitignore"
echo ""
echo -e "${GREEN}You can now use the launch-cloudrun command!${NC}"
