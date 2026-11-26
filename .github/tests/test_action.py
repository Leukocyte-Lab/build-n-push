import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ActionSafety(unittest.TestCase):
    def invoke(self, **overrides):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            log = folder / 'docker.jsonl'
            docker = folder / 'docker'
            docker.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                              'with open(os.environ["DOCKER_TEST_LOG"],"a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                              'if sys.argv[1]=="login": sys.stdin.read()\n')
            docker.chmod(0o755)
            env = {**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH'],
                   'DOCKER_TEST_LOG': str(log), 'INPUT_REGISTRY': 'ghcr.io',
                   'INPUT_REPOSITORY': 'leukocyte-lab/argushack2/action-test',
                   'INPUT_TAGS': 'sha-' + 'a' * 40 + '-123-1', 'INPUT_PUSH': 'false',
                   'GITHUB_EVENT_NAME': 'pull_request', 'GITHUB_REF_PROTECTED': 'false',
                   'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
                   'GITHUB_REPOSITORY_OWNER': 'Leukocyte-Lab', 'GHCR_PUBLISH_ENABLED': 'true',
                   'INPUT_SSH': 'false', 'INPUT_SSH_PRIVATE_KEY': '',
                   'INPUT_USERNAME': '', 'INPUT_PASSWORD': '', **overrides}
            result = subprocess.run(['sh', str(ROOT / 'entrypoint.sh')], env=env, capture_output=True, text=True)
            calls = [json.loads(s) for s in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_pr_build_needs_no_credentials_and_never_logs_in(self):
        result, calls = self.invoke()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(['build'], [c[0] for c in calls])

    def test_pr_push_and_ssh_are_rejected_before_docker(self):
        for changes in [{'INPUT_PUSH': 'true'}, {'INPUT_SSH_PRIVATE_KEY': 'fixture-only'}, {'INPUT_PASSWORD': 'fixture-only'}]:
            result, calls = self.invoke(**changes)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual([], calls)

    def test_unprotected_push_is_rejected_before_login(self):
        result, calls = self.invoke(INPUT_PUSH='true', GITHUB_EVENT_NAME='push', INPUT_USERNAME='fixture', INPUT_PASSWORD='fixture-only')
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], calls)

    def test_protected_publish_logs_in_builds_and_pushes_only_unique_run_tag(self):
        result, calls = self.invoke(INPUT_PUSH='true', GITHUB_EVENT_NAME='push', GITHUB_REF_PROTECTED='true', INPUT_USERNAME='fixture', INPUT_PASSWORD='fixture-only')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(['login', 'build', 'push'], [c[0] for c in calls])
        self.assertNotIn('fixture-only', json.dumps(calls))

    def test_unapproved_or_existing_alias_tags_never_log_in(self):
        for changes in [{'INPUT_TAGS': 'latest'}, {'INPUT_TAGS': 'v1.0.0'}, {'GHCR_PUBLISH_ENABLED': 'false'}]:
            result, calls = self.invoke(INPUT_PUSH='true', GITHUB_EVENT_NAME='push', GITHUB_REF_PROTECTED='true', INPUT_USERNAME='fixture', INPUT_PASSWORD='fixture-only', **changes)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual([], calls)

    def test_wrong_org_and_argument_injection_are_rejected(self):
        for changes in [{'INPUT_REPOSITORY': 'other-org/image'}, {'INPUT_TAGS': 'v1 --push'}, {'INPUT_REGISTRY': 'ghcr.io/path'}]:
            result, calls = self.invoke(**changes)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual([], calls)

    def test_context_with_spaces_is_one_argument(self):
        result, calls = self.invoke(INPUT_PATH='path with spaces')
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(['--', 'path with spaces'], calls[0][-2:])


if __name__ == '__main__':
    unittest.main()
