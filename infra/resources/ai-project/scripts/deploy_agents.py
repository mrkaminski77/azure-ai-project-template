#!/usr/bin/env python3
"""Create or update Foundry agents defined under infra/resources/ai-project/agents/.

For each subdirectory in agents/, reads "<agent_id>.yml" (agent config) and
"instructions.md" (agent instructions), merges them into the agent-definition.json
template, and pushes the result to the Foundry project's Agents API.

Usage:
    python deploy_agents.py [--environment dev]

The environment can also be supplied via the ENVIRONMENT variable, matching the
convention used by the Bicep deployments (main.bicepparam).
"""

import argparse
import json
import os
import sys
from pathlib import Path

import requests
import yaml
from azure.identity import DefaultAzureCredential

SCRIPT_DIR = Path(__file__).resolve().parent
AI_PROJECT_DIR = SCRIPT_DIR.parent
INFRA_DIR = AI_PROJECT_DIR.parent.parent
AGENTS_DIR = AI_PROJECT_DIR / "agents"
AGENT_TEMPLATE_PATH = AGENTS_DIR / "agent-definition.json"

TOKEN_SCOPE = "https://ai.azure.com/.default"
API_VERSION = "v1"


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def get_config(environment: str) -> tuple[dict, dict]:
    env_config = load_yaml(INFRA_DIR / "env-config.yml")[environment]
    project_config = load_yaml(INFRA_DIR / "project-config.yml")
    return env_config, project_config


def get_project_endpoint(env_config: dict, project_config: dict, environment: str) -> str:
    foundry_name = env_config["foundryResourceName"]
    # project name follows the same "<name>-<environment>" convention as main.bicep
    project_name = f"{project_config['aiProjectName']}-{environment}"
    return f"https://{foundry_name}.services.ai.azure.com/api/projects/{project_name}"


def resolve_mcp_tool(tool: dict, environment: str) -> dict:
    """Turn a `function` app reference into the environment-suffixed MCP server_url."""
    resolved = dict(tool)
    function_app = resolved.pop("function", None)
    if function_app:
        function_app_name = f"{function_app}-{environment}"
        resolved["server_url"] = f"https://{function_app_name}.azurewebsites.net/mcp"
    return resolved


def resolve_tools(tools: list, environment: str) -> list:
    resolved_tools = []
    for tool in tools or []:
        if tool.get("type") == "mcp":
            resolved_tools.append(resolve_mcp_tool(tool, environment))
        else:
            resolved_tools.append(tool)
    return resolved_tools


def substitute(value, replacements: dict):
    if isinstance(value, str):
        return replacements.get(value, value)
    if isinstance(value, dict):
        return {k: substitute(v, replacements) for k, v in value.items()}
    if isinstance(value, list):
        return [substitute(v, replacements) for v in value]
    return value


def build_agent_payload(agent_dir: Path, environment: str) -> dict:
    agent_id = agent_dir.name
    agent_config = load_yaml(agent_dir / f"{agent_id}.yml")
    instructions = (agent_dir / "instructions.md").read_text(encoding="utf-8")

    with AGENT_TEMPLATE_PATH.open("r", encoding="utf-8") as f:
        template = json.load(f)

    payload = substitute(template, {"{{agentId}}": agent_id, "{{instructions}}": instructions})

    payload["name"] = agent_config.get("agentName", agent_id)
    payload["definition"]["model"] = agent_config.get("model", payload["definition"]["model"])
    payload["definition"]["tools"] = resolve_tools(agent_config.get("tools"), environment)

    return payload


def agent_exists(project_endpoint: str, agent_id: str, token: str) -> bool:
    response = requests.get(
        f"{project_endpoint}/agents/{agent_id}",
        headers={"Authorization": f"Bearer {token}"},
        params={"api-version": API_VERSION},
        timeout=30,
    )
    if response.status_code == 200:
        return True
    if response.status_code == 404:
        return False
    response.raise_for_status()
    return False


def create_or_update_agent(project_endpoint: str, agent_id: str, payload: dict, token: str) -> None:
    if agent_exists(project_endpoint, agent_id, token):
        url = f"{project_endpoint}/agents/{agent_id}"
        action = "Updating"
    else:
        url = f"{project_endpoint}/agents"
        action = "Creating"

    print(f"{action} agent '{agent_id}' -> {url}")
    response = requests.post(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        params={"api-version": API_VERSION},
        json=payload,
        timeout=60,
    )
    response.raise_for_status()
    print(f"  -> {response.status_code}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--environment",
        default=os.environ.get("ENVIRONMENT", "dev"),
        help="Environment name (a top-level key in env-config.yml). Defaults to $ENVIRONMENT or 'dev'.",
    )
    args = parser.parse_args()
    environment = args.environment

    env_config, project_config = get_config(environment)
    project_endpoint = get_project_endpoint(env_config, project_config, environment)

    token = DefaultAzureCredential().get_token(TOKEN_SCOPE).token

    agent_dirs = sorted(p for p in AGENTS_DIR.iterdir() if p.is_dir())
    if not agent_dirs:
        print(f"No agent directories found under {AGENTS_DIR}")
        return 0

    for agent_dir in agent_dirs:
        agent_id = agent_dir.name
        agent_yml_path = agent_dir / f"{agent_id}.yml"
        if not agent_yml_path.exists():
            print(f"Skipping '{agent_id}': no {agent_yml_path.name} found")
            continue

        payload = build_agent_payload(agent_dir, environment)
        create_or_update_agent(project_endpoint, agent_id, payload, token)

    return 0


if __name__ == "__main__":
    sys.exit(main())
