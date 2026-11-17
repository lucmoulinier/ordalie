# Test de PrintOgl (image de la vue 3D) avec le choix de la couleur de fond (2026-11-09) :
#  - fond noir, blanc, puis une couleur choisie : le coin de l'image a cette couleur, la molécule est dessinée ;
#  - bouton « choose... » : « other » sélectionné, échantillon et image à la couleur choisie ;
#  - Cancel : aucun fichier écrit ;
#  - après l'image, la vue garde son fond noir (couleur d'effacement remise).
# Usage : tclsh8.6 test/printogl_fond_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
source [file join [file dirname [file normalize [info script]]] phase3 commun.tcl]
proc Q {s} {W::ask $s}

# lance PrintOgl, répond à la fenêtre du fond, attend la fin
proc Image {fichier choix {couleur ""}} {
    set id [Q [list probe::fire [list PrintOgl $fichier]]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .bgchx}]} {
	if {[clock milliseconds] - $t0 > 20000} {return "pas de fenêtre"}
	after 200
    }
    V "fenêtre du fond modale" {[Q {grab current}] eq ".bgchx"} [Q {grab current}]
    if {$choix eq "cancel"} {
	Q {.bgchx.f.bcan invoke}
    } else {
	if {$couleur ne ""} {Q [list set ::NwOj(BgOglCol) $couleur]}
	Q [list .bgchx.f.r$choix invoke]
	Q {.bgchx.f.bok invoke}
    }
    set r [W::waitfor $id 120000]
    if {[Err $r]} {return $r}
    return ""
}
# couleur d'un pixel du PNG, et nombre de pixels d'une autre couleur que le coin
proc Pixels {fichier} {
    Q [string map [list @F@ $fichier] {
	set p [image create photo -file {@F@}]
	set coin [$p get 0 0]
	set w [image width $p]; set h [image height $p]; set n 0
	for {set y 0} {$y < $h} {incr y 7} {
	    for {set x 0} {$x < $w} {incr x 7} {
		if {[$p get $x $y] ne $coin} {incr n}
	    }
	}
	image delete $p
	list $coin $n
    }]
}
# couleur d'effacement courante de la vue
proc Effacement {} {
    Q {
	$::pgl(wogl) makecurrent
	set v [tcl3dVector GLfloat 4]
	glGetFloatv GL_COLOR_CLEAR_VALUE $v
	set r [lmap i {0 1 2} {expr {round([$v get $i] * 255)}}]
	$v delete
	set r
    }
}

if {[catch {
    Start $Test/I_maj.xml
    F "viewer" VisualiseStructure 300000
    foreach {tag choix couleur attendu} {
	noir  black ""      {0 0 0}
	blanc white ""      {255 255 255}
	autre other #3366cc {51 102 204}
    } {
	set f $Tmp/$tag.png
	set e [Image $f $choix $couleur]
	V "fond $tag : PrintOgl sans erreur" {$e eq ""} $e
	V "fond $tag : fichier écrit" {[file exists $f]}
	if {! [file exists $f]} continue
	lassign [Pixels $f] coin n
	V "fond $tag : coin de l'image à la couleur choisie" {$coin eq $attendu} $coin
	V "fond $tag : molécule dessinée" {$n > 50} "$n pixels"
	V "fond $tag : la vue garde son fond noir" {[Effacement] eq {0 0 0}} [Effacement]
    }
    # bouton « choose... » : la fenêtre de choix de couleur est remplacée par une réponse fixe
    Q {rename tk_chooseColor tk_chooseColor_vrai; proc tk_chooseColor {args} {return #ff8000}}
    set id [Q [list probe::fire [list PrintOgl $Tmp/choisie.png]]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .bgchx}] && [clock milliseconds] - $t0 < 20000} {after 200}
    Q {.bgchx.f.rblack invoke; .bgchx.f.rbtn invoke}
    V "choose : « other » sélectionné" {[Q {set ::NwOj(BgOgl)}] eq "other"} [Q {set ::NwOj(BgOgl)}]
    V "choose : échantillon de la couleur" {[Q {.bgchx.f.lcol cget -bg}] eq "#ff8000"} [Q {.bgchx.f.lcol cget -bg}]
    Q {.bgchx.f.bok invoke}
    set r [W::waitfor $id 120000]
    V "choose : PrintOgl sans erreur" {! [Err $r]} $r
    Q {rename tk_chooseColor {}; rename tk_chooseColor_vrai tk_chooseColor}
    if {[file exists $Tmp/choisie.png]} {
	V "choose : coin de l'image orange" {[lindex [Pixels $Tmp/choisie.png] 0] eq {255 128 0}} [lindex [Pixels $Tmp/choisie.png] 0]
    } else {
	V "choose : fichier écrit" 0
    }

    set e [Image $Tmp/annule.png cancel]
    V "Cancel : sans erreur" {$e eq ""} $e
    V "Cancel : aucun fichier" {! [file exists $Tmp/annule.png]}
    Inv "après les images"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
