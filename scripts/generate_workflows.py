import os
import re

AUDIT_SCRIPT = "scripts/repo_audit.sh"
WORKFLOW_DIR = ".github/workflows"
TEMPLATE = """name: {name}

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit check
        shell: bash
        run: |
          bash scripts/repo_audit.sh {flag}
"""

def generate_workflows():
    if not os.path.exists(WORKFLOW_DIR):
        os.makedirs(WORKFLOW_DIR)

    with open(AUDIT_SCRIPT, "r") as f:
        content = f.read()

    # Find all --audit-* flags mentioned in the script main logic or elsewhere
    # Based on the script structure, they are in the 'Main Logic' section
    # but we can just find all audit_*() function definitions and map them back.
    functions = re.findall(r"audit_([a-z0-9_]+)\(\) \{", content)

    for func in functions:
        name_parts = func.split("_")
        display_name = " ".join(part.capitalize() for part in name_parts)
        flag = "--audit-" + func.replace("_", "-")
        filename = "audit-" + func.replace("_", "-") + ".yml"

        wf_content = TEMPLATE.format(name=display_name, flag=flag)
        filepath = os.path.join(WORKFLOW_DIR, filename)

        with open(filepath, "w") as wf:
            wf.write(wf_content)
        print(f"Generated: {filepath}")

if __name__ == "__main__":
    generate_workflows()
