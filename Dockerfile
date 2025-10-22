FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache expect

WORKDIR /home/node/packages/cli
ENTRYPOINT []

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Create the simplified claude expect script
RUN echo '#!/usr/bin/expect -f\n\
log_user 1\n\
set timeout 300\n\
\n\
# Get the command-line argument (the prompt)\n\
set prompt [lindex $argv 0]\n\
\n\
# Launch Claude with the prompt\n\
spawn claude -p "$prompt"\n\
\n\
# Wait for Claude to complete and print the response\n\
expect eof\n\
' > /home/node/packages/cli/claude-expect.sh && chmod +x /home/node/packages/cli/claude-expect.sh

CMD ["/entrypoint.sh"]