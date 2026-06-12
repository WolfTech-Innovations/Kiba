import os
import yaml
from datetime import datetime

workflow_dir = ".github/workflows"
workflows = []

for f in sorted(os.listdir(workflow_dir)):
    if f.endswith(".yml") or f.endswith(".yaml"):
        filepath = os.path.join(workflow_dir, f)
        try:
            with open(filepath, 'r') as stream:
                data = yaml.safe_load(stream)
                name = data.get('name', f)
        except Exception:
            name = f
        workflows.append((name, filepath))

# Sort by name
workflows.sort()

now = datetime.now().strftime("%a %b %d %H:%M:%S UTC %Y")

with open("WORKFLOWS.md", "w") as f:
    f.write("# GitHub Workflows Manual\n")
    f.write(f"Generated on {now}\n\n")
    f.write("| Workflow Name | File Path |\n")
    f.write("|---------------|-----------|\n")
    for name, path in workflows:
        f.write(f"| {name} | `{path}` |\n")

print("Updated WORKFLOWS.md")
