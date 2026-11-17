#!/bin/bash
# Lance les tests de la phase 3 l'un après l'autre (instance 7 du banc). P3_RESEAU=0 : sans réseau.
cd "$(dirname "$0")/.."
export ORDALIDIR=${ORDALIDIR:-/home/moumou/clordali} ODIR=${ODIR:-/home/moumou/clordali} GSCOPEDIR=${GSCOPEDIR:-/home/ripp/gscope}
T=/home/moumou/tcl/bin/tclsh8.6; rc=0
for t in sensibilite_test parcours_test rendu3d_test; do
  echo "=== $t"; timeout 1200 $T phase3/$t.tcl 7 | grep -E "^(FAIL|BILAN)" || rc=1
done
for f in test/T_tutorial_maj.ord test/R_tutorial_maj.ord test/I_maj.xml; do
  echo "=== allerretour_test $(basename $f)"; timeout 1200 $T phase3/allerretour_test.tcl 7 $ORDALIDIR/$f | grep -E "^(FAIL|BILAN)" || rc=1
done
exit $rc
