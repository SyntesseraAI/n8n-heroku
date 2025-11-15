# Builder stage for custom nodes
FROM n8nio/n8n:latest AS builder

USER root

# Install build dependencies for native modules
RUN apk add --no-cache make g++ python3

# Build custom n8n nodes
COPY ./custom-nodes /tmp/custom-nodes
WORKDIR /tmp/custom-nodes
RUN npm install --include=dev && \
    npm run build

# Final stage
FROM n8nio/n8n:latest

USER root

# Install expect, docker client, and google cloud SDK
RUN apk add --no-cache expect docker-cli python3 py3-pip curl bash && \
    curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/usr/local

# Add gcloud to PATH
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

WORKDIR /home/node/packages/cli
ENTRYPOINT []

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Copy the sonnet expect script
COPY ./sonnet.sh /home/node/packages/cli/sonnet.sh
RUN chmod +x /home/node/packages/cli/sonnet.sh

# Copy the opus expect script
COPY ./opus.sh /home/node/packages/cli/opus.sh
RUN chmod +x /home/node/packages/cli/opus.sh

# Copy the haiku expect script
COPY ./haiku.sh /home/node/packages/cli/haiku.sh
RUN chmod +x /home/node/packages/cli/haiku.sh

# Copy the opusplan expect script
COPY ./opusplan.sh /home/node/packages/cli/opusplan.sh
RUN chmod +x /home/node/packages/cli/opusplan.sh

# Copy the Cloud Run launcher script
COPY ./launch-cloudrun.sh /home/node/packages/cli/launch-cloudrun
RUN chmod +x /home/node/packages/cli/launch-cloudrun

# Copy built custom nodes from builder stage
RUN mkdir -p /home/node/packages/cli/.n8n/custom
COPY --from=builder /tmp/custom-nodes /home/node/packages/cli/.n8n/custom/n8n-custom-nodes
RUN chown -R node:node /home/node/packages/cli/.n8n

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /home/node/packages/cli

CMD ["/entrypoint.sh"]