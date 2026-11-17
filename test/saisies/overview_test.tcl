# Alignment > Overview : liste des features (dessin de la feature choisie : couleur des éléments aux bons
# endroits de l'image), +/- (taille), Show/Hide region, Annotations, clic (centre l'alignement), Print,
# Close ; réglages gardés dans l'ORD (sauvegarde et réouverture).
# Usage : tclsh8.6 test/saisies/overview_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# éléments longs de la feature : couleur au milieu de l'élément dans l'image de la feature
proc Pixels {Id ft} {
    Q [string map [list @I $Id @F $ft] {
	set img [$::Ovw(O@I,w) itemcget $::Ovw(O@I,@F) -image]
	# échelle de l'overview (l'image d'une feature s'arrête à son dernier élément)
	set z [expr {$::Ovw(O@I,ScaleTot) eq "" ? 1.0 : [::tcl::mathop::* 1.0 {*}$::Ovw(O@I,ScaleTot)]}]
	set sx [expr {$::Ovw(O@I,ScaOriX)/100.*$z}]
	set sy [expr {$::Ovw(O@I,ScaOriY)/100.*$z}]
	set faux {}; set n 0
	set y -1
	foreach nom $::LNOrdali {
	    incr y
	    if {[string trim $nom] eq "" || ! [info exists ::TabSF($nom,@F)]} continue
	    foreach e $::TabSF($nom,@F) {
		if {[dict get $e fstop] - [dict get $e fstart] < 40} continue
		set col [expr {([dict get $e fstart]+[dict get $e fstop])/2}]
		# couleur du dernier élément qui couvre la colonne (dessiné par-dessus)
		set c ""
		foreach x $::TabSF($nom,@F) {if {[dict get $x fstart] <= $col && [dict get $x fstop] >= $col} {set c [dict get $x fcolor]}}
		# loin des bords des éléments voisins
		set bord 0
		foreach x $::TabSF($nom,@F) {foreach k {fstart fstop} {if {abs([dict get $x $k] - $col) < 4} {set bord 1}}}
		if {$bord} continue
		set px [expr {int(($col+0.5)*$sx)}]
		lassign [winfo rgb . $c] R G B
		# bande de pixels de la séquence (arrondis du redimensionnement)
		set bon 0
		for {set py [expr {int($y*$sy)}]} {$py <= int(($y+1)*$sy) && $py < [image height $img]} {incr py} {
		    lassign [$img get $px $py] r g b
		    if {abs($r-$R/256) <= 60 && abs($g-$G/256) <= 60 && abs($b-$B/256) <= 60} {set bon 1}
		}
		if {! $bon} {lappend faux "$nom $col: $r $g $b / $c"}
		incr n
		if {$n >= 25} break
	    }
	    if {$n >= 25} break
	}
	list $n $faux
    }]
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    F "Overview" AfficheOverview 120000
    set Id [Q {lindex $::Ovw(Liste) end}]
    set w .overview$Id
    V "fenêtre" {[Q "winfo exists $w"]}
    V "liste : features de l'instance" {[lsort [lrange [Q "$w.btn.combo cget -values"] 2 end]] eq [lsort [Q {set ::ListeTypesDeFeatures}]] || [lsort [Q "$w.btn.combo cget -values"]] ne ""} [Q "$w.btn.combo cget -values"]
    foreach ft {PFAM-A STRUCT} {
	Q "set ::Ovw(O$Id,Feat) $ft"
	F "feature $ft" "MetAJourDessinOverview $Id $w.btn.combo" 120000
	V "$ft : image dessinée" {[Q "info exists ::Ovw(O$Id,$ft)"]}
	lassign [Pixels $Id $ft] n faux
	V "$ft : couleur des éléments ($n vérifiés)" {$n > 0 && $faux eq ""} [lrange $faux 0 3]
    }
    # taille
    set w0 [Q "$w.c cget -width"]
    F "+" "ChangeEchelleOverview $Id plus" 120000
    V "+ : plus grand" {[Q "$w.c cget -width"] > $w0} [Q "$w.c cget -width"]
    lassign [Pixels $Id STRUCT] n faux
    V "+ : feature toujours juste" {$faux eq ""} [lrange $faux 0 2]
    F "-" "ChangeEchelleOverview $Id moins" 120000
    V "- : taille revenue" {abs([Q "$w.c cget -width"] - $w0) <= 2} [Q "$w.c cget -width"]
    # région
    Q "set ::Ovw(O$Id,ShowRegion) 0"
    F "Hide region" "ShowHideOverviewRegion $Id"
    V "région cachée" {[Q "$w.c itemcget \$::Ovw(O$Id,TagRegion) -state"] eq "hidden"}
    Q "set ::Ovw(O$Id,ShowRegion) 1"
    F "Show region" "ShowHideOverviewRegion $Id"
    V "région montrée" {[Q "$w.c itemcget \$::Ovw(O$Id,TagRegion) -state"] eq "normal"}
    # clic : l'alignement se centre
    set x0 [Q {lindex [$::NomTextSeq xview] 0}]
    F "clic sur l'overview" "CentreOverview $Id [expr {int($w0*0.8)}] 50" 30000
    V "clic : alignement déplacé" {[Q {lindex [$::NomTextSeq xview] 0}] > $x0} [Q {$::NomTextSeq xview}]
    # annotations
    Q "set ::Ovw(O$Id,ShowAnno) 1"
    F "Annotations" "DessineAnnotationsSurOverview $Id"
    # print
    Q [list probe::answer tk_getSaveFile $Tmp/ov.png]
    F "Print" "PrintOverview $w.c png" 60000
    V "Print : image écrite" {[file exists $Tmp/ov.png]}
    # gardé dans l'ORD
    F "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/o.ord] 120000
    Stop
    Start $Tmp/o.ord
    set Id [Q {lindex $::Ovw(Liste) end}]
    V "réouverture : overview rouverte" {$Id ne "" && [Q "winfo exists .overview$Id"]}
    V "réouverture : feature STRUCT" {[Q "set ::Ovw(O$Id,Feat)"] eq "STRUCT"} [Q "set ::Ovw(O$Id,Feat)"]
    F "Close" "DetruitOverview $Id"
    V "fermée" {! [Q "winfo exists .overview$Id"]}
    Inv "après Overview"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
