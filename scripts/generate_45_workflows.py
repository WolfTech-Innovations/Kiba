import os

# Define the 45 audit checks with their Title Case names and internal function suffixes
audits = [
    ("Audit Build SH Customize Set E", "build_sh_customize_set_e"),
    ("Audit Build SH Pacman Populate", "build_sh_pacman_populate"),
    ("Audit Build SH PaperDE ldconfig", "build_sh_paperde_ldconfig"),
    ("Audit Build SH Liveuser UID", "build_sh_liveuser_uid"),
    ("Audit Build SH Relative Symlinks", "build_sh_relative_symlinks"),
    ("Audit Build SH Desktop Entry Kiba", "build_sh_desktop_entry_kiba"),
    ("Audit Build SH Sudoers Perms", "build_sh_sudoers_perms"),
    ("Audit Build SH Wallpaper Consistency", "build_sh_wallpaper_consistency"),
    ("Audit Build SH Octopi Usage", "build_sh_octopi_usage"),
    ("Audit Build SH Zsh Default", "build_sh_zsh_default"),
    ("Audit Markdown Empty Link Check", "markdown_empty_link_check"),
    ("Audit Repo Markdown Anchor Links", "repo_markdown_anchor_links"),
    ("Audit Repo README Badge HTTPS", "repo_readme_badge_https"),
    ("Audit Repo No Chmod 777 Strict", "repo_no_chmod_777_strict"),
    ("Audit Workflow No GitHub Token Leak", "workflow_no_github_token_leak"),
    ("Audit Repo No Plaintext Chpasswd", "repo_no_plaintext_chpasswd"),
    ("Audit Repo Gitkeep No Extension", "repo_gitkeep_no_extension"),
    ("Audit Repo No Nested Git Dir", "repo_no_nested_git_dir"),
    ("Audit Repo Trailing Whitespace All", "repo_trailing_whitespace_all"),
    ("Audit Repo Shell Extension Consistency", "repo_shell_extension_consistency"),
    ("Audit Repo License Sanity", "repo_license_sanity"),
    ("Audit Repo License Filename", "repo_license_filename"),
    ("Audit Repo Lowercase Directories", "repo_lowercase_directories"),
    ("Audit Repo Snake Case Scripts", "repo_snake_case_scripts"),
    ("Audit Repo No Pyc", "repo_no_pyc"),
    ("Audit Repo No Backup Files Hygiene", "repo_no_backup_files_hygiene"),
    ("Audit Repo PNPM Exclusive", "repo_pnpm_exclusive"),
    ("Audit Repo Forbidden Filenames", "repo_forbidden_filenames"),
    ("Audit Repo Large File Prevention Strict", "repo_large_file_prevention_strict"),
    ("Audit Repo Hex Colors", "repo_hex_colors"),
    ("Audit Repo SVG Metadata", "repo_svg_metadata"),
    ("Audit Workflow Checkout V4", "workflow_checkout_v4"),
    ("Audit Workflow No Node 16 Actions", "workflow_no_node_16_actions"),
    ("Audit Workflow Explicit Bash Shell", "workflow_explicit_bash_shell"),
    ("Audit Workflow No Empty Run Blocks", "workflow_no_empty_run_blocks"),
    ("Audit Workflow Job Permissions Only", "workflow_job_permissions_only"),
    ("Audit Workflow Timeout Reasonable", "workflow_timeout_reasonable"),
    ("Audit Workflow Kebab Filenames Strict", "workflow_kebab_filenames_strict"),
    ("Audit Workflow No Absolute Script Paths", "workflow_no_absolute_script_paths"),
    ("Audit Workflow Unused Workflow Inputs", "workflow_unused_workflow_inputs"),
    ("Audit Shebang Consistency", "shebang_consistency"),
    ("Audit Shell Script Pipefail", "shell_script_pipefail"),
    ("Audit Shell Script Trap Err Cleanup", "shell_script_trap_err_cleanup"),
    ("Audit Package Engines Field", "package_engines_field"),
    ("Audit Package Private Enforcement", "package_private_enforcement"),
]

workflow_template = """name: {name}

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  audit:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Run {name}
        run: bash scripts/repo_audit.sh --check {function_suffix}
        shell: bash
"""

os.makedirs(".github/workflows", exist_ok=True)

# Remove existing audit-*.yml workflows to avoid stale ones
for f in os.listdir(".github/workflows"):
    if f.startswith("audit-") and f.endswith(".yml"):
        os.remove(os.path.join(".github/workflows", f))

for name, function_suffix in audits:
    filename = name.lower().replace(" ", "-") + ".yml"
    filepath = os.path.join(".github/workflows", filename)
    with open(filepath, "w") as f:
        f.write(workflow_template.format(name=name, function_suffix=function_suffix))

print(f"Successfully generated {len(audits)} workflows in .github/workflows/")
