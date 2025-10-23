#!/usr/bin/expect -f
log_user 0
set timeout 3600

# Get the prompt from argument or stdin
if {[llength $argv] > 0} {
    set prompt [lindex $argv 0]
} else {
    set prompt [read stdin]
}

# Launch Claude with the prompt
spawn claude --allowedTools --model sonnet "mcp__github" -p "$prompt"

# Capture and print only the output
expect {
    -re "(.+)" {
        puts $expect_out(1,string)
        exp_continue
    }
    eof
}
