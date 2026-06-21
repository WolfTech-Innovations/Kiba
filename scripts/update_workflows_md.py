#!/usr/bin/env python3
# License: MIT
import os
import yaml
from datetime import datetime

try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

WORKFLOW_DIR = ".github/workflows"
OUTPUT_FILE = "WORKFLOWS.md"

def get_workflow_info():
    workflows = []
    if not os.path.exists(WORKFLOW_DIR):
        return workflows

    for filename in sorted(os.listdir(WORKFLOW_DIR)):
        if filename.endswith(".yml") or filename.endswith(".yaml"):
            filepath = os.path.join(WORKFLOW_DIR, filename)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    data = yaml.load(f, Loader=Loader)
                    name = data.get("name", filename)
                    workflows.append((name, f"./{filepath}"))
            except Exception as e:
                print(f"Error reading {filepath}: {e}")
    return workflows

def update_markdown(workflows):
    timestamp = datetime.now().strftime("%a %b %d %H:%M:%S UTC %Y")
    lines = [
        "# GitHub Workflows Manual",
        f"Generated on {timestamp}",
        "",
        "| Workflow Name | File Path |",
        "|---------------|-----------|"
    ]
    for name, path in workflows:
        lines.append(f"| {name} | `{path}` |")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

if __name__ == "__main__":
    info = get_workflow_info()
    update_markdown(info)
    print(f"Updated {OUTPUT_FILE} with {len(info)} workflows.")
