import os
import yaml
import time

try:
    from yaml import CSafeLoader as Loader
except ImportError:
    from yaml import SafeLoader as Loader

WORKFLOWS_DIR = ".github/workflows"
OUTPUT_FILE = "WORKFLOWS.md"

def generate_workflows_md():
    workflows = []
    if not os.path.exists(WORKFLOWS_DIR):
        print(f"Error: {WORKFLOWS_DIR} not found.")
        return

    for filename in sorted(os.listdir(WORKFLOWS_DIR)):
        if filename.endswith(".yml") or filename.endswith(".yaml"):
            filepath = os.path.join(WORKFLOWS_DIR, filename)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    data = yaml.load(f, Loader=Loader)
                    name = data.get('name', filename)
                    workflows.append((name, filepath))
            except Exception as e:
                print(f"Error parsing {filepath}: {e}")

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write("# GitHub Workflows Manual\n")
        f.write(f"Generated on {time.strftime('%a %b %d %H:%M:%S UTC %Y', time.gmtime())}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        for name, path in workflows:
            f.write(f"| {name} | `./{path}` |\n")

    print(f"Successfully updated {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_workflows_md()
