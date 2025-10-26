#!/bin/bash
set -e

echo "Starting Cloud Run Claude Code container..."



# Configure Claude Code CLI authentication and GitHub MCP server if tokens are provided
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  export CLAUDE_CODE_OAUTH_TOKEN
  echo "CLAUDE_CODE_OAUTH_TOKEN detected; claude-code CLI authentication ready."

  # Add GitHub MCP server if token is available (requires runtime secret)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "Configuring GitHub MCP server..."
    claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $GITHUB_TOKEN"
  fi
else
  echo "Warning: CLAUDE_CODE_OAUTH_TOKEN not set; claude-code CLI may require authentication."
fi

# Check if PROMPT is provided
if [ -z "${PROMPT:-}" ]; then
  echo "Error: PROMPT environment variable is required"
  exit 1
fi

echo "Executing opusplan.sh with prompt..."
echo "$PROMPT" | /app/opusplan.sh

echo "Cloud Run job completed successfully"
