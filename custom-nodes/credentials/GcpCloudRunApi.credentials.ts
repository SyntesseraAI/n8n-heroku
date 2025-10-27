import {
	IAuthenticateGeneric,
	ICredentialTestRequest,
	ICredentialType,
	INodeProperties,
} from 'n8n-workflow';

export class GcpCloudRunApi implements ICredentialType {
	name = 'gcpCloudRunApi';
	displayName = 'GCP Cloud Run API';
	documentationUrl = 'https://cloud.google.com/run/docs';
	properties: INodeProperties[] = [
		{
			displayName: 'Project ID',
			name: 'projectId',
			type: 'string',
			default: '',
			required: true,
			description: 'The Google Cloud Project ID',
		},
		{
			displayName: 'Region',
			name: 'region',
			type: 'string',
			default: 'us-central1',
			required: true,
			description: 'The GCP region for Cloud Run (e.g., us-central1)',
		},
		{
			displayName: 'Service Name',
			name: 'serviceName',
			type: 'string',
			default: 'claude-code-runner',
			required: true,
			description: 'The Cloud Run service name',
		},
		{
			displayName: 'Claude Code OAuth Token',
			name: 'claudeCodeOauthToken',
			type: 'string',
			typeOptions: {
				password: true,
			},
			default: '',
			required: true,
			description: 'The Claude Code OAuth token for authentication',
		},
		{
			displayName: 'GitHub Token',
			name: 'githubToken',
			type: 'string',
			typeOptions: {
				password: true,
			},
			default: '',
			required: false,
			description: 'GitHub token for MCP server (optional)',
		},
	];

	authenticate: IAuthenticateGeneric = {
		type: 'generic',
		properties: {},
	};

	test: ICredentialTestRequest = {
		request: {
			baseURL: '=https://{{$credentials.region}}-run.googleapis.com',
			url: '=/v2/projects/{{$credentials.projectId}}/locations/{{$credentials.region}}/services',
			method: 'GET',
		},
	};
}
