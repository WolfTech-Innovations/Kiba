#!/usr/bin/env python3
# License: MIT
import os

DOCS_DIR = "docs"
OUTPUT_FILE = "WIKI.md"

def get_markdown_files():
    files = []
    if not os.path.exists(DOCS_DIR):
        return files
    for f in sorted(os.listdir(DOCS_DIR)):
        if f.endswith(".md") and f != "README.md":
            files.append(os.path.join(DOCS_DIR, f))
    return files

def sync_wiki():
    files = get_markdown_files()
    content = ["# KibaOS Wiki", "Welcome to the unified KibaOS documentation.", ""]

    # Table of Contents
    content.append("## Table of Contents")
    for f in files:
        title = os.path.basename(f).replace(".md", "").replace("-", " ").title()
        anchor = os.path.basename(f).replace(".md", "").lower()
        content.append(f"- [{title}](#{anchor})")
    content.append("")

    # Combined Content
    for f in files:
        title = os.path.basename(f).replace(".md", "").replace("-", " ").title()
        anchor = os.path.basename(f).replace(".md", "").lower()
        content.append(f"<a name=\"{anchor}\"></a>")
        content.append(f"## {title}")
        with open(f, "r", encoding="utf-8") as md_file:
            # Skip first line if it's a # title
            lines = md_file.readlines()
            if lines and lines[0].startswith("# "):
                content.extend([l.strip() for l in lines[1:]])
            else:
                content.extend([l.strip() for l in lines])
        content.append("")
        content.append("---")
        content.append("")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(content))
    print(f"Updated {OUTPUT_FILE} with {len(files)} documentation files.")

if __name__ == "__main__":
    sync_wiki()
