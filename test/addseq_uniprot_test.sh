#!/bin/bash
# Test : Add sequences > from database dans test/T_tutorial.ord (instance M5).
# Utilise le banc ~/.cache/claude-ordalie-tests/probe et le réseau (UniProt).
P=~/.cache/claude-ordalie-tests/probe; N=${1:-1}; B=${GUI_BASE:-$HOME/.cache/claude-ordalie-tests/audit_gui}
ajoute() {  # $1 = accessions ; $2 = script exécuté avant le dialogue
    $P/probe.sh $N -fire -wait 5000 "$2 ; AjouteSequenceOrPDB database" > /dev/null
    $P/probe.sh $N "set ::TAddS(SeqIdIn) {$1}" > /dev/null
    $P/probe.sh $N -fire -wait 300000 '.was.fbut.ok invoke' | cut -c1-400
}
etat='list instance [MacCourant name] n [llength [lmap x $::LNOrdali {if {[string trim $x] eq ""} continue; set x}]] longueurs [lsort -unique [lmap x $::LSOrdali {if {$x eq ""} continue; string length $x}]] attente [winfo exists .fattendre]'
$P/gui_instance.sh start $N $(dirname $(readlink -f $0))/T_tutorial.ord
$P/probe.sh $N "$etat"
echo "== un access"; ajoute A0A3S7X901 ""; $P/probe.sh $N "$etat"
echo "== deux access, virgule, minuscules"; ajoute "A0A836FPM5, a0a088s0i4" ""; $P/probe.sh $N "$etat"
echo "== doublon : rien à ajouter"; ajoute A0A3S7X901 ""; $P/probe.sh $N "$etat"
echo "== alignement, ordre, sauvegarde"
$P/probe.sh $N 'foreach a {A0A3S7X901 A0A836FPM5 A0A088S0I4} {set i [lsearch $::LNOrdali $a]; lappend r $a $i [regexp -all {[A-Za-z]} [lindex $::LSOrdali $i]]}; set r'
echo "== erreurs"; cat $B/inst$N/errors.log 2>/dev/null | grep -av READY | head -20; cat $B/inst$N/dialogs.log 2>/dev/null | cut -c1-200
$P/gui_instance.sh stop $N > /dev/null 2>&1
