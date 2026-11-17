# Test du viewer 3D (New Object / Edit) :
#  - un objet CPK sans couleur choisie est dessiné avec les couleurs d'atomes,
#    une couleur choisie reste respectée ;
#  - créer ou éditer un objet redessine la vue sans mouvement de souris.
# Lancement : DISPLAY=<X avec GLX> wish8.6 test/viewer3d_cpk_refresh_test.tcl [racine Ordalie]
set Racine [expr {[llength $argv] ? [lindex $argv 0] : [file dirname [file dirname [file normalize [info script]]]]}]
set ::env(ORDALIDIR) $Racine
set argv [list $Racine/test/D_maj.xml]
fconfigure stdout -buffering line
set ::NbEchecs 0
proc Verifie {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag $info"
    if {! $ok} {incr ::NbEchecs}
}
proc bgerror {msg} {puts "BGERROR: $msg\n$::errorInfo"; incr ::NbEchecs}
proc Dlg {} {
    if {[winfo exists .pdbchooser]} {.pdbchooser.btn.selall invoke; update; .pdbchooser.btn.cebon invoke}
    if {[winfo exists .pdbref]} {
	set b [lindex [lsort [winfo children .pdbref.fmol.d]] 0]
	$b invoke; .pdbref.btn.cebon invoke
    }
    after 300 Dlg
}
proc Attends {ms} {after $ms {set ::Fin 1}; vwait ::Fin; update}

# compte les redessins et note les couleurs des sphères
set ::NbDisplay 0
proc Instrumente {} {
    rename Togl_DisplayFonct Togl_DisplayFonct_orig
    proc Togl_DisplayFonct {args} {incr ::NbDisplay; Togl_DisplayFonct_orig {*}$args}
    rename gluSphere gluSphere_orig
    rename glColor4f glColor4f_orig
    proc glColor4f {args} {set ::CoulCou $args; glColor4f_orig {*}$args}
    proc gluSphere {args} {
	dict incr ::Spheres [join [lrange $::CoulCou 0 2]]
	gluSphere_orig {*}$args
    }
}

# crée (ou édite) l'objet : tous les résidus de type $type, couleur $col
proc FaitObjet {mol nom type col {edit 0}} {
    global NwOj NwOjR
    DefineNewObj $mol [expr {$edit ? "obj_$nom" : ""}]
    if {! $edit} {set NwOj(Obj) $nom}
    # hors de la vue 3D : sa fermeture ne doit pas exposer (donc redessiner) la vue
    wm geometry $NwOj(Toplevel) +3000+3000
    update
    Attends 300
    foreach e [array names NwOjR] {
	lset NwOjR($e) 1 $type
	lset NwOjR($e) 2 $col
    }
    # seul compte ce qui est dessiné après le OK
    set ::Spheres [dict create]
    set avant $::NbDisplay
    FinNewObj ok
    # seule la boucle d'événements peut redessiner ici : aucun mouvement de souris
    Attends 500
    return [expr {$::NbDisplay - $avant}]
}

proc Act {} {
    proc ::FaireLire {args} {puts "FAIRELIRE: [string map {\n " / "} [join $args]]"}
    ChangeMode superpose
    $::FrmBouton.select.falcl.sal invoke
    after 300 Dlg
    $::FrmBouton.select.frmsst.fin invoke
    $::FrmBouton.select.frmsst.dpl invoke
    Attends 1500
    set mol [lindex $::Liste3dMol 0]
    Instrumente
    Attends 500

    # valeurs de référence de CouleurDeAtome : numéros atomiques comme noms
    foreach {nomA noA} {" C  " 6 " N  " 7 " O  " 8 " P  " 15 " S  " 16} {
	Verifie "couleur $nomA = Z $noA" {[CouleurDeAtome $nomA] eq [CouleurDeAtome $noA]} \
	    "[CouleurDeAtome $nomA] / [CouleurDeAtome $noA]"
    }

    # 1. CPK sans couleur (None => couldefond) : couleurs d'atomes
    set n [FaitObjet $mol tcpk 7 couldefond]
    Verifie "création : redessin sans souris" {$n > 0} "($n redessins)"
    set vus [dict keys $::Spheres]
    set attendu [list [CouleurDeAtome C] [CouleurDeAtome N] [CouleurDeAtome O]]
    Verifie "CPK None : sphères dessinées" {[llength $vus] > 0} "$::Spheres"
    foreach c $attendu {
	Verifie "CPK None : couleur d'atome $c" {[join $c] in $vus}
    }
    set gris [join [lrange [RGBDeLaTkCol couldefond] 0 2]]
    Verifie "CPK None : pas de couleur par défaut $gris" {$gris ni $vus}
    # image du rendu si demandée : TEST_SHOT=fichier.png
    if {[info exists ::env(TEST_SHOT)]} {PrintOgl $::env(TEST_SHOT)}

    # 2. édition vers une couleur choisie : respectée, redessin immédiat
    set n [FaitObjet $mol tcpk 7 red 1]
    Verifie "édition : redessin sans souris" {$n > 0} "($n redessins)"
    set rouge [join [lrange [RGBDeLaTkCol red] 0 2]]
    Verifie "CPK red : une seule couleur, rouge" {[dict keys $::Spheres] eq [list $rouge]} "$::Spheres"

    # 3. retour à None en édition : couleurs d'atomes à nouveau
    FaitObjet $mol tcpk 7 couldefond 1
    Verifie "CPK re-édité None : couleur d'atome" {[join [CouleurDeAtome N]] in [dict keys $::Spheres]} "$::Spheres"
    Verifie "CPK re-édité None : plus de rouge uni" {$rouge ni [dict keys $::Spheres]}

    # Ribbon + CPK : cha�nes lat�rales seulement, une seule fois
    FaitObjet $mol trc 5 couldefond
    set nb 0
    dict for {c n} $::Spheres {incr nb $n}
    Verifie "Ribbon + CPK : moins de sph�res que CPK et sans doublon" {$nb > 0 && $nb < 11096} "$nb"

    # 4. un ribbon None garde la couleur par défaut (non concerné)
    set n [FaitObjet $mol trib 3 couldefond]
    Verifie "ribbon : redessin sans souris" {$n > 0}

    # feature couvrant des colonnes avant le premier residu de la chaine :
    # pas d'erreur, et les residus couverts sont bien traites
    DefineNewObj $mol ""
    set ::NwOj(Obj) tfeat
    wm geometry $::NwOj(Toplevel) +3000+3000
    Attends 300
    set nom [BonNomPDB "${mol}_$::NwOj(Chain)"]
    set feat Cons-T80
    set couvre 0
    foreach e $::TabSF($nom,$feat) {
	DecortiqueUneFeature $e d f c s n
	for {set i $d} {$i <= $f} {incr i} {if {[DonnePosGS $nom $i] == 0} {incr couvre}}
    }
    Verifie "feature : couvre des colonnes avant la chaine" {$couvre > 0} "$nom $couvre"
    set ::NwOj(ColorSel) red
    set ::NwOj(FeatCol) $feat
    set r [catch {ColorChainNwOj feature} m]
    Verifie "feature : ColorChainNwOj sans erreur" {! $r} $m
    set ::NwOj(TypeSel) Atoms
    set ::NwOj(FeatSel) $feat
    set r [catch {SelectChainNwOj feature} m]
    Verifie "feature : SelectChainNwOj sans erreur" {! $r} $m
    set nb 0
    foreach e [array names ::NwOjR "$::NwOj(Chain),*"] {
	if {[lindex $::NwOjR($e) 2] eq "red" && [lindex $::NwOjR($e) 1] != 0} {incr nb}
    }
    Verifie "feature : residus colores et types" {$nb > 0} "$nb"
    Verifie "feature : pas de residu 0 cree" {! [info exists ::NwOjR($::NwOj(Chain),0)]}
    FinNewObj cancel

    puts "BILAN : $::NbEchecs échec(s)"
    exit [expr {$::NbEchecs ? 1 : 0}]
}
proc H {args} {trace remove variable ::VariablesAuDepart write H; trace add execution LanceOrdali leave {apply {args {after 500 {if {[catch Act e]} {puts "ACTERR $e\n$::errorInfo"; exit 3}}}}}}
trace add variable ::VariablesAuDepart write H
after 400000 {puts TIMEOUT; exit 2}
uplevel #0 [list source $Racine/src/ordali.tcl]
