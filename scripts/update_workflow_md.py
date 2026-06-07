import os
import re

workflow_dir = ".github/workflows"
workflow_md = "WORKFLOWS.md"

def get_workflow_name(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
        match = re.search(r'^name:\s*(.*)$', content, re.MULTILINE)
        if match:
            return match.group(1).strip().strip('"').strip("'")
    return None

workflows = []
for f in sorted(os.listdir(workflow_dir)):
    if f.endswith(".yml") or f.endswith(".yaml"):
        path = os.path.join(workflow_dir, f)
        name = get_workflow_name(path)
        if name:
            workflows.append((name, path))

# Sort by name
workflows.sort(key=lambda x: x[0])

with open(workflow_md, 'w') as f:
    f.write("# GitHub Workflows Manual\n")
    # Use a dummy date to match previous style or just omit
    f.write("Generated on Repo Update\n\n")
    f.write("| Workflow Name | File Path |\n")
    f.write("|---------------|-----------|\n")
    for name, path in workflows:
        f.write(f"| {name} | `{path}` |\n")

print(f"Updated {workflow_md} with {len(workflows)} workflows.")
