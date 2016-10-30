#!/bin/bash

# Copyright (c) 2016  Erik Martin-Dorel.

template="/tmp/autograde-ocaml.XXX"
solution_file="solution.ml"
test_file="test.ml"
teach_files="{prelude.ml,prepare.ml,$solution_file,$test_file}"
report_prefix="ocaml" # for example

## Initial values
bin=""
dest_dir=""
from_dir=""
trim="false"
teacher_itself="false"

## Exit immediately in case of an error
set -e

function usage () {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [--] FILE.ml ...
       $(basename "$0") [-t] -f DIR

Auto-grade OCaml assignments.

Options:
  -h      display this help and exit

  -b BIN  full path to the 'learnocaml-grader.byte' binary (mandatory)

  -d DIR  name of non-existing directory to be populated with results
          (default: \$(mktemp -d $template))

  -f DIR  name of teacher's source folder (mandatory) containing:
          $teach_files

  -t      trim $test_file file by removing its first and last line

If there is no given .ml file, the teachers's $solution_file file itself
will be graded.

Author of this script: Erik Martin-Dorel.
EOF
}

## Parse options
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "htb:f:d:" opt; do
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
        '?')
            usage >&2
            exit 1
            ;;
    esac
done

if [ "x$bin" = "x" ]; then
    echo "Error: you must specify the path to the learnocaml-grader binary (-b …)." >&2
    usage >&2
    exit 1
fi

if [ ! -x "$bin" ]; then
    echo "Error: '$bin' does not exist or is not executable." >&2
    usage >&2
    exit 1
fi

if [ "x$from_dir" = "x" ]; then
    echo "Error: you must specify the path to the teacher's source folder (-f …)." >&2
    usage >&2
    exit 1
fi

if [ "x$dest_dir" = "x" ]; then
    dest_dir=$(mktemp -d "$template")
    echo "Created directory '$dest_dir' that will be populated with results." >&2
else
    if [ -e "$dest_dir" ]; then
        echo "Error: -d '$dest_dir': file or directory already exists, a new path is expected." >&2
        usage >&2
        exit 1
    fi
    mkdir -v -p "$dest_dir"
fi

shift "$((OPTIND-1))" # Shift off the options and optional "--".
if [ $# -lt 1 ]; then
    echo "No file provided. The teacher's $solution_file file will be graded." >&2
    teacher_itself="true"
fi

## Teacher test

if [ "$teacher_itself" = "true" ]; then
    echo "Grading '$solution_file'..." >&2

    dir0="$dest_dir"

    #...

    eval cp -av "$from_dir"/$teach_files "$dir0" #(no quotes)

    ## Overwrite a trimmed file if need be
    if [ "$trim" = "true" ]; then
        tail -n+2 < "$from_dir/$test_file" | head -n-1 > "$dir0/$test_file"
    fi

    ## Main command: no -grade-student option.
    "$bin" "-display-progression" "-dump-reports" "$dir0/$report_prefix" "$dir0"
    RET=$?

    { echo "done."; echo; } >&2

    echo "See report in: $dest_dir" >&2

    exit $RET
fi

## Main task

for arg; do
    echo "Grading '$arg'..." >&2

    base0=$(basename -s .ml "$arg")
    dir0="$dest_dir/$base0"

    mkdir -v "$dir0"

    cp -av "$arg" "$dir0/student.ml"

    eval cp -av "$from_dir"/$teach_files "$dir0" #(no quotes)

    ## Overwrite a trimmed file if need be
    if [ "$trim" = "true" ]; then
        tail -n+2 < "$from_dir/$test_file" | head -n-1 > "$dir0/$test_file"
    fi

    ## Main command
    "$bin" "-display-progression" "-grade-student" "-dump-reports" "$dir0/$report_prefix" "$dir0"

    { echo "done."; echo; } >&2
done

echo "See reports in: $dest_dir" >&2