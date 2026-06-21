#!/usr/bin/env python3
# License: MIT
import re
import os

BUILD_SCRIPT = "build.sh"

def extract_heredoc(content, filename):
    pattern = rf"cat > \"\${{AIROOTFS}}.*{filename}\" << '([^']+)'\n(.*?)\n\1"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(2)
    return None

def main():
    if not os.path.exists(BUILD_SCRIPT):
        print(f"Error: {BUILD_SCRIPT} not found.")
        return

    with open(BUILD_SCRIPT, "r", encoding="utf-8") as f:
        content = f.read()

    # Extract QSS
    qss = extract_heredoc(content, "stylesheet.qss")
    if qss:
        with open("calamares_extracted.qss", "w") as f:
            f.write(qss)
        print("Extracted stylesheet.qss to calamares_extracted.qss")
    else:
        print("Warning: Could not extract stylesheet.qss")

    # Extract branding.desc
    branding = extract_heredoc(content, "branding.desc")
    if branding:
        with open("calamares_extracted.desc", "w") as f:
            f.write(branding)
        print("Extracted branding.desc to calamares_extracted.desc")
    else:
        print("Warning: Could not extract branding.desc")

if __name__ == "__main__":
    main()
