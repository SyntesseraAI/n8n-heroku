# n8n-heroku

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://dashboard.heroku.com/new?template=https://github.com/SyntesseraAI/n8n-heroku/tree/main)

## n8n - Free and open fair-code licensed node based Workflow Automation Tool.

This is a [Heroku](https://heroku.com/)-focused container implementation of [n8n](https://n8n.io/).

Use the **Deploy to Heroku** button above to launch n8n on Heroku. When deploying, make sure to check all configuration options and adjust them to your needs. It's especially important to set `N8N_ENCRYPTION_KEY` to a random secure value.

If you plan to use the `@anthropic-ai/claude-code` CLI in your automation flows, add a `CLAUDE_CODE_OAUTH_TOKEN` config var during deployment so the container can authenticate the CLI on startup.

## Cloud Run Integration

This deployment includes a Cloud Run launcher that allows you to offload heavy Claude Code tasks to Google Cloud Run containers. This is useful for:

- Running resource-intensive AI operations without impacting your n8n instance
- Executing long-running Claude Code tasks with dedicated resources
- Scaling AI workloads independently from your n8n workflows

### Quick Setup

1. Set the required environment variables in Heroku:
   - `GCP_PROJECT_ID` - Your Google Cloud Project ID
   - `GCP_SERVICE_ACCOUNT_KEY` - Base64-encoded service account JSON key
   - `CLAUDE_CODE_OAUTH_TOKEN` - Your Claude Code OAuth token

2. Use the `launch-cloudrun` command from within your container:
   ```bash
   launch-cloudrun -p "Your prompt here" -b
   ```

For detailed setup instructions, see [cloudrun/README.md](cloudrun/README.md).

## Additional Resources

Refer to the [Heroku n8n tutorial](https://docs.n8n.io/hosting/server-setups/heroku/) for more information.

If you have questions after trying the tutorials, check out the [forums](https://community.n8n.io/).
