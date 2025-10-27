#!/usr/bin/env node

const pty = require('node-pty');

// Helper function to strip ANSI escape codes and non-printable characters
function stripAnsiCodes(text) {
	// Remove ANSI escape sequences (including color codes, cursor movement, etc.)
	return text
		.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '') // ANSI CSI sequences
		.replace(/\x1b\][0-9;]*\x07/g, '') // OSC sequences
		.replace(/\x1b\][0-9;]*\x1b\\/g, '') // OSC sequences (alternative terminator)
		.replace(/\r\n/g, '\n') // Normalize line endings
		.replace(/\r/g, '\n') // Convert remaining CR to LF
		.replace(/\x1b[=>]/g, ''); // Other escape sequences
}

// Get environment variables
const prompt = process.env.PROMPT;
const model = process.env.MODEL || 'opusplan';
const claudeCodeOauthToken = process.env.CLAUDE_CODE_OAUTH_TOKEN;
const githubToken = process.env.GITHUB_TOKEN;

// Validate required environment variables
if (!prompt) {
	console.error('Error: PROMPT environment variable is required');
	process.exit(1);
}

if (!claudeCodeOauthToken) {
	console.error('Error: CLAUDE_CODE_OAUTH_TOKEN environment variable is required');
	process.exit(1);
}

// Configure GitHub MCP server if token is available
if (githubToken) {
	console.log('Configuring GitHub MCP server...');
	const configProcess = pty.spawn('claude', [
		'mcp',
		'add',
		'--transport',
		'http',
		'github',
		'https://api.githubcopilot.com/mcp',
		'-H',
		`Authorization: Bearer ${githubToken}`
	], {
		name: 'xterm-color',
		cols: 120,
		rows: 30,
		env: {
			...process.env,
			CLAUDE_CODE_OAUTH_TOKEN: claudeCodeOauthToken,
		},
	});

	configProcess.onExit(({ exitCode }) => {
		// Continue even if GitHub MCP setup fails
		if (exitCode !== 0) {
			console.log('GitHub MCP server configuration failed, continuing without it...');
		}
		runClaudeCode();
	});
} else {
	runClaudeCode();
}

function runClaudeCode() {
	console.log(`Executing Claude Code with model: ${model}`);

	let output = '';

	// Build arguments for Claude Code
	const args = [
		'--allowedTools',
		'--model',
		model,
		'mcp__github',
		'mcp__mermaidchart',
		'mcp__codacy',
		'mcp__context7',
		'mcp__shadcn',
		'-p',
		prompt,
	];

	// Spawn Claude Code using pty
	const childProcess = pty.spawn('claude', args, {
		name: 'xterm-color',
		cols: 120,
		rows: 30,
		env: {
			...process.env,
			CLAUDE_CODE_OAUTH_TOKEN: claudeCodeOauthToken,
		},
	});

	// Capture output
	childProcess.onData((data) => {
		output += data;
		// Print in real-time (will be captured by Cloud Run logs)
		process.stdout.write(data);
	});

	// Handle process exit
	childProcess.onExit(({ exitCode, signal }) => {
		if (exitCode === 0) {
			console.log('\n--- Claude Code execution completed successfully ---');
			process.exit(0);
		} else {
			console.error(`\nClaude Code exited with code ${exitCode}${signal ? ` (signal: ${signal})` : ''}`);
			process.exit(exitCode || 1);
		}
	});

	// Handle errors
	childProcess.on('error', (err) => {
		console.error('Error spawning Claude Code:', err);
		process.exit(1);
	});
}
