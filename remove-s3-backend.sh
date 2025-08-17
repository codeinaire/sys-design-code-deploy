#!/usr/bin/env bash
set -euo pipefail

# Remove Terraform backend "s3" blocks from all main.tf files under the repo

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root_dir="$script_dir"

# Find all main.tf files and process them
changed=0
while IFS= read -r -d '' tf_file; do
  tmp_file="$(mktemp)"

  awk '
    BEGIN { in_backend = 0; depth = 0; pending_backend_open = 0 }
    {
      original_line = $0

      if (in_backend) {
        line_copy = original_line
        opens = gsub(/\{/, "", line_copy)
        closes = gsub(/\}/, "", line_copy)
        depth += (opens - closes)
        if (depth <= 0) { in_backend = 0 }
        next
      }

      # If previous line matched backend without an opening brace, wait until we see the opening brace
      if (pending_backend_open) {
        line_copy = original_line
        opens = gsub(/\{/, "", line_copy)
        closes = gsub(/\}/, "", line_copy)
        if (opens > 0) {
          in_backend = 1
          pending_backend_open = 0
          depth = opens - closes
          if (depth <= 0) { in_backend = 0 }
          next
        } else {
          next
        }
      }

      # Detect start of backend "s3" block (brace can be on same line)
      if (match(original_line, /^[[:space:]]*backend[[:space:]]*"s3"([[:space:]]*\{)?[[:space:]]*$/)) {
        in_backend = 1
        depth = 0
        line_copy = original_line
        opens = gsub(/\{/, "", line_copy)
        closes = gsub(/\}/, "", line_copy)
        depth += (opens - closes)
        if (opens == 0) {
          # No opening brace on this line: mark pending and do not print this or following lines until block ends
          pending_backend_open = 1
          in_backend = 0
        } else if (depth <= 0) {
          in_backend = 0
        }
        next
      }

      print original_line
    }
  ' "$tf_file" > "$tmp_file"

  if ! cmp -s "$tf_file" "$tmp_file"; then
    cp "$tf_file" "$tf_file.bak"
    mv "$tmp_file" "$tf_file"
    echo "Updated: $tf_file (backup at $tf_file.bak)"
    changed=$((changed+1))
  else
    rm -f "$tmp_file"
  fi
done < <(find "$repo_root_dir" -type f -name 'main.tf' -print0)

if [[ $changed -eq 0 ]]; then
  echo "No changes were necessary."
else
  echo "Done. Updated $changed file(s)."
fi
