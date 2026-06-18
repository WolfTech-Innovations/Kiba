import os
import yaml
from datetime import datetime

try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

WORKFLOW_DIR = ".github/workflows"
OUTPUT_FILE = "WORKFLOWS.md"

def get_workflows():
    workflows = []
    for f in sorted(os.listdir(WORKFLOW_DIR)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = os.path.join(WORKFLOW_DIR, f)
            try:
                with open(filepath, 'r', encoding='utf-8') as stream:
                    data = yaml.load(stream, Loader=Loader)
                    name = data.get('name', f)
                    steps = []
                    if name == "Audit - Repository Health":
                        jobs = data.get('jobs', {})
                        for job_name in jobs:
                            job_steps = jobs[job_name].get('steps', [])
                            for step in job_steps:
                                if 'name' in step and step['name'] not in ["checkout", "actions/checkout@v4"]:
                                    steps.append(step['name'])
                    workflows.append((name, filepath, steps))
            except Exception as e:
                print(f"Error parsing {filepath}: {e}")
    return workflows

def generate_markdown(workflows):
    now = datetime.now().strftime("%a %b %d %H:%M:%S UTC %Y")
    content = f"# GitHub Workflows Manual\n"
    content += f"Generated on {now}\n\n"
    content += "| Workflow Name | File Path | Details |\n"
    content += "|---------------|-----------|---------|\n"
    for name, path, steps in workflows:
        details = ""
        if steps:
            details = "<details><summary>Included Checks</summary><ul>"
            for step in steps:
                details += f"<li>{step}</li>"
            details += "</ul></details>"
        content += f"| {name} | `./{path}` | {details} |\n"
    return content

if __name__ == "__main__":
    workflows = get_workflows()
    markdown = generate_markdown(workflows)
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(markdown)
    print(f"Updated {OUTPUT_FILE} with {len(workflows)} workflows.")
