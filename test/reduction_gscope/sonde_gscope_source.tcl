# gscope_source.tcl de test : charge le dump COMPLET de Gscope, puis enveloppe chaque proc
# supprimée par la réduction pour journaliser ses appels (une ligne par proc, dans SONDE_LOG).
# Variables d'environnement : SONDE_DUMP (dump complet), SONDE_LISTE (procs supprimées,
# une par ligne), SONDE_LOG (journal). À placer dans un répertoire donné en GSCOPEDIR.
source $::env(SONDE_DUMP)
set ::SondeLog $::env(SONDE_LOG)
proc SondeAppel {p} {
    if {[info exists ::SondeVu($p)]} return
    set ::SondeVu($p) 1
    set appelant [expr {[info level] > 2 ? [lindex [info level -2] 0] : "global"}]
    catch {set c [open $::SondeLog a]; puts $c "APPEL_SUPPRIME $p <- $appelant ([pid])"; close $c}
}
set f [open $::env(SONDE_LISTE)]
foreach l [split [read $f] \n] {
    set p [lindex $l 0]
    # procs de la bibliothèque Tcl présentes par erreur dans le dump
    if {$p in {::pkg_mkIndex ::tclPkgSetup ::tclPkgUnknown}} continue
    if {$p eq "" || [info procs $p] eq ""} continue
    rename $p ${p}__sonde
    proc $p args "SondeAppel [list $p]; uplevel 1 \[list [list ${p}__sonde]\] \$args"
}
close $f
