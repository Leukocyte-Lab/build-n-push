#!/usr/bin/env python3
"""Validate metadata supplied on stdin; this helper never contacts a registry/API."""
import json
import sys


def verify(data, package, repository):
    if not isinstance(data, dict) or data.get('package_type') != 'container':
        raise ValueError('Unknown container metadata')
    if not isinstance(data.get('name'), str) or data['name'].lower() != package.lower():
        raise ValueError('Unknown package identity')
    if data.get('visibility') != 'private':
        raise ValueError('Private visibility is unverified')
    owner = data.get('owner')
    if not isinstance(owner, dict) or not isinstance(owner.get('login'), str) or owner['login'].lower() != 'leukocyte-lab':
        raise ValueError('Package owner is unverified')
    linked = data.get('repository')
    if not isinstance(linked, dict) or not isinstance(linked.get('full_name'), str) or linked['full_name'].lower() != repository.lower():
        raise ValueError('Same-repository linkage is unverified')


def main():
    try:
        verify(json.load(sys.stdin), sys.argv[1], sys.argv[2])
    except (ValueError, TypeError, IndexError):
        print('Private package owner/name/linkage is unverified; publication blocked', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
