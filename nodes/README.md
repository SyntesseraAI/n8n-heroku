# n8n Claude Code Custom Nodes

This directory contains custom n8n nodes for integrating Claude Code into your n8n workflows.

## Nodes

### Claude Code Node

The Claude Code node allows you to execute AI-powered coding tasks directly within your n8n workflows using Anthropic's Claude models.

**Features:**
- Multiple model options: Sonnet 4.5, Opus 4, Opus Plan, Haiku 4
- Local execution using the Claude CLI
- Support for MCP servers (GitHub integration and more)
- Configurable timeout and working directory
- Full tool access control

**Parameters:**
- **Model**: Choose between Sonnet, Opus, Opus Plan, or Haiku
- **Prompt**: The task or instruction to send to Claude Code
- **MCP Servers**: Comma-separated list of MCP servers to enable (default: `mcp__github`)
- **Additional Options**:
  - Timeout: Maximum execution time in seconds (default: 3600)
  - Allow All Tools: Enable/disable tool usage (default: true)
  - Working Directory: Custom working directory for execution

**Credentials:**
The node requires Claude Code API credentials with your OAuth token. You can obtain this token from your Claude Code CLI configuration.

## Directory Structure

```
nodes/
├── package.json                          # Node package configuration
├── tsconfig.json                         # TypeScript configuration
├── gulpfile.js                          # Build configuration
├── credentials/
│   └── ClaudeCodeApi.credentials.ts     # Claude Code API credentials
└── nodes/
    └── ClaudeCode/
        ├── ClaudeCode.node.ts           # Node implementation
        ├── ClaudeCode.node.json         # Node metadata
        └── claude-code.svg              # Node icon
```

## Development

### Building the Nodes

```bash
cd nodes
npm install
npm run build
```

This will compile the TypeScript files and copy assets to the `dist/` directory.

### Adding New Nodes

To add a new node:

1. Create a new directory under `nodes/nodes/`:
   ```bash
   mkdir -p nodes/nodes/YourNode
   ```

2. Create the node implementation file:
   ```typescript
   // nodes/nodes/YourNode/YourNode.node.ts
   import { INodeType, INodeTypeDescription } from 'n8n-workflow';

   export class YourNode implements INodeType {
     description: INodeTypeDescription = {
       displayName: 'Your Node',
       name: 'yourNode',
       // ... rest of configuration
     };
   }
   ```

3. Add the node icon:
   ```bash
   # Create an SVG icon
   nodes/nodes/YourNode/your-node.svg
   ```

4. Register the node in `package.json`:
   ```json
   {
     "n8n": {
       "nodes": [
         "dist/nodes/ClaudeCode/ClaudeCode.node.js",
         "dist/nodes/YourNode/YourNode.node.js"
       ]
     }
   }
   ```

5. Build and test:
   ```bash
   npm run build
   ```

### Adding New Credentials

To add a new credential type:

1. Create a credential file under `credentials/`:
   ```typescript
   // credentials/YourCredential.credentials.ts
   import { ICredentialType, INodeProperties } from 'n8n-workflow';

   export class YourCredential implements ICredentialType {
     name = 'yourCredential';
     displayName = 'Your Credential';
     properties: INodeProperties[] = [
       // ... credential fields
     ];
   }
   ```

2. Register the credential in `package.json`:
   ```json
   {
     "n8n": {
       "credentials": [
         "dist/credentials/ClaudeCodeApi.credentials.js",
         "dist/credentials/YourCredential.credentials.js"
       ]
     }
   }
   ```

## Installation

The custom nodes are automatically installed when building the Docker image. The Dockerfile:

1. Copies the `nodes/` directory
2. Installs dependencies
3. Builds the nodes
4. Copies them to n8n's custom nodes directory

To rebuild the Docker image with the latest nodes:

```bash
docker build -t your-image-name .
```

## Usage in n8n

1. **Add Credentials:**
   - Go to n8n Credentials
   - Add "Claude Code API" credential
   - Enter your Claude Code OAuth token

2. **Add the Node:**
   - In your workflow, search for "Claude Code"
   - Drag it onto the canvas
   - Select your credentials
   - Configure the model and prompt

3. **Example Workflow:**
   ```
   Trigger → Claude Code → Process Output
   ```

## Testing

To test the node locally without Docker:

1. Build the nodes:
   ```bash
   cd nodes
   npm run build
   ```

2. Link to your local n8n installation:
   ```bash
   # In your local n8n custom nodes directory
   ln -s /path/to/this/nodes/dist /path/to/.n8n/custom/
   ```

3. Restart n8n and the node should appear

## Environment Variables

The Claude Code node uses the following environment variables:

- `CLAUDE_CODE_OAUTH_TOKEN`: OAuth token for Claude Code (set via credentials)

## Troubleshooting

### Node Not Appearing in n8n

1. Check that the build was successful: `npm run build`
2. Verify the dist/ directory contains the compiled files
3. Check n8n logs for any node loading errors
4. Ensure credentials are properly configured

### Execution Errors

1. Verify the Claude CLI is installed: `claude --version`
2. Check that CLAUDE_CODE_OAUTH_TOKEN is set correctly
3. Review the node execution logs in n8n
4. Increase the timeout if needed for long-running tasks

## Future Nodes

Planned nodes for future development:

- **Cloud Run Node**: Execute Claude Code on Google Cloud Run (using launch-cloudrun.sh logic)
- **MCP Manager Node**: Manage MCP server connections
- **Code Review Node**: Specialized node for code review tasks
- **Documentation Generator Node**: Generate documentation from code

## Contributing

To contribute a new node:

1. Follow the structure outlined in "Adding New Nodes"
2. Include proper TypeScript types
3. Add comprehensive error handling
4. Include a descriptive icon
5. Document all parameters in the node description

## License

MIT
