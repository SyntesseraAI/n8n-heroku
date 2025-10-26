FROM node:18-alpine

# Install expect and bash
RUN apk add --no-cache expect bash

WORKDIR /app

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Copy the opusplan script
COPY opusplan.sh /app/opusplan.sh
RUN chmod +x /app/opusplan.sh

# Copy the startup script
COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

# Set environment variables for Claude Code
ENV NODE_ENV=production

ENTRYPOINT ["/app/startup.sh"]
