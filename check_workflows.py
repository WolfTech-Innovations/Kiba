# License: MIT
import yaml
try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader
import os
import sys

workflow_dir = ".github/workflows"
all_passed = True
count = 0

if not os.path.exists(workflow_dir):
    print(f"Error: {workflow_dir} does not exist")
    sys.exit(1)

for f in sorted(os.listdir(workflow_dir)):
    if f.endswith(".yml") or f.endswith(".yaml"):
        filepath = os.path.join(workflow_dir, f)
        count += 1
        try:
            with open(filepath, 'r', encoding='utf-8') as stream:
                # Use CSafeLoader for significant performance gains on large numbers of files
                yaml.load(stream, Loader=Loader)
            print(f"Passed: {filepath}")
        except Exception as exc:
            print(f"Failed: {filepath} - {exc}")
            all_passed = False

if not all_passed:
    sys.exit(1)
else:
    print(f"All {count} workflows passed YAML syntax check.")
