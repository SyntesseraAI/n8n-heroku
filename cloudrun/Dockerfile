FROM node:18-alpine

# Install expect and bash
RUN apk add --no-cache expect bash

WORKDIR /app

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Pre-configure MCP servers (non-secret ones)
# Note: GitHub MCP server requires GITHUB_TOKEN, so it's configured at runtime
RUN claude mcp add --transport http mermaidchart "https://mcp.mermaidchart.com/mcp" || true && \
    claude mcp add --transport stdio codacy -- npx -y @codacy/codacy-mcp@latest || true && \
    claude mcp add --transport http context7 https://mcp.context7.com/mcp || true && \
    claude mcp add --transport stdio shadcn -- npx shadcn@latest mcp || true

# Copy the opusplan script
COPY opusplan.sh /app/opusplan.sh
RUN chmod +x /app/opusplan.sh

# Copy the startup script
COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

# Set environment variables for Claude Code
ENV NODE_ENV=production

ENTRYPOINT ["/app/startup.sh"]
