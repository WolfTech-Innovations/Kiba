import os
from datetime import datetime

workflow_dir = ".github/workflows"
workflows = []
for f in sorted(os.listdir(workflow_dir)):
    if f.endswith(".yml") or f.endswith(".yaml"):
        with open(os.path.join(workflow_dir, f), "r") as stream:
            for line in stream:
                if line.startswith("name:"):
                    name = line.split(":", 1)[1].strip().strip("\"")
                    workflows.append((name, f"./.github/workflows/{f}"))
                    break

print("# GitHub Workflows Manual")
print(f"Generated on {datetime.now().strftime('%a %b %d %H:%M:%S UTC %Y')}")
print("\n| Workflow Name | File Path |")
print("|---------------|-----------|")
for name, path in workflows:
    print(f"| {name} | {path} |")
