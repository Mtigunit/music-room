#!/bin/sh

set -eu

current_branch=${1:-${GITHUB_REF_NAME:-$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)}}

if [ -z "$current_branch" ]; then
	echo "Skipping main-branch protection: detached HEAD."
	exit 0
fi

case "$current_branch" in
	main|master)
		echo "Push blocked: direct pushes to '$current_branch' are not allowed."
		exit 1
		;;
esac

echo "Main-branch protection passed for '$current_branch'."