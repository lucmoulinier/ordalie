# Génère les données riches du banc dans ~/.cache/claude-ordalie-tests/donnees (jamais dans test/) :
# T_riche.ord = T_tutorial_maj.ord + objets 3D + superposition faite, sauvé en ORD.
# Usage : tclsh8.6 gen_donnees.tcl [numéro d'instance]
set H [file dirname [file normalize [info script]]]
source $H/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 26}]
set D $env(HOME)/.cache/claude-ordalie-tests/donnees
proc F {tag cmd {ms 300000}} {
    set r [W::fire $cmd $ms]
    set ok [expr {[dict get $r state] eq "done" && [dict get $r code] == 0 && ! [dict exists $r bgerrors]}]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [expr {$ok ? {} : [string range $r 0 500]}]"
    if {! $ok} {incr ::Echecs}
}
set Echecs 0
exec $H/gui_instance.sh start $N $D/T_tutorial_maj.ord </dev/null >@stdout 2>@stderr
W::connect [expr {4500+$N}]
W::ask {
    proc ::Fait {mol nom args} {
	global NwOj NwOjR
	DefineNewObj $mol ""
	set NwOj(Obj) $nom
	update
	set Lr [lsort -dictionary [array names NwOjR]]
	set moitie [expr {[llength $Lr]/2}]
	lassign $args t1 c1 t2 c2 srf
	foreach e [lrange $Lr 0 $moitie-1] {lset NwOjR($e) 1 $t1; lset NwOjR($e) 2 $c1}
	foreach e [lrange $Lr $moitie end] {lset NwOjR($e) 1 $t2; lset NwOjR($e) 2 $c2}
	set NwOj(Surface) [expr {$srf ne ""}]
	FinNewObj ok
    }
    proc ::Dlg {} {
	if {[winfo exists .pdbchooser]} {.pdbchooser.btn.selall invoke; update; .pdbchooser.btn.cebon invoke}
	if {[winfo exists .pdbref]} {set ::chxmolref [lindex $::ListePDB 0]; update; .pdbref.btn.cebon invoke}
	set ::DlgId [after 300 Dlg]
    }
}
F viewer VisualiseStructure
for {set i 0} {$i < 100 && ! [W::ask {winfo exists .ordogl}]} {incr i} {after 200}
lassign [W::ask {lsort $::Liste3dMol}] m1 m2
puts "molécules du viewer : $m1 $m2"
F "objet ribbon + CPK" [list Fait $m1 orib 3 red 7 blue]
F "objet trace" [list Fait $m2 ocat 2 green1 6 cyan]
F "fermeture du viewer" QuitteViandox
W::ask {set ::DlgId [after 300 Dlg]; unset -nocomplain ::SupRotTrans; ChangeMode superpose; $::FrmBouton.select.falcl.sal invoke}
F superposition {$::FrmBouton.select.frmsst.fin invoke}
W::ask {after cancel $::DlgId}
puts "structures transformées : [W::ask {array names ::SupRotTrans}]"
W::ask {ChangeMode feature}
F "sauvegarde ORD" [list SauveLAlignement ORD $D/T_riche.ord]
catch {close $W::ch}
exec $H/gui_instance.sh stop $N </dev/null >@stdout 2>@stderr
after 1000
exec $H/gui_instance.sh start $N $D/T_riche.ord </dev/null >@stdout 2>@stderr
W::connect [expr {4500+$N}]
puts "réouverture : instances [W::ask LesMacs]"
puts "réouverture : ListePDB [W::ask {set ::ListePDB}] objets [W::ask {lmap m [info class instances Structure] {list $m [$m _ListeObjets]}}]"
puts "réouverture : SupRotTrans [W::ask {array names ::SupRotTrans}]"
puts "réouverture : arbres [W::ask {set ::Abr(Liste)}]"
catch {close $W::ch}
exec $H/gui_instance.sh stop $N </dev/null >@stdout 2>@stderr
puts "BILAN : $Echecs échec(s)"
