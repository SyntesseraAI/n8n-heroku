import {
	IAuthenticateGeneric,
	ICredentialTestRequest,
	ICredentialType,
	INodeProperties,
} from 'n8n-workflow';

export class ClaudeCodeApi implements ICredentialType {
	name = 'claudeCodeApi';
	displayName = 'Claude Code API';
	documentationUrl = 'https://docs.anthropic.com/claude/docs/claude-code';
	properties: INodeProperties[] = [
		{
			displayName: 'OAuth Token',
			name: 'oauthToken',
			type: 'string',
			typeOptions: {
				password: true,
			},
			default: '',
			required: true,
			description: 'The Claude Code OAuth token for authentication',
		},
	];

	authenticate: IAuthenticateGeneric = {
		type: 'generic',
		properties: {
			headers: {
				Authorization: '=Bearer {{$credentials.oauthToken}}',
			},
		},
	};

	test: ICredentialTestRequest = {
		request: {
			baseURL: 'https://api.anthropic.com',
			url: '/v1/messages',
			method: 'POST',
			headers: {
				'anthropic-version': '2023-06-01',
				'content-type': 'application/json',
			},
			body: {
				model: 'claude-sonnet-4-20250514',
				max_tokens: 10,
				messages: [
					{
						role: 'user',
						content: 'test',
					},
				],
			},
		},
	};
}
