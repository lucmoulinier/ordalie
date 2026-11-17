#!/bin/bash
# Tests des fenêtres et modes à saisie (2026-11-09), puis contrôle du catalogue (catalogue.txt).
# Usage : test/saisies/lance.sh [numéro d'instance]   (instance 7 par défaut ; réseau UniProt pour retrieve_info)
cd "$(dirname "$0")/.."
export ORDALIDIR=${ORDALIDIR:-/home/moumou/clordali} ODIR=${ODIR:-/home/moumou/clordali} GSCOPEDIR=${GSCOPEDIR:-/home/ripp/gscope}
T=/home/moumou/tcl/bin/tclsh8.6; N=${1:-7}; rc=0
for t in preferences motif identite export_features feateditor featsummary editeur annotation barcode sauvepdb colorie_ss fenetre print retrieve_info overview overview_instance clustering arbre arbre_instance conservation clicdroit_alignement clicdroit_arbre clicdroit_3d catalogue; do
  echo "=== $t"; timeout 1800 $T saisies/${t}_test.tcl $N 2>&1 | grep -E "^(FAIL|BILAN)" || rc=1
  /home/moumou/.cache/claude-ordalie-tests/probe/gui_instance.sh stop $N > /dev/null 2>&1
done
exit $rc
