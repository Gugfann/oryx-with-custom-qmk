#!/usr/bin/env bash
#
# Build the layout locally, using the checked-out ./qmk_firmware submodule.
#
# Usage:
#   ./build-local.sh                  build the layout currently in ./<layout_id>
#   ./build-local.sh --fetch          pull the latest layout from Oryx, merge it into the
#                                     current branch (like the GitHub Action), then build
#   ./build-local.sh --rebuild-image  rebuild the Docker image (e.g. after editing Dockerfile)
#   ./build-local.sh --flash          flash the keyboard after a successful build
#                                     (put the board in bootloader mode first: press the
#                                     reset button on the back; can be combined with --fetch)
#
# Options (env vars):
#   LAYOUT_ID   Oryx layout id          (default: 6qgoE)
#   GEOMETRY    keyboard                (default: voyager)
#   ENGINE      native | docker | podman
#               (default: native if qmk + arm-none-eabi-gcc are installed,
#                otherwise docker, otherwise podman)
#
# --fetch commits the Oryx source to the local 'oryx' branch and merges it into
# your current branch. Nothing is pushed and the submodule is not updated.

set -euo pipefail

LAYOUT_ID="${LAYOUT_ID:-6qgoE}"
GEOMETRY="${GEOMETRY:-voyager}"
IMAGE="qmk"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

FETCH=0
FLASH=0
REBUILD_IMAGE=0
for arg in "$@"; do
  case "$arg" in
    --fetch) FETCH=1 ;;
    --flash) FLASH=1 ;;
    --rebuild-image) REBUILD_IMAGE=1 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "${ENGINE:-}" ]]; then
  if command -v qmk >/dev/null && command -v arm-none-eabi-gcc >/dev/null; then ENGINE=native
  elif command -v docker >/dev/null; then ENGINE=docker
  elif command -v podman >/dev/null; then ENGINE=podman
  else echo "Need qmk + arm-none-eabi-gcc, or docker/podman installed" >&2; exit 1
  fi
fi

TMP_DIR=""
cleanup_tmp() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    git worktree remove --force "$TMP_DIR/oryx" 2>/dev/null || true
    rm -rf "$TMP_DIR"
    git worktree prune
  fi
  TMP_DIR=""
}

fetch_layout() {
  echo "==> Fetching latest layout '${LAYOUT_ID}' (${GEOMETRY}) from Oryx"
  local query response hash_id
  query=$(LAYOUT_ID="$LAYOUT_ID" GEOMETRY="$GEOMETRY" python3 - <<'EOF'
import json, os
print(json.dumps({
    "query": "query getLayout($hashId: String!, $revisionId: String!, $geometry: String) {layout(hashId: $hashId, geometry: $geometry, revisionId: $revisionId) { revision { hashId, qmkVersion, title }}}",
    "variables": {
        "hashId": os.environ["LAYOUT_ID"],
        "geometry": os.environ["GEOMETRY"],
        "revisionId": "latest",
    },
}))
EOF
)
  response=$(curl -fsSL 'https://oryx.zsa.io/graphql' \
    --header 'Content-Type: application/json' --data "$query")
  hash_id=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["layout"]["revision"]["hashId"])' <<<"$response")

  local title
  title=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["layout"]["revision"]["title"] or "")' <<<"$response")
  [[ -n "$title" ]] || title="latest layout modification made with Oryx"

  local target
  target="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$target" == "oryx" || "$target" == "HEAD" ]]; then
    echo "Check out the branch you want to merge into (e.g. main) first; currently on '${target}'." >&2
    exit 1
  fi
  if [[ -n "$(git status --porcelain --ignore-submodules=all --untracked-files=no)" ]]; then
    echo "Working tree has uncommitted changes. Commit or stash them before using --fetch." >&2
    exit 1
  fi

  git fetch --quiet origin oryx 2>/dev/null || echo "    (could not fetch origin/oryx; using local branch)"
  if ! git show-ref --verify --quiet refs/heads/oryx; then
    if ! git show-ref --verify --quiet refs/remotes/origin/oryx; then
      echo "No 'oryx' branch found locally or on origin." >&2
      exit 1
    fi
    git branch oryx origin/oryx
  elif git show-ref --verify --quiet refs/remotes/origin/oryx \
      && git merge-base --is-ancestor oryx origin/oryx; then
    git branch -f oryx origin/oryx
  fi

  # Use a temporary worktree so the oryx branch can be committed to without
  # touching your current working tree.
  TMP_DIR="$(mktemp -d)"
  trap cleanup_tmp EXIT
  git worktree add --quiet "$TMP_DIR/oryx" oryx
  curl -fsSL "https://oryx.zsa.io/source/${hash_id}" -o "$TMP_DIR/source.zip"
  unzip -oj "$TMP_DIR/source.zip" '*_source/*' -d "$TMP_DIR/oryx/$LAYOUT_ID" >/dev/null
  git -C "$TMP_DIR/oryx" add -A -- "$LAYOUT_ID"
  if git -C "$TMP_DIR/oryx" diff --cached --quiet; then
    echo "    No layout change on Oryx"
  else
    git -C "$TMP_DIR/oryx" commit -q -m "✨(oryx): ${title}"
    echo "    Committed to 'oryx': ${title}"
  fi
  cleanup_tmp

  if git merge-base --is-ancestor oryx HEAD; then
    echo "    '${target}' already contains the latest Oryx layout"
  else
    echo "==> Merging 'oryx' into '${target}'"
    if ! git merge --no-edit -Xignore-all-space oryx; then
      echo "Merge conflict. Resolve it (git status), commit, then re-run without --fetch." >&2
      exit 1
    fi
  fi
}

ensure_image() {
  if [[ $REBUILD_IMAGE -eq 1 ]] || ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "==> Building ${IMAGE} image (one-time)"
    "$ENGINE" build -t "$IMAGE" .
  fi
}

[[ $FETCH -eq 1 ]] && fetch_layout

if [[ ! -d "$LAYOUT_ID" ]]; then
  echo "Layout folder ./${LAYOUT_ID} not found. Run with --fetch first." >&2
  exit 1
fi

if [[ ! -f qmk_firmware/Makefile ]]; then
  echo "==> Initialising qmk_firmware submodule"
  git submodule update --init --recursive qmk_firmware
fi

# Firmware >= 24 keeps ZSA boards under keyboards/zsa
if [[ -d qmk_firmware/keyboards/zsa ]]; then
  keyboard_dir="qmk_firmware/keyboards/zsa"
  make_prefix="zsa/"
else
  keyboard_dir="qmk_firmware/keyboards"
  make_prefix=""
fi

echo "==> Copying keymap into ${keyboard_dir}/${GEOMETRY}/keymaps/${LAYOUT_ID}"
rm -rf "${keyboard_dir}/${GEOMETRY}/keymaps/${LAYOUT_ID}"
mkdir -p "${keyboard_dir}/${GEOMETRY}/keymaps"
cp -r "$LAYOUT_ID" "${keyboard_dir}/${GEOMETRY}/keymaps/${LAYOUT_ID}"

echo "==> Compiling ${make_prefix}${GEOMETRY}:${LAYOUT_ID} (${ENGINE})"
if [[ "$ENGINE" == "native" ]]; then
  (cd qmk_firmware && QMK_HOME="$ROOT/qmk_firmware" \
    make -j"$(nproc)" -Otarget "${make_prefix}${GEOMETRY}:${LAYOUT_ID}")
else
  ensure_image
  run_args=(--rm -w /qmk -e HOME=/tmp
    -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*')
  if [[ "$ENGINE" == "docker" ]]; then
    run_args+=(-v "$ROOT/qmk_firmware:/qmk" --user "$(id -u):$(id -g)")
  else
    run_args+=(-v "$ROOT/qmk_firmware:/qmk:Z" --userns=keep-id)
  fi
  "$ENGINE" run "${run_args[@]}" "$IMAGE" \
    make -j"$(nproc)" -Otarget "${make_prefix}${GEOMETRY}:${LAYOUT_ID}"
fi

normalized="${GEOMETRY//\//_}"
mkdir -p build
found=0
flash_file=""
for f in qmk_firmware/*"${normalized}"*"${LAYOUT_ID}"*.bin qmk_firmware/*"${normalized}"*"${LAYOUT_ID}"*.hex; do
  [[ -f "$f" ]] || continue
  cp -f "$f" build/
  echo "==> Firmware ready: build/$(basename "$f")"
  [[ "$f" == *.bin ]] && flash_file="build/$(basename "$f")"
  found=1
done
[[ $found -eq 1 ]] || { echo "Build finished but no .bin/.hex found" >&2; exit 1; }

if [[ $FLASH -eq 1 ]]; then
  [[ -n "$flash_file" ]] || { echo "No .bin file to flash" >&2; exit 1; }
  echo "==> Flashing. Put the keyboard in bootloader mode now (press the reset button)."
  if [[ "$ENGINE" == "native" ]]; then
    (cd qmk_firmware && QMK_HOME="$ROOT/qmk_firmware" \
      qmk flash -kb "${make_prefix}${GEOMETRY}" -km "$LAYOUT_ID")
  elif command -v wally-cli >/dev/null; then
    wally-cli "$flash_file"
  else
    echo "Can't flash from a container. Install the qmk toolchain (native mode) or wally-cli," >&2
    echo "or flash ${flash_file} with Keymapp." >&2
    exit 1
  fi
fi
