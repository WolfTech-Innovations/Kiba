import os

audit_script = "scripts/repo_audit.sh"
workflow_dir = ".github/workflows"

if not os.path.exists(workflow_dir):
    os.makedirs(workflow_dir)

flags = []
with open(audit_script, 'r') as f:
    for line in f:
        if "--audit-" in line and ")" in line:
            flag = line.split(")")[0].strip().replace("--", "")
            if flag not in flags:
                flags.append(flag)

template = """name: {name}

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - name: Run audit
        shell: bash
        run: bash scripts/repo_audit.sh --{flag}
"""

for flag in flags:
    filename = f"{flag}.yml"
    name = flag.replace("audit-", "").replace("-", " ").title()
    content = template.format(name=name, flag=flag)
    filepath = os.path.join(workflow_dir, filename)
    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Generated {filepath}")

print(f"Total workflows generated: {len(flags)}")
