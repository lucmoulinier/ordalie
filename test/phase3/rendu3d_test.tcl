# Phase 3 : rendu du viewer 3D jugé sur l'image. La vue OpenGL est capturée (ffmpeg, écran Xvfb du banc)
# et ses pixels comptés par couleur. Après chaque action, sans aucun mouvement de souris :
#  - objet CPK sans couleur choisie : couleurs d'atomes (rouge O, bleu N), pas seulement du gris ;
#  - suppression de l'objet : l'image revient à l'état d'avant ;
#  - objet ruban rouge, puis édité en bleu : la couleur change à l'écran.
# Usage : tclsh8.6 test/phase3/rendu3d_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
source [file join [file dirname [file normalize [info script]]] commun.tcl]

# zone de la vue OpenGL à l'écran
proc ZoneGL {} {
    Q {
	set l [list .ordogl]; set g ""
	while {$l ne {}} {
	    set l [lassign $l w]
	    if {[winfo class $w] eq "Togl"} {set g $w; break}
	    lappend l {*}[winfo children $w]
	}
	raise .ordogl; update
	list [winfo rootx $g] [winfo rooty $g] [winfo width $g] [winfo height $g]
    }
}
proc Q {s} {W::ask $s}
# capture et compte : pixels non noirs, rouges, bleus, gris (saturation faible)
proc Capture {tag} {
    # le dessin en OpenGL logiciel (Xvfb) des sphères CPK prend plusieurs secondes
    after 1500
    after [expr {[info exists ::env(P3_ATTENTE)] ? $::env(P3_ATTENTE) : 1500}]
    # zone lue une seule fois : remettre la fenêtre au premier plan la redessinerait
    # et masquerait un défaut de rafraîchissement
    if {! [info exists ::Zone]} {set ::Zone [ZoneGL]}
    lassign $::Zone x y w h
    set w [expr {$w / 2 * 2}]; set h [expr {$h / 2 * 2}]
    set f $::Tmp/$tag.ppm
    exec ffmpeg -y -loglevel error -f x11grab -video_size ${w}x$h -i localhost:[expr {80+$::N}].0+$x,$y -frames:v 1 -vcodec ppm -f image2 $f
    if {[info exists ::env(P3_IMAGES)]} {catch {exec ffmpeg -y -loglevel error -i $f $::env(P3_IMAGES)/$tag.png}}
    set c [open $f rb]; set d [read $c]; close $c
    # en-tête P6 : "P6\nW H\n255\n"
    regexp {^P6\s+(\d+)\s+(\d+)\s+(\d+)\s} $d tete W H M
    binary scan [string range $d [string length $tete] end] cu* px
    set n 0; set r 0; set b 0; set g 0
    foreach {R G B} $px {
	if {$R + $G + $B < 60} continue
	incr n
	set mx [expr {max($R,$G,$B)}]; set mn [expr {min($R,$G,$B)}]
	if {$mx - $mn < 30} {incr g; continue}
	if {$R > 120 && $R > 2*$G && $R > 2*$B} {incr r}
	if {$B > 120 && $B > 2*$R && $B > 2*$G} {incr b}
    }
    set res [dict create dessin $n rouge $r bleu $b gris $g]
    puts "     image $tag : $res"
    return $res
}
# capture après une action : le dessin logiciel peut prendre plusieurs secondes,
# on attend (20 s au plus) que l'image change par rapport à $ref
proc Apres {tag ref} {
    set t0 [clock seconds]
    while {1} {
	set I [Capture $tag]
	if {$I ne $ref || [clock seconds] - $t0 > 20} {return $I}
    }
}
proc Objet {mol nom type col {edit 0}} {
    Q [list DefineNewObj $mol [expr {$edit ? "obj_$nom" : ""}]]
    if {! $edit} {Q [list set ::NwOj(Obj) $nom]}
    # dialogue hors de la vue : sa fermeture ne doit pas exposer (donc redessiner) la vue,
    # seul compte le redessin demandé par l'action (comme viewer3d_cpk_refresh_test.tcl)
    Q {wm geometry $::NwOj(Toplevel) +3000+3000; update; list}
    Q [list apply {{type col} {foreach e [array names ::NwOjR] {lset ::NwOjR($e) 1 $type; lset ::NwOjR($e) 2 $col}}} $type $col]
    F "objet $nom ([expr {$edit ? "édité" : "créé"}], type $type, $col)" {FinNewObj ok}
}

if {[catch {
    Start $Test/I_maj.xml
    F "viewer" VisualiseStructure
    for {set i 0} {$i < 100 && ! [Q {winfo exists .ordogl}]} {incr i} {after 200}
    set mol [lindex [Q {lsort $::Liste3dMol}] 0]
    # objets par défaut éteints : seuls les objets du test sont dessinés
    foreach o [Q "$mol _ListeObjets"] {Q [list catch [list $mol ObjetOff $o]]}
    # appels directs des méthodes : redessin demandé comme le fait le viewer
    Q {set l [list .ordogl]; while {$l ne {}} {set l [lassign $l w]; if {[winfo class $w] eq "Togl"} {$w postredisplay; break}; lappend l {*}[winfo children $w]}; update; list}
    set I0 [Capture vide]

    Objet $mol cpk 7 couldefond
    set I1 [Apres cpk $I0]
    V "CPK : dessiné sans mouvement de souris" {[dict get $I1 dessin] > [dict get $I0 dessin] + 500}
    # couleurs jugées après un redessin forcé : indépendant du défaut de rafraîchissement
    Q {$::pgl(wogl) postredisplay; update; list}
    after 3000
    set I1f [Capture cpk_redessine]
    V "CPK : couleurs d'atomes, pas seulement du gris" {[dict get $I1f rouge] > 100 && [dict get $I1f bleu] > 30} $I1f
    F "suppression de l'objet CPK" [list DeleteObjet $mol obj_cpk]
    set I2 [Apres apres_suppression $I1f]
    V "suppression : image revenue à l'état d'avant" {abs([dict get $I2 dessin] - [dict get $I0 dessin]) < 200} "avant $I0 après $I2"

    Objet $mol ruban 3 red
    set I3 [Apres ruban_rouge $I2]
    V "ruban rouge : rouge à l'écran" {[dict get $I3 rouge] > 500 && [dict get $I3 rouge] > 5 * ([dict get $I3 bleu] + 1)} $I3
    Objet $mol ruban 3 blue 1
    set I4 [Apres ruban_bleu $I3]
    V "ruban édité en bleu : bleu à l'écran" {[dict get $I4 bleu] > 500 && [dict get $I4 bleu] > 5 * ([dict get $I4 rouge] + 1)} $I4
    Inv "fin"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
