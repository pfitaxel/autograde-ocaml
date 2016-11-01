autograde-ocaml
===============

autograde-ocaml is a tool to help grading (offline) OCaml assignments,
partly relying on OCamlPro's learn-ocaml codebase.

It consists of a Bash script (autograde-ocaml.bash) that calls a
specific version of learn-ocaml's CLI tool (learnocaml-grader.byte),
fed on dedicated automated tests (provided by the teacher).

Report bugs to: [Erik Martin-Dorel](mailto:erik.martin-dorel@irit.fr)

Usage summary
-------------

1. Clone my fork of the learn-ocaml repo and switch to branch feature/batch.
2. Build learn-ocaml.
3. Clone this repo.
4. **Write the teacher's solution (solution.ml) and ad-hoc grader (test.ml).**
5. Put {prelude.ml,prepare.ml,solution.ml,test.ml} in the same folder (prof).
6. Put all submissions in the same folder (rendus).
7. Make sure that the OPAM environment variables are properly set.
8. Run autograde-ocaml.bash:  
   `.../autograde-ocaml.bash -b ... -f prof`  
   `.../autograde-ocaml.bash -b ... -f prof -m ... rendus/*.ml`  
9. Address the failing submissions (compilation error, looping recursion, ...).

(The step 4 above will typically be the most time-consuming task.)
