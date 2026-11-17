# Test des objets 3D gardés dans un fichier ORD : créés, sauvés, restaurés,
# édités, supprimés, puis re-sauvés.
# Usage : tclsh8.6 test/objets3d_ord_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
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
	proc ::Dict {mol obj} {set [info object namespace ::$mol]::$obj}
	proc ::Flags {mol obj} {
	    set d [Dict $mol $obj]
	    lmap k {FlagRib FlagCat FlagAtm FlagCPK FlagPrl FlagSrf} {dict get $d $k}
	}
	proc ::Etat {mol obj} {list [Flags $mol $obj] [lsort -dictionary -stride 2 [$mol editObject $obj]]}
    }
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 180000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? $r : ""}]
    return $r
}
proc Viewer {} {
    F "ouverture du viewer" VisualiseStructure
    for {set i 0} {$i < 100 && ! [W::ask {winfo exists .ordogl}]} {incr i} {after 200}
}

set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] objets3d_[pid]]
file mkdir $Tmp
set ord $Tmp/o.ord

# --- 1. création et sauvegarde
Start $Test/I_maj.xml
Viewer
lassign [W::ask {lsort $::Liste3dMol}] m1 m2
puts "structures : $m1 $m2"
F "objet ribbon + CPK" [list Fait $m1 orib 3 red 7 blue]
F "objet atomes + surface" [list Fait $m1 osrf 1 orange 0 couldefond 1]
F "objet trace" [list Fait $m2 ocat 2 green1 6 cyan]
F "objet à supprimer" [list Fait $m1 odel 3 red 3 red]
F "suppression" [list DeleteObjet $m1 obj_odel]
set Lo1 [lsort [W::ask "$m1 _ListeObjets"]]
set Lo2 [lsort [W::ask "$m2 _ListeObjets"]]
foreach {m o} [list $m1 obj_orib $m1 obj_osrf $m2 obj_ocat] {set Avant($o) [W::ask [list Etat $m $o]]}
F "sauvegarde ORD" [list SauveLAlignement ORD $ord]
Stop

# --- 2. réouverture
Start $ord
V "aucun objet avant le viewer" {[W::ask "$m1 _ListeObjets"] eq {}}
Viewer
V "$m1 : mêmes objets, sans doublon" {[lsort [W::ask "$m1 _ListeObjets"]] eq $Lo1} [W::ask "$m1 _ListeObjets"]
V "$m2 : mêmes objets, sans doublon" {[lsort [W::ask "$m2 _ListeObjets"]] eq $Lo2} [W::ask "$m2 _ListeObjets"]
V "objet supprimé : absent" {"obj_odel" ni [W::ask "$m1 _ListeObjets"]}
foreach {m o} [list $m1 obj_orib $m1 obj_osrf $m2 obj_ocat] {
    set e [W::ask [list Etat $m $o]]
    V "$o : représentations et couleurs retrouvées" {$e eq $Avant($o)} [lindex $e 0]
    V "$o : bouton présent" {[W::ask "winfo exists \$::pgl(frObjc).f$m.bto[string range $o 4 end]"]}
    V "$o : éteint à l'ouverture" {! [W::ask "$m _EtatDeObjet $o"]}
    V "$o : dessiné" {[W::ask "dict get \[Dict $m $o\] globj"] != 0 || [W::ask "dict get \[Dict $m $o\] glList"] ne "-1"} [W::ask "dict get \[Dict $m $o\] glList"]
}
F "allumer orib" "\$::pgl(frObjc).f$m1.btoorib invoke"
V "orib : allumé" {[W::ask "$m1 _EtatDeObjet obj_orib"]}
F "éteindre CT" "foreach o \[$m1 _ListeObjets\] {if {\[string match obj_CT* \$o\]} {\$::pgl(frObjc).f$m1.bto\[string range \$o 4 end\] invoke}}"
if {[info exists env(TEST_SHOT)]} {
    F "image" "update; \$::pgl(wogl) postredisplay; update; after 1500; update"
    exec $P/gui_instance.sh shot $N $env(TEST_SHOT) </dev/null >@stdout
}
# édition d'un objet restauré
F "édition" [list apply {{m} {
    global NwOj NwOjR
    DefineNewObj $m obj_ocat
    foreach e [array names NwOjR] {lset NwOjR($e) 1 3; lset NwOjR($e) 2 pink}
    set NwOj(Surface) 0
    FinNewObj ok
}} $m2]
set EditOcat [W::ask [list Etat $m2 obj_ocat]]
V "édition : ribbon seul" {[lindex $EditOcat 0] eq {1 0 0 0 0 0}} [lindex $EditOcat 0]
F "suppression d'un objet restauré" [list DeleteObjet $m1 obj_osrf]
# fermer et rouvrir le viewer dans la session
F "fermeture du viewer" QuitteViandox
Viewer
V "viewer rouvert : pas de doublon" {[lsort [W::ask "$m1 _ListeObjets"]] eq [lsearch -all -inline -not $Lo1 obj_osrf]}
F "sauvegarde 2" [list SauveLAlignement ORD $ord]
Stop

# --- 3. deuxième réouverture
Start $ord
Viewer
V "objet restauré puis supprimé : absent" {"obj_osrf" ni [W::ask "$m1 _ListeObjets"]}
V "orib : toujours là" {"obj_orib" in [W::ask "$m1 _ListeObjets"]}
V "ocat : édition gardée" {[W::ask [list Etat $m2 obj_ocat]] eq $EditOcat}
F "nouvel objet après réouverture" [list Fait $m1 oneuf 3 red 3 red]
V "nouvel objet : présent" {"obj_oneuf" in [W::ask "$m1 _ListeObjets"]}
F "objet déjà existant refusé proprement" [list ObjectAlreadyExists orib]
Stop

# --- 4. ORD existants
foreach f {R_tutorial.ord T_tutorial.ord} {
    Start $Test/$f
    if {[W::ask {llength $::ListePDB}]} {
	W::ask {set ::StrucAVoir {}}
	Viewer
	V "$f : viewer ouvert" {[W::ask {winfo exists .ordogl}]}
    } else {
	puts "$f : pas de structure"
    }
    Stop
}
file delete -force $Tmp
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
