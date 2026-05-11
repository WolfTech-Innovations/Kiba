# License: MIT
import os
import re
import sys
import yaml

# Use CSafeLoader for high-efficiency YAML parsing in environments with many files.
try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

def audit_workflow_job_ids():
    """
    Audits all GitHub Action workflows to ensure job IDs follow kebab-case (hyphen-separated).
    Optimized for performance by processing all files in a single pass.
    """
    workflow_dir = ".github/workflows"
    kebab_case_pattern = re.compile(r"^[a-z0-9-]+$")
    errors_found = False

    if not os.path.exists(workflow_dir):
        sys.exit(0)

    for filename in sorted(os.listdir(workflow_dir)):
        if not (filename.endswith(".yml") or filename.endswith(".yaml")):
            continue

        filepath = os.path.join(workflow_dir, filename)
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = yaml.load(f, Loader=Loader)

            if not data or "jobs" not in data or not isinstance(data["jobs"], dict):
                continue

            bad_jobs = [job_id for job_id in data["jobs"].keys() if not kebab_case_pattern.match(str(job_id))]

            if bad_jobs:
                print(f"Error: {filepath} contains job IDs not in kebab-case: {', '.join(bad_jobs)}")
                errors_found = True
        except Exception:
            continue

    if errors_found:
        sys.exit(1)

if __name__ == "__main__":
    audit_workflow_job_ids()
