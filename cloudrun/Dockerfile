FROM node:22-alpine

# Install bash and build dependencies for node-pty
RUN apk add --no-cache bash python3 make g++

WORKDIR /app

# Install Claude Code CLI and node-pty globally
RUN npm install -g @anthropic-ai/claude-code node-pty

# Pre-configure MCP servers (non-secret ones)
# Note: GitHub MCP server requires GITHUB_TOKEN, so it's configured at runtime
RUN claude mcp add --transport http mermaidchart "https://mcp.mermaidchart.com/mcp" || true && \
    claude mcp add --transport stdio codacy -- npx -y @codacy/codacy-mcp@latest || true && \
    claude mcp add --transport http context7 https://mcp.context7.com/mcp || true && \
    claude mcp add --transport stdio shadcn -- npx shadcn@latest mcp || true

# Copy the Node.js runner script
COPY run-claude.js /app/run-claude.js
RUN chmod +x /app/run-claude.js

# Copy the startup script
COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

# Set environment variables for Claude Code
ENV NODE_ENV=production

ENTRYPOINT ["/app/startup.sh"]
