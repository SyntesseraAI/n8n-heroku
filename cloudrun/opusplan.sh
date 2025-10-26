#!/usr/bin/expect -f
log_user 0
set timeout 3600

# Get the prompt from argument or stdin
if {[llength $argv] > 0} {
    set prompt [lindex $argv 0]
} else {
    set prompt [read stdin]
}

# Launch Claude with the prompt and all MCP servers
spawn claude --allowedTools --model opusplan "mcp__github" "mcp__mermaidchart" "mcp__codacy" "mcp__context7" "mcp__shadcn" -p "$prompt"

# Capture and print only the output
expect {
    -re "(.+)" {
        puts $expect_out(1,string)
        exp_continue
    }
    eof
}
