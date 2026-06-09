import os
import yaml
import re

WORKFLOW_DIR = ".github/workflows"
WORKFLOWS_MD = "WORKFLOWS.md"

def get_workflow_name(filepath):
    try:
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
            return data.get('name', os.path.basename(filepath))
    except:
        return os.path.basename(filepath)

def update_workflows_md():
    workflows = []
    for f in os.listdir(WORKFLOW_DIR):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = os.path.join(WORKFLOW_DIR, f)
            name = get_workflow_name(filepath)
            workflows.append((name, filepath))

    workflows.sort(key=lambda x: x[0].lower())

    from datetime import datetime
    now = datetime.now().strftime("%a %b %d %H:%M:%S UTC %Y")

    content = "# GitHub Workflows Manual\n"
    content += f"Generated on {now}\n\n"
    content += "| Workflow Name | File Path |\n"
    content += "|---------------|-----------|\n"

    for name, path in workflows:
        content += f"| {name} | `{path}` |\n"

    with open(WORKFLOWS_MD, 'w') as f:
        f.write(content)
    print(f"Updated {WORKFLOWS_MD}")

if __name__ == "__main__":
    update_workflows_md()
