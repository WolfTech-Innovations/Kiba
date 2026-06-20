#!/usr/bin/env python3
import os
import yaml
import datetime

workflow_dir = ".github/workflows"
output_file = "WORKFLOWS.md"

def get_workflow_name(filepath):
    try:
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
            return data.get('name', os.path.basename(filepath))
    except:
        return os.path.basename(filepath)

def main():
    workflows = []
    for f in sorted(os.listdir(workflow_dir)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            path = os.path.join(workflow_dir, f)
            name = get_workflow_name(path)
            workflows.append((name, f"./{path}"))

    with open(output_file, 'w') as f:
        f.write("# GitHub Workflows Manual\n")
        f.write(f"Generated on {datetime.datetime.now(datetime.timezone.utc).strftime('%a %b %d %H:%M:%S UTC %Y')}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        for name, path in workflows:
            f.write(f"| {name} | `{path}` |\n")

if __name__ == "__main__":
    main()
