"""Workflow contracts; run with the locked package-update-tools Python."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class WorkflowTests(unittest.TestCase):
    def test_update_workflow_only_publishes_main_after_validation(self):
        path = ROOT / ".github/workflows/package-updates.yml"
        self.assertTrue(path.exists(), "package update workflow is missing")
        workflow = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
        self.assertEqual(set(workflow["on"]), {"schedule", "workflow_dispatch"})
        self.assertEqual(workflow["on"]["schedule"], [{"cron": "23 8 * * 1"}])
        self.assertEqual(workflow["permissions"], {"contents": "read"})
        job = workflow["jobs"]["update"]
        self.assertIn("github.ref == 'refs/heads/main'", job["if"])
        self.assertEqual(job["strategy"]["matrix"]["include"], [
            {"package": "sane-scan-pdf", "path": "pkgs/sane-scan-pdf/default.nix"},
            {"package": "octoapp", "path": "pkgs/octoapp/default.nix"},
        ])
        steps = job["steps"]
        uses = {s["uses"].split("@")[0]: s for s in steps if "uses" in s}
        for step in uses.values():
            self.assertRegex(step["uses"], r"@[0-9a-f]{40}$")
        checkout = uses["actions/checkout"]
        self.assertEqual(checkout["with"]["ref"], "main")
        self.assertEqual(checkout["with"]["persist-credentials"], "false")
        token = uses["actions/create-github-app-token"]
        self.assertEqual(token["with"], {
            "app-id": "${{ vars.PACKAGE_UPDATE_APP_ID }}",
            "private-key": "${{ secrets.PACKAGE_UPDATE_APP_PRIVATE_KEY }}",
            "owner": "${{ github.repository_owner }}",
            "repositories": "${{ github.event.repository.name }}",
            "permission-contents": "write",
            "permission-pull-requests": "write",
        })
        build = next(s for s in steps if s.get("id") == "update")
        self.assertIn("scripts/update_packages.py", build["run"])
        self.assertIn("--apply", build["run"])
        self.assertLess(steps.index(build), steps.index(token))
        publish = uses["peter-evans/create-pull-request"]
        self.assertIn("steps.changes.outputs.changed == 'true'", publish["if"])
        self.assertIn("!inputs.check_only", publish["if"])
        self.assertEqual(token["if"], publish["if"])
        self.assertEqual(publish["with"]["token"], "${{ steps.app-token.outputs.token }}")
        self.assertEqual(publish["with"]["base"], "main")
        self.assertEqual(publish["with"]["branch"], "automation/package-${{ matrix.package }}")
        self.assertEqual(publish["with"]["add-paths"], "${{ matrix.path }}")
        self.assertNotIn("branch-suffix", publish["with"])
        self.assertNotIn("pull_request_target", workflow["on"])
        self.assertNotIn("automerge", path.read_text())
        self.assertEqual(workflow["on"]["workflow_dispatch"]["inputs"]["check_only"]["default"], "true")


    def test_pr_test_workflow_has_no_write_credentials(self):
        path = ROOT / ".github/workflows/package-update-tests.yml"
        workflow = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
        self.assertEqual(set(workflow["on"]), {"pull_request", "push", "workflow_dispatch"})
        self.assertEqual(workflow["permissions"], {"contents": "read"})
        self.assertNotIn("secrets.", path.read_text())
        for job in workflow["jobs"].values():
            self.assertNotIn("permissions", job)
            for step in job["steps"]:
                if "uses" in step:
                    self.assertRegex(step["uses"], r"@[0-9a-f]{40}$")
                if step.get("uses", "").startswith("actions/checkout@"):
                    self.assertEqual(step["with"]["persist-credentials"], "false")


if __name__ == "__main__":
    unittest.main()
