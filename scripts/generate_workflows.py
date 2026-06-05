import os
import re

AUDIT_SCRIPT = "scripts/repo_audit.sh"
WORKFLOW_DIR = ".github/workflows"

TEMPLATE = """name: Audit {name}

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit {flag}
        shell: bash
        run: |
          bash scripts/repo_audit.sh {flag}
"""

def get_audit_flags():
    flags = []
    # In repo_audit.sh, the audit functions are named audit_repo_xxx
    # We want to generate --audit-repo-xxx flags for them.
    with open(AUDIT_SCRIPT, "r") as f:
        for line in f:
            match = re.match(r"^audit_([a-z0-9_]+)\(\) \{", line)
            if match:
                name = match.group(1).replace("_", "-")
                flag = f"--audit-{name}"
                if flag not in flags:
                    flags.append(flag)
    return flags

def main():
    if not os.path.exists(WORKFLOW_DIR):
        os.makedirs(WORKFLOW_DIR)

    flags = get_audit_flags()
    print(f"Found {len(flags)} audit flags.")

    for flag in flags:
        # --audit-repo-license-sanity -> audit-repo-license-sanity.yml
        name_part = flag.replace("--audit-", "")
        filename = f"{name_part}.yml"
        filepath = os.path.join(WORKFLOW_DIR, filename)

        # Pretty name: Repo License Sanity
        pretty_name = name_part.replace("-", " ").title()

        content = TEMPLATE.format(name=pretty_name, flag=flag)

        with open(filepath, "w") as f:
            f.write(content)
        print(f"Generated {filepath}")

if __name__ == "__main__":
    main()
