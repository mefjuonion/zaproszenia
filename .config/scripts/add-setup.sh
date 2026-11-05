#!/usr/bin/env bash
#
# Add a component (service) from the template to this project.
#
# Usage (through mise):
#   mise run add-setup <component> [name]
#
#   mise run add-setup frontend/next          ->  src/frontend
#   mise run add-setup api/fastapi worker     ->  src/worker
#
# What it does:
#   1. Fetches the templates branch of the template repository.
#   2. Copies <component> to src/<name>. <name> defaults to the first part of <component>.
#   3. Replaces __NAME__ with <name> in the component's compose.yml and lefthook.yml.
#   4. Adds the component's compose.yml to .config/docker-compose.yml.
#   5. Installs the tools from the component's mise.toml.
#   6. Syncs Claude skills for the project's technologies (sync-agents.sh).
#
# Variables (set in mise.toml):
#   TEMPLATE_REPO   Template repository URL or path.
#   TEMPLATE_REF    Branch with the components (default: templates).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE_PATH="$REPO_ROOT/.config/docker-compose.yml"
FILES_WITH_NAME_PLACEHOLDER=(compose.yml lefthook.yml)
# Same rule as Cloud Run service names, enforced in services.tf.
VALID_NAME='^[a-z][a-z0-9-]{0,47}[a-z0-9]$'

fail() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  echo "Usage: mise run add-setup <component> [name], e.g. mise run add-setup frontend/next" >&2
  exit 1
}

# --- Arguments ---------------------------------------------------------------

component="${1:-}"
[[ -n "$component" ]] || usage
name="${2:-${component%%/*}}"
repo="${TEMPLATE_REPO:-}"
ref="${TEMPLATE_REF:-templates}"
dest="$REPO_ROOT/src/$name"

[[ -n "$repo" ]] || fail "TEMPLATE_REPO is not set (see [env] in mise.toml)"
[[ "$name" =~ $VALID_NAME ]] ||
  fail "'$name' is not a valid service name (lowercase letters, digits and hyphens, starting with a letter)"
[[ ! -e "$dest" ]] || fail "src/$name already exists"

# --- Fetch the template ------------------------------------------------------
# A throwaway repository, so nothing is added to this project's git config.

source "$REPO_ROOT/.config/scripts/lib/fetch-branch.sh"
echo "Fetching $ref from $repo"
fetch_branch "$repo" "$ref"
workdir="$FETCHED_DIR"
template() { git -C "$workdir" "$@"; }

list_components() {
  local group
  template ls-tree -d --name-only FETCH_HEAD | while read -r group; do
    template ls-tree -d --name-only "FETCH_HEAD:$group" | sed "s|^|  $group/|"
  done
}

if [[ "$(template cat-file -t "FETCH_HEAD:$component" 2>/dev/null)" != "tree" ]]; then
  echo "Error: no component '$component' in $repo ($ref). Available:" >&2
  list_components >&2
  exit 1
fi

# --- Copy and rename ---------------------------------------------------------

extracted="$workdir/out/$component"
mkdir -p "$workdir/out"
template archive FETCH_HEAD "$component" | tar -x -C "$workdir/out"

for file in "${FILES_WITH_NAME_PLACEHOLDER[@]}"; do
  if [[ -f "$extracted/$file" ]]; then
    sed -i.bak "s/__NAME__/$name/g" "$extracted/$file"
    rm "$extracted/$file.bak"
  fi
done

mkdir -p "$REPO_ROOT/src"
mv "$extracted" "$dest"
echo "Copied $component to src/$name"

# --- Register in the local dev stack -----------------------------------------

if [[ -f "$dest/compose.yml" ]]; then
  echo "  - ../src/$name/compose.yml" >>"$COMPOSE_FILE_PATH"
  echo "Added src/$name/compose.yml to .config/docker-compose.yml"
fi

# --- Install the component's tools -------------------------------------------

if [[ -f "$dest/mise.toml" ]]; then
  echo "Installing tools from src/$name/mise.toml"
  (cd "$REPO_ROOT" && mise install --monorepo)
fi

# --- Match Claude skills to the new technology -------------------------------

"$REPO_ROOT/.config/scripts/sync-agents.sh" ||
  echo "Warning: Claude skills not synced, run it later with: mise run agents" >&2

echo
echo "Done. Start it with: mise run dev"
