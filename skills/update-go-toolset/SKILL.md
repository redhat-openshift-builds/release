---
name: update-go-toolset
description: Update go-toolset image SHAs to latest from Red Hat Catalog. Use when the user wants to update go-toolset base images in the release repo.
user_invocable: true
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# Update go-toolset Image SHAs

This skill fetches the latest go-toolset image digests from the Red Hat Container Catalog (Pyxis API) for both ubi9 and ubi10, then updates all references in the release repo YAML files, and opens a pull request with the changes.

## Step 0: Preconditions

Verify you are in the release repo by checking that `tasks/` and `pipelines/` directories exist at the repo root. If they do not exist, stop and tell the user this skill must be run from the release repo root.

Check you are on the `main` branch:

```bash
git branch --show-current
```

If not on `main`, ask the user whether to proceed anyway or switch to `main` first.

Verify `python3` and the `requests` module are available:

```bash
python3 -c "import requests; print('requests available')"
```

If `requests` is not installed, attempt `pip3 install requests` and retry. If that also fails, stop and tell the user to install the `requests` Python package.

## Step 1: Fetch Latest SHAs from Pyxis

Run the following inline Python script to query the Red Hat Container Catalog (Pyxis) API for the latest go-toolset image digests. Do NOT modify the script logic — run it exactly as shown.

```bash
python3 << 'PYEOF'
import requests, json, sys

PYXIS_API = "https://catalog.redhat.com/api/containers/v1/images"

REPOS = {
    "ubi9": "ubi9/go-toolset",
    "ubi10": "ubi10/go-toolset",
}

results = {}

for label, repo_path in REPOS.items():
    filter_str = (
        f"repositories.tags.name==latest;"
        f"repositories.repository=={repo_path}"
    )
    params = {
        "filter": filter_str,
        "page_size": 1,
        "sort_by": "last_update_date[desc]",
    }
    resp = requests.get(PYXIS_API, params=params, timeout=30)
    if resp.status_code != 200:
        print(f"ERROR: Pyxis returned {resp.status_code} for {label}", file=sys.stderr)
        sys.exit(1)

    data = resp.json()
    images = data.get("data", [])
    if not images:
        print(f"ERROR: No images found for {label} ({repo_path})", file=sys.stderr)
        sys.exit(1)

    image = images[0]

    # Extract manifest_list_digest from the matching repository entry
    digest = None
    for repo in image.get("repositories", []):
        if repo.get("repository") == repo_path:
            digest = repo.get("manifest_list_digest")
            break

    if not digest:
        print(f"ERROR: No manifest_list_digest found for {label}", file=sys.stderr)
        sys.exit(1)

    # Extract version from parsed_data.labels
    version = "unknown"
    for lbl in image.get("parsed_data", {}).get("labels", []):
        if lbl.get("name") == "version":
            version = lbl.get("value", "unknown")
            break

    results[label] = {"digest": digest, "version": version, "repo_path": repo_path}

# Output as JSON for easy parsing, and also human-readable
print(json.dumps(results, indent=2))
print()
for label, info in results.items():
    print(f"{label}: registry.redhat.io/{info['repo_path']}@{info['digest']}  (version: {info['version']})")
PYEOF
```

Capture the JSON output. Parse the digest values for ubi9 and ubi10. Display the results to the user in a readable table and ask: "These are the latest go-toolset digests from Red Hat Catalog. Proceed with updating?" using AskUserQuestion. If the user declines, stop.

## Step 2: Discover and Update Files

Find all YAML files referencing go-toolset SHAs:

```bash
grep -rn 'go-toolset@sha256' --include='*.yaml' --include='*.yml' .
```

For each file found:

1. Read the file with the Read tool.
2. Determine whether the reference is ubi9 or ubi10 by examining the image string (it will contain `ubi9/go-toolset` or `ubi10/go-toolset`).
3. Compare the current SHA against the newly fetched SHA for that variant.
4. If the SHA differs, use the Edit tool to replace the old full image reference (`registry.redhat.io/ubiN/go-toolset@sha256:OLD_HASH`) with the new one (`registry.redhat.io/ubiN/go-toolset@sha256:NEW_HASH`).
5. If the SHA is already current, skip that file and note it.

After processing all files, display a summary:

```
Updated files:
  - pipelines/konflux-build-multi-platform.yaml (ubi9 SHA updated)
  - tasks/unit-test.yaml (ubi10 SHA updated)

Already current:
  (none)
```

If no files were found at all, stop and tell the user there are no go-toolset references in the repo. If all files are already current, stop and tell the user everything is up to date — no changes needed.

## Step 3: Create Branch, Commit, and Push

Create and switch to a new branch:

```bash
git checkout -b update-go-toolset-shas
```

If the branch already exists, ask the user via AskUserQuestion:
- A) Delete and recreate
- B) Use a different name (e.g., `update-go-toolset-shas-2`)
- C) Abort

Stage only the specific files that were changed (never use `git add -A` or `git add .`):

```bash
git add pipelines/konflux-build-multi-platform.yaml tasks/unit-test.yaml
```

(Use the actual list of changed files from Step 2.)

Commit with sign-off and GPG signing, using a HEREDOC for the commit message:

```bash
git commit -s -S -m "$(cat <<'EOF'
chore: update go-toolset image SHAs to latest

Update ubi9/go-toolset and ubi10/go-toolset with latest image digests.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

Detect fork setup:

```bash
FETCH_URL=$(git remote get-url origin)
PUSH_URL=$(git remote get-url --push origin)
echo "Fetch: $FETCH_URL"
echo "Push:  $PUSH_URL"
```

If `FETCH_URL != PUSH_URL` (fork setup):
- Extract upstream slug: `UPSTREAM_SLUG=$(echo "$FETCH_URL" | sed 's/.*github.com[:/]\(.*\)\.git/\1/')`
- Extract fork owner: `FORK_OWNER=$(echo "$PUSH_URL" | sed 's/.*github.com[:/]\([^/]*\).*/\1/')`

If same URLs (direct access):
- Extract slug: `SLUG=$(echo "$FETCH_URL" | sed 's/.*github.com[:/]\(.*\)\.git/\1/')`

Push the branch:

```bash
git push -u origin update-go-toolset-shas
```

If push fails because the branch already exists on the remote, use `--force-with-lease`.

## Step 4: Create Pull Request

Build the PR body dynamically from the list of updated files from Step 2. Replace `<file1>`, `<file2>` with actual file paths.

If fork setup (`FETCH_URL != PUSH_URL`):

```bash
gh pr create --repo "$UPSTREAM_SLUG" --base main \
  --head "$FORK_OWNER:update-go-toolset-shas" \
  --title "chore: update go-toolset image SHAs to latest" \
  --body "$(cat <<'EOF'
## Summary
- Update ubi9/go-toolset SHA in `<file1>`
- Update ubi10/go-toolset SHA in `<file2>`
EOF
)"
```

If direct access (same URLs):

```bash
gh pr create --repo "$SLUG" --base main \
  --title "chore: update go-toolset image SHAs to latest" \
  --body "$(cat <<'EOF'
## Summary
- Update ubi9/go-toolset SHA in `<file1>`
- Update ubi10/go-toolset SHA in `<file2>`
EOF
)"
```

Display the PR URL to the user when done.

## Error Handling

- **Pyxis API failure**: If the API returns a non-200 status or no images, display the error and stop. Suggest the user check https://catalog.redhat.com manually.
- **Missing requests module**: Attempt `pip3 install requests`. If that fails, tell the user to install it (`pip3 install requests` or `brew install python-requests`).
- **No go-toolset files found**: Tell the user there are no `go-toolset@sha256` references in YAML files in this repo.
- **All SHAs already current**: Tell the user all go-toolset references are already up to date. Do not create a branch, commit, or PR.
- **Branch already exists**: Delete the local branch and recreate it. For remote, use `--force-with-lease`.
- **Push failure**: Display the git error output and suggest the user check remote permissions and authentication.
- **PR creation failure**: Display the `gh` error output. Common causes: not authenticated (`gh auth login`), PR already exists for this branch. If a PR already exists, display its URL instead.
