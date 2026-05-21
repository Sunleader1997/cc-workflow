#!/bin/bash
# Install the workflow skill to ~/.claude/skills
# Usage: bash install_skill.sh

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.claude/skills/workflow"
SKILL_NAME="workflow"

echo "Installing skill: ${SKILL_NAME}"
echo "Source: ${SOURCE_DIR}"
echo "Target: ${TARGET_DIR}"

if [ -d "${TARGET_DIR}" ]; then
    echo ""
    echo "Skill '${SKILL_NAME}' already exists at ${TARGET_DIR}"
    read -r -p "Overwrite? [y/N] " confirm
    case "${confirm}" in
        [yY][eE][sS]|[yY])
            echo "Overwriting..."
            rm -rf "${TARGET_DIR}"
            ;;
        *)
            echo "Installation cancelled."
            exit 0
            ;;
    esac
fi

mkdir -p "$(dirname "${TARGET_DIR}")"
cp -r "${SOURCE_DIR}" "${TARGET_DIR}"

echo ""
echo "Skill '${SKILL_NAME}' installed successfully to ${TARGET_DIR}"
