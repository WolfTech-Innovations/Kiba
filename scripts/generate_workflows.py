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
  schedule:
    - cron: '0 0 * * 0'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Run Audit
        run: bash {script} --check {check}
        shell: bash
"""

def generate_workflows():
    if not os.path.exists(WORKFLOW_DIR):
        os.makedirs(WORKFLOW_DIR)

    with open(AUDIT_SCRIPT, "r") as f:
        content = f.read()

    # Find all functions starting with audit_
    functions = re.findall(r"^(audit_[a-zA-Z0-9_]+)\(\)", content, re.MULTILINE)

    for func in functions:
        # Convert audit_foo_bar to Audit Foo Bar for the name
        clean_name = func.replace("audit_", "").replace("_", " ").title()
        # Convert audit_foo_bar to audit-foo-bar.yml for the filename
        filename = func.replace("_", "-") + ".yml"

        workflow_content = TEMPLATE.format(
            name=clean_name,
            script=AUDIT_SCRIPT,
            check=func.replace("audit_", "")
        )

        with open(os.path.join(WORKFLOW_DIR, filename), "w") as wf:
            wf.write(workflow_content)
        print(f"Generated {filename}")

if __name__ == "__main__":
    generate_workflows()
