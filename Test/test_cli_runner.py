import contextlib
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import run_tests


class CliRunnerTests(unittest.TestCase):
    def test_run_godot_parses_result(self):
        record = {"suite": "controller", "tests": ["test_example"]}
        output = "game output\n" + run_tests.PREFIX + json.dumps(record) + "\n"
        completed = subprocess.CompletedProcess([], 0, stdout=output)
        with mock.patch.object(run_tests.subprocess, "run", return_value=completed) as run:
            actual, captured, problem = run_tests.run_godot("godot", "controller", "--list", 5)
        self.assertEqual(actual, record)
        self.assertEqual(captured, output)
        self.assertIsNone(problem)
        self.assertIn("--headless", run.call_args.args[0])

    def test_run_godot_reports_timeout_and_partial_output(self):
        timeout = subprocess.TimeoutExpired(["godot"], 5, output=b"partial")
        with mock.patch.object(run_tests.subprocess, "run", side_effect=timeout):
            record, output, problem = run_tests.run_godot("godot", "controller", "test_x", 5)
        self.assertIsNone(record)
        self.assertEqual(output, "partial")
        self.assertIn("Timed out", problem)

    def test_run_godot_rejects_bad_or_missing_results(self):
        for output in ("", run_tests.PREFIX + "not json\n",
                       run_tests.PREFIX + '{"suite": "view"}\n'):
            with self.subTest(output=output):
                completed = subprocess.CompletedProcess([], 0, stdout=output)
                with mock.patch.object(run_tests.subprocess, "run", return_value=completed):
                    record, _, problem = run_tests.run_godot("godot", "controller", "--list", 5)
                self.assertIsNone(record)
                self.assertIsNotNone(problem)

    def test_run_godot_rejects_nonzero_exit_even_with_result(self):
        output = run_tests.PREFIX + '{"suite": "controller", "tests": ["test_x"]}\n'
        completed = subprocess.CompletedProcess([], 1, stdout=output)
        with mock.patch.object(run_tests.subprocess, "run", return_value=completed):
            record, _, problem = run_tests.run_godot("godot", "controller", "--list", 5)
        self.assertIsNone(record)
        self.assertIn("exited with code 1", problem)

    def run_main(self, test_result, output="", test="test_example"):
        discovery = {"suite": "controller", "tests": ["test_example"]}
        result = {"suite": "controller", "result": test_result}
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(run_tests, "run_godot", side_effect=[
                (discovery, "", None), (result, output, None)
            ]), contextlib.redirect_stdout(io.StringIO()):
                code = run_tests.main(["--test", test, "--log-dir", directory])
            log = Path(directory, "controller-test_example.log").read_text()
        return code, log

    def test_clean_pass(self):
        result = {"test": "test_example", "passed": True, "error": "", "duration_ms": 10}
        code, log = self.run_main(result, "test output")
        self.assertEqual(code, 0)
        self.assertEqual(log, "test output")

    def test_assertion_failure_returns_nonzero(self):
        result = {"test": "test_example", "passed": False, "error": "failed", "duration_ms": 10}
        code, _ = self.run_main(result)
        self.assertEqual(code, 1)

    def test_engine_error_makes_passing_test_unsuccessful(self):
        result = {"test": "test_example", "passed": True, "error": "", "duration_ms": 10}
        for output in ("ERROR: Missing node\n", "SCRIPT ERROR: Invalid call\n"):
            with self.subTest(output=output):
                code, _ = self.run_main(result, output)
                self.assertEqual(code, 1)

    def test_invalid_test_result_returns_nonzero(self):
        result = {"test": "test_example", "passed": "true", "error": "", "duration_ms": 10}
        code, _ = self.run_main(result)
        self.assertEqual(code, 1)

    def test_unknown_test_is_not_run(self):
        discovery = {"suite": "controller", "tests": ["test_example"]}
        with mock.patch.object(run_tests, "run_godot", return_value=(discovery, "", None)) as run:
            with contextlib.redirect_stdout(io.StringIO()):
                code = run_tests.main(["--test", "test_missing"])
        self.assertEqual(code, 1)
        self.assertEqual(run.call_count, 1)

    def test_view_and_both_suites_are_rejected(self):
        for suite in ("view", "both"):
            with self.subTest(suite=suite), mock.patch.object(run_tests, "run_godot") as run:
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as exc:
                    run_tests.main(["--suite", suite])
                self.assertEqual(exc.exception.code, 2)
                run.assert_not_called()

    def test_empty_discovery_is_not_success(self):
        discovery = {"suite": "controller", "tests": []}
        with mock.patch.object(run_tests, "run_godot", return_value=(discovery, "", None)):
            with contextlib.redirect_stdout(io.StringIO()):
                code = run_tests.main([])
        self.assertEqual(code, 1)

    def test_test_timeout_is_not_success(self):
        discovery = {"suite": "controller", "tests": ["test_example"]}
        with mock.patch.object(run_tests, "run_godot", side_effect=[
            (discovery, "", None), (None, "partial output", "Timed out")
        ]), contextlib.redirect_stdout(io.StringIO()):
            code = run_tests.main([])
        self.assertEqual(code, 1)

    def test_discovery_errors_make_passing_run_unsuccessful(self):
        discovery = {"suite": "controller", "tests": ["test_example"]}
        result = {"suite": "controller", "result": {
            "test": "test_example", "passed": True, "error": "", "duration_ms": 10
        }}
        with mock.patch.object(run_tests, "run_godot", side_effect=[
            (discovery, "ERROR: Startup failure\n", None), (result, "", None)
        ]), contextlib.redirect_stdout(io.StringIO()):
            code = run_tests.main([])
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
