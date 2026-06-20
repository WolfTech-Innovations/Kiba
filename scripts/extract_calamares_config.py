#!/usr/bin/env python3
import re
import os
import sys

def extract_heredoc(content, marker):
    pattern = rf'cat > .*? << \'{marker}\'\n(.*?)\n{marker}'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        # Try without quotes around marker
        pattern = rf'cat > .*? << {marker}\n(.*?)\n{marker}'
        match = re.search(pattern, content, re.DOTALL)
    return match.group(1) if match else None

def main():
    if not os.path.exists('build.sh'):
        print("build.sh not found")
        sys.exit(1)

    with open('build.sh', 'r') as f:
        content = f.read()

    # Extract QSS
    qss = extract_heredoc(content, 'QSS')
    if qss:
        with open('calamares-style.qss', 'w') as f:
            f.write(qss)
        print("Extracted calamares-style.qss")
    else:
        print("Failed to extract QSS")

    # Extract Branding
    branding = extract_heredoc(content, 'BRANDING')
    if branding:
        with open('branding.desc', 'w') as f:
            f.write(branding)
        print("Extracted branding.desc")
    else:
        print("Failed to extract BRANDING")

if __name__ == "__main__":
    main()
