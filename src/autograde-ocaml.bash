#!/bin/bash

# Copyright (c) 2016  Erik Martin-Dorel.

template="/tmp/autograde-ocaml.XXX"
solution_file="solution.ml"
test_file="test.ml"
teach_files="{prelude.ml,prepare.ml,$solution_file,$test_file}"
report_prefix="ocaml" # for example
max_time="4s"

## Initial values
bin=""
dest_dir=""
from_dir=""
trim="false"
teacher_itself="false"
max_pts=""

## Exit immediately in case of an error
set -e

function usage () {
    cat <<EOF
Usage: $(basename "$0") [options] -b BIN -f DIR [--] FILE.ml ...
       $(basename "$0") [options] -b BIN -f DIR

Auto-grade OCaml assignments.

If there is no given .ml file, the teachers's $solution_file file itself
will be graded.

Options:
  -h      display this help and exit

  -b BIN  full path to the 'learnocaml-grader.byte' binary (mandatory)

  -d DIR  name of non-existing or empty directory to be populated with results
          (default: \$(mktemp -d $template))

  -f DIR  name of teacher's source folder (mandatory) containing:
          $teach_files

  -t      trim $test_file file by removing its first and last line

  -m INT  maximum number of points (optional): add the string "/ INT"
          in the html report

Remark: make sure that the OPAM env. variables are properly set.

Author: Erik Martin-Dorel.
EOF
}

## Parse options
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "htb:f:d:m:" opt; do
    case "$opt" in
        h)
            usage
            exit 0
            ;;
        t)
            trim="true"
            ;;
        b)
            bin="$OPTARG"
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
        '?')
            usage >&2
            exit 1
            ;;
    esac
done

if [ "x$bin" = "x" ]; then
    echo "Error: you must specify the path to the learnocaml-grader binary (-b BIN)." >&2
    usage >&2
    exit 1
fi

if [ ! -x "$bin" ]; then
    echo "Error: '$bin' does not exist or is not executable." >&2
    usage >&2
    exit 1
fi

if [ "x$from_dir" = "x" ]; then
    echo "Error: you must specify the path to the teacher's source folder (-f DIR)." >&2
    usage >&2
    exit 1
fi

if [ "x$dest_dir" = "x" ]; then
    dest_dir=$(mktemp -d "$template")
    echo "Created directory '$dest_dir' that will be populated with results." >&2
else
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
    <meta charset="ISO-8859-1">
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
        sed -e "0,/\(<span class=\"score\">[0-9]* pts\)\(<\/span>\)/s||\1 / $max\2|" "$fil"
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

    dir0="$dest_dir"

    #...

    eval cp -av "'$from_dir'"/$teach_files "'$dir0'" #(caution)

    ## Overwrite a trimmed file if need be
    if [ "$trim" = "true" ]; then
        echo "Overwrite '$dir0/$test_file' after trimming." >&2
        tail -n+2 < "$from_dir/$test_file" | head -n-1 > "$dir0/$test_file"
    fi

    ## Main command: no -grade-student option.
    RET=0; timeout "$max_time" "$bin" "-display-progression" "-dump-reports" "$dir0/$report_prefix" "$dir0" || RET=$?

    if [ $RET -eq 124 ]; then
        echo "Timeout. Maybe due to unbounded recursion?" > "$dir0/$report_prefix.timeout"
        cat "$dir0/$report_prefix.timeout" >&2
    else
        htmlify "$dir0/$report_prefix.report.html" "$solution_file" "$max_pts"
    fi

    eval rm -f "'$dir0'"/$teach_files #(caution)

    { echo "done."; echo; } >&2

    echo "See report in: $dest_dir" >&2

    exit 0
fi

## Main task

for arg; do
    echo "Grading '$arg'..." >&2

    base0=$(basename -s .ml "$arg")
    dir0="$dest_dir/$base0"

    mkdir -v "$dir0"

    cp -av "$arg" "$dir0/student.ml"

    eval cp -av "'$from_dir'"/$teach_files "'$dir0'" #(caution)

    ## Overwrite a trimmed file if need be
    if [ "$trim" = "true" ]; then
        echo "Overwrite '$dir0/$test_file' after trimming." >&2
        tail -n+2 < "$from_dir/$test_file" | head -n-1 > "$dir0/$test_file"
    fi

    ## Main command
    RET=0; timeout "$max_time" "$bin" "-display-progression" "-grade-student" "-dump-reports" "$dir0/$report_prefix" "$dir0" || RET=$?

    if [ $RET -eq 124 ]; then
        echo "Timeout. Maybe due to unbounded recursion?" > "$dir0/$report_prefix.timeout"
        cat "$dir0/$report_prefix.timeout" >&2
    else
        htmlify "$dir0/$report_prefix.report.html" "$arg" "$max_pts"
    fi

    eval rm -f "'$dir0'"/$teach_files #(caution)

    { echo "done."; echo; } >&2
done

echo "See reports in: $dest_dir" >&2
