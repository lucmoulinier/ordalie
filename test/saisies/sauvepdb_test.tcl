# Structures > Save PDB : fenêtre « Select parameters » (molécule, chaîne, plage de résidus). Le fichier
# écrit est comparé à la base de la structure : bonnes chaînes, résidus de la plage seulement, coordonnées ;
# il est relu comme structure par Ordalie. Toutes les chaînes ; plage refusée (non entière) ; Dismiss.
# Usage : tclsh8.6 test/saisies/sauvepdb_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# ouvre la fenêtre, règle les champs, OK ; renvoie {messages}
proc Sauve {fichier champs {bouton bok}} {
    Q [list probe::answer tk_getSaveFile $fichier]
    set id [Q [list probe::fire SauveLesPDB]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .sp.f.fbut.bok}] && [clock milliseconds] - $t0 < 20000} {after 200}
    foreach {k v} $champs {Q [list set ::SP($k) $v]}
    set r [W::fire ".sp.f.fbut.$bouton invoke" 60000]
    set msg [Dialogues $r]
    if {[Err $r]} {lappend msg "ERREUR [string range [expr {[dict exists $r errorInfo] ? [dict get $r errorInfo] : $r}] 0 400]"}
    set r2 [W::waitfor $id 20000]
    if {[Err $r2]} {lappend msg "ERREUR [string range [expr {[dict exists $r2 errorInfo] ? [dict get $r2 errorInfo] : $r2}] 0 400]"}
    lappend msg {*}[Dialogues $r2]
    if {[Q {winfo exists .sp}]} {Q {.sp.f.fbut.bdi invoke}; W::waitfor $id 20000}
    return $msg
}
# lignes ATOM d'un fichier : {chaîne résidu nom_atome x y z}
proc Atomes {f} {
    set c [open $f]; set L [split [read $c] \n]; close $c
    set r {}
    foreach l $L {
	if {[string range $l 0 3] ne "ATOM"} continue
	lappend r [list [string index $l 21] [string trim [string range $l 22 26]] [string trim [string range $l 12 15]] [string trim [string range $l 30 37]] [string trim [string range $l 38 45]] [string trim [string range $l 46 53]]]
    }
    return $r
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set mol [Q {set m ""; foreach p $::ListePDB {set x [string toupper [DonneIdDeAccessPDB $p]]; if {[info object isa object ::$x] && [llength [::$x _chains]] > 1} {set m $x; break}}; set m}]
    if {$mol eq ""} {set mol [Q {string toupper [DonneIdDeAccessPDB [lindex $::ListePDB 0]]}]}
    set Lchn [Q "lsort \[::$mol _chains\]"]
    set c [lindex $Lchn 0]
    set Lres [Q "::$mol _resnumber -chain $c -polymer"]
    set d [lindex $Lres 10]; set f [lindex $Lres 40]
    puts "     $mol, chaînes $Lchn, chaîne $c, résidus $d à $f"
    # une chaîne, une plage
    set msg [Sauve $Tmp/a.pdb [list Mol $mol ChnAll one LaChn $c ResAll rng ResFrom $d ResTo $f]]
    V "chaîne $c, $d-$f : sans message" {[lsearch -all -inline -not -glob $msg tk_getSaveFile*] eq ""} $msg
    V "fichier écrit" {[file exists $Tmp/a.pdb]}
    set A [Atomes $Tmp/a.pdb]
    V "seulement la chaîne $c" {[lsort -unique [lmap a $A {lindex $a 0}]] eq [list $c]} [lsort -unique [lmap a $A {lindex $a 0}]]
    set att [lrange $Lres 10 40]
    V "résidus $d à $f exactement" {[lsort -unique -integer [lmap a $A {lindex $a 1}]] eq [lsort -integer $att]} "[lindex [lsort -unique -integer [lmap a $A {lindex $a 1}]] 0]..[lindex [lsort -unique -integer [lmap a $A {lindex $a 1}]] end] ([llength [lsort -unique [lmap a $A {lindex $a 1}]]] / [llength $att])"
    # coordonnées : celles de la base
    set db [Q "set \[info object namespace ::$mol\]::db"]
    set base [Q [string map [list @DB $db @M $mol @C $c] {@DB eval {select r.rnbr, a.aname, a.x, a.y, a.z from atoms as a, residues as r, chains as c, pdb as p where p.name = '@M' and c.pk_pdb = p.pk_pdb and c.name = '@C' and r.pk_chains = c.pk_chains and r.type != 'ligand' and a.pk_residues = r.pk_residues}}]]
    array set B {}
    foreach {rr an x y z} $base {set B([string trimleft [string trim $rr] 0],[string trim $an]) [format "%.3f %.3f %.3f" $x $y $z]}
    set faux 0
    foreach a $A {lassign $a ch rr an x y z; if {! [info exists B($rr,$an)] || $B($rr,$an) ne [format "%.3f %.3f %.3f" $x $y $z]} {incr faux}}
    V "coordonnées = base ([llength $A] atomes)" {$faux == 0 && [llength $A] > 0} "$faux différents"
    # relu par Ordalie
    set r [Q [list catch [list LoadNewStructure $Tmp/a.pdb RELU_A] m]]
    V "fichier relu comme structure" {$r == 0} [Q {set m}]
    if {$r == 0} {
	V "relu : chaîne et résidus" {[Q "::RELU_A _chains"] eq [list $c] && [llength [Q "::RELU_A _resnumber -chain $c -polymer"]] == [llength $att]} "[Q {::RELU_A _chains}]"
	Q {catch {::RELU_A destroy}}
    }
    # toutes les chaînes, toute la structure
    set msg [Sauve $Tmp/b.pdb [list Mol $mol ChnAll all ResAll all]]
    set B2 [Atomes $Tmp/b.pdb]
    V "toutes les chaînes" {[lsort -unique [lmap a $B2 {lindex $a 0}]] eq $Lchn} [lsort -unique [lmap a $B2 {lindex $a 0}]]
    set nbase [Q [string map [list @DB $db @M $mol] {@DB onecolumn {select count(*) from atoms as a, residues as r, chains as c, pdb as p where p.name = '@M' and c.pk_pdb = p.pk_pdb and r.pk_chains = c.pk_chains and r.type != 'ligand' and a.pk_residues = r.pk_residues}}]]
    V "tous les atomes ($nbase)" {[llength $B2] == $nbase} [llength $B2]
    # plage refusée
    set msg [Sauve $Tmp/c.pdb [list Mol $mol ChnAll one LaChn $c ResAll rng ResFrom 1x ResTo 20]]
    V "plage non entière : message" {[string match "*valid residue range*" $msg]} $msg
    V "rien d'écrit" {! [file exists $Tmp/c.pdb]}
    set msg [Sauve $Tmp/d.pdb [list Mol $mol] bdi]
    V "Dismiss : rien d'écrit" {! [file exists $Tmp/d.pdb]}
    Inv "après Save PDB"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
