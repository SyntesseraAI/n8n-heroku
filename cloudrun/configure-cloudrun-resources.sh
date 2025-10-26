#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cloud Run Resource Configuration${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to show available resource options
show_resource_options() {
  cat << EOF
${BLUE}Available Resource Configurations:${NC}

${YELLOW}Memory Options:${NC}
  - 512Mi   (minimum)
  - 1Gi
  - 2Gi
  - 4Gi     (current default)
  - 8Gi
  - 16Gi
  - 32Gi    (maximum)

${YELLOW}CPU Options:${NC}
  - 1       (1 vCPU)
  - 2       (2 vCPU - current default)
  - 4       (4 vCPU)
  - 8       (8 vCPU - maximum)

${YELLOW}Timeout Options:${NC}
  - 300s    (5 minutes)
  - 600s    (10 minutes)
  - 1800s   (30 minutes)
  - 3600s   (1 hour - current default)

${YELLOW}Note:${NC} Higher CPU counts require proportionally higher memory.
Minimum ratios:
  - 1 CPU:  512Mi - 4Gi
  - 2 CPU:  1Gi - 8Gi
  - 4 CPU:  2Gi - 16Gi
  - 8 CPU:  4Gi - 32Gi

EOF
}

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
show_resource_options

# Get memory configuration
DEFAULT_MEMORY="${CLOUDRUN_MEMORY:-4Gi}"
read -p "Enter memory limit [${DEFAULT_MEMORY}]: " INPUT_MEMORY
MEMORY=${INPUT_MEMORY:-$DEFAULT_MEMORY}

# Validate memory format
if ! [[ "$MEMORY" =~ ^[0-9]+(Mi|Gi)$ ]]; then
  echo -e "${RED}Error: Invalid memory format. Use format like '4Gi' or '512Mi'${NC}"
  exit 1
fi

# Get CPU configuration
DEFAULT_CPU="${CLOUDRUN_CPU:-2}"
read -p "Enter CPU count [${DEFAULT_CPU}]: " INPUT_CPU
CPU=${INPUT_CPU:-$DEFAULT_CPU}

# Validate CPU
if ! [[ "$CPU" =~ ^[1248]$ ]]; then
  echo -e "${RED}Error: Invalid CPU count. Must be 1, 2, 4, or 8${NC}"
  exit 1
fi

# Get timeout configuration
DEFAULT_TIMEOUT="${CLOUDRUN_TIMEOUT:-3600s}"
read -p "Enter task timeout [${DEFAULT_TIMEOUT}]: " INPUT_TIMEOUT
TIMEOUT=${INPUT_TIMEOUT:-$DEFAULT_TIMEOUT}

# Validate timeout format
if ! [[ "$TIMEOUT" =~ ^[0-9]+s$ ]]; then
  echo -e "${RED}Error: Invalid timeout format. Use format like '3600s'${NC}"
  exit 1
fi

# Get max retries
DEFAULT_RETRIES="${CLOUDRUN_MAX_RETRIES:-0}"
read -p "Enter max retries [${DEFAULT_RETRIES}]: " INPUT_RETRIES
MAX_RETRIES=${INPUT_RETRIES:-$DEFAULT_RETRIES}

# Validate retries
if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: Invalid max retries. Must be a number${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}Configuration Summary:${NC}"
echo "  Project ID:    $GCP_PROJECT_ID"
echo "  Region:        $GCP_REGION"
echo "  Service Name:  $SERVICE_NAME"
echo "  Memory:        $MEMORY"
echo "  CPU:           $CPU vCPU"
echo "  Timeout:       $TIMEOUT"
echo "  Max Retries:   $MAX_RETRIES"
echo ""

# Calculate estimated cost per hour (rough estimate for us-central1)
# Cloud Run Jobs pricing: $0.00002400 per vCPU-second, $0.00000250 per GiB-second
# Convert timeout to seconds
TIMEOUT_SECONDS=${TIMEOUT%s}

# Extract memory number and unit
MEMORY_NUM=${MEMORY%[GM]i}
MEMORY_UNIT=${MEMORY#${MEMORY_NUM}}

# Convert to GiB
if [ "$MEMORY_UNIT" = "Mi" ]; then
  MEMORY_GIB=$(echo "scale=2; $MEMORY_NUM / 1024" | bc)
else
  MEMORY_GIB=$MEMORY_NUM
fi

# Calculate cost per execution
CPU_COST=$(echo "scale=4; $CPU * $TIMEOUT_SECONDS * 0.00002400" | bc)
MEMORY_COST=$(echo "scale=4; $MEMORY_GIB * $TIMEOUT_SECONDS * 0.00000250" | bc)
TOTAL_COST=$(echo "scale=4; $CPU_COST + $MEMORY_COST" | bc)

echo -e "${BLUE}Estimated cost per job execution (if runs full timeout):${NC}"
echo "  CPU cost:      \$${CPU_COST}"
echo "  Memory cost:   \$${MEMORY_COST}"
echo "  Total:         \$${TOTAL_COST}"
echo ""
echo -e "${YELLOW}Note: Actual cost depends on execution time. Jobs are billed per second.${NC}"
echo ""

read -p "Apply this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Configuration cancelled."
  exit 1
fi

echo ""
echo -e "${YELLOW}Updating environment variables...${NC}"

# Create or update .env file for future reference
ENV_FILE="cloudrun/.env.resources"
cat > "$ENV_FILE" << EOF
# Cloud Run Resource Configuration
# Generated on $(date)
export CLOUDRUN_MEMORY="$MEMORY"
export CLOUDRUN_CPU="$CPU"
export CLOUDRUN_TIMEOUT="$TIMEOUT"
export CLOUDRUN_MAX_RETRIES="$MAX_RETRIES"
EOF

echo -e "${GREEN}✓ Configuration saved to: $ENV_FILE${NC}"
echo ""
echo -e "${YELLOW}To use these settings:${NC}"
echo "  source $ENV_FILE"
echo ""
echo -e "${YELLOW}Or export them manually:${NC}"
echo "  export CLOUDRUN_MEMORY=\"$MEMORY\""
echo "  export CLOUDRUN_CPU=\"$CPU\""
echo "  export CLOUDRUN_TIMEOUT=\"$TIMEOUT\""
echo "  export CLOUDRUN_MAX_RETRIES=\"$MAX_RETRIES\""
echo ""
echo -e "${BLUE}These settings will be used by launch-cloudrun.sh${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration Complete${NC}"
echo -e "${GREEN}========================================${NC}"
