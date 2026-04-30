import os
import sys
import json
import subprocess
import requests

def get_failed_logs(run_id):
    try:
        # Fetch logs using GitHub CLI
        result = subprocess.run(
            ["gh", "run", "view", run_id, "--log"],
            capture_output=True,
            text=True,
            check=True
        )
        # Truncate logs if they are too long (e.g., keep last 10000 characters)
        return result.stdout[-10000:]
    except subprocess.CalledProcessError as e:
        print(f"Error fetching logs: {e}")
        return "Could not fetch logs."

def main():
    api_key = os.getenv("JAPI")
    if not api_key:
        print("Error: JAPI environment variable not set.")
        sys.exit(1)

    event_name = os.getenv("GITHUB_EVENT_NAME")
    repo = os.getenv("GITHUB_REPOSITORY")

    prompt = ""
    title = ""

    if event_name == "workflow_run":
        run_id = os.getenv("FAILED_RUN_ID")
        workflow_name = os.getenv("WORKFLOW_NAME")
        logs = get_failed_logs(run_id)
        title = f"Fix failure in {workflow_name} (Run {run_id})"
        prompt = (
            f"The GitHub Actions workflow '{workflow_name}' failed in run {run_id}.\n"
            f"Repository: {repo}\n"
            f"Logs:\n{logs}\n\n"
            "Analyze the failure and provide a fix. Ensure you follow the project's coding standards."
        )
    elif event_name == "issues":
        issue_number = os.getenv("ISSUE_NUMBER")
        issue_title = os.getenv("ISSUE_TITLE")
        issue_body = os.getenv("ISSUE_BODY")
        title = f"Fix Issue #{issue_number}: {issue_title}"
        prompt = (
            f"Fix the following issue reported in repository {repo}:\n"
            f"Issue #{issue_number}: {issue_title}\n"
            f"Description:\n{issue_body}\n\n"
            "Provide a complete fix for this issue."
        )
    else:
        print(f"Unsupported event: {event_name}")
        sys.exit(0)

    # Jules API endpoint
    url = "https://jules.googleapis.com/v1alpha/sessions"

    headers = {
        "x-goog-api-key": api_key,
        "Content-Type": "application/json"
    }

    # Construct source identifier (assuming github-<owner>-<repo> format)
    owner, repo_name = repo.split('/')
    source_id = f"sources/github-{owner}-{repo_name}"

    payload = {
        "prompt": prompt,
        "title": title,
        "sourceContext": {
            "source": source_id,
            "githubRepoContext": {
                "startingBranch": "main"
            }
        },
        "requirePlanApproval": False,
        "automationMode": "AUTO_CREATE_PR"
    }

    print(f"Creating Jules session: {title}")
    response = requests.post(url, headers=headers, json=payload)

    if response.status_code == 200 or response.status_code == 201:
        data = response.json()
        print(f"Successfully created Jules session: {data.get('name')}")
        print(f"Session URL: {data.get('url')}")
    else:
        print(f"Error creating Jules session: {response.status_code}")
        print(response.text)
        sys.exit(1)

if __name__ == "__main__":
    main()
