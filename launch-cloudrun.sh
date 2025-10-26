#!/bin/bash
set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="${CLOUDRUN_SERVICE_NAME:-claude-code-runner}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
JOB_NAME="${SERVICE_NAME}-job-$(date +%s)"

# Resource configuration (can be set via environment variables or configure-cloudrun-resources.sh)
MEMORY="${CLOUDRUN_MEMORY:-4Gi}"
CPU="${CLOUDRUN_CPU:-2}"
TIMEOUT="${CLOUDRUN_TIMEOUT:-3600s}"
MAX_RETRIES="${CLOUDRUN_MAX_RETRIES:-0}"

# Help function
show_help() {
  cat << EOF
Usage: ./launch-cloudrun.sh [OPTIONS]

Launch a Google Cloud Run job to execute Claude Code with opusplan model.

Options:
  -p, --prompt PROMPT           The prompt to send to Claude Code (required)
  -m, --model MODEL             Claude model to use (default: opusplan)
  -P, --project PROJECT_ID      GCP Project ID (default: \$GCP_PROJECT_ID)
  -r, --region REGION           GCP Region (default: us-central1)
  -n, --name SERVICE_NAME       Service name (default: claude-code-runner)
  -v, --verbose                 Show verbose output (configuration, logs, resource usage)
  -h, --help                    Show this help message

Environment Variables:
  GCP_PROJECT_ID                Google Cloud Project ID
  GCP_REGION                    Google Cloud Region
  CLAUDE_CODE_OAUTH_TOKEN       Claude Code OAuth token (required)
  GITHUB_TOKEN                  GitHub token for MCP server (optional)
  CLOUDRUN_MEMORY               Memory limit (default: 4Gi)
  CLOUDRUN_CPU                  CPU count (default: 2)
  CLOUDRUN_TIMEOUT              Task timeout (default: 3600s)
  CLOUDRUN_MAX_RETRIES          Max retries (default: 0)

Examples:
  ./launch-cloudrun.sh -p "Create a new feature for user authentication"
  ./launch-cloudrun.sh -p "Review the code" --verbose
  ./launch-cloudrun.sh -p "Quick task" -m sonnet
EOF
}

# Parse command line arguments
PROMPT=""
MODEL="opusplan"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--prompt)
      PROMPT="$2"
      shift 2
      ;;
    -m|--model)
      MODEL="$2"
      shift 2
      ;;
    -P|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -n|--name)
      SERVICE_NAME="$2"
      IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$PROMPT" ]; then
  echo "Error: Prompt is required (-p or --prompt)"
  show_help
  exit 1
fi

if [ -z "$PROJECT_ID" ]; then
  echo "Error: GCP_PROJECT_ID must be set either as environment variable or via -P flag"
  exit 1
fi

if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
  echo "Error: CLAUDE_CODE_OAUTH_TOKEN environment variable is required"
  exit 1
fi

if [ "$VERBOSE" = true ]; then
  echo "=== Cloud Run Configuration ==="
  echo "Project ID: $PROJECT_ID"
  echo "Region: $REGION"
  echo "Service Name: $SERVICE_NAME"
  echo "Image: $IMAGE_NAME"
  echo "Job Name: $JOB_NAME"
  echo "Model: $MODEL"
  echo ""
  echo "=== Resource Configuration ==="
  echo "Memory: $MEMORY"
  echo "CPU: $CPU vCPU"
  echo "Timeout: $TIMEOUT"
  echo "Max Retries: $MAX_RETRIES"
  echo ""
  echo "=== Launching Cloud Run Job ==="
fi

# Create and execute Cloud Run job (suppress output unless verbose)
if [ "$VERBOSE" = true ]; then
  gcloud run jobs create "$JOB_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --set-env-vars="PROMPT=$PROMPT,CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN,MODEL=$MODEL" \
    --set-env-vars="GITHUB_TOKEN=${GITHUB_TOKEN:-}" \
    --memory="$MEMORY" \
    --cpu="$CPU" \
    --max-retries="$MAX_RETRIES" \
    --task-timeout="$TIMEOUT"
else
  gcloud run jobs create "$JOB_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --set-env-vars="PROMPT=$PROMPT,CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN,MODEL=$MODEL" \
    --set-env-vars="GITHUB_TOKEN=${GITHUB_TOKEN:-}" \
    --memory="$MEMORY" \
    --cpu="$CPU" \
    --max-retries="$MAX_RETRIES" \
    --task-timeout="$TIMEOUT" \
    --quiet 2>&1 >/dev/null
fi

if [ "$VERBOSE" = true ]; then
  echo "=== Executing Job ==="
fi

if [ "$VERBOSE" = true ]; then
  gcloud run jobs execute "$JOB_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --wait
else
  gcloud run jobs execute "$JOB_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --wait \
    --quiet 2>&1 >/dev/null
fi

# Fetch and display logs
if [ "$VERBOSE" = true ]; then
  echo "=== Fetching Job Logs ==="
  gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=$JOB_NAME" \
    --project="$PROJECT_ID" \
    --limit=50 \
    --format="table(timestamp,textPayload)"
  echo ""
  echo "=== Resource Usage Summary ==="
else
  # In quiet mode, only show the actual Claude output (no timestamps)
  gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=$JOB_NAME" \
    --project="$PROJECT_ID" \
    --limit=50 \
    --format="value(textPayload)" | grep -v "^$"
fi

# Resource usage summary (only in verbose mode)
if [ "$VERBOSE" = true ]; then
  # Get the execution name
  EXECUTION_NAME=$(gcloud run jobs executions list \
    --job="$JOB_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --limit=1 \
    --format="value(metadata.name)" 2>/dev/null || echo "")

  if [ -n "$EXECUTION_NAME" ]; then
    # Show execution details
    gcloud run jobs executions describe "$EXECUTION_NAME" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --format="table(
        metadata.name:label='Execution',
        status.startTime.date('%Y-%m-%d %H:%M:%S'):label='Start Time',
        status.completionTime.date('%Y-%m-%d %H:%M:%S'):label='End Time',
        status.succeededCount:label='Succeeded',
        status.failedCount:label='Failed',
        spec.template.spec.template.spec.containers[0].resources.limits.memory:label='Memory Limit',
        spec.template.spec.template.spec.containers[0].resources.limits.cpu:label='CPU Limit'
      )" 2>/dev/null || echo "Unable to fetch execution details"

    # Try to get resource usage from logs
    echo ""
    echo "Checking for resource usage in logs..."
    gcloud logging read "
      resource.type=cloud_run_job
      AND labels.\"run.googleapis.com/execution_name\"=\"$EXECUTION_NAME\"
      AND (
        textPayload=~'Memory usage'
        OR textPayload=~'CPU usage'
        OR severity=WARNING
      )
    " \
      --project="$PROJECT_ID" \
      --limit=10 \
      --format="table(timestamp,severity,textPayload)" \
      --order=asc 2>/dev/null || echo "No resource usage logs found"
  else
    echo "Unable to fetch execution details"
  fi

  echo ""
  echo "=== Cleaning Up ==="
fi

# Cleanup (always happens, but only announce in verbose mode)
if [ "$VERBOSE" = true ]; then
  echo "Deleting job: $JOB_NAME"
fi

gcloud run jobs delete "$JOB_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --quiet 2>&1 >/dev/null

if [ "$VERBOSE" = true ]; then
  echo "Cloud Run job completed successfully!"
fi
