#!/usr/bin/env bash
set -euo pipefail

BIN_PATH="${1:-./out/reverse}"

if [ ! -x "${BIN_PATH}" ]; then
    echo "Error: executable not found at ${BIN_PATH}"
    exit 1
fi

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "${TMP_OUTPUT}"' EXIT

"${BIN_PATH}" > "${TMP_OUTPUT}"

grep -Eq '^Zeros above main diagonal: [0-9]+$' "${TMP_OUTPUT}"
grep -Eq '^Positive below secondary diagonal: [0-9]+$' "${TMP_OUTPUT}"

zeros_count="$(awk -F': ' '/^Zeros above main diagonal:/ {print $2}' "${TMP_OUTPUT}")"
positive_count="$(awk -F': ' '/^Positive below secondary diagonal:/ {print $2}' "${TMP_OUTPUT}")"

if ! [[ "${zeros_count}" =~ ^[0-9]+$ ]] || [ "${zeros_count}" -gt 21 ]; then
    echo "Error: invalid zeros count: ${zeros_count}"
    exit 1
fi

if ! [[ "${positive_count}" =~ ^[0-9]+$ ]] || [ "${positive_count}" -gt 21 ]; then
    echo "Error: invalid positive count: ${positive_count}"
    exit 1
fi

awk '
BEGIN {
    section = ""
    initial_rows = 0
    result_rows = 0
    format_error = 0
}

$0 == "Initial matrix:" {
    section = "initial"
    next
}

$0 == "Result matrix:" {
    section = "result"
    next
}

$0 ~ /^Zeros above main diagonal:/ {
    section = ""
    next
}

$0 ~ /^Positive below secondary diagonal:/ {
    section = ""
    next
}

section == "initial" && NF > 0 {
    if (NF != 7) {
        format_error = 1
    }
    for (i = 1; i <= NF; i++) {
        if ($i !~ /^-?[0-9]+$/) {
            format_error = 1
        }
    }
    initial_rows++
    next
}

section == "result" && NF > 0 {
    if (NF != 7) {
        format_error = 1
    }
    for (i = 1; i <= NF; i++) {
        if ($i !~ /^-?[0-9]+$/) {
            format_error = 1
        }
    }
    result_rows++
    next
}

END {
    if (format_error || initial_rows != 7 || result_rows != 7) {
        exit 1
    }
}
' "${TMP_OUTPUT}"

echo "Tests passed"
