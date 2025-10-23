FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache expect

WORKDIR /home/node/packages/cli
ENTRYPOINT []

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Copy the generic claude-run script
COPY ./claude-run.sh /home/node/packages/cli/claude-run.sh
RUN chmod +x /home/node/packages/cli/claude-run.sh

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

CMD ["/entrypoint.sh"]