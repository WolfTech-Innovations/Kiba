import yaml
import os
import sys

workflows = [
    ".github/workflows/check-branch-naming-v3.yml",
    ".github/workflows/audit-build-debian-trixie-debootstrap.yml",
    ".github/workflows/audit-build-kernel-purge-order.yml",
    ".github/workflows/kiba.yml",
    ".github/workflows/cachyos-kernel-monitor.yml"
]
all_passed = True
for f in workflows:
    if not os.path.exists(f):
        print(f"Error: {f} does not exist")
        all_passed = False
        continue
    try:
        with open(f, 'r') as stream:
            yaml.safe_load(stream)
        print(f"Passed: {f}")
    except yaml.YAMLError as exc:
        print(f"Failed: {f} - {exc}")
        all_passed = False

if not all_passed:
    sys.exit(1)
else:
    print(f"All {len(workflows)} workflows passed YAML syntax check.")
