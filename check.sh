#!/bin/bash

TESTCASES_DIR="Testcases"
INPUT_DIR="$TESTCASES_DIR/Inputs"
EXPECTED_DIR="$TESTCASES_DIR/Expected Output"
ACTUAL_ROOT="$TESTCASES_DIR/Actual Output"
TIME_LIMIT="8s"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

compare_dirs() {
    local expected="$1"
    local actual="$2"
    diff -ru "$expected" "$actual" > /dev/null 2>&1
}

grade_submission() {
    local student_dir="$1"
    local submission="$2"
    local roll_number
    roll_number=$(basename "$student_dir")
    local submission_name
    submission_name=$(basename "$submission")
    local log_file="$student_dir/${submission_name%.bash}_grading_log.txt"

    echo "Grading $submission_name for $roll_number" > "$log_file"
    echo "----------------------------------------" >> "$log_file"

    local total_tests=0
    local passed_tests=0

    shopt -s nullglob
    for tc_dir in "$INPUT_DIR"/Test_Case_*; do
        [ -d "$tc_dir" ] || continue
        total_tests=$((total_tests + 1))
        local tc_name
        tc_name=$(basename "$tc_dir")
        local expected_tc="$EXPECTED_DIR/$tc_name"
        local actual_tc="$ACTUAL_ROOT/$roll_number/$tc_name"
        actual_tc=$(realpath -m "$actual_tc")
        local work_dir
        work_dir=$(mktemp -d)

        rm -rf "$actual_tc"
        mkdir -p "$actual_tc"

        cp "$submission" "$work_dir/analyze_logs.sh"
        chmod +x "$work_dir/analyze_logs.sh"

        shopt -s nullglob
        local input_files=("$tc_dir"/*)
        shopt -u nullglob
        if [ ${#input_files[@]} -gt 0 ]; then
            cp -r "$tc_dir"/* "$work_dir/"
        fi

        (
            cd "$work_dir" || exit 1
            timeout "$TIME_LIMIT" bash ./analyze_logs.sh > "$actual_tc/terminal_output.txt" 2>&1
        )
        exit_code=$?

        if [ "$exit_code" -eq 124 ]; then
            echo "$tc_name: FAILED (Timeout)" >> "$log_file"
            echo -e "${RED}$tc_name: FAILED (Timeout)${NC}"
            rm -rf "$work_dir"
            continue
        elif [ "$exit_code" -ne 0 ]; then
            echo "$tc_name: FAILED (Runtime Error code $exit_code)" >> "$log_file"
            echo -e "${RED}$tc_name: FAILED (Runtime Error)${NC}"
            rm -rf "$work_dir"
            continue
        fi

        if [ -d "$work_dir/reports" ]; then
            cp -r "$work_dir/reports" "$actual_tc/"
        fi

        if compare_dirs "$expected_tc" "$actual_tc"; then
            echo "$tc_name: PASSED" >> "$log_file"
            echo -e "${GREEN}$tc_name: PASSED${NC}"
            passed_tests=$((passed_tests + 1))
        else
            echo "$tc_name: FAILED (Wrong Answer)" >> "$log_file"
            echo -e "${RED}$tc_name: FAILED (Wrong Answer)${NC}"
            diff -ru "$expected_tc" "$actual_tc" >> "$log_file" 2>&1 || true
        fi

        rm -rf "$work_dir"
    done
    shopt -u nullglob

    echo "SUMMARY: Passed $passed_tests / $total_tests" >> "$log_file"
    echo -e "${CYAN}Score for $submission_name: ${GREEN}$passed_tests${CYAN} / ${total_tests}${NC}"
}

echo "Starting Lab 13 shell-script autograder..."
mkdir -p "$ACTUAL_ROOT"

found_any=0
shopt -s nullglob
for student_dir in CS*/; do
    [ -d "$student_dir" ] || continue
    local_scripts=("$student_dir"/CS*.bash)
    if [ ${#local_scripts[@]} -eq 0 ]; then
        continue
    fi
    found_any=1
    echo "=================================================="
    echo -e "${YELLOW}Checking student folder: $(basename "$student_dir")${NC}"
    for submission in "${local_scripts[@]}"; do
        [ -f "$submission" ] || continue
        grade_submission "$student_dir" "$submission"
    done
done
shopt -u nullglob

if [ "$found_any" -eq 0 ]; then
    echo -e "${RED}No student .bash submission files found under CS*/ directories.${NC}"
    exit 1
fi

echo "=================================================="
echo -e "${GREEN}Grading complete. See '$ACTUAL_ROOT' for generated outputs.${NC}"
