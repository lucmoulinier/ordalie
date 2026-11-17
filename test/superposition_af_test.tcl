# Test de la superposition avec des modèles AlphaFold (Q9BW92_A) dans T_tutorial.ord.
# Usage : tclsh8.6 test/superposition_af_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 400]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    # répond aux deux dialogues de la superposition
    W::ask {proc ::Dlg {} {
	if {[winfo exists .pdbchooser]} {.pdbchooser.btn.selall invoke; update; .pdbchooser.btn.cebon invoke}
	if {[winfo exists .pdbref]} {set ::chxmolref $::RefVoulue; update; .pdbref.btn.cebon invoke}
	after 300 Dlg
    }}
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 120000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? [dict get $r errorInfo] : ""}]
    return $r
}
proc Instance {nom} {F "instance $nom" [list apply {{nom} {
    set ::MacChoisi [lsearch -inline [LesMacs] "$nom -*"]
    MiseAJourMac
}} $nom] 60000}
# superposition complète : zones = tout l'alignement
proc Super {ref} {
    W::ask [list set ::RefVoulue $ref]
    W::ask {unset -nocomplain ::SupRotTrans; ChangeMode superpose; $::FrmBouton.select.falcl.sal invoke; after 300 Dlg}
    F "superposition, référence $ref" {$::FrmBouton.select.frmsst.fin invoke}
    W::ask {foreach i [after info] {if {[lindex [after info $i] 0] eq "Dlg"} {after cancel $i}}}
    V "référence $ref : en tête" {[W::ask {lindex $::StrucAVoir 0}] eq $ref} [W::ask {set ::StrucAVoir}]
    set Lmoved [W::ask {array names ::SupRotTrans}]
    V "référence $ref : structures transformées" {[llength $Lmoved] >= 2} $Lmoved
    V "référence $ref : tous dans l'alignement" {[W::ask {llength [lmap m $::StrucAVoir {if {[BonNomPDB $m] in $::LNOrdali} continue; set m}]}] == 0} [W::ask {set ::StrucAVoir}]
    W::ask {ChangeMode feature}
}

Start $Test/T_tutorial.ord
# noms : un access UniProt n'est pas un PDB
foreach {e s} {Q9BW92_A Q9BW92_A E9AEW4_A E9AEW4_A A0A3S7X901 A0A3S7X901 PDB_1QF6_A PDB_1QF6_A 1qf6_A PDB_1QF6_A ::1QF6_A PDB_1QF6_A 1QF6 PDB_1QF6_} {
    V "BonNomPDB $e" {[W::ask [list BonNomPDB $e]] eq $s} [W::ask [list BonNomPDB $e]]
}
Instance M4
V "M4 : Q9BW92_A dans ListePDB" {"Q9BW92_A" in [W::ask {set ::ListePDB}]}
V "M4 : ListePDB limitée à l'instance" {[W::ask {llength [lmap m $::ListePDB {if {$m in $::LNOrdali} continue; set m}]}] == 0} [W::ask {set ::ListePDB}]
Super Q9BW92_A
Super 1QF6_A
F "viewer après superposition" VisualiseStructure
V "viewer ouvert" {[W::ask {winfo exists .ordogl}]}
F "fermeture du viewer" QuitteViandox
Instance M5
V "M5 : E9AEW4_A dans ListePDB" {"E9AEW4_A" in [W::ask {set ::ListePDB}]}
V "M5 : Q9BW92_A retirée de ListePDB" {"Q9BW92_A" ni [W::ask {set ::ListePDB}]}
Super E9AEW4_A
Stop
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
