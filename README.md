# Log Analyser

A Bash script that scans `.log` files in a directory, cleans and classifies them by severity, detects duplicate log lines, and generates per-file and consolidated reports — using only shell scripting and standard Linux command-line tools (`sed`, `grep`, `awk`, `sort`, `uniq`).

Built for **CS1234 — Lab 13 (Shell Scripting)**, IIT Madras.

## Features

- **Auto-discovery** — scans the current directory for every `.log` file; exits cleanly with `No log files found.` if none exist.
- **Cleaning pipeline** — normalises each log via `sed`: collapses repeated spaces/tabs, strips leading/trailing whitespace, and removes blank lines before analysis.
- **Severity counting** — counts `INFO`, `WARNING`, `ERROR`, and `CRITICAL` tags per file (case-sensitive — lowercase variants are ignored).
- **Four-tier classification**

  | Classification | Condition |
  |---|---|
  | `SEVERE` | at least one `CRITICAL` line |
  | `DANGEROUS` | no `CRITICAL`, at least one `ERROR` |
  | `ATTENTION` | no `CRITICAL`/`ERROR`, at least one `WARNING` |
  | `SAFE` | none of the above |

- **Duplicate detection** — flags exact repeated lines (post-cleaning) in the format `count line`.
- **Most-frequent severity** — per file, with deterministic tie-breaking: `CRITICAL > ERROR > WARNING > INFO`. Reports `NONE` if all counts are zero.
- **Per-file + global reporting** — individual summaries plus one consolidated report with totals and the files with maximum `ERROR` / `CRITICAL` counts.
- **Live terminal progress** while processing each file.

## Usage

```bash
chmod +x analyze_logs.sh
./analyze_logs.sh
```

Run it from a directory containing one or more `.log` files. No arguments or interactive input required — it operates on whatever `.log` files are present in the current working directory.

## Output Structure

```
reports/
├── cleaned/
│   └── <base>_cleaned.log
├── errors/
│   ├── <base>_warning.txt
│   ├── <base>_error.txt
│   └── <base>_critical.txt
├── summary/
│   ├── <base>_duplicates.txt
│   └── <base>_summary.txt
└── final_report.txt
```

- **`cleaned/`** — whitespace-normalised, blank-line-stripped copy of each input log.
- **`errors/`** — severity-specific line extracts (empty files are created when no matching lines exist).
- **`summary/`** — per-file duplicate report and summary (counts, classification, most frequent severity).
- **`final_report.txt`** — number of files processed, a section per file, overall totals, and the files with maximum `ERROR` and `CRITICAL` counts.

### Example

Input — `server.log`:
```
INFO Boot
ERROR Disk failure
ERROR Disk failure
WARNING Retry requested
INFO Shutdown
```

Output — `summary/server_summary.txt`:
```
File: server.log
Total lines: 5
INFO count: 2
WARNING count: 1
ERROR count: 2
CRITICAL count: 0
Classification: DANGEROUS
Most frequent severity: ERROR
```

Output — `summary/server_duplicates.txt`:
```
2 ERROR Disk failure
```

## Implementation Notes

- **Cleaning** uses a single `sed -E` pass: `s/[[:space:]]+/ /g; s/^ //; s/ $//; /^$/d`.
- **Counting** uses `grep -w -c` for whole-word, case-sensitive severity tag matches.
- **Duplicate detection** pipes `sort | uniq -c`, then reformats via `awk` to `count line`.
- **Tie-breaking** for most-frequent severity is resolved deterministically using the fixed priority order, applied after computing all four counts.
- Script relies only on POSIX-friendly shell scripting and standard Linux utilities — no external dependencies.

## Testing

The `testcases/` directory contains sample `.log` files covering the representative scenarios: no logs present, single-file classifications across all four severity tiers, duplicate detection, multi-file aggregation, and case-sensitivity / empty-file edge cases.

`check.sh` validates script output against expected results — run it after `analyze_logs.sh` to verify correctness:

```bash
./check.sh or use 'sudo ./check.sh' to avoid permission related issues.
```

## Requirements

- Bash
- Standard GNU coreutils (`sed`, `grep`, `awk`, `sort`, `uniq`) — present by default on any Linux system.
