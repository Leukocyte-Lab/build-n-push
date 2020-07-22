# Build n' Push

Builds and pushes Docker images and logs in to a Docker registry.

[Features](#features)

[Inputs](#inputs)

- [`repository`](#repository)
- [`username`](#username)
- [`password`](#password)
- [`tags`](#tags)
- [`path`](#path)
- [`dockerfile`](#dockerfile)
- [`push`](#push)
- [`ssh_private_key`](#ssh_private_key)
- [`ssh`](#ssh)

[Example](#example)

## Features

- BuildKit SSH support

## Inputs

### `repository`

**Required** Docker repository

### `username`

**Required** Username used to log in to a Docker registry.

### `password`

**Required** Password used to log in to a Docker registry.

### `tags`

Comma-delimited list of tags. These will be added to the registry/repository to form the image's tags.

Example:

```yaml
tags: v1,v1.0
```

### `path`

Path to the build context. Default to `.`

### `dockerfile`

Path to the Dockerfile. Defaults to `{path}/Dockerfile`

Note this path is **not** releative to the `path` but is relative to the working directory.

### `push`

Boolean value. Defaults to `true`.

Whether to push the built image.

### `ssh_private_key`

SSH private key for BuildKit to fetch private data in builds.

### `ssh`

Boolean value. Default to `false`.

Whether to add `--ssh default` into build command.

## Example

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v2

  - name: Build n' Push images
    uses: Leukocyte-Lab/build-n-push@v1
    env:
      DOCKER_BUILDKIT: 1
    with:
      ssh: true
      ssh_private_key: ${{ secrets.SSH_KEY }}
      repository: myorg/myrepo
      username: ${{ secrets.REGISTRY_USERNAME }}
      password: ${{ secrets.REGISTRY_PASSWORD }}
      registry: registry.myregistry.com
      tags: latest,v1
```
