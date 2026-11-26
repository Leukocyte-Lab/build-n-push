#!/bin/sh
set -efu

fail() { printf '%s\n' "$1" >&2; exit 1; }

registry=${INPUT_REGISTRY:-ghcr.io}
repository=${INPUT_REPOSITORY:-}
tags=${INPUT_TAGS:-latest}
push=${INPUT_PUSH:-false}

case "$push" in true|false) ;; *) fail 'push must be true or false' ;; esac
case "$registry" in ''|*[!a-zA-Z0-9.:-]*) fail 'invalid registry host' ;; esac
case "$repository" in ''|/*|*/|*//*|*[!a-z0-9._/-]*) fail 'invalid repository path' ;; esac
if [ "$registry" = ghcr.io ]; then
    case "$repository" in leukocyte-lab/*) ;; *) fail 'GHCR repository must be under leukocyte-lab/' ;; esac
fi

# PR builds never log in or receive an SSH key. Publishing also requires the
# calling workflow to grant package access and isolate protected publication.
case "${GITHUB_EVENT_NAME:-}" in
    pull_request|pull_request_target)
        [ "$push" = false ] || fail 'publishing is forbidden in pull requests'
        [ -z "${INPUT_SSH_PRIVATE_KEY:-}" ] || fail 'SSH credentials are forbidden in pull requests'
        [ -z "${INPUT_USERNAME:-}${INPUT_PASSWORD:-}" ] || fail 'registry credentials are forbidden in pull requests'
        ;;
esac
if [ "$push" = true ]; then
    case "${GITHUB_EVENT_NAME:-}" in push|release|workflow_dispatch) ;; *) fail 'publishing requires an explicit GitHub publish event' ;; esac
    [ "${GITHUB_REF_PROTECTED:-false}" = true ] || fail 'publishing requires a protected ref'
    [ -n "${INPUT_USERNAME:-}" ] && [ -n "${INPUT_PASSWORD:-}" ] || fail 'publishing requires credentials'
    if [ "$registry" = ghcr.io ]; then
        [ "${GHCR_PUBLISH_ENABLED:-false}" = true ] || fail 'GHCR package/access readiness has not been approved'
        case "${GITHUB_REPOSITORY_OWNER:-}" in Leukocyte-Lab|leukocyte-lab) ;; *) fail 'unexpected publishing owner' ;; esac
        [ -n "${GITHUB_SHA:-}" ] && [ -n "${GITHUB_RUN_ID:-}" ] && [ -n "${GITHUB_RUN_ATTEMPT:-}" ] || fail 'publishing requires a unique run identity'
        [ "$tags" = "sha-${GITHUB_SHA}-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}" ] || fail 'GHCR publication requires the unique run tag from the package preflight'
    fi
fi

validate_tags() {
    task_ifs=$IFS
    IFS=,
    for tag in $tags; do
        case "$tag" in ''|[.-]*|*[!a-zA-Z0-9_.-]*) fail 'invalid image tag' ;; esac
        [ "${#tag}" -le 128 ] || fail 'image tag is too long'
    done
    IFS=$task_ifs
}
validate_tags

cleanup() {
    if [ -n "${action_agent_pid:-}" ]; then ssh-agent -k >/dev/null 2>&1 || :; fi
}
trap cleanup EXIT HUP INT TERM
if [ "${INPUT_SSH:-false}" = true ] && [ -n "${INPUT_SSH_PRIVATE_KEY:-}" ]; then
    eval "$(ssh-agent -s)" >/dev/null
    action_agent_pid=$SSH_AGENT_PID
    printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" | ssh-add - >/dev/null 2>&1
fi

if [ "$push" = true ]; then
    printf '%s\n' "$INPUT_PASSWORD" | docker login "$registry" -u "$INPUT_USERNAME" --password-stdin
fi

set --
task_ifs=$IFS
IFS=,
for tag in $tags; do set -- "$@" -t "$registry/$repository:$tag"; done
IFS=$task_ifs
[ -z "${INPUT_DOCKERFILE:-}" ] || set -- "$@" -f "$INPUT_DOCKERFILE"
[ "${INPUT_SSH:-false}" != true ] || set -- "$@" --ssh default
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    set -- "$@" --label "org.opencontainers.image.source=https://github.com/$GITHUB_REPOSITORY"
fi
docker build "$@" -- "${INPUT_PATH:-.}"

if [ "$push" = true ]; then
    task_ifs=$IFS
    IFS=,
    for tag in $tags; do docker push "$registry/$repository:$tag"; done
    IFS=$task_ifs
fi
