import os
import re

AUDIT_SCRIPT = "scripts/repo_audit.sh"
WORKFLOW_DIR = ".github/workflows"

TEMPLATE = """name: {title}
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
      - uses: actions/checkout@v4
      - name: Run Audit
        shell: bash
        run: bash scripts/repo_audit.sh {flag}
"""

def flag_to_title(flag):
    # Remove leading --
    name = flag.lstrip('-')
    # Replace hyphens with spaces and capitalize words
    title = ' '.join(word.capitalize() if word not in ['sh', 'uid', 'v4'] else word.upper() for word in name.split('-'))
    return title

def main():
    if not os.path.exists(WORKFLOW_DIR):
        os.makedirs(WORKFLOW_DIR)

    with open(AUDIT_SCRIPT, 'r') as f:
        content = f.read()

    # Find all flags in the case statement or similar
    flags = re.findall(r'--audit-[a-z0-9-]+', content)
    # Deduplicate while preserving order
    seen = set()
    unique_flags = [x for x in flags if not (x in seen or seen.add(x))]

    for flag in unique_flags:
        title = flag_to_title(flag)
        filename = flag.lstrip('-') + ".yml"
        filepath = os.path.join(WORKFLOW_DIR, filename)

        workflow_content = TEMPLATE.format(title=title, flag=flag)

        with open(filepath, 'w') as f:
            f.write(workflow_content)
        print(f"Generated {filepath}")

if __name__ == "__main__":
    main()
