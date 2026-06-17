# License: MIT
import os
import yaml
import datetime
try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

def update_workflows_md():
    workflow_dir = ".github/workflows"
    output_file = "WORKFLOWS.md"
    workflows = []

    if not os.path.exists(workflow_dir):
        print(f"Error: {workflow_dir} does not exist")
        return

    for f in sorted(os.listdir(workflow_dir)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = os.path.join(workflow_dir, f)
            try:
                with open(filepath, 'r', encoding='utf-8') as stream:
                    data = yaml.load(stream, Loader=Loader)
                    name = data.get('name', f)
                    workflows.append((name, filepath))
            except Exception as exc:
                print(f"Warning: Could not parse {filepath} - {exc}")

    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%a %b %d %H:%M:%S UTC %Y")

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# GitHub Workflows Manual\n")
        f.write(f"Generated on {timestamp}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        for name, path in workflows:
            f.write(f"| {name} | `./{path}` |\n")

    print(f"Successfully updated {output_file}")

if __name__ == "__main__":
    update_workflows_md()
