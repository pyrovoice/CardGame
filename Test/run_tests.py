#!/usr/bin/env python3
"""Run the controller test scenarios in isolated Godot processes."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import subprocess
import sys

PROJECT = Path(__file__).resolve().parent.parent
PREFIX = "CARDGAME_TEST_RESULT:"
ERROR_LINE = re.compile(r"^(?:SCRIPT ERROR|ERROR):", re.MULTILINE)


def run_godot(godot, suite, test_name, timeout):
    command = [
        godot, "--headless", "--path", str(PROJECT),
        "--script", "res://Test/CliTestRunner.gd", "--", suite, test_name,
    ]
    try:
        completed = subprocess.run(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return None, output, f"Timed out after {timeout:g}s"
    except OSError as exc:
        return None, "", f"Could not start Godot: {exc}"

    output = completed.stdout
    records = [line[len(PREFIX):] for line in output.splitlines() if line.startswith(PREFIX)]
    if completed.returncode != 0:
        return None, output, f"Godot exited with code {completed.returncode}"
    if len(records) != 1:
        return None, output, f"Expected one result record, got {len(records)}"
    try:
        record = json.loads(records[0])
    except json.JSONDecodeError as exc:
        return None, output, f"Invalid result record: {exc}"
    if not isinstance(record, dict) or record.get("suite") != suite:
        return None, output, "Result record has an invalid suite"
    return record, output, None


def engine_errors(output):
    return [line for line in output.splitlines() if ERROR_LINE.match(line)]


def valid_test_result(record, test_name):
    result = record.get("result")
    return (
        isinstance(result, dict)
        and result.get("test") == test_name
        and isinstance(result.get("passed"), bool)
        and isinstance(result.get("error"), str)
        and isinstance(result.get("duration_ms"), (int, float))
        and not isinstance(result.get("duration_ms"), bool)
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"),
                        help="Godot executable (default: GODOT_BIN or godot on PATH)")
    parser.add_argument("--suite", choices=("controller",), default="controller")
    parser.add_argument("--test", help="Run one exact controller test name")
    parser.add_argument("--timeout", type=float, default=30,
                        help="Maximum seconds per Godot process (default: 30)")
    parser.add_argument("--log-dir", type=Path, help="Save complete Godot output per process")
    parser.add_argument("--verbose", action="store_true", help="Print complete Godot output")
    args = parser.parse_args(argv)
    if args.timeout <= 0 or not args.timeout < float("inf"):
        parser.error("--timeout must be a positive finite number")
    if args.log_dir:
        args.log_dir.mkdir(parents=True, exist_ok=True)

    error_counts = Counter()
    infrastructure_failures = 0
    passed = 0
    failed = 0
    tests_with_engine_errors = 0
    suites = (args.suite,)

    def execute(suite, name):
        record, output, problem = run_godot(args.godot, suite, name, args.timeout)
        errors = engine_errors(output)
        error_counts.update(errors)
        if args.verbose:
            print(f"\n--- {suite} / {name} Godot output ---\n{output}", flush=True)
        if args.log_dir:
            label = "discovery" if name == "--list" else name
            (args.log_dir / f"{suite}-{label}.log").write_text(output, encoding="utf-8")
        return record, problem, len(errors)

    for suite in suites:
        record, problem, _ = execute(suite, "--list")
        if problem:
            print(f"ERROR {suite} discovery: {problem}", flush=True)
            infrastructure_failures += 1
            continue
        tests = record.get("tests")
        if (not isinstance(tests, list) or not tests
                or not all(isinstance(name, str) and name.startswith("test_") for name in tests)
                or len(tests) != len(set(tests))):
            print(f"ERROR {suite} discovery: invalid or empty test list", flush=True)
            infrastructure_failures += 1
            continue
        if args.test:
            if args.test not in tests:
                print(f"ERROR {suite}: unknown test {args.test}", flush=True)
                infrastructure_failures += 1
                continue
            tests = [args.test]
        print(f"\nRunning {len(tests)} {suite} test(s)", flush=True)
        for test_name in tests:
            record, problem, error_count = execute(suite, test_name)
            if error_count:
                tests_with_engine_errors += 1
            error_suffix = f"; {error_count} Godot error messages" if error_count else ""
            if problem is None and not valid_test_result(record, test_name):
                problem = "Invalid test result record"
            if problem:
                infrastructure_failures += 1
                print(f"ERROR {suite}/{test_name}: {problem}{error_suffix}", flush=True)
            elif record["result"]["passed"]:
                passed += 1
                print(f"ASSERTIONS PASS {suite}/{test_name} "
                      f"({record['result']['duration_ms']}ms{error_suffix})", flush=True)
            else:
                failed += 1
                print(f"ASSERTIONS FAIL {suite}/{test_name}: "
                      f"{record['result']['error']}{error_suffix}", flush=True)

    if error_counts:
        print("\nGodot errors (counts across discovery and test processes):")
        for error, count in error_counts.most_common():
            print(f"  {count}x {error}")
        if not args.verbose and not args.log_dir:
            print("Use --verbose or --log-dir PATH for complete output and backtraces.")
    print(f"\nResults: {passed} assertion passes, {failed} assertion failures, "
          f"{infrastructure_failures} process/discovery errors, "
          f"{tests_with_engine_errors} tests with Godot errors, "
          f"{sum(error_counts.values())} Godot error messages")
    return 1 if failed or infrastructure_failures or error_counts else 0


if __name__ == "__main__":
    sys.exit(main())
