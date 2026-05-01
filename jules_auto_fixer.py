import os
import sys
import json
import subprocess
import urllib.request
import urllib.error

def get_failed_logs(run_id):
    try:
        # Fetch logs using GitHub CLI
        result = subprocess.run(
            ["gh", "run", "view", run_id, "--log"],
            capture_output=True,
            text=True,
            check=True
        )
        # Truncate logs if they are too long
        return result.stdout[-10000:]
    except subprocess.CalledProcessError as e:
        print(f"Error fetching logs: {e}")
        return "Could not fetch logs."

def find_source(api_key, repo_full_name):
    url = "https://jules.googleapis.com/v1alpha/sources"
    req = urllib.request.Request(url)
    req.add_header("x-goog-api-key", api_key)

    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                sources = data.get("sources", [])
                owner, repo_name = repo_full_name.split("/")
                for src in sources:
                    github_repo = src.get("githubRepo", {})
                    if github_repo.get("owner") == owner and github_repo.get("repo") == repo_name:
                        return src.get("name")
    except Exception as e:
        print(f"Error finding source: {e}")

    # Fallback to heuristic
    owner, repo_name = repo_full_name.split("/")
    return f"sources/github-{owner}-{repo_name}"

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
            "Analyze the failure and provide a fix."
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

    source_id = find_source(api_key, repo)
    print(f"Using source: {source_id}")

    # Jules API endpoint
    url = "https://jules.googleapis.com/v1alpha/sessions"

    headers = {"x-goog-api-key": api_key, "Content-Type": "application/json"}

    payload = {
        "prompt": prompt,
        "title": title,
        "sourceContext": {
            "source": source_id,
            "githubRepoContext": {"startingBranch": "main"},
        },
        "requirePlanApproval": False,
        "automationMode": "AUTO_CREATE_PR",
    }

    print(f"Creating Jules session: {title}")
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req) as response:
            if response.status in [200, 201]:
                res_data = json.loads(response.read().decode())
                print(f"Successfully created Jules session: {res_data.get('name')}")
                print(f"Session URL: {res_data.get('url')}")
            else:
                print(f"Error creating Jules session: {response.status}")
                print(response.read().decode())
                sys.exit(1)
    except urllib.error.HTTPError as e:
        print(f"Error creating Jules session: {e.code}")
        print(e.read().decode())
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error creating Jules session: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
