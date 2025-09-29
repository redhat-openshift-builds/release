#!/bin/bash

# Use this script to update the Tekton Task Bundle references to the LATEST clean version tag.
# update-pipelines.sh .tekton/*.yaml

set -euo pipefail

FILES=$*

# Find existing image references
OLD_REFS="$( \
  yq -N \
  '... | select(has("resolver")) |
  .params // [] | .[] |
  select(.name == "bundle") |
  .value' \
  $FILES | \
  sort -u \
)"

# Find updates for image references
for old_ref in ${OLD_REFS}; do
    # 1. Extract the repository name (e.g., quay.io/my-org/my-bundle)
    repo_tag="${old_ref%@*}"
    repo="${repo_tag%:*}"

    echo -e "\nChecking for new versions of ${repo}..."

    # 2. Get all tags that look like versions
    version_tags=$(skopeo list-tags "docker://${repo}" | \
                   yq '.Tags[]' | \
                   grep -E '^[0-9]+\.[0-9]+' || true)

    if [[ -z "$version_tags" ]]; then
        echo -e "\n--> Could not find any valid version tags for ${repo}. Skipping."
        continue
    fi

    # 3. Find the highest version number by stripping suffixes before sorting
    latest_version_num=$(echo -e "\n${version_tags}" | sed 's/-.*//' | sort -V | tail -n1)

    # 4. From all tags matching that version, prefer the clean one (e.g., "0.1" over "0.1-hash")
    candidate_tags=$(echo -e "\n${version_tags}" | grep "^${latest_version_num}")
    latest_tag=$(echo -e "\n${candidate_tags}" | grep -E "^${latest_version_num}$" || echo -e "\n${candidate_tags}" | head -n1)

    # 5. Construct the new reference with the chosen latest tag
    new_repo_tag="${repo}:${latest_tag}"
    new_digest="$(skopeo inspect --no-tags "docker://${new_repo_tag}" | yq '.Digest')"
    new_ref="${new_repo_tag}@${new_digest}"

    # 6. If the new reference is different, update the files
    if [[ "$new_ref" == "$old_ref" ]]; then
        echo -e "\n--> ${old_ref} is already up-to-date."
        continue
    fi

    echo -e "\nNew version found! Updating to ${new_ref}"
    for file in $FILES; do
        sed -i "s#${old_ref}#${new_ref}#g" "$file"
    done
done
