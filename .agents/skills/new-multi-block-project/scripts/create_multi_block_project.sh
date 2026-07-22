#!/usr/bin/env bash
set -e

# Script Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SKILL_DIR/resources/template_project"

PROJECT_NAME=""
FORCE=0

usage() {
    echo "Usage: $0 --name <project_name> [--force]"
    echo "  -n, --name   Name of the multi-developer project to create"
    echo "  --force      Overwrite destination directory if it exists"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            PROJECT_NAME="$2"
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

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: Project name is required."
    usage
fi

TARGET_DIR="$(pwd)/$PROJECT_NAME"

if [[ -d "$TARGET_DIR" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        echo "Warning: Overwriting existing directory '$PROJECT_NAME'..."
        rm -rf "$TARGET_DIR"
    else
        echo "Error: Directory '$PROJECT_NAME' already exists. Use --force to overwrite."
        exit 1
    fi
fi

# 1. Copy template directory
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# 2. Replace placeholders in content
find "$TARGET_DIR" -type f -exec sed -i "s/__PROJECT_NAME__/${PROJECT_NAME}/g" {} +

# 3. Rename files containing placeholders
find "$TARGET_DIR" -name "*__PROJECT_NAME__*" | while read -r filepath; do
    newpath="$(echo "$filepath" | sed "s/__PROJECT_NAME__/${PROJECT_NAME}/g")"
    mv "$filepath" "$newpath"
done

echo "Successfully created multi-developer project '$PROJECT_NAME' at: $TARGET_DIR"
