# License: MIT
import sys
from pathlib import Path
import yaml

def check_workflows():
    workflow_dir = Path(".github/workflows")
    all_passed = True
    count = 0

    if not workflow_dir.exists():
        print(f"Error: {workflow_dir} does not exist")
        sys.exit(1)

    for filepath in sorted(workflow_dir.glob("*.y*ml")):
        count += 1
        try:
            with filepath.open('r', encoding='utf-8') as stream:
                yaml.safe_load(stream)
            print(f"Passed: {filepath}")
        except Exception as exc:
            print(f"Failed: {filepath} - {exc}")
            all_passed = False

    if not all_passed:
        sys.exit(1)
    else:
        print(f"All {count} workflows passed YAML syntax check.")

if __name__ == "__main__":
    check_workflows()
