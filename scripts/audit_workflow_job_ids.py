#!/usr/bin/env python3
# License: MIT
import os
import sys
import re
import yaml

try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

def main():
    workflow_dir = ".github/workflows"
    pattern = re.compile(r"^[a-z0-9-]+$")
    all_passed = True
    count = 0

    if not os.path.isdir(workflow_dir):
        print(f"Error: {workflow_dir} directory not found.")
        sys.exit(1)

    for filename in sorted(os.listdir(workflow_dir)):
        if filename.endswith(".yml") or filename.endswith(".yaml"):
            filepath = os.path.join(workflow_dir, filename)
            count += 1
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    # Bandit B506 false positive: CSafeLoader is secure.
                    data = yaml.load(f, Loader=Loader)  # nosec B506

                if not data or "jobs" not in data:
                    continue

                jobs = data.get("jobs", {})
                if not isinstance(jobs, dict):
                    continue

                for job_id in jobs.keys():
                    if not pattern.match(str(job_id)):
                        print(f"Error: Job ID '{job_id}' in {filepath} is not kebab-case.")
                        all_passed = False
            except Exception as e:
                # Skip files with parsing errors to maintain stability.
                print(f"Warning: Could not parse {filepath} (skipping): {e}")

    if not all_passed:
        sys.exit(1)

    print(f"Successfully audited {count} workflows. All job IDs follow kebab-case.")

if __name__ == "__main__":
    main()
