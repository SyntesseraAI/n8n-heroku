import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeConnectionTypes,
	NodeOperationError,
} from 'n8n-workflow';

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Helper function to strip ANSI escape codes and non-printable characters
function stripAnsiCodes(text: string): string {
	// Remove ANSI escape sequences (including color codes, cursor movement, etc.)
	// eslint-disable-next-line no-control-regex
	return text
		.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '') // ANSI CSI sequences
		.replace(/\x1b\][0-9;]*\x07/g, '') // OSC sequences
		.replace(/\x1b\][0-9;]*\x1b\\/g, '') // OSC sequences (alternative terminator)
		.replace(/\r\n/g, '\n') // Normalize line endings
		.replace(/\r/g, '\n') // Convert remaining CR to LF
		.replace(/\x1b[=>]/g, ''); // Other escape sequences
}

// Helper function to execute Cloud Run job
async function executeCloudRunJob(
	projectId: string,
	region: string,
	serviceName: string,
	prompt: string,
	model: string,
	claudeCodeOauthToken: string,
	githubToken: string,
	memory: string,
	cpu: string,
	timeout: string,
	maxRetries: string,
	verbose: boolean,
): Promise<string> {
	const imageName = `gcr.io/${projectId}/${serviceName}`;
	const jobName = `${serviceName}-job-${Date.now()}`;

	try {
		// Create Cloud Run job
		const envVars = [
			`PROMPT=${prompt.replace(/"/g, '\\"')}`,
			`CLAUDE_CODE_OAUTH_TOKEN=${claudeCodeOauthToken}`,
			`MODEL=${model}`,
			`GITHUB_TOKEN=${githubToken || ''}`,
		].join(',');

		const createCmd = `gcloud run jobs create "${jobName}" \
			--image="${imageName}" \
			--region="${region}" \
			--project="${projectId}" \
			--set-env-vars="${envVars}" \
			--memory="${memory}" \
			--cpu="${cpu}" \
			--max-retries="${maxRetries}" \
			--task-timeout="${timeout}" \
			--quiet`;

		if (verbose) {
			console.log(`Creating Cloud Run job: ${jobName}`);
		}

		await execAsync(createCmd);

		// Execute the job
		if (verbose) {
			console.log('Executing Cloud Run job...');
		}

		const executeCmd = `gcloud run jobs execute "${jobName}" \
			--region="${region}" \
			--project="${projectId}" \
			--wait \
			--quiet`;

		await execAsync(executeCmd);

		// Fetch logs
		if (verbose) {
			console.log('Fetching logs...');
		}

		const logsCmd = `gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=${jobName}" \
			--project="${projectId}" \
			--limit=50 \
			--format="${verbose ? 'table(timestamp,textPayload)' : 'value(textPayload)'}"`;

		const { stdout: logs } = await execAsync(logsCmd);

		// Delete the job (cleanup)
		if (verbose) {
			console.log('Cleaning up job...');
		}

		const deleteCmd = `gcloud run jobs delete "${jobName}" \
			--region="${region}" \
			--project="${projectId}" \
			--quiet`;

		await execAsync(deleteCmd);

		// Filter out empty lines and return
		const filteredLogs = logs
			.split('\n')
			.filter(line => line.trim() !== '')
			.join('\n');

		return stripAnsiCodes(filteredLogs);
	} catch (error) {
		// Try to cleanup even if there was an error
		try {
			const deleteCmd = `gcloud run jobs delete "${jobName}" \
				--region="${region}" \
				--project="${projectId}" \
				--quiet`;
			await execAsync(deleteCmd);
		} catch (cleanupError) {
			// Ignore cleanup errors
		}

		throw error;
	}
}

export class CloudRunDispatch implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Cloud Run Dispatch',
		name: 'cloudRunDispatch',
		icon: { light: 'file:cloudrun.svg', dark: 'file:cloudrun.svg' },
		group: ['transform'],
		version: 1,
		subtitle: '={{$parameter["model"]}}',
		description: 'Execute Claude Code on Google Cloud Run for scalable AI-powered coding',
		defaults: {
			name: 'Cloud Run Dispatch',
		},
		inputs: [NodeConnectionTypes.Main],
		outputs: [NodeConnectionTypes.Main],
		usableAsTool: true,
		credentials: [
			{
				name: 'gcpCloudRunApi',
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
				default: 'opusplan',
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
				displayName: 'Additional Options',
				name: 'additionalOptions',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				options: [
					{
						displayName: 'Memory',
						name: 'memory',
						type: 'string',
						default: '4Gi',
						description: 'Memory limit for Cloud Run job (e.g., 4Gi, 8Gi)',
					},
					{
						displayName: 'CPU',
						name: 'cpu',
						type: 'string',
						default: '2',
						description: 'Number of CPUs for Cloud Run job',
					},
					{
						displayName: 'Timeout',
						name: 'timeout',
						type: 'string',
						default: '3600s',
						description: 'Task timeout (e.g., 3600s for 1 hour)',
					},
					{
						displayName: 'Max Retries',
						name: 'maxRetries',
						type: 'string',
						default: '0',
						description: 'Maximum number of retries for failed tasks',
					},
					{
						displayName: 'Verbose',
						name: 'verbose',
						type: 'boolean',
						default: false,
						description: 'Whether to include timestamps and detailed logs in output',
					},
				],
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const returnData: INodeExecutionData[] = [];

		// Get credentials
		const credentials = await this.getCredentials('gcpCloudRunApi');
		const projectId = credentials.projectId as string;
		const region = credentials.region as string;
		const serviceName = credentials.serviceName as string;
		const claudeCodeOauthToken = credentials.claudeCodeOauthToken as string;
		const githubToken = (credentials.githubToken as string) || '';

		for (let i = 0; i < items.length; i++) {
			try {
				// Get parameters
				const model = this.getNodeParameter('model', i) as string;
				const prompt = this.getNodeParameter('prompt', i) as string;
				const additionalOptions = this.getNodeParameter('additionalOptions', i, {}) as {
					memory?: string;
					cpu?: string;
					timeout?: string;
					maxRetries?: string;
					verbose?: boolean;
				};

				const memory = additionalOptions.memory || '4Gi';
				const cpu = additionalOptions.cpu || '2';
				const timeout = additionalOptions.timeout || '3600s';
				const maxRetries = additionalOptions.maxRetries || '0';
				const verbose = additionalOptions.verbose || false;

				// Execute Cloud Run job
				const output = await executeCloudRunJob(
					projectId,
					region,
					serviceName,
					prompt,
					model,
					claudeCodeOauthToken,
					githubToken,
					memory,
					cpu,
					timeout,
					maxRetries,
					verbose,
				);

				returnData.push({
					json: {
						model,
						prompt,
						output,
						projectId,
						region,
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
				// Adding itemIndex allows other workflows to handle this error
				if (error instanceof Error && (error as any).context) {
					// If the error thrown already contains the context property,
					// only append the itemIndex
					(error as any).context.itemIndex = i;
					throw error;
				}
				throw new NodeOperationError(this.getNode(), error as Error, {
					itemIndex: i,
				});
			}
		}

		return [returnData];
	}
}
