#!/bin/bash

# Copyright (c) 2016-2018  Erik Martin-Dorel.

# todo: rewrite using cmdliner?

template="/tmp/autograde-ocaml.XXX"
solution_file="solution.ml"
test_file="test.ml"
teach_files=(prelude.ml prepare.ml "$solution_file" "$test_file" template.ml)
report_prefix="ocaml" # for example
student_file="student.ml"
note_file="note.csv"
LEARNOCAML_VERSION="0.12"

## Initial values
dest_dir=""
from_dir=""
trim="false"
teacher_itself="false"
max_pts=""
keep_going="false"
max_time="60s"
ind_time="4" # in secs

## Exit immediately in case of an error
set -euo pipefail

function usage () {
    cat <<EOF
Usage: $(basename "$0") [options] -f DIR [--] DIR1/dm.ml ...
       $(basename "$0") [options] -f DIR [--] */*.ml  # e.g.
       $(basename "$0") [options] -f DIR

Auto-grade OCaml assignments.

If there is no given .ml file, the teachers's $solution_file file itself
will be graded.

Options:
  -h      display this help and exit

  -d DIR  name of non-existing or empty directory to be populated with results
          (default: \$(mktemp -d $template))

  -f DIR  name of teacher's source folder (mandatory) containing:
          ${teach_files[@]}

  -t      trim $test_file file by removing its first and last line

  -m INT  maximum number of points (optional): add the string "/ INT"
          in the html report

  -k      keep going: when there is an error with a submission, do not
          call 'less' on the error file

  -x 60s  timeout (default $max_time): maximum time length to grade one submission

Remark: make sure that the OPAM env. variables are properly set.

Author: Erik Martin-Dorel.
EOF
}

## Auxiliary function
get_note () {
    local file="$1"
    local max="$2"
    local name="$3"
    local firstname="$4"
    set -e  # TODO: print warnings
    [ -f "$file" ]
    echo -n "$name,$firstname,="
    # TODO: document that this requires libxml2-utils
    xmllint --html --xpath '//span[@class="title clickable"]/span[@class="score"]/text()' "$file" | sed -e 's, \?pts\? \?/ \?[0-9]\+,,'
    # see also cat-sed-max()
    if [ -n "$max" ]; then echo -n "/$max"; fi
}

## Parse options
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "htb:f:d:m:kx:" opt; do
    case "$opt" in
        h)
            usage
            exit 0
            ;;
        t)
            trim="true"
            ;;
        f)
            from_dir="$OPTARG"
            ;;
        d)
            dest_dir="$OPTARG"
            ;;
        m)
            max_pts="$OPTARG"
            ;;
        k)
            keep_going="true"
            ;;
        x)
            max_time="$OPTARG"
            ;;
        '?')
            usage >&2
            exit 1
            ;;
    esac
done

if [ "x$from_dir" = "x" ]; then
    echo "Error: you must specify the path to the teacher's source folder (-f DIR)." >&2
    usage >&2
    exit 1
fi

if [ "x$dest_dir" = "x" ]; then
    dest_dir=$(mktemp -d "$template")
    echo "Created directory '$dest_dir' that will be populated with results." >&2
else
    echo "Warning: option '-d' can lead to absolute path leaking:" >&2
    echo 'e.g. "Match_failure /home/user/.../NOM_Prenom_12345_dm1/solution.ml:40:2"' >&2
    read -r -s -p 'Press Enter to continue (or ^C to exit)...'; echo
    if [ -e "$dest_dir" ]; then
        if [ ! -d "$dest_dir" ] || ( ls -1qA "$dest_dir" | grep -q . ); then
            echo "Error: -d '$dest_dir': is a non-empty directory or an existing file." >&2
            usage >&2
            exit 1
            # else OK
        fi
    else
        mkdir -v -p "$dest_dir"
    fi
fi

shift "$((OPTIND-1))" # Shift off the options and optional "--".
if [ $# -lt 1 ]; then
    echo "No file provided. The teacher's $solution_file file will be graded." >&2
    teacher_itself="true"
fi

function html-head () {
    cat <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>OCaml report - $1</title>
  </head>
  <body>
EOF
}

function html-foot () {
    cat <<EOF
  </body>
</html>
EOF
}

function cat-sed-max () {
    fil="$1"
    max="$2"
    if [ "x$max" != "x" ]; then
        # requires GNU sed
        sed -e "0,/\(<span class=\"score\">[-0-9]* pts\?\)\(<\/span>\)/s||\1 / $max\2|" "$fil"
    else
        cat "$fil"
    fi
}

function htmlify () {
    F="$1"
    H="$2"
    M="$3"
    T=$(mktemp "$F.XXX")
    cp -a "$F" "$T"
    { html-head "$H"; cat-sed-max "$T" "$M"; html-foot; } > "$F"
    rm -f "$T"
}

## Teacher test

if [ "$teacher_itself" = "true" ]; then
    echo "Grading '$solution_file'..." >&2
    firstname="Prénom"
    name="PROF"

    dir0=$(readlink -f "$dest_dir")

    # (there is only one file to grade; no need to create subfolders)

    for f in "${teach_files[@]}"; do
        cp -pv "$from_dir/$f" "$dir0"
    done

    ## Overwrite a trimmed file if need be
    if [ "$trim" = "true" ]; then
        echo "Overwrite '$dir0/$test_file' after trimming." >&2
        tail -n+2 < "$from_dir/$test_file" | head -n-1 > "$dir0/$test_file"
    fi

    ## Main command: no -grade-student option.
    RET=0; sudo timeout "$max_time" /usr/bin/docker run --rm -v "$dir0:$dir0" --name learn-ocaml-corr ocamlsf/learn-ocaml:$LEARNOCAML_VERSION grade --dump-reports "$dir0/$report_prefix" --timeout "$ind_time" -e "$dir0" || RET=$?

    if [ $RET -eq 124 ]; then
        echo "Timeout. Maybe due to unbounded recursion?" > "$dir0/$report_prefix.timeout"
        cat "$dir0/$report_prefix.timeout" >&2
    else
        htmlify "$dir0/$report_prefix.report.html" "$solution_file" "$max_pts"
        get_note "$dir0/$report_prefix.report.html" "$max_pts" "$name" "$firstname" > "$dir0/$note_file"
    fi

    for f in "${teach_files[@]}"; do
        rm -f "$dir0/$f"
    done

    { echo "done."; echo; } >&2

    echo "See report in: $dest_dir" >&2

    exit 0
fi

## Main task

for arg; do
    if [ -d "$arg" ]; then
        echo "Error: '$arg' is a directory, not a .ml submission." >&2
        exit 1
    elif [ ! -r "$arg" ]; then
        echo "Error: file '$arg' does not exist or is not readable." >&2
        exit 1
    fi
done

errLog="$dest_dir/error.org"
> "$errLog"

for arg; do

    echo "Grading '$arg'..." >&2

    base0=$(basename -s .ml "$arg")
    firstname="Prénom"
    name="NOM"
    if [[ "$arg" =~ "/" ]]; then
        base1=$(basename "${arg%/$base0.ml}")
        name=${base1//_assignsubmission_file_/}  # Moodle suffix
        name=${name%%_*}
        firstname=$(sed -e 's/[A-Z -]\+$//' <<< "$name")
        name=${name#$firstname }
        base0="${base1}"
    fi
    dir0=$(readlink -f "$dest_dir/$base0")

    mkdir -v "$dir0"

    cp -av "$arg" "$dir0/$student_file"

    for f in "${teach_files[@]}"; do
        cp -pv "$from_dir/$f" "$dir0"
    done

    ## Overwrite a trimmed file if need be
    if [ "$trim" = "true" ]; then
        echo "Overwrite '$dir0/$test_file' after trimming." >&2
        tail -n+2 < "$from_dir/$test_file" | head -n-1 > "$dir0/$test_file"
    fi

    ## Main command
    set -x
    RET=0; sudo timeout "$max_time" /usr/bin/docker run --rm -v "$dir0:$dir0" --name learn-ocaml-corr ocamlsf/learn-ocaml:$LEARNOCAML_VERSION grade --dump-reports "$dir0/$report_prefix" --timeout "$ind_time" -e "$dir0" "--grade-student" "$dir0/$student_file" 2>&1 | tee "$dir0/$report_prefix.error" || RET=$?
    set +x

    ## TODO: Double-check the exit status
    if [ $RET -eq 124 ]; then
        cat >> "$errLog" <<EOF
* Timeout: [[file:$base0/$report_prefix.error]]
Source: [[file:$base0/$student_file]]
EOF
        echo "Timeout. Maybe due to looping recursion?" | tee -a "$dir0/$report_prefix.error"
        if [ "$keep_going" = "false" ]; then
            less "$dir0/$report_prefix.error"
        fi
    elif [ $RET -eq 130 ]; then
        echo "Script interrupted." >&2
        exit 130
    elif [ $RET -ne 0 ] && [ $RET -ne 2 ] && [ $RET -ne 1 ]; then
        cat >> "$errLog" <<EOF
* Error $RET: [[file:$base0/$report_prefix.error]]
Source: [[file:$base0/$student_file]]
EOF
        echo "Grader exited with error code $RET." | tee -a "$dir0/$report_prefix.error"
        if [ "$keep_going" = "false" ]; then
            less "$dir0/$report_prefix.error"
        fi
    else
        rm "$dir0/$report_prefix.error"
        htmlify "$dir0/$report_prefix.report.html" "$base0.ml" "$max_pts" || true
        get_note "$dir0/$report_prefix.report.html" "$max_pts" "$name" "$firstname" > "$dir0/$note_file" || true
    fi

    for f in "${teach_files[@]}"; do
        rm -f "$dir0/$f"
    done

    { echo "done."; echo; } >&2
done

echo "See reports in: $dest_dir" >&2
echo "See summary of errors in: $errLog" >&2
