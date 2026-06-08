import os
import yaml
from datetime import datetime

# Try to use CSafeLoader for performance
try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

workflow_dir = ".github/workflows"
output_file = "WORKFLOWS.md"

def get_workflow_name(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = yaml.load(f, Loader=Loader)
            if data and isinstance(data, dict):
                return data.get('name', os.path.basename(filepath))
            return os.path.basename(filepath)
    except Exception:
        return os.path.basename(filepath)

if not os.path.exists(workflow_dir):
    print(f"Error: {workflow_dir} not found.")
    exit(1)

workflows = []
for f in os.listdir(workflow_dir):
    if f.endswith(".yml") or f.endswith(".yaml"):
        path = os.path.join(workflow_dir, f)
        name = get_workflow_name(path)
        workflows.append((name, path))

# Sort alphabetically by name
workflows.sort(key=lambda x: x[0].lower())

now = datetime.utcnow().strftime("%a %b %d %H:%M:%S UTC %Y")

content = f"# GitHub Workflows Manual\nGenerated on {now}\n\n"
content += "| Workflow Name | File Path |\n"
content += "|---------------|-----------|\n"

for name, path in workflows:
    content += f"| {name} | `{path}` |\n"

with open(output_file, "w", encoding='utf-8') as f:
    f.write(content)

print(f"Updated {output_file} with {len(workflows)} workflows.")
