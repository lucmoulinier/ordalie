#!/bin/bash
# Vérification de la réduction de LesProcsDeGscope.tcl : même batterie de tests avec
#  - "complet" : le dump complet + une sonde sur chaque proc supprimée (sonde_gscope_source.tcl) ;
#    tout appel d'une proc supprimée est écrit dans appels_supprimees.log (doit rester vide) ;
#  - "reduit"  : le fichier réduit.
# Usage : batterie.sh complet|reduit <instance> <dump_complet> <fichier_reduit> <liste_supprimees> <rep_resultats>
# (lancer les deux variantes sur deux instances différentes, par ex. 5 et 6, avec setsid nohup)
V=$1; N=$2; DUMP=$3; REDUIT=$4; LISTE=$5; R=$6/$V
O=${ORDALIDIR:-$(cd "$(dirname "$0")/../.." && pwd)}
mkdir -p $R/sorties $R/gscope
case $V in
  complet) cp "$(dirname "$0")/sonde_gscope_source.tcl" $R/gscope/gscope_source.tcl ;;
  reduit)  echo "source [list $REDUIT]" > $R/gscope/gscope_source.tcl ;;
esac
export GSCOPEDIR=$R/gscope ORDALIDIR=$O ODIR=$O GUI_BASE=$R/gui
export SONDE_DUMP=$DUMP SONDE_LISTE=$LISTE SONDE_LOG=$R/appels_supprimees.log
T=${TCLSH:-/home/moumou/tcl/bin/tclsh8.6}; W=${WISH:-/home/moumou/tcl/bin/wish8.6}
P=$O/test/banc
cd $O/test
B=$R/bilan.txt; : > $B
lance() { # nom timeout commande...
  local nom=$1 to=$2; shift 2
  local d=$(date +%s)
  timeout $to "$@" > $R/sorties/$nom.out 2>&1; local rc=$?
  $P/gui_instance.sh stop $N > /dev/null 2>&1
  echo "$nom rc=$rc $(( $(date +%s)-d ))s $(grep -a -E '^BILAN' $R/sorties/$nom.out | tail -1) fails=$(grep -a -c -E '^FAIL' $R/sorties/$nom.out) invalid=$(grep -a -c 'invalid command name' $R/sorties/$nom.out)" >> $B
}
for t in arbres_radial_ord audit_corrections cif_noms cif_secstr groupes_instance infoseq mafft_livre objets3d_ord \
         phase2_corrections phase3_corrections phase4_corrections printogl_fond reouverture_ord rsf_refus superposition_af; do
  lance $t 1800 $T ${t}_test.tcl $N
done
lance ord_maj 1800 $T ord_maj_test.tcl $O/test/T_tutorial_maj.ord $N
for t in preferences motif identite export_features feateditor featsummary editeur annotation barcode sauvepdb colorie_ss fenetre print retrieve_info overview overview_instance clustering arbre arbre_instance conservation clicdroit_alignement clicdroit_arbre clicdroit_3d catalogue; do
  lance saisies_$t 1800 $T saisies/${t}_test.tcl $N
done
for t in sensibilite_test parcours_test rendu3d_test; do
  lance phase3_$t 1200 $T phase3/$t.tcl $N
done
for f in T_tutorial_maj.ord R_tutorial_maj.ord I_maj.xml; do
  lance phase3_allerretour_$f 1200 $T phase3/allerretour_test.tcl $N $O/test/$f
done
for t in viewer3d_instance viewer3d_cpk_refresh; do
  lance $t 900 xvfb-run -a -s "-screen 0 1600x1200x24 +extension GLX" $W ${t}_test.tcl
done
grep -a -h 'invalid command name' $R/gui/inst*/*.log $R/sorties/*.out 2>/dev/null | sort | uniq -c > $R/invalid_commands.txt
echo FIN >> $B
