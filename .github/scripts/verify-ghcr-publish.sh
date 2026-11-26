#!/usr/bin/env bash
set -euo pipefail

fail() { printf '%s\n' "$1" >&2; exit 1; }
case "${GITHUB_EVENT_NAME:-}" in push|workflow_dispatch) ;; *) fail 'Publication is unavailable to PR events' ;; esac
[[ "${GITHUB_REF_PROTECTED:-false}" == true ]] || fail 'Publication requires a protected ref'
[[ "${GHCR_PUBLISH_ENABLED:-false}" == true ]] || fail 'Private package/access readiness has not been approved'
case "${GITHUB_REPOSITORY_OWNER:-}" in Leukocyte-Lab|leukocyte-lab) ;; *) fail 'Unexpected repository owner' ;; esac
case "${GITHUB_REF:-}" in refs/heads/develop|refs/heads/main|refs/heads/master|refs/heads/release/*|refs/tags/v*) ;; *) fail 'Unexpected publication ref' ;; esac
[[ "${GHCR_PACKAGE:-}" =~ ^[a-z0-9][a-z0-9._/-]+$ ]] || fail 'Invalid GHCR package path'
[[ "${GITHUB_SHA:-}" =~ ^[a-f0-9]{40}$ ]] || fail 'Expected a full commit SHA'
[[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]] || fail 'Expected a unique workflow run identity'

# Refuse missing, inaccessible or non-private packages. Do not create a package
# or change visibility/access, and do not retry with another identity.
encoded_package=${GHCR_PACKAGE//\//%2F}
visibility=$(gh api "/orgs/leukocyte-lab/packages/container/$encoded_package" --jq .visibility)
[[ "$visibility" == private ]] || fail 'Existing private package visibility/access is not verified'

image_tag="sha-${GITHUB_SHA}-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
printf 'image_tag=%s\ntags_name=%s\n' "$image_tag" "$image_tag" >> "$GITHUB_OUTPUT"
