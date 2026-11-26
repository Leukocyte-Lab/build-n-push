import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PublishGuard(unittest.TestCase):
    def invoke(self, **overrides):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            gh = folder / 'gh'
            gh.write_text('#!/bin/sh\nprintf "%s\\n" called >> "$GH_CALL_LOG"\n'
                          '[ "${GH_TEST_STATUS:-0}" = 0 ] || exit "$GH_TEST_STATUS"\n'
                          'printf "%s\\n" "${GH_TEST_VISIBILITY:-private}"\n')
            gh.chmod(0o755)
            output, log = folder / 'output', folder / 'gh-calls'
            env = {**os.environ, 'PATH': directory + os.pathsep + os.environ['PATH'],
                   'GH_CALL_LOG': str(log), 'GITHUB_OUTPUT': str(output),
                   'GITHUB_EVENT_NAME': 'push', 'GITHUB_REF_PROTECTED': 'true',
                   'GHCR_PUBLISH_ENABLED': 'true', 'GITHUB_REPOSITORY_OWNER': 'Leukocyte-Lab',
                   'GITHUB_REF': 'refs/heads/develop', 'GHCR_PACKAGE': 'argushack3/fixture',
                   'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
                   'GH_TEST_STATUS': '0', 'GH_TEST_VISIBILITY': 'private', **overrides}
            proc = subprocess.run(['bash', str(ROOT / '.github/scripts/verify-ghcr-publish.sh')],
                                  env=env, capture_output=True, text=True)
            return proc, output.read_text() if output.exists() else '', log.exists()

    def test_pr_unprotected_unapproved_and_other_owner_never_call_api(self):
        for values in [{'GITHUB_EVENT_NAME': 'pull_request'}, {'GITHUB_REF_PROTECTED': 'false'},
                       {'GHCR_PUBLISH_ENABLED': 'false'}, {'GITHUB_REPOSITORY_OWNER': 'fork-owner'},
                       {'GITHUB_REF': 'refs/heads/codex/candidate'}]:
            with self.subTest(values=values):
                proc, output, called = self.invoke(**values)
                self.assertNotEqual(0, proc.returncode)
                self.assertFalse(called)
                self.assertEqual('', output)

    def test_denied_or_public_package_cannot_emit_publish_tag(self):
        for values in [{'GH_TEST_STATUS': '1'}, {'GH_TEST_VISIBILITY': 'public'}, {'GH_TEST_VISIBILITY': 'internal'}]:
            proc, output, called = self.invoke(**values)
            self.assertNotEqual(0, proc.returncode)
            self.assertTrue(called)
            self.assertEqual('', output)

    def test_private_package_uses_unique_run_and_attempt_tag(self):
        for ref in ['refs/heads/develop', 'refs/heads/release/fixture', 'refs/tags/v0.0.0-fixture']:
            proc, output, called = self.invoke(GITHUB_REF=ref)
            self.assertEqual(0, proc.returncode, proc.stderr)
            self.assertTrue(called)
            self.assertIn('image_tag=sha-' + 'a' * 40 + '-123-1', output)
            self.assertNotIn('latest', output)


if __name__ == '__main__':
    unittest.main()
