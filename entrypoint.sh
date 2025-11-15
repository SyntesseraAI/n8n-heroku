#!/bin/sh

# check if port variable is set or go with default
if [ -z ${PORT+x} ]; then echo "PORT variable not defined, leaving N8N to default port."; else export N8N_PORT="$PORT"; echo "N8N will start on '$PORT'"; fi

# configure Google Cloud authentication if service account key is provided
if [ -n "${GCP_SERVICE_ACCOUNT_KEY:-}" ]; then
  echo "Configuring Google Cloud authentication..."
  echo "$GCP_SERVICE_ACCOUNT_KEY" | base64 -d > /tmp/gcp-key.json
  gcloud auth activate-service-account --key-file=/tmp/gcp-key.json
  if [ -n "${GCP_PROJECT_ID:-}" ]; then
    gcloud config set project "$GCP_PROJECT_ID"
    echo "GCP authentication configured for project: $GCP_PROJECT_ID"
  fi
  # Configure docker to use gcloud credentials for GCR
  gcloud auth configure-docker --quiet
  rm /tmp/gcp-key.json
else
  echo "GCP_SERVICE_ACCOUNT_KEY not set; Cloud Run functionality will not be available."
fi

# Configure Claude Code CLI authentication and GitHub MCP server if tokens are provided
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  export CLAUDE_CODE_OAUTH_TOKEN
  echo "CLAUDE_CODE_OAUTH_TOKEN detected; claude-code CLI authentication ready."

  # Add GitHub MCP server if token is available (requires runtime secret)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "Configuring GitHub MCP server..."
    claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $GITHUB_TOKEN"
  fi

  echo "Testing MCP server configuration..."
  claude -p "Hello Claude, describe your MCP servers"
else
  echo "CLAUDE_CODE_OAUTH_TOKEN not set; claude-code CLI will require authentication."
fi

# regex function
parse_url() {
  eval $(echo "$1" | sed -e "s#^\(\(.*\)://\)\?\(\([^:@]*\)\(:\(.*\)\)\?@\)\?\([^/?]*\)\(/\(.*\)\)\?#${PREFIX:-URL_}SCHEME='\2' ${PREFIX:-URL_}USER='\4' ${PREFIX:-URL_}PASSWORD='\6' ${PREFIX:-URL_}HOSTPORT='\7' ${PREFIX:-URL_}DATABASE='\9'#")
}

# prefix variables to avoid conflicts and run parse url function on arg url
PREFIX="N8N_DB_" parse_url "$DATABASE_URL"
echo "$N8N_DB_SCHEME://$N8N_DB_USER:$N8N_DB_PASSWORD@$N8N_DB_HOSTPORT/$N8N_DB_DATABASE"
# Separate host and port    
N8N_DB_HOST="$(echo $N8N_DB_HOSTPORT | sed -e 's,:.*,,g')"
N8N_DB_PORT="$(echo $N8N_DB_HOSTPORT | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"

export DB_TYPE=postgresdb
export DB_POSTGRESDB_HOST=$N8N_DB_HOST
export DB_POSTGRESDB_PORT=$N8N_DB_PORT
export DB_POSTGRESDB_DATABASE=$N8N_DB_DATABASE
export DB_POSTGRESDB_USER=$N8N_DB_USER
export DB_POSTGRESDB_PASSWORD=$N8N_DB_PASSWORD

# kickstart nodemation
n8n