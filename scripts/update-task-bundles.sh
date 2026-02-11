#!/bin/bash

# Use this script to update the Tekton Task Bundle references to the LATEST clean version tag.
# Usage: update-task-bundles.sh pipelines/*.yaml

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file1.yaml> [file2.yaml ...]"
    exit 1
fi

FILES=("$@")

# Find existing image references
mapfile -t OLD_REFS < <(
  yq -N \
  '... | select(has("resolver")) |
  .params // [] | .[] |
  select(.name == "bundle") |
  .value' \
  "${FILES[@]}" | \
  sort -u
)

if [[ ${#OLD_REFS[@]} -eq 0 ]]; then
    echo "No bundle references found in the provided files."
    exit 0
fi

# Cache: repo -> "latest_tag digest" to avoid duplicate registry lookups
declare -A REPO_CACHE

# Find updates for image references
for old_ref in "${OLD_REFS[@]}"; do
    # 1. Extract the repository name (e.g., quay.io/my-org/my-bundle)
    repo_tag="${old_ref%@*}"
    repo="${repo_tag%:*}"

    echo ""
    echo "Checking for new versions of ${repo}..."

    # 2. Check cache for this repo, otherwise query the registry
    if [[ -n "${REPO_CACHE[$repo]+x}" ]]; then
        latest_tag="${REPO_CACHE[$repo]%% *}"
        new_digest="${REPO_CACHE[$repo]#* }"
    else
        # Get all tags that look like versions
        version_tags=$(skopeo list-tags "docker://${repo}" | \
                       yq '.Tags[]' | \
                       grep -E '^[0-9]+\.[0-9]+' || true)

        if [[ -z "$version_tags" ]]; then
            echo "--> Could not find any valid version tags for ${repo}. Skipping."
            continue
        fi

        # 3. Find the highest version number by stripping suffixes before sorting
        latest_version_num=$(echo "$version_tags" | sed 's/-.*//' | sort -V | tail -n1)

        # 4. From all tags matching that version, prefer the clean one (e.g., "0.1" over "0.1-hash")
        escaped_version=$(printf '%s' "$latest_version_num" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
        candidate_tags=$(echo "$version_tags" | grep "^${escaped_version}")
        latest_tag=$(echo "$candidate_tags" | grep -E "^${escaped_version}$" || echo "$candidate_tags" | head -n1)

        # 5. Resolve the digest for the chosen tag
        new_digest="$(skopeo inspect --no-tags "docker://${repo}:${latest_tag}" | yq '.Digest')" || {
            echo "--> Failed to inspect ${repo}:${latest_tag}. Skipping."
            continue
        }

        # Cache the result
        REPO_CACHE[$repo]="${latest_tag} ${new_digest}"
    fi

    # 6. Construct the new reference
    new_ref="${repo}:${latest_tag}@${new_digest}"

    # 7. If the new reference is different, update the files
    if [[ "$new_ref" == "$old_ref" ]]; then
        echo "--> ${old_ref} is already up-to-date."
        continue
    fi

    echo "New version found! Updating to ${new_ref}"
    escaped_old_ref=$(printf '%s' "$old_ref" | sed 's/[.[\*^$()+?{|\\/#]/\\&/g')
    for file in "${FILES[@]}"; do
        sed -i "s#${escaped_old_ref}#${new_ref}#g" "$file"
    done
done
