import os
import re

AUDIT_SCRIPT = "scripts/repo_audit.sh"
WORKFLOW_DIR = ".github/workflows"

TEMPLATE = """name: {name}

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit check
        shell: bash
        run: bash scripts/repo_audit.sh --check {check_name}
"""

def generate_workflows():
    if not os.path.exists(WORKFLOW_DIR):
        os.makedirs(WORKFLOW_DIR)

    with open(AUDIT_SCRIPT, 'r') as f:
        content = f.read()

    # Find all functions starting with audit_
    functions = re.findall(r'^audit_([a-zA-Z0-9_]+)\(\)', content, re.MULTILINE)

    for func in functions:
        check_name = func
        # Convert audit_build_sh_something to "Audit Build SH Something" for the name
        display_name = "Audit " + " ".join(word.capitalize() if word not in ['sh', 'uid', 'v4'] else word.upper() for word in func.split('_'))

        filename = f"audit-{func.replace('_', '-')}.yml"
        filepath = os.path.join(WORKFLOW_DIR, filename)

        workflow_content = TEMPLATE.format(
            name=display_name,
            check_name=check_name
        )

        with open(filepath, 'w') as f:
            f.write(workflow_content)
        print(f"Generated {filepath}")

if __name__ == "__main__":
    generate_workflows()
