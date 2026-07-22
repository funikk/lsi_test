#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_BLOCK_DIR="$SKILL_DIR/resources/template_block"

PROJECT_DIR=""
BLOCK_NAME=""
FORCE=0

usage() {
    echo "Usage: $0 --project <project_path> --block <block_name> [--force]"
    echo "  -p, --project   Target multi-developer project directory (or relative path)"
    echo "  -b, --block     Name of the new sub-block to add"
    echo "  --force         Overwrite block directory if it exists"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--project)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -b|--block)
            BLOCK_NAME="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$PROJECT_DIR" || -z "$BLOCK_NAME" ]]; then
    echo "Error: Both --project and --block parameters are required."
    usage
fi

if [[ ! -d "$PROJECT_DIR/blocks" ]]; then
    echo "Error: Directory '$PROJECT_DIR/blocks' not found. Is '$PROJECT_DIR' a valid multi-developer project?"
    exit 1
fi

TARGET_BLOCK_DIR="$(cd "$PROJECT_DIR/blocks" && pwd)/$BLOCK_NAME"

if [[ -d "$TARGET_BLOCK_DIR" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        echo "Warning: Overwriting existing block '$BLOCK_NAME'..."
        rm -rf "$TARGET_BLOCK_DIR"
    else
        echo "Error: Sub-block '$BLOCK_NAME' already exists under '$PROJECT_DIR/blocks'. Use --force to overwrite."
        exit 1
    fi
fi

# 1. Copy block template
cp -r "$TEMPLATE_BLOCK_DIR" "$TARGET_BLOCK_DIR"

# 2. Replace placeholders in content
find "$TARGET_BLOCK_DIR" -type f -exec sed -i "s/__BLOCK_NAME__/${BLOCK_NAME}/g" {} +

# 3. Rename files containing placeholders
find "$TARGET_BLOCK_DIR" -name "*__BLOCK_NAME__*" | while read -r filepath; do
    newpath="$(echo "$filepath" | sed "s/__BLOCK_NAME__/${BLOCK_NAME}/g")"
    mv "$filepath" "$newpath"
done

echo "Successfully added sub-block '$BLOCK_NAME' to project at: $TARGET_BLOCK_DIR"
