#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cloud Run Image Rebuild Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get configuration
if [ -z "${GCP_PROJECT_ID:-}" ]; then
  read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
fi

if [ -z "$GCP_PROJECT_ID" ]; then
  echo -e "${RED}Error: GCP_PROJECT_ID is required${NC}"
  exit 1
fi

# Get region (use environment variable as default if set)
DEFAULT_REGION="${GCP_REGION:-us-central1}"
read -p "Enter GCP Region [${DEFAULT_REGION}]: " INPUT_REGION
GCP_REGION=${INPUT_REGION:-$DEFAULT_REGION}

# Get service name (use environment variable as default if set)
DEFAULT_SERVICE_NAME="${CLOUDRUN_SERVICE_NAME:-claude-code-runner}"
read -p "Enter Cloud Run service name [${DEFAULT_SERVICE_NAME}]: " INPUT_SERVICE_NAME
SERVICE_NAME=${INPUT_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}

IMAGE_NAME="gcr.io/${GCP_PROJECT_ID}/${SERVICE_NAME}"

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID: $GCP_PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  Service Name: $SERVICE_NAME"
echo "  Image: $IMAGE_NAME"
echo ""

read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Rebuild cancelled."
  exit 1
fi

echo ""
echo -e "${YELLOW}Rebuilding image...${NC}"
echo ""

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}Error: Docker is not running${NC}"
  exit 1
fi

# Authenticate with GCR if needed
echo -e "${YELLOW}Configuring Docker authentication...${NC}"
gcloud auth configure-docker --quiet 2>/dev/null || true

# Build the image
echo ""
echo -e "${YELLOW}Building Docker image for linux/amd64...${NC}"
docker build --platform linux/amd64 -t "$IMAGE_NAME" .

# Push to GCR
echo ""
echo -e "${YELLOW}Pushing to Google Container Registry...${NC}"
docker push "$IMAGE_NAME"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Image Rebuilt Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Image available at: $IMAGE_NAME"
echo ""
echo -e "${GREEN}Next Cloud Run job will use the updated image.${NC}"
