#!/bin/sh

set -eu

current_branch=${1:-${GITHUB_REF_NAME:-${GITHUB_HEAD_REF:-$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)}}}

if [ -z "$current_branch" ]; then
	echo "Skipping branch-name check: detached HEAD."
	exit 0
fi

case "$current_branch" in
	main|master)
		echo "Branch name check failed: '$current_branch' is reserved for protected branches."
		exit 1
		;;
	feat/*|fix/*|docs/*|chore/*|refactor/*|test/*|ci/*|build/*|hotfix/*|release/*|perf/*)
		echo "Branch name check passed for '$current_branch'."
		;;
	*)
		echo "Branch name check failed: use a prefix like feat/, fix/, docs/, chore/, refactor/, test/, ci/, build/, hotfix/, release/, or perf/."
		exit 1
		;;
esac