import os
import datetime

WORKFLOW_DIR = ".github/workflows"
OUTPUT_FILE = "WORKFLOWS.md"

def get_workflow_name(filepath):
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if line.startswith('name:'):
                    # Extract name and strip quotes if present
                    name = line.split('name:', 1)[1].strip()
                    if (name.startswith('"') and name.endswith('"')) or (name.startswith("'") and name.endswith("'")):
                        name = name[1:-1]
                    return name
        return os.path.basename(filepath)
    except Exception:
        return os.path.basename(filepath)

def main():
    workflows = []
    if not os.path.exists(WORKFLOW_DIR):
        print(f"Error: {WORKFLOW_DIR} does not exist")
        return

    for f in sorted(os.listdir(WORKFLOW_DIR)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = os.path.join(WORKFLOW_DIR, f)
            name = get_workflow_name(filepath)
            workflows.append((name, filepath))

    # Using manual UTC offset string to avoid potential issues in some environments
    now = datetime.datetime.now().strftime("%a %b %d %H:%M:%S UTC %Y")

    with open(OUTPUT_FILE, 'w') as f:
        f.write("# GitHub Workflows Manual\n")
        f.write(f"Generated on {now}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        for name, path in workflows:
            f.write(f"| {name} | `{path}` |\n")
    print(f"Successfully updated {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
