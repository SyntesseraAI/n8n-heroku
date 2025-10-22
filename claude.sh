#!/usr/bin/expect -f
log_user 0
set timeout 300

# Get the command-line argument (the prompt)
set prompt [lindex $argv 0]

# Launch Claude with the prompt
spawn claude -p "$prompt"

# Capture and print only the output
expect {
    -re "(.+)" {
        puts $expect_out(1,string)
        exp_continue
    }
    eof
}
