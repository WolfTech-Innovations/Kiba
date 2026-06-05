import os

def generate_name(filename):
    # Remove .yml extension and split by '-'
    parts = filename.replace('.yml', '').split('-')
    # Capitalize each part, but keep 'sh' as 'SH'
    name_parts = [p.upper() if p == 'sh' else p.capitalize() for p in parts]
    return ' '.join(name_parts)

def generate_workflow(filename):
    name = generate_name(filename)
    audit_flag = "--" + filename.replace('.yml', '')

    workflow_content = f"""name: {name}

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  audit:
    name: Run {name}
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit
        shell: bash
        run: |
          chmod +x scripts/repo_audit.sh
          ./scripts/repo_audit.sh {audit_flag}
"""
    return workflow_content

def main():
    input_file = 'workflows_to_add.txt'
    output_dir = '.github/workflows'

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    with open(input_file, 'r') as f:
        workflows = [line.strip() for line in f if line.strip()]

    for wf_file in workflows:
        filepath = os.path.join(output_dir, wf_file)
        content = generate_workflow(wf_file)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Generated: {filepath}")

if __name__ == "__main__":
    main()
