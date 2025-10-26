#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cloud Run Job Monitoring${NC}"
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

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID: $GCP_PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  Service Name: $SERVICE_NAME"
echo ""

# Function to monitor a specific job execution
monitor_execution() {
  local execution_name=$1

  echo -e "${BLUE}=== Execution Details ===${NC}"
  gcloud run jobs executions describe "$execution_name" \
    --region="$GCP_REGION" \
    --project="$GCP_PROJECT_ID" \
    --format="table(
      metadata.name,
      status.completionTime.yesno(no='Running'),
      status.succeededCount,
      status.failedCount,
      spec.template.spec.template.spec.containers[0].resources.limits.memory,
      spec.template.spec.template.spec.containers[0].resources.limits.cpu
    )"

  echo ""
  echo -e "${BLUE}=== Resource Usage Logs ===${NC}"
  gcloud logging read "
    resource.type=cloud_run_job
    AND labels.\"run.googleapis.com/execution_name\"=\"$execution_name\"
    AND (
      textPayload=~'Memory usage'
      OR textPayload=~'CPU usage'
      OR textPayload=~'memory'
      OR textPayload=~'cpu'
    )
  " \
    --project="$GCP_PROJECT_ID" \
    --limit=20 \
    --format="table(timestamp,textPayload)" \
    --order=asc

  echo ""
  echo -e "${BLUE}=== Execution Logs (Last 30 entries) ===${NC}"
  gcloud logging read "
    resource.type=cloud_run_job
    AND labels.\"run.googleapis.com/execution_name\"=\"$execution_name\"
  " \
    --project="$GCP_PROJECT_ID" \
    --limit=30 \
    --format="table(timestamp,textPayload)" \
    --order=asc
}

# List recent job executions
echo -e "${YELLOW}Fetching recent job executions...${NC}"
echo ""

# Get all jobs matching the service name pattern
JOBS=$(gcloud run jobs list \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT_ID" \
  --format="value(metadata.name)" \
  --filter="metadata.name ~ ${SERVICE_NAME}")

if [ -z "$JOBS" ]; then
  echo -e "${RED}No jobs found matching service name: $SERVICE_NAME${NC}"
  exit 1
fi

# Get executions for each job
echo -e "${BLUE}=== Recent Job Executions ===${NC}"
EXECUTION_LIST=""
for job in $JOBS; do
  executions=$(gcloud run jobs executions list \
    --job="$job" \
    --region="$GCP_REGION" \
    --project="$GCP_PROJECT_ID" \
    --limit=5 \
    --format="value(metadata.name)" 2>/dev/null || true)

  if [ -n "$executions" ]; then
    EXECUTION_LIST="$EXECUTION_LIST$executions"$'\n'
  fi
done

if [ -z "$EXECUTION_LIST" ]; then
  echo -e "${RED}No executions found for jobs matching: $SERVICE_NAME${NC}"
  exit 0
fi

# Display executions with numbers
echo ""
i=1
declare -a execution_array
while IFS= read -r execution; do
  if [ -n "$execution" ]; then
    execution_array[$i]=$execution
    # Get basic info
    info=$(gcloud run jobs executions describe "$execution" \
      --region="$GCP_REGION" \
      --project="$GCP_PROJECT_ID" \
      --format="value(status.completionTime.date('%Y-%m-%d %H:%M:%S'),status.succeededCount)" 2>/dev/null || echo "Unknown,0")

    completion_time=$(echo "$info" | cut -d',' -f1)
    succeeded=$(echo "$info" | cut -d',' -f2)

    status_icon="${GREEN}✓${NC}"
    if [ "$succeeded" = "0" ]; then
      status_icon="${RED}✗${NC}"
    fi

    echo -e "  ${BLUE}[$i]${NC} $execution - $completion_time $status_icon"
    ((i++))
  fi
done <<< "$EXECUTION_LIST"

echo ""
read -p "Enter execution number to monitor (or 'q' to quit): " choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
  echo "Exiting..."
  exit 0
fi

# Validate choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
  echo -e "${RED}Invalid choice${NC}"
  exit 1
fi

selected_execution=${execution_array[$choice]}

echo ""
echo -e "${GREEN}Monitoring execution: $selected_execution${NC}"
echo ""

monitor_execution "$selected_execution"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Monitoring Complete${NC}"
echo -e "${GREEN}========================================${NC}"
