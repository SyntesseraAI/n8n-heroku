FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache expect

WORKDIR /home/node/packages/cli
ENTRYPOINT []

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Copy the claude expect script
COPY ./claude.sh /home/node/packages/cli/claude.sh
RUN chmod +x /home/node/packages/cli/claude.sh

CMD ["/entrypoint.sh"]