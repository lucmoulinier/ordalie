# 3D viewer lié à son instance (2026-11-16)
# x = instance chargée de D_maj.xml, y = copie de x sans PDB_1EOV_A.
# Usage (display avec GLX, ex. Xvfb :88 +extension GLX) :
#   DISPLAY=localhost:88 /home/moumou/tcl/bin/wish8.6 test/viewer3d_instance_test.tcl
# (ordali-dev : DMAJ=/home/moumou/clordali/test/D_maj.xml)
# Dernière ligne attendue : BILAN : erreurs=0 verifs KO=0
set ::Racine [file dirname [file dirname [file normalize [info script]]]]
set ::env(ORDALIDIR) $::Racine
# DMAJ : autre D_maj.xml (ordali-dev/test n'en a pas)
set argv [list [expr {[info exists ::env(DMAJ)] ? $::env(DMAJ) : [file join $::Racine test D_maj.xml]}]]
fconfigure stdout -buffering line
proc bgerror {msg} {puts "BGERROR: $msg\n[join [lrange [split $::errorInfo \n] 0 12] \n]"}
set ::NERR 0
proc T {tag script} {
    if {[catch {uplevel #0 $script} e]} {incr ::NERR; puts "ERREUR $tag: $e\n[join [lrange [split $::errorInfo \n] 0 14] \n]"} else {puts "OK $tag -> [string range $e 0 200]"}
    update
}
set ::NKO 0
proc V {tag cond} {
    if {[uplevel #0 [list expr $cond]]} {puts "  VERIF OK  $tag"} else {incr ::NKO; puts "  VERIF KO  $tag  ($cond)"}
}
# répond au dialogue .chxviewer : 0 = Close it, 1 = Cancel
proc Repond {n} {
    if {[winfo exists .chxviewer]} {
	set ::VuDialogue 1
	.chxviewer.button$n invoke
	return
    }
    after 200 [list Repond $n]
}
set ::LMsg {}
proc Act {} {
    proc ::FaireLire {args} {lappend ::LMsg [join $args]; puts "FAIRELIRE: [string map {\n " / "} [join $args]]"}
    set ::Lx [ExtraitListeDeListe $::ListePDB 0]
    set ::X [MacCourant]; set ::NX [llength $::Lx]
    puts "ListePDB x = $::Lx  instance=[MacCourant] [MacCourant name]"

    # --- viewer ouvert dans x
    T open-x {VisualiseStructure}
    update; after 500; update
    V "viewer ouvert" {[ViewerOuvert]}
    V "pgl(Mac)=x" {$::pgl(Mac) == $::X}
    V "titre avec instance" {[string match "*instance*" [wm title .ordogl]]}
    set ::FeatX $::ListeFeat43d
    T map-x {set ::Mol3dCou 1EFW; update; set ::Obj3dCou CA1EFWA; set ::Feat3dCou PFAM-A; set ::Feat3dCou2 None; UpdateMolObjFeat}
    V "mapping x accepté" {$::pgl(FeatsMappees) eq {PFAM-A None}}

    # --- création de y sans 1eov
    T cree-y {
	set i [lsearch -nocase -glob $::LNOrdali PDB_1eov*]
	set ::LNOrdali [lreplace $::LNOrdali $i $i]
	set ::LSOrdali [lreplace $::LSOrdali $i $i]
	EnregistreLeMac "y" "sans 1eov"
	set ::NomY [MacCourant name]
	VueEditee 0
	MiseAJourMac x $::NomY
    }
    puts "instance=[MacCourant] [MacCourant name] ListePDB y=[ExtraitListeDeListe $::ListePDB 0]"
    V "1eov retiré de y" {"PDB_1EOV_A" ni $::LNOrdali}
    V "dans y" {[MacCourant] != $::X}
    V "viewer toujours ouvert" {[ViewerOuvert]}
    V "liste features gardée" {$::ListeFeat43d eq $::FeatX}
    V "structures du viewer inchangées" {[llength [StrucDuViewer]] == $::NX}

    # --- refus dans y
    set ::LMsg {}
    T map-y {set ::Feat3dCou Cons-T80; UpdateMolObjFeat}
    V "mapping y refusé (message)" {[string match "*opened for another instance*" [lindex $::LMsg end]]}
    V "combobox revenue à PFAM-A" {$::Feat3dCou eq "PFAM-A"}
    set ::LMsg {}
    T newobj-y {DefineNewObj 1EFW}
    V "édition objet refusée" {! [winfo exists .nwoj] && [llength $::LMsg] == 1}
    set ::LMsg {}
    after 300 {Repond 1}
    T qm-auto-y {QuickMappingAuto 1EFW CA1EFWA pfam none}
    V "QuickMappingAuto : Cancel, rien fait" {$::pgl(Mac) == $::X && [llength $::LMsg] == 0}

    # --- permis dans y
    set ::LMsg {}
    T alloff-y {TousObjetsOff}
    T allon-y {TousObjetsOn}
    T zoom-y {HandleZoom 0.03 $::pgl(wogl); HandleZoom -0.03 $::pgl(wogl)}
    T redraw-y {$::pgl(wogl) postredisplay; update}
    V "actions de vue sans message" {[llength $::LMsg] == 0}

    # --- Visualise structure depuis y : Cancel puis Close it
    set ::VuDialogue 0
    after 300 {Repond 1}
    T vis-y-cancel {VisualiseStructure}
    V "dialogue affiché" {$::VuDialogue}
    V "Cancel : viewer de x gardé" {[ViewerOuvert] && $::pgl(Mac) == $::X}
    set ::VuDialogue 0
    after 300 {Repond 0}
    T vis-y-close {VisualiseStructure}
    update; after 500; update
    V "Close it : viewer de y" {[ViewerOuvert] && $::pgl(Mac) == [MacCourant]}
    V "structures de y" {[llength [StrucDuViewer]] == $::NX - 1 && "PDB_1EOV_A" ni [StrucDuViewer]}
    V "titre y" {[string match "*$::NomY*" [wm title .ordogl]]}
    V "objet du viewer x gardé (CA1EFWA)" {"obj_CA1EFWA" in [1EFW _ListeObjets]}
    set ::LMsg {}
    T map-y2 {set ::Mol3dCou 1EFW; update; set ::Obj3dCou CA1EFWA; set ::Feat3dCou PFAM-A; UpdateMolObjFeat}
    V "mapping accepté dans y" {[llength $::LMsg] == 0 && [lindex $::pgl(FeatsMappees) 0] eq "PFAM-A"}

    # --- retour dans x : viewer de y bloqué ; superposition -> dialogue
    T retour-x {MiseAJourMac x [lindex [NomDeMac $::X] 0]}
    V "dans x" {[MacCourant] == $::X}
    set ::LMsg {}
    T map-x2 {set ::Feat3dCou PFAM-A; UpdateMolObjFeat}
    V "mapping refusé dans x (viewer de y)" {[llength $::LMsg] == 1}
    set ::VuDialogue 0
    after 300 {Repond 1}
    T super-cancel {FaitSuperposition 0}
    V "superposition : dialogue, Cancel" {$::VuDialogue && [ViewerOuvert]}
    # SS-Cons / ColorieMol3dSelonFeatures : dialogue, Cancel
    set ::VuDialogue 0
    after 300 {Repond 1}
    T colorie-cancel {ColorieMol3dSelonFeatures PFAM-A}
    V "ColorieMol3dSelonFeatures : dialogue, Cancel, rien colorié" {$::VuDialogue && $::pgl(Mac) != $::X}

    # --- fermeture propre
    T close {QuitteViandox}
    V "fermé" {! [ViewerOuvert] && ! [info exists ::pgl]}
    T reopen-x {VisualiseStructure}
    update; after 500; update
    V "réouvert dans x" {[ViewerOuvert] && $::pgl(Mac) == $::X && [llength [StrucDuViewer]] == $::NX}
    T close2 {QuitteViandox}

    puts "BILAN : erreurs=$::NERR verifs KO=$::NKO"
    exit 0
}
proc H {args} {trace remove variable ::VariablesAuDepart write H; trace add execution LanceOrdali leave {apply {args {after 500 {if {[catch Act e]} {puts "ACTERR $e $::errorInfo"; exit 3}}}}}}
trace add variable ::VariablesAuDepart write H
after 400000 {puts TIMEOUT; exit 2}
uplevel #0 [list source [file join $::Racine src ordali.tcl]]
