import os
import yaml
from datetime import datetime

def update_workflows_md():
    workflow_dir = ".github/workflows"
    output_file = "WORKFLOWS.md"

    workflows = []
    for f in sorted(os.listdir(workflow_dir)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = os.path.join(workflow_dir, f)
            try:
                with open(filepath, 'r', encoding='utf-8') as stream:
                    data = yaml.safe_load(stream)
                    name = data.get('name', f)
                    workflows.append((name, filepath))
            except Exception as e:
                print(f"Error reading {filepath}: {e}")

    now = datetime.utcnow().strftime("%a %b %d %H:%M:%S UTC %Y")

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# GitHub Workflows Manual\n")
        f.write(f"Generated on {now}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        for name, path in workflows:
            f.write(f"| {name} | `./{path}` |\n")

    print(f"Updated {output_file} with {len(workflows)} workflows.")

if __name__ == "__main__":
    update_workflows_md()
