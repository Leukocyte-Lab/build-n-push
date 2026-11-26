# GHCR publication candidate

This is a local migration candidate. No GHCR image, package permission, runner build, registry login or deployment has been verified by these workflow changes.

Pull requests run build/lint/tests on GitHub-hosted runners with read permissions. They do not receive a PAT, SSH identity or registry password. Private Go modules, submodules or npm packages may therefore require separately reviewed repository/package access; failure does not justify adding a broader credential to a PR job.

Publication requires a push to an existing protected branch or protected `v*` tag and the repository variable `GHCR_PUBLISH_ENABLED=true`. The common action's fixture publisher additionally requires an explicit manual request on protected `master`. No variable, protection rule, package, permission or visibility is created by this candidate.

Before login, the workflow's own `GITHUB_TOKEN` must be able to read the target container package and the API must report `private`. Missing, inaccessible, public or internal packages stop the job. Package existence/private visibility does not prove push permission. Existing package linking and explicit Actions access for each calling repository must be reviewed separately; the OCI source label does not grant access or change visibility.

The only published tag is `sha-<full commit SHA>-<run ID>-<attempt>`. This reserves a new run-specific name instead of replacing existing version, `latest`, `develop` or release-channel tags. Other writers must exclude this namespace. A package/tag policy or writer that can reuse this name is a publication blocker; GitHub/GHCR does not provide an atomic create-if-absent tag operation here. Record the resulting digest and verify all required platforms/blobs/attachments before consumers switch. Previous release images cannot be relabeled as point-free builds.

GitOps/manifest updates have a separate default-off gate, `GHCR_MANIFEST_UPDATES_ENABLED=true`, in addition to the publication gate and protected ref. It must remain off until the image digest, exact component combination, private pull credentials, offline behavior and rollback are verified. The old registry value remains an explicit Kustomize image-name selector for updating existing manifests. It is not used as a GHCR login. This candidate does not update a manifest repository or deploy anything.

Where a manual version-release workflow exists, it has its own default-off `GHCR_RELEASE_ENABLED=true` and protected source branch requirement. Existing release credentials and event-chain behavior are not assumed: pushes made with `GITHUB_TOKEN` normally do not trigger a subsequent workflow. No tag/branch/release should be created to test this candidate until that chain is reviewed.

UI/Report container builds now pass npm authentication through BuildKit `--secret`/`secret-envs`, not Docker build arguments. Local builds needing that private dependency must use the same secret mount; no token is stored in the Dockerfile. Their Docker builds have not been run by the offline guard tests.

The Captain protected publisher preserves its existing private-build inputs separately from GHCR authentication. A protected dependency checkout may still require its existing narrowly scoped repository identity; it is not assumed that a container package token reads other private repositories. Its PR job does not use that identity. E2E tests that contact external services are excluded from this PR/publication gate; use a separately approved isolated integration environment.

Rollback is to keep all gates disabled and continue using the previously verified image/chart/deployment combination. These workflows do not delete or modify Harbor, published artifacts, customer settings, permissions or historical tags. Candidate release worktrees are local backports, not branches to compare directly against a newer default branch containing unrelated application changes.

Before pushing or opening a private Draft PR, review repository/app triggers and Draft review-bot settings. The current remote default workflow of `build-n-push` publishes a GitLab fixture on any push that uses that unchanged workflow. A push uses the workflow at its event SHA/ref, so a branch containing this complete candidate is not automatically governed by the old default-branch workflow. This candidate's push filter accepts only `master`; a `codex/*` branch push does not match it. This corrects the earlier broader assumption about the default branch. No branch has been pushed, and remote app/review side effects remain unverified. See [GitHub workflow selection](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows#workflow-triggers) and [push events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push).

## Strict package ownership gate

Metadata must identify the exact container package, Leukocyte-Lab owner, private visibility and this same source repository linkage. Missing or different linkage stops publication; never change package linkage/permissions to satisfy this guard. A metadata read still does not prove Actions write access. All checks here are synthetic fixtures, not destination verification.
