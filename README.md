autograde-ocaml
===============

autograde-ocaml is a tool to help grading (offline) OCaml assignments,
partly relying on OCamlPro's learn-ocaml codebase.

It consists of a Bash script (autograde-ocaml.bash) that calls a
specific version of learn-ocaml's CLI tool (learnocaml-grader.byte),
fed on dedicated automated tests (provided by the teacher).

For reporting bugs: feel free to create a [GitHub issue](https://github.com/pfitaxel/autograde-ocaml/issues/new).

Usage summary
-------------

1. [Install Docker](https://github.com/coq-community/docker-coq/wiki/CLI-usage) and `xmllint` (package `libxml2-utils`)
2. Clone this repo and inspect the `autograde-ocaml.bash` script.
3. **Write the teacher's solution (solution.ml) and ad-hoc grader (test.ml).**
4. Put {prelude.ml,prepare.ml,solution.ml,test.ml,template.ml} in the same folder (prof).
5. To extract the last saved draft as backup (in case the student only clicked on Sync, not Grade):__
   `rsync -av sync/ sync+draft`  
   `find sync+draft -name save.json | xargs -n 1 bash -c 'target="ue-tpn-1"; head="(* FROM save.json *)"; f="$1"; str=$(jq -r "\"$head\n\" + .\"exercises-editors\".\"$target\"[1]" "$f"); if [ -n "$str" ] && [ "$str" != "$head" ]; then newml="${f//save.json/$target-draft.ml}"; echo "+ Read $f and write $target-draft.ml"; printf "%s" "$str" > "$newml"; else echo "- Skip $f for $target"; fi' bash | tee -a sync+draft-jq.log`  
   (repeat with a different "ue-tpn-1")  
5. Put all submissions in the same folder or in subdirs of the same folder (submissions). E.g.:__
   `mkdir sync2`  
   `find sync+draft -name save.json -exec bash -c 'dir="$1"; dir=${dir%/save.json}; tok=${dir#sync/}; tok=${tok//\//-}; rsync -av "$dir/" "sync2/$tok"' bash '{}' \;`  
6. Run autograde-ocaml.bash:  
   `.../autograde-ocaml.bash -f prof`  
   `.../autograde-ocaml.bash -f prof -l -m 60 -x 60s -k -- submissions/*/*.ml`  
   `rsync -av .../pfitaxel-exam-repository/src/easy-check /tmp/`  
   `.../autograde-ocaml.bash -f prof -e -l -m 60 -x 30s -k $(find sync2 -name "tpn.ml")`  
7. Address the failing submissions (compilation error, looping recursion, ...).  
8. Collect the `*.csv`:  
   `for f in res-1 res-1-draft; do find "$f" -name "*.csv" -print0 | xargs --null -n 1 bash -c 'printf "%s," "${1%/*.csv}"; cat "$1"; echo' bash > "$f".csv; done`  

(The step 3 above will typically be the most time-consuming task.)

ToDo
----

* `get_note`: Ensure `xmllint --html --xpath …` always prints sth (dflt: 0)

* `error.org`: Ensure it's nonempty/gathers compilation errors from docker-run.
