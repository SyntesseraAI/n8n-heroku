#!/usr/bin/expect -f
log_user 0
set timeout 3600

# Get the command-line arguments (model and prompt)
set model [lindex $argv 0]
set prompt [lindex $argv 1]

# Launch Claude with the prompt
spawn claude --allowedTools --model $model "mcp__github" -p "$prompt"

# Capture and print only the output
expect {
    -re "(.+)" {
        puts $expect_out(1,string)
        exp_continue
    }
    eof
}
