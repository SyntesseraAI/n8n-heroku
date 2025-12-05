import { IExecuteFunctions, INodeExecutionData, INodeType, INodeTypeDescription, NodeConnectionTypes, NodeOperationError } from "n8n-workflow";

import * as pty from "node-pty";

// Helper function to strip ANSI escape codes and non-printable characters
function stripAnsiCodes(text: string): string {
  // Remove ANSI escape sequences (including color codes, cursor movement, etc.)
  // eslint-disable-next-line no-control-regex
  return text
    .replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "") // ANSI CSI sequences
    .replace(/\x1b\][0-9;]*\x07/g, "") // OSC sequences
    .replace(/\x1b\][0-9;]*\x1b\\/g, "") // OSC sequences (alternative terminator)
    .replace(/\r\n/g, "\n") // Normalize line endings
    .replace(/\r/g, "\n") // Convert remaining CR to LF
    .replace(/\x1b[=>]/g, ""); // Other escape sequences
}

// Helper function to execute Claude Code
function executeClaudeCode(args: string[], oauthToken: string, timeout: number, workingDirectory: string): Promise<string> {
  return new Promise((resolve, reject) => {
    let output = "";

    // Set up environment with OAuth token
    const env = {
      ...process.env,
      CLAUDE_CODE_OAUTH_TOKEN: oauthToken,
    };

    // Spawn the claude process using pty (pseudoterminal) for raw mode support
    const childProcess = pty.spawn("claude", args, {
      name: "xterm-color",
      cols: 120,
      rows: 30,
      cwd: workingDirectory,
      env: env,
    });

    // Set timeout
    const timeoutId = setTimeout(() => {
      childProcess.kill();
      reject(new Error(`Claude Code execution timed out after ${timeout / 1000} seconds`));
    }, timeout);

    // Capture output (stdout and stderr are combined in pty)
    childProcess.onData((data: string) => {
      output += data;
    });

    // Handle process exit
    childProcess.onExit(({ exitCode, signal }: { exitCode: number; signal?: number }) => {
      clearTimeout(timeoutId);

      if (exitCode === 0) {
        // Strip ANSI codes and non-printable characters from output
        resolve(stripAnsiCodes(output));
      } else {
        reject(new Error(`Claude Code exited with code ${exitCode}${signal ? ` (signal: ${signal})` : ""}. Output: ${stripAnsiCodes(output) || "No output"}`));
      }
    });
  });
}

export class ClaudeCode implements INodeType {
  description: INodeTypeDescription = {
    displayName: "Claude Code",
    name: "claudeCode",
    icon: { light: "file:claude-code.svg", dark: "file:claude-code.svg" },
    group: ["transform"],
    version: 1,
    subtitle: '={{$parameter["model"]}}',
    description: "Execute Claude Code with AI-powered coding assistance",
    defaults: {
      name: "Claude Code",
    },
    inputs: [NodeConnectionTypes.Main],
    outputs: [NodeConnectionTypes.Main],
    usableAsTool: true,
    credentials: [
      {
        name: "claudeCodeApi",
        required: true,
      },
    ],
    properties: [
      {
        displayName: "Model",
        name: "model",
        type: "options",
        options: [
          {
            name: "Sonnet",
            value: "sonnet",
            description: "Claude Sonnet - Balanced performance and speed",
          },
          {
            name: "Opus",
            value: "opus",
            description: "Claude Opus - Highest intelligence",
          },
          {
            name: "Opus Plan",
            value: "opusplan",
            description: "Claude Opus with planning mode - Best for complex tasks",
          },
          {
            name: "Haiku",
            value: "haiku",
            description: "Claude Haiku - Fastest responses",
          },
        ],
        default: "sonnet",
        description: "The Claude model to use for code execution",
      },
      {
        displayName: "Prompt",
        name: "prompt",
        type: "string",
        typeOptions: {
          rows: 4,
        },
        default: "",
        required: true,
        description: "The task or prompt to send to Claude Code",
      },
      {
        displayName: "MCP Servers",
        name: "mcpServers",
        type: "multiOptions",
        options: [
          {
            name: "GitHub",
            value: "mcp__github",
          }
        ],
        default: ["mcp__github"],
        description: "Select which MCP servers to enable",
      },
      {
        displayName: "Additional Options",
        name: "additionalOptions",
        type: "collection",
        placeholder: "Add Option",
        default: {},
        options: [
          {
            displayName: "Timeout (seconds)",
            name: "timeout",
            type: "number",
            default: 3600,
            description: "Maximum execution time in seconds",
          },
          {
            displayName: "Allow All Tools",
            name: "allowedTools",
            type: "boolean",
            default: true,
            description: "Whether to allow Claude Code to use all available tools",
          },
          {
            displayName: "Working Directory",
            name: "workingDirectory",
            type: "string",
            default: "",
            description: "Working directory for Claude Code execution",
          },
        ],
      },
    ],
  };

  async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
    const items = this.getInputData();
    const returnData: INodeExecutionData[] = [];

    // Get credentials
    const credentials = await this.getCredentials("claudeCodeApi");
    const oauthToken = credentials.oauthToken as string;

    for (let i = 0; i < items.length; i++) {
      try {
        // Get parameters
        const model = this.getNodeParameter("model", i) as string;
        const prompt = this.getNodeParameter("prompt", i) as string;
        const mcpServers = this.getNodeParameter("mcpServers", i, [
          "mcp__github"
        ]) as string[];
        const additionalOptions = this.getNodeParameter("additionalOptions", i, {}) as {
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
          args.push("--allowedTools");
        }

        args.push("--model", model);

        // Add MCP servers (selected from multi-options)
        if (mcpServers && mcpServers.length > 0) {
          mcpServers.forEach((server) => {
            args.push(server);
          });
        }

        args.push("-p", prompt);

        // Execute Claude Code
        const output = await executeClaudeCode(args, oauthToken, timeout * 1000, workingDirectory);

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
