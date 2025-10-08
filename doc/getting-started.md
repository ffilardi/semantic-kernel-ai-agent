# Getting Started

There are 3 options for getting started:

1. Run the template virtually by using [GitHub Codespaces](#41-github-codespaces), which sets up tools automatically (quickest way).
2. Run in your local VS Code using the [VS Code Dev Containers](#42-vs-code-dev-containers) extension.
3. Setting-up a [Local Environment](#43-local-environment) (MacOS, Linux or Windows).

## GitHub Codespaces

Prerequisites:
- Azure subscription with permissions to create resource groups and deploy resources.
- GitHub account.

Steps:
1. Open the repository in [GitHub Codespaces](https://codespaces.new/ffilardi-insight/semantic-kernel-agent)
2. Configure the settings and create the Codespace (this may take several minutes)

## VS Code Dev Containers

Prerequisites:
- Azure subscription with permissions to create resource groups and deploy resources.
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) for VS Code
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) 

Steps:
1. Start Docker Desktop
2. Open the project in a [VS Code Dev Container](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/ffilardi-insight/semantic-kernel-agent) (this may take several minutes)

## Local Environment

Prerequisites:
- Azure subscription with permissions to create resource groups and deploy resources.
- Install [Azure Developer CLI](https://aka.ms/install-azd)
    - Windows: `winget install microsoft.azd`
    - Linux: `curl -fsSL https://aka.ms/install-azd.sh | bash`
    - MacOS: `brew tap azure/azd && brew install azd`
- Install [Python 3.12+](https://www.python.org/downloads/) for local development
- Install [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) for advanced scenarios (optional)

Steps:
1. Clone the repository locally:
    ```shell
    git clone <repository-url>
    cd <repository-folder>
    ```

2. Install Python dependencies:
   ```shell
   pip install -r src/agent_backend/requirements.txt
   pip install -r src/agent_frontend/requirements.txt
   ```

3. Open VS Code and load the local project folder