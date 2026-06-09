import os
import yaml
from datetime import datetime

WORKFLOW_DIR = ".github/workflows"
OUTPUT_FILE = "WORKFLOWS.md"

def update_workflows_md():
    workflows = []
    if not os.path.exists(WORKFLOW_DIR):
        print(f"Error: {WORKFLOW_DIR} does not exist")
        return

    for f in sorted(os.listdir(WORKFLOW_DIR)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = os.path.join(WORKFLOW_DIR, f)
            try:
                with open(filepath, 'r') as stream:
                    data = yaml.safe_load(stream)
                    name = data.get('name', f)
                    workflows.append((name, filepath))
            except Exception:
                workflows.append((f, filepath))

    with open(OUTPUT_FILE, "w") as f:
        f.write("# GitHub Workflows Manual\n")
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"Updated on {now}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        for name, path in workflows:
            f.write(f"| {name} | `{path}` |\n")
    print(f"Updated {OUTPUT_FILE}")

if __name__ == "__main__":
    update_workflows_md()
