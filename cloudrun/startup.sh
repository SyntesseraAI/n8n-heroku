#!/bin/bash
set -e

# Configure Claude Code CLI authentication and GitHub MCP server if tokens are provided
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  export CLAUDE_CODE_OAUTH_TOKEN

  # Add GitHub MCP server if token is available (requires runtime secret)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer $GITHUB_TOKEN" 2>&1 >/dev/null || true
  fi
else
  echo "Error: CLAUDE_CODE_OAUTH_TOKEN not set" >&2
  exit 1
fi

# Check if PROMPT is provided
if [ -z "${PROMPT:-}" ]; then
  echo "Error: PROMPT environment variable is required" >&2
  exit 1
fi

# Set default model if not provided
MODEL="${MODEL:-opusplan}"

# Execute Claude Code with the prompt and all MCP servers
exec claude --allowedTools --model "$MODEL" \
  "mcp__github" \
  "mcp__mermaidchart" \
  "mcp__codacy" \
  "mcp__context7" \
  "mcp__shadcn" \
  -p "$PROMPT"
