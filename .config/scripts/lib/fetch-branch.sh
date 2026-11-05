# Shared by add-setup.sh and sync-agents.sh. Source it, do not run it.
#
# fetch_branch <repo> <ref>
#   Fetches <ref> of <repo> into a throwaway repository and sets FETCHED_DIR to its path.
#   Read files with: git -C "$FETCHED_DIR" archive / ls-tree / cat-file ... FETCH_HEAD
#   The directory is removed when the calling script exits.
#   Call it directly, not as $(fetch_branch ...): a subshell would remove the directory at once.

fetch_branch() {
  local repo="$1" ref="$2"
  FETCHED_DIR="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$FETCHED_DIR'" EXIT
  git -C "$FETCHED_DIR" init -q
  if ! git -C "$FETCHED_DIR" fetch -q --depth 1 "$repo" "$ref" 2>/dev/null; then
    echo "Error: cannot fetch branch '$ref' from $repo (does the branch exist and do you have access?)" >&2
    exit 1
  fi
}
