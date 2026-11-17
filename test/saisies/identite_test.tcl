# Sequences > Identity tool : identité d'une paire choisie dans les deux listes, comparée à un calcul
# indépendant (résidus identiques à la même colonne / longueur sans gaps de la plus courte) :
# sur tout l'alignement, puis sur une plage de colonnes ; Summary (moyenne, min, max par groupe) ;
# Details ; Return ; dans une autre instance.
# Usage : tclsh8.6 test/saisies/identite_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# identité attendue (en %) entre n1 et n2 sur les colonnes d..f
proc Ident {n1 n2 {d 0} {f end}} {
    Q [string map [list @1 $n1 @2 $n2 @d $d @f $f] {
	set s1 [string range $::Sequences(@1) @d @f]; set s2 [string range $::Sequences(@2) @d @f]
	set p 0
	foreach a [split $s1 ""] b [split $s2 ""] {if {$a ne "." && $a eq $b} {incr p}}
	set l1 [string length [string map {. ""} $s1]]; set l2 [string length [string map {. ""} $s2]]
	set l [expr {min($l1,$l2)}]
	expr {$l ? 100.0*$p/$l : -1}
    }]
}
proc Paire {n1 n2} {
    Q "set ::nsq1 $n1; set ::nsq2 $n2"
    F "paire $n1 / $n2" {CherchePCI $::FrmBouton.fpci.fse.sq2} 30000
    Q {set ::pciLbl}
}
# Details : fenêtre modale, fermée par le test
proc Details {} {
    set id [Q [list probe::fire {$::FrmBouton.fpci.fse.det invoke}]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .detailspci}] && [clock milliseconds] - $t0 < 20000} {after 200}
    V "Details : fenêtre" {[Q {winfo exists .detailspci}]}
    Q {destroy .detailspci}
    set r [W::waitfor $id 20000]
    V "Details : sans erreur" {! [Err $r]} $r
}
proc Mode {} {
    F "mode Identity" {ChangeMode donnepci} 60000
    V "mode Identity : listes des séquences" {[Q {winfo exists $::FrmBouton.fpci.fse.sq1}]}
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set Ln [Q {lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : [string trim $n]}}}]
    Mode
    V "listes : toutes les séquences" {[lrange [Q {$::FrmBouton.fpci.fse.sq1 cget -values}] 1 end] eq $Ln}
    F "Compute (tout l'alignement)" {$::FrmBouton.fpci.bdo invoke} 120000
    foreach {i j} {0 1 0 50 3 90 10 11 20 100} {
	set a [lindex $Ln $i]; set b [lindex $Ln $j]
	set lbl [Paire $a $b]
	set att [format %5.1f [Ident $a $b]]
	V "$a / $b : identité" {$lbl eq "Identity : $att %"} "$lbl (attendu $att)"
    }
    # plage de colonnes 100 à 299
    F "Clear" {$::FrmBouton.fpci.falcl.cle invoke}
    Q {set ::ZoneSelect {{100 299}}}
    F "Compute (colonnes 100 à 299)" {$::FrmBouton.fpci.bdo invoke} 120000
    foreach {i j} {0 1 3 90} {
	set a [lindex $Ln $i]; set b [lindex $Ln $j]
	set lbl [Paire $a $b]
	set att [format %5.1f [Ident $a $b 100 299]]
	V "$a / $b sur 100-299 : identité" {$lbl eq "Identity : $att %"} "$lbl (attendu $att)"
    }
    # Summary : moyenne et extrêmes de la plage, sur tout l'alignement
    set r [W::fire {SummaryPCI} 30000]
    V "Summary : fenêtre" {[Q {winfo exists .spci}]}
    set txt [Q {set r {}; foreach w [winfo children .spci.fgr.f0] {catch {lappend r [$w cget -text]}}; set r}]
    set m 0.0; set n 0; set mn 999; set mx -999
    set k 1
    foreach a [lrange $Ln 0 end-1] {
	foreach b [lrange $Ln $k end] {
	    set v [Ident $a $b 100 299]
	    if {$v < 0} continue
	    set m [expr {$m+$v}]; incr n
	    set mn [expr {min($mn,$v)}]; set mx [expr {max($mx,$v)}]
	}
	incr k
    }
    set moy [format %6.2f [expr {$m/$n}]]
    V "Summary : moyenne $moy" {[lsearch -glob $txt "$moy *"] >= 0} $txt
    V "Summary : min et max" {[lsearch -exact $txt [format "%6.2f %6.2f" $mn $mx]] >= 0} "attendu [format "%6.2f %6.2f" $mn $mx]"
    Q {.spci.bok invoke}
    W::waitfor [dict get $r id] 10000
    # Details
    Paire [lindex $Ln 0] [lindex $Ln 1]
    Details
    F "Return" {$::FrmBouton.fpci.frbt.ret invoke} 30000
    V "Return : mode normal" {[Q QuelMode] in {ordali feature}} [Q QuelMode]
    Inv "après Identity"

    puts "=== autre instance"
    F "instance M5" {MiseAJourMac x {M5 - Kinetoplatids}} 120000
    set Ln [Q {lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : [string trim $n]}}}]
    Mode
    V "M5 : listes des séquences de M5" {[lrange [Q {$::FrmBouton.fpci.fse.sq1 cget -values}] 1 end] eq $Ln}
    F "Compute" {$::FrmBouton.fpci.bdo invoke} 120000
    set a [lindex $Ln end]; set b [lindex $Ln end-1]
    set lbl [Paire $a $b]
    set att [format %5.1f [Ident $a $b]]
    V "M5 : $a / $b" {$lbl eq "Identity : $att %"} "$lbl (attendu $att, sur 100-299 [format %5.1f [Ident $a $b 100 299]], zone [Q {set ::ZonePCI}])"
    Details
    F "Return" {$::FrmBouton.fpci.frbt.ret invoke} 30000
    Inv "M5"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
