#!/bin/bash
set -e

echo "Starting Cloud Run Claude Code container..."



# Configure Claude Code with OAuth token if provided
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  # Ensure required global tooling is available
  echo "Installing @anthropic-ai/claude-code globally..."
  npm install -g @anthropic-ai/claude-code
  
  export CLAUDE_CODE_OAUTH_TOKEN
  echo "CLAUDE_CODE_OAUTH_TOKEN detected; claude-code CLI authentication ready."

  # Add MCP servers
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "Adding GitHub MCP server..."
    claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $GITHUB_TOKEN"
  fi

  echo "Adding Mermaid Chart MCP server..."
  claude mcp add --transport http mermaidchart "https://mcp.mermaidchart.com/mcp"

  echo "Adding Codacy MCP server..."
  claude mcp add --transport stdio codacy -- npx -y @codacy/codacy-mcp@latest

  echo "Adding Context7 MCP server..."
  claude mcp add --transport http context7 https://mcp.context7.com/mcp

  echo "Adding shadcn MCP server..."
  claude mcp add --transport stdio shadcn -- npx shadcn@latest mcp

  echo "Testing MCP server configuration..."
  claude -p "Hello Claude, describe your MCP servers"
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
