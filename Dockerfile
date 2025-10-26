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

CMD ["/entrypoint.sh"]