FROM node:18-alpine

# Install bash (no longer need expect - Claude Code runs natively with OAuth)
RUN apk add --no-cache bash

WORKDIR /app

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Pre-configure MCP servers (non-secret ones)
# Note: GitHub MCP server requires GITHUB_TOKEN, so it's configured at runtime
RUN claude mcp add --transport http mermaidchart "https://mcp.mermaidchart.com/mcp" || true && \
    claude mcp add --transport stdio codacy -- npx -y @codacy/codacy-mcp@latest || true && \
    claude mcp add --transport http context7 https://mcp.context7.com/mcp || true && \
    claude mcp add --transport stdio shadcn -- npx shadcn@latest mcp || true

# Copy the startup script (runs Claude Code natively, no separate opusplan.sh needed)
COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

# Set environment variables for Claude Code
ENV NODE_ENV=production

ENTRYPOINT ["/app/startup.sh"]
