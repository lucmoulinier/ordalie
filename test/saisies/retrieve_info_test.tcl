# Sequences > Retrieve Sequences information (réseau : UniProt). Deux séquences dont l'organisme et le
# Taxa Id ont été faussés : Retrieve sur la sélection les rétablit (valeurs d'UniProt), résumé des
# changements, et les valeurs sont gardées après sauvegarde ORD et réouverture. Cancel et « aucune
# sélection » : rien ne change.
# Usage : tclsh8.6 test/saisies/retrieve_info_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Info {n} {Q "list \$::TDesOrganismes($n) \$::TDesTaxId($n)"}
# lance Retrieve, choisit l'option, valide
proc Retrieve {option {bouton bok}} {
    set id [Q [list probe::fire LaunchCheckInfosSeqs]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .wcheckinfos.fbut.bok}] && [clock milliseconds] - $t0 < 20000} {after 200}
    Q [list set ::seqs2check $option]
    Q ".wcheckinfos.fbut.$bouton invoke"
    set r [W::waitfor $id 600000]
    V "Retrieve $option : sans erreur" {! [Err $r]} [expr {[Err $r] ? [string range [dict get $r errorInfo] 0 300] : ""}]
    return $r
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set LN [Q {lmap n $::LNOrdali {string trim $n}}]
    set Li [lsearch -all -not $LN ""]
    set y1 [expr {[lindex $Li 2] + 1}]; set y2 [expr {[lindex $Li 7] + 1}]
    set a [lindex $LN $y1-1]; set b [lindex $LN $y2-1]
    set A0 [Info $a]; set B0 [Info $b]
    puts "     $a $A0 ; $b $B0"
    # valeurs faussées, en mémoire et dans la base
    foreach n [list $a $b] {
	Q "set ::TDesOrganismes($n) {Faux organisme}; set ::TDesTaxId($n) 1; EcritInfosSeqDansBase $n {orga {Faux organisme} taxid 1}"
    }
    Q {set ::PosInitNom 1.0}
    W::fire "SelectNomSeq une $y1.0" 20000
    W::fire "SelectNomSeq ctr $y2.0" 20000
    # Cancel : rien
    Retrieve selected bcl
    V "Cancel : rien ne change" {[Info $a] eq {{Faux organisme} 1}}
    set r [Retrieve selected]
    V "résumé des changements" {[Q {winfo exists .sumchg}]}
    Q {catch {destroy .sumchg}}
    V "$a : organisme et Taxa Id d'UniProt" {[lindex [Info $a] 0] ne "Faux organisme" && [lindex [Info $a] 1] != 1} [Info $a]
    V "$b : organisme et Taxa Id d'UniProt" {[lindex [Info $b] 0] ne "Faux organisme" && [lindex [Info $b] 1] != 1} [Info $b]
    V "$a : Taxa Id d'origine retrouvé" {[lindex [Info $a] 1] == [lindex $A0 1]} "[Info $a] / $A0"
    set A1 [Info $a]; set B1 [Info $b]
    F "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/r.ord] 120000
    Stop
    Start $Tmp/r.ord
    V "réouverture : $a gardée" {[Info $a] eq $A1} [Info $a]
    V "réouverture : $b gardée" {[Info $b] eq $B1} [Info $b]
    # aucune sélection
    Q {set ::NomSeqSel {}}
    set id [Q [list probe::fire LaunchCheckInfosSeqs]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .wcheckinfos.fbut.bok}] && [clock milliseconds] - $t0 < 20000} {after 200}
    Q {set ::seqs2check selected}
    set r [W::fire {.wcheckinfos.fbut.bok invoke} 20000]
    V "aucune sélection : message" {[string match "*No sequences selected*" [Dialogues $r]]} [Dialogues $r]
    Q {catch {.wcheckinfos.fbut.bcl invoke}}
    W::waitfor $id 20000
    Inv "après Retrieve"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
