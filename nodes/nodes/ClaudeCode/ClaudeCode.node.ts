import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

import { spawn } from 'child_process';

// Helper function to execute Claude Code
function executeClaudeCode(
	args: string[],
	oauthToken: string,
	timeout: number,
	workingDirectory: string,
): Promise<string> {
	return new Promise((resolve, reject) => {
		let output = '';
		let errorOutput = '';

		// Set up environment with OAuth token
		const env = {
			...process.env,
			CLAUDE_CODE_OAUTH_TOKEN: oauthToken,
		};

		// Spawn the claude process
		const childProcess = spawn('claude', args, {
			env,
			cwd: workingDirectory,
			shell: true,
		});

		// Set timeout
		const timeoutId = setTimeout(() => {
			childProcess.kill();
			reject(new Error(`Claude Code execution timed out after ${timeout / 1000} seconds`));
		}, timeout);

		// Capture stdout
		childProcess.stdout.on('data', (data: Buffer) => {
			output += data.toString();
		});

		// Capture stderr
		childProcess.stderr.on('data', (data: Buffer) => {
			errorOutput += data.toString();
		});

		// Handle process exit
		childProcess.on('close', (code: number | null) => {
			clearTimeout(timeoutId);

			if (code === 0) {
				resolve(output);
			} else {
				reject(
					new Error(
						`Claude Code exited with code ${code}. Error: ${errorOutput || 'No error output'}`,
					),
				);
			}
		});

		// Handle errors
		childProcess.on('error', (error: Error) => {
			clearTimeout(timeoutId);
			reject(new Error(`Failed to execute Claude Code: ${error.message}`));
		});
	});
}

export class ClaudeCode implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Claude Code',
		name: 'claudeCode',
		icon: 'file:claude-code.svg',
		group: ['transform'],
		version: 1,
		subtitle: '={{$parameter["model"]}}',
		description: 'Execute Claude Code with AI-powered coding assistance',
		defaults: {
			name: 'Claude Code',
		},
		inputs: ['main'],
		outputs: ['main'],
		credentials: [
			{
				name: 'claudeCodeApi',
				required: true,
			},
		],
		properties: [
			{
				displayName: 'Model',
				name: 'model',
				type: 'options',
				options: [
					{
						name: 'Sonnet 4.5',
						value: 'sonnet',
						description: 'Claude Sonnet 4.5 - Balanced performance and speed',
					},
					{
						name: 'Opus 4',
						value: 'opus',
						description: 'Claude Opus 4 - Highest intelligence',
					},
					{
						name: 'Opus Plan',
						value: 'opusplan',
						description: 'Claude Opus with planning mode - Best for complex tasks',
					},
					{
						name: 'Haiku 4',
						value: 'haiku',
						description: 'Claude Haiku 4 - Fastest responses',
					},
				],
				default: 'sonnet',
				description: 'The Claude model to use for code execution',
			},
			{
				displayName: 'Prompt',
				name: 'prompt',
				type: 'string',
				typeOptions: {
					rows: 4,
				},
				default: '',
				required: true,
				description: 'The task or prompt to send to Claude Code',
			},
			{
				displayName: 'MCP Servers',
				name: 'mcpServers',
				type: 'string',
				default: 'mcp__github mcp__codacy mcp__context7 mcp__mermaidchart mcp__shadcn',
				description: 'Space-separated list of MCP servers to enable (all installed servers by default)',
			},
			{
				displayName: 'Additional Options',
				name: 'additionalOptions',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				options: [
					{
						displayName: 'Timeout (seconds)',
						name: 'timeout',
						type: 'number',
						default: 3600,
						description: 'Maximum execution time in seconds',
					},
					{
						displayName: 'Allow All Tools',
						name: 'allowedTools',
						type: 'boolean',
						default: true,
						description: 'Whether to allow Claude Code to use all available tools',
					},
					{
						displayName: 'Working Directory',
						name: 'workingDirectory',
						type: 'string',
						default: '',
						description: 'Working directory for Claude Code execution',
					},
				],
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const returnData: INodeExecutionData[] = [];

		// Get credentials
		const credentials = await this.getCredentials('claudeCodeApi');
		const oauthToken = credentials.oauthToken as string;

		for (let i = 0; i < items.length; i++) {
			try {
				// Get parameters
				const model = this.getNodeParameter('model', i) as string;
				const prompt = this.getNodeParameter('prompt', i) as string;
				const mcpServers = this.getNodeParameter('mcpServers', i, 'mcp__github mcp__codacy mcp__context7 mcp__mermaidchart mcp__shadcn') as string;
				const additionalOptions = this.getNodeParameter('additionalOptions', i, {}) as {
					timeout?: number;
					allowedTools?: boolean;
					workingDirectory?: string;
				};

				const timeout = additionalOptions.timeout || 3600;
				const allowedTools = additionalOptions.allowedTools !== false;
				const workingDirectory = additionalOptions.workingDirectory || process.cwd();

				// Build command arguments
				const args: string[] = [];

				if (allowedTools) {
					args.push('--allowedTools');
				}

				args.push('--model', model);

				// Add MCP servers (space-separated)
				if (mcpServers) {
					const servers = mcpServers.split(/\s+/).filter(s => s);
					servers.forEach(server => {
						args.push(server);
					});
				}

				args.push('-p', prompt);

				// Execute Claude Code
				const output = await executeClaudeCode(
					args,
					oauthToken,
					timeout * 1000,
					workingDirectory,
				);

				returnData.push({
					json: {
						model,
						prompt,
						output,
						success: true,
					},
					pairedItem: i,
				});
			} catch (error) {
				if (this.continueOnFail()) {
					returnData.push({
						json: {
							error: error instanceof Error ? error.message : String(error),
							success: false,
						},
						pairedItem: i,
					});
					continue;
				}
				throw error;
			}
		}

		return [returnData];
	}
}
