#!/usr/bin/expect -f
log_user 1
set timeout 300

# Get the command-line argument (the prompt)
set prompt [lindex $argv 0]

# Launch Claude with the prompt
spawn claude -p "$prompt"

# Wait for Claude to complete and print the response
expect eof
