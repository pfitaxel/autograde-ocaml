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

1. [Install Docker](https://github.com/coq-community/docker-coq/wiki/CLI-usage)
2. Clone this repo and inspect the `autograde-ocaml.bash` script.
3. **Write the teacher's solution (solution.ml) and ad-hoc grader (test.ml).**
4. Put {prelude.ml,prepare.ml,solution.ml,test.ml,template.ml} in the same folder (prof).
5. Put all submissions in the same folder or in subdirs of the same folder (submissions).
6. Run autograde-ocaml.bash:  
   `.../autograde-ocaml.bash -f prof`  
   `.../autograde-ocaml.bash -f prof -m 80 -x 60s -k -- submissions/*/*.ml`  
7. Address the failing submissions (compilation error, looping recursion, ...).

(The step 3 above will typically be the most time-consuming task.)
