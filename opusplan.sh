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
spawn claude --allowedTools --model opusplan "mcp__github" -p "$prompt"

# Capture and print only the output, filtering ANSI escape sequences
expect {
    -re "(.+)" {
        set output $expect_out(1,string)
        # Remove ANSI escape sequences including cursor visibility codes
        regsub -all "\033\\\[\\?25h" $output "" output
        regsub -all "\033\\\[[0-9;]*m" $output "" output
        if {[string length $output] > 0} {
            puts $output
        }
        exp_continue
    }
    eof
}
