#!/bin/bash

# Advanced log analysis script for Lab 13.
# The script processes all .log files in the current directory and generates
# cleaned copies, severity-wise extracts, duplicate summaries, per-file reports,
# and a global final report inside reports/.

set -u

REPORTS_DIR="reports"
CLEANED_DIR="$REPORTS_DIR/cleaned"
ERRORS_DIR="$REPORTS_DIR/errors"
SUMMARY_DIR="$REPORTS_DIR/summary"
FINAL_REPORT="$REPORTS_DIR/final_report.txt"

count_word_lines() {
    local word="$1"
    local file="$2"
    grep -w -c "$word" "$file" 2>/dev/null || true
}

append_matches() {
    local word="$1"
    local src="$2"
    local dst="$3"
    grep -w "$word" "$src" > "$dst" 2>/dev/null || :
}

choose_most_frequent() {
    local info="$1"
    local warning="$2"
    local error="$3"
    local critical="$4"

    if [ "$info" -eq 0 ] && [ "$warning" -eq 0 ] && [ "$error" -eq 0 ] && [ "$critical" -eq 0 ]; then
        echo "NONE"
        return
    fi

    local max="$critical"
    local label="CRITICAL"

    if [ "$error" -gt "$max" ]; then
        max="$error"
        label="ERROR"
    fi
    if [ "$warning" -gt "$max" ]; then
        max="$warning"
        label="WARNING"
    fi
    if [ "$info" -gt "$max" ]; then
        max="$info"
        label="INFO"
    fi

    echo "$label"
}

if ! ls -1 ./*.log >/dev/null 2>&1; then
    echo "No log files found."
    exit 0
fi

rm -rf "$REPORTS_DIR"
mkdir -p "$CLEANED_DIR" "$ERRORS_DIR" "$SUMMARY_DIR"
> "$FINAL_REPORT"

processed_files=0
overall_info=0
overall_warning=0
overall_error=0
overall_critical=0

max_error_file=""
max_error_count=-1
max_critical_file=""
max_critical_count=-1

for file in ./*.log; do
    [ -f "$file" ] || continue

    filename=$(basename "$file")
    base_name="${filename%.log}"
    cleaned_file="$CLEANED_DIR/${base_name}_cleaned.log"
    warning_file="$ERRORS_DIR/${base_name}_warning.txt"
    error_file="$ERRORS_DIR/${base_name}_error.txt"
    critical_file="$ERRORS_DIR/${base_name}_critical.txt"
    duplicates_file="$SUMMARY_DIR/${base_name}_duplicates.txt"
    summary_file="$SUMMARY_DIR/${base_name}_summary.txt"

    echo "Processing $filename ..."

    sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; /^$/d' "$file" > "$cleaned_file"

    total_lines=$(wc -l < "$cleaned_file")
    info_count=$(count_word_lines "INFO" "$cleaned_file")
    warning_count=$(count_word_lines "WARNING" "$cleaned_file")
    error_count=$(count_word_lines "ERROR" "$cleaned_file")
    critical_count=$(count_word_lines "CRITICAL" "$cleaned_file")

    append_matches "WARNING" "$cleaned_file" "$warning_file"
    append_matches "ERROR" "$cleaned_file" "$error_file"
    append_matches "CRITICAL" "$cleaned_file" "$critical_file"

    if [ "$critical_count" -gt 0 ]; then
        classification="SEVERE"
    elif [ "$error_count" -gt 0 ]; then
        classification="DANGEROUS"
    elif [ "$warning_count" -gt 0 ]; then
        classification="ATTENTION"
    else
        classification="SAFE"
    fi

    most_frequent=$(choose_most_frequent "$info_count" "$warning_count" "$error_count" "$critical_count")

    sort "$cleaned_file" | uniq -c | awk '$1 > 1 {count=$1; $1=""; sub(/^ +/, ""); print count " " $0}' > "$duplicates_file"

    {
        echo "File: $filename"
        echo "Total lines: $total_lines"
        echo "INFO count: $info_count"
        echo "WARNING count: $warning_count"
        echo "ERROR count: $error_count"
        echo "CRITICAL count: $critical_count"
        echo "Classification: $classification"
        echo "Most frequent severity: $most_frequent"
    } > "$summary_file"

    {
        echo "File: $filename"
        echo "Classification: $classification"
        echo "ERROR count: $error_count"
        echo "CRITICAL count: $critical_count"
        echo
    } >> "$FINAL_REPORT"

    overall_info=$((overall_info + info_count))
    overall_warning=$((overall_warning + warning_count))
    overall_error=$((overall_error + error_count))
    overall_critical=$((overall_critical + critical_count))
    processed_files=$((processed_files + 1))

    if [ "$error_count" -gt "$max_error_count" ]; then
        max_error_count="$error_count"
        max_error_file="$filename"
    fi

    if [ "$critical_count" -gt "$max_critical_count" ]; then
        max_critical_count="$critical_count"
        max_critical_file="$filename"
    fi

    echo "Classification: $classification"
done

{
    printf 'Processed files: %s\n\n' "$processed_files"
    cat "$FINAL_REPORT"
    echo "Overall totals:"
    echo "INFO total: $overall_info"
    echo "WARNING total: $overall_warning"
    echo "ERROR total: $overall_error"
    echo "CRITICAL total: $overall_critical"
    echo
    echo "File with max ERROR: $max_error_file"
    echo "File with max CRITICAL: $max_critical_file"
} > "$FINAL_REPORT.tmp"

mv "$FINAL_REPORT.tmp" "$FINAL_REPORT"

echo "Analysis complete."
echo "Reports stored in reports/"
