#!/bin/zsh

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
reports_dir="$repo_dir/GPT Reports"
converter="$reports_dir/docx-to-md.py"
input_path="${1:-}"

fail() {
  print -u2 -- "$1"
  exit 1
}

[[ -n "$input_path" ]] || fail "No Word document was provided."
[[ -f "$input_path" ]] || fail "The selected file does not exist: $input_path"
[[ "${input_path:e:l}" == "docx" ]] || fail "Please choose a .docx file."
[[ -f "$converter" ]] || fail "The converter is missing: $converter"

branch="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD)" || \
  fail "The documents repository is not currently on a branch."

# Update first so the generated commit is based on the latest remote branch.
git -C "$repo_dir" pull --rebase --autostash --quiet

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/docx-publish.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT

working_docx="$work_dir/${input_path:t}"
cp -- "$input_path" "$working_docx"

conversion_output="$(/usr/bin/python3 "$converter" "$working_docx")"
last_line="${conversion_output##*$'\n'}"
[[ "$last_line" == "Wrote "* ]] || fail "Conversion finished but did not report an output file."

generated_path="${last_line#Wrote }"
[[ -f "$generated_path" ]] || fail "The generated Markdown file could not be found."

output_name="${generated_path:t}"
target_path="$reports_dir/$output_name"
relative_path="GPT Reports/$output_name"

if git -C "$repo_dir" ls-files --error-unmatch -- "$relative_path" >/dev/null 2>&1; then
  action="Update"
else
  action="Add"
fi

cp -- "$generated_path" "$target_path"

if [[ -z "$(git -C "$repo_dir" status --porcelain -- "$relative_path")" ]]; then
  print -- "No changes were needed for $output_name."
  exit 0
fi

git -C "$repo_dir" add -- "$relative_path"
git -C "$repo_dir" commit --only --quiet -m "📝 $action report: ${output_name:r}" -- "$relative_path"

if ! git -C "$repo_dir" push --quiet origin "$branch"; then
  fail "The Markdown file was converted and committed locally, but the push failed. Open Terminal and run: git -C ${(q)repo_dir} push"
fi

print -- "Published $output_name to GitHub."
