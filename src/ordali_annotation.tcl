

#
# --- ordali_annotation.tcl
#
# Annotations ("memo tags") of a snapshot.
#
# Anno(Lanno) : list of annotations {pk text color zone status}
#   - zone   : list of "y.x1 y.x2" (display lines, x2 included, as
#              biotext tags). In the db, the zone is stored as a
#              list of {sequence-name x1 x2} : it does not depend
#              on the order of the sequences in the snapshot.
#   - status : -1 deleted, 0 as in AnnoMac, 1 edited, 2 new
#
# AnnoMac : annotations of the current snapshot, in memory, as
#   {pk text color zone} with the zone as in the db. Like the
#   features (TabSF), they are read from the db by CreeVue
#   (ChargeAnnotationsDuMac), changed by the annotation mode
#   (Return : ManageAnnotation save, VueEditee 1) and written in
#   the db only with the snapshot (EnregistreLeMac : Overwrite,
#   New Instance, change of instance, file save). Reset or "Leave
#   without saving" read the db again : the changes are dropped.
#   Anno is only the working state of the annotation mode.
# Each annotation is displayed with the tag Anno_<pk>.
# AnnoTxt(<pk>) : text of the displayed annotations (balloon).
#


proc CouleurTexteAnnotation {col} {
    # black or white text, according to the background color
    if {[catch {winfo rgb . $col} rgb]} {
	return black
    }
    lassign $rgb r g b
    if {(0.299*$r + 0.587*$g + 0.114*$b)/65535. < 0.5} {
	return white
    }

    return black
}


proc ZoneAnnotationVersNoms {zon} {
    # display lines -> {name x1 x2} (db)
    set Lz {}
    foreach {p1 p2} $zon {
	lassign [split $p1 .] y x1
	lassign [split $p2 .] y x2
	set nom [string trim [lindex $::LNOrdali $y-1]]
	if {$nom ne ""} {
	    lappend Lz [list $nom $x1 $x2]
	}
    }

    return $Lz
}


proc ZoneAnnotationVersLignes {zdb} {
    # {name x1 x2} (db) -> display lines. Zones written by older
    # versions ("y.x1 y.x2" ...) are kept as they are.
    if {[regexp {^[0-9]+\.[0-9]+$} [lindex $zdb 0]]} {
	return $zdb
    }
    set Lz {}
    foreach e $zdb {
	lassign $e nom x1 x2
	set i [lsearch -exact $::LNOrdali $nom]
	if {$i != -1} {
	    incr i
	    lappend Lz $i.$x1 $i.$x2
	}
    }

    return $Lz
}


proc ChargeAnnotationsDuMac {} {
    # annotations of the current snapshot : db -> AnnoMac
    global AnnoMac db

    set pkmac [MacCourant index]
    set AnnoMac {}
    $db eval {select pk_annotation, annotation, color, zone from annotation where pk_snap = $pkmac order by pk_annotation} {
	lappend AnnoMac [list $pk_annotation $annotation $color $zone]
    }

    return
}


proc ManageAnnotation {what {pkann ""} {txt ""} {col ""} {zon ""}} {
    # Annotations of the CURRENT snapshot (AnnoMac, in memory)
    global Anno AnnoMac

    if {! [info exists AnnoMac]} {
	set AnnoMac {}
    }
    set ret {}
    switch $what {
	"getall" {
	    set Anno(Lanno) {}
	    foreach ann $AnnoMac {
		lassign $ann pk txt col zone
		lappend Anno(Lanno) [list $pk $txt $col [ZoneAnnotationVersLignes $zone] 0]
	    }
	}
	"get" {
	    set i [lsearch -exact -index 0 $AnnoMac $pkann]
	    if {$i != -1} {
		set ret [lindex $AnnoMac $i]
		lappend ret 0
	    }
	}
	"record" {
	    # new annotation, put in AnnoMac by 'save'
	    lappend Anno(Lanno) [list $Anno(iAnno) $txt $col $zon 2]
	    set ret $Anno(iAnno)
	    incr Anno(iAnno)
	}
	"save" {
	    # changes of the annotation mode -> AnnoMac. The db is
	    # written with the snapshot (EnregistreLeMac)
	    if {! [info exists Anno(Lanno)]} {
		return
	    }
	    set Lnew {}
	    set Lmac {}
	    set Change 0
	    foreach ann $Anno(Lanno) {
		lassign $ann pk txt col zon status
		if {$status != 0} {
		    set Change 1
		}
		if {$status == -1} {
		    continue
		}
		lappend Lmac [list $pk $txt $col [ZoneAnnotationVersNoms $zon]]
		lappend Lnew [list $pk $txt $col $zon 0]
	    }
	    set AnnoMac $Lmac
	    if {$Change} {
		# the snapshot has to be saved
		VueEditee 1
	    }
	    set Anno(Lanno) $Lnew
	}
    }

    return $ret
}


proc LoadSnapAnnotations {} {
    # annotations of the current snapshot -> Anno
    global Anno AnnoMac db

    ManageAnnotation "getall"
    set Lcol {}
    foreach ann $Anno(Lanno) {
	lappend Lcol [lindex $ann 2]
    }
    set Anno(LColorsUsed) [linsert [lsort -unique $Lcol] 0 "None" "All"]

    # pk of new annotations : unique in the whole table, and among
    # the annotations not written in the db yet
    set imax [$db eval {select max(pk_annotation) from annotation}]
    if {! [string is integer -strict $imax]} {
	set imax 0
    }
    foreach ann $AnnoMac {
	set pk [lindex $ann 0]
	if {[string is integer -strict $pk] && $pk > $imax} {
	    set imax $pk
	}
    }
    set Anno(iAnno) [expr {$imax + 1}]

    return
}


proc EffaceAnnotations {} {
    # remove the annotations from the display
    global NomTextSeq AnnoTxt

    set state [$NomTextSeq cget -state]
    $NomTextSeq configure -state normal
    foreach t [lsearch -all -inline -glob [$NomTextSeq tag names] "Anno_*"] {
	$NomTextSeq tag delete $t
    }
    $NomTextSeq configure -state $state
    unset -nocomplain AnnoTxt

    return
}


proc DessineAnnotations {{Lcol "All"}} {
    # display the annotations of Anno(Lanno) having one of the
    # colors of Lcol ("All" : every annotation)
    global NomTextSeq Anno AnnoTxt

    EffaceAnnotations
    if {! [info exists Anno(Lanno)] || $Lcol eq "None"} {
	return
    }

    set state [$NomTextSeq cget -state]
    $NomTextSeq configure -state normal
    set nl [llength $::LNOrdali]
    foreach ann $Anno(Lanno) {
	lassign $ann pk txt col zon status
	if {$status == -1 || ($Lcol ne "All" && $col ni $Lcol)} {
	    continue
	}
	# zones out of the alignment (sequences removed ...)
	set Lz {}
	foreach {p1 p2} $zon {
	    if {[lindex [split $p1 .] 0] <= $nl} {
		lappend Lz $p1 $p2
	    }
	}
	if {$Lz eq {}} {
	    continue
	}
	set tag "Anno_$pk"
	$NomTextSeq tag configure $tag -foreground [CouleurTexteAnnotation $col] -background $col
	$NomTextSeq tag add $tag {*}$Lz
	$NomTextSeq tag raise $tag
	set AnnoTxt($pk) $txt
    }
    $NomTextSeq configure -state $state

    return
}


proc ShowAnnotation {{what ""}} {
    # Annotation mode : show all annotations, none, or the ones
    # of a given color
    global Anno

    if {$what eq ""} {
	set what $Anno(ShowColor)
    } else {
	set Anno(ShowColor) $what
    }
    DessineAnnotations $what

    return
}


proc AnnotationSousLePointeur {y x} {
    # pk of the annotation displayed at y.x (the last one drawn,
    # on top), or ""
    global Anno

    set res ""
    if {! [info exists Anno(Lanno)]} {
	return ""
    }
    foreach ann $Anno(Lanno) {
	lassign $ann pk txt col zon status
	if {$status == -1} {
	    continue
	}
	foreach {p1 p2} $zon {
	    lassign [split $p1 .] y1 x1
	    lassign [split $p2 .] y2 x2
	    if {$y == $y1 && $x >= $x1 && $x <= $x2} {
		set res $pk
	    }
	}
    }

    return $res
}


proc PositionAnnotation {w xp yp {quoi ""}} {
    # bindings of the annotation mode (bindtag BAnno)
    global Anno NomTextSeq LNOrdali

    lassign [split [$w index @$xp,$yp] .] y x

    switch $quoi {
	"start" {
	    # a new zone : the window of the previous one is closed
	    AddAnnotation cancel
	    set Anno(xdebut) $x
	    set Anno(ydebut) $y
	}
	"move" {
	    if {! [info exists Anno(xdebut)]} {
		return
	    }
	    set xd $Anno(xdebut)
	    set yd $Anno(ydebut)
	    if {$x < $xd} {
		lassign [list $x $xd] xd x
	    }
	    if {$y < $yd} {
		lassign [list $y $yd] yd y
	    }
	    # the separators are not part of the zone
	    set Ltag {}
	    for {set i $yd} {$i <= $y} {incr i} {
		if {[string trim [lindex $LNOrdali $i-1]] ne ""} {
		    lappend Ltag $i.$xd $i.$x
		}
	    }
	    $NomTextSeq configure -state normal
	    catch {$NomTextSeq tag remove selZoneAnno}
	    if {$Ltag != {}} {
		$NomTextSeq tag add selZoneAnno {*}$Ltag
		$NomTextSeq tag raise selZoneAnno
	    }
	    $NomTextSeq configure -state disabled
	}
	"endsel" {
	    if {! [info exists Anno(xdebut)]} {
		return
	    }
	    unset -nocomplain Anno(xdebut) Anno(ydebut)
	    if {[$NomTextSeq tag ranges selZoneAnno] ne ""} {
		CreateNewAnnotationWindow $xp $yp
	    }
	}
	"delete" {
	    set pk [AnnotationSousLePointeur $y $x]
	    if {$pk eq ""} {
		return
	    }
	    set i [lsearch -exact -index 0 $Anno(Lanno) $pk]
	    if {[lindex $Anno(Lanno) $i 4] == 2} {
		# not in the db yet
		set Anno(Lanno) [lreplace $Anno(Lanno) $i $i]
	    } else {
		lset Anno(Lanno) $i 4 -1
	    }
	    ShowAnnotation
	}
	"edit" {
	    set pk [AnnotationSousLePointeur $y $x]
	    if {$pk eq ""} {
		return
	    }
	    AddAnnotation cancel
	    CreateNewAnnotationWindow $xp $yp $pk
	}
    }

    return
}


proc CreateNewAnnotationWindow {xp yp {pk ""}} {
    # Window to define the color and the text of an annotation :
    # a new one (zone selZoneAnno), or annotation pk to be edited
    global Anno NomTextSeq

    if {[winfo exists .frAnno]} {
	raise .frAnno
	return
    }

    set txt ""
    if {$pk eq ""} {
	if {[$NomTextSeq tag ranges selZoneAnno] eq ""} {
	    return
	}
	if {$Anno(ShowColor) ni {None All}} {
	    set Anno(Color) $Anno(ShowColor)
	} elseif {! [info exists Anno(Color)] || $Anno(Color) eq ""} {
	    set Anno(Color) [lindex $::Couleurs(Stock) 0]
	}
    } else {
	set i [lsearch -exact -index 0 $Anno(Lanno) $pk]
	lassign [lindex $Anno(Lanno) $i] pk txt Anno(Color)
    }
    set Anno(PkEdit) $pk

    frame .frAnno -relief raised -bd 2
    grid columnconfig .frAnno 0 -weight 1

    set w .frAnno.f
    frame $w
    grid columnconfig $w 0 -weight 1
    label $w.titre \
	-text [expr {$pk eq "" ? "New annotation" : "Edit annotation"}] \
	-font TitleFont \
	-anchor w -justify left
    frame $w.fcol
    grid columnconfig $w.fcol 1 -weight 1
    label $w.fcol.labcol \
	-text "Color : " \
	-justify left
    set Lcol $::Couleurs(Stock)
    if {$Anno(Color) ni $Lcol} {
	lappend Lcol $Anno(Color)
    }
    ttk::combobox $w.fcol.cbbcol \
	-state readonly \
	-width [PlusLongEltDe $Lcol] \
	-values $Lcol \
	-textvariable ::Anno(Color)
    grid $w.fcol.labcol -row 0 -column 0 -sticky w
    grid $w.fcol.cbbcol -row 0 -column 1 -sticky ew

    text $w.txt \
	-bg white -fg blue \
	-width 30 \
	-height 5 \
	-wrap word
    $w.txt insert end $txt
    set Anno(WText) $w.txt
    frame $w.fbut
    button $w.fbut.butcan \
	-text " Cancel " \
	-bg red -fg white \
	-command [list AddAnnotation cancel]
    button $w.fbut.butok \
	-text " OK " \
	-bg green1 \
	-default active \
	-command [list AddAnnotation ok]
    grid $w.fbut.butcan -row 0 -column 0 -sticky w
    grid $w.fbut.butok  -row 0 -column 1 -sticky e
    grid columnconfig $w.fbut all -weight 1

    grid $w.titre -row 0 -column 0 -sticky ew
    grid $w.fcol  -row 1 -column 0 -sticky ew -pady 5
    grid $w.txt   -row 2 -column 0 -sticky ew
    grid $w.fbut  -row 3 -column 0 -sticky ew -pady {10 5} -padx 10
    grid $w -row 0 -column 0 -sticky news -padx 10 -pady 10

    # Ctrl-Return : OK, Escape : Cancel
    bind $w.txt <Control-Return> "[list $w.fbut.butok invoke] ; break"
    bind $w.txt <Escape> [list $w.fbut.butcan invoke]

    # near the pointer, inside the alignment widget
    update idletasks
    set wf [winfo reqwidth .frAnno]
    set hf [winfo reqheight .frAnno]
    set x [expr {min($xp + 10, [winfo width $NomTextSeq] - $wf)}]
    set y [expr {min($yp + 10, [winfo height $NomTextSeq] - $hf)}]
    place .frAnno -in $NomTextSeq -x [expr {max(0,$x)}] -y [expr {max(0,$y)}]
    raise .frAnno
    focus $w.txt

    return
}


proc AddAnnotation {what} {
    # OK / Cancel of the annotation window
    global NomTextSeq Anno

    if {$what eq "cancel"} {
	destroy .frAnno
	catch {$NomTextSeq tag remove selZoneAnno}
	return
    }
    if {! [winfo exists .frAnno]} {
	return
    }

    set txt [string trim [$Anno(WText) get 1.0 end]]
    set col $Anno(Color)
    set pk  $Anno(PkEdit)
    destroy .frAnno

    if {$pk eq ""} {
	# new annotation on the selected zone
	set zon [$NomTextSeq tag ranges selZoneAnno]
	catch {$NomTextSeq tag remove selZoneAnno}
	if {$zon eq {}} {
	    FaireLire "No annotation zone defined !"
	    return
	}
	ManageAnnotation "record" "" $txt $col $zon
    } else {
	set i [lsearch -exact -index 0 $Anno(Lanno) $pk]
	lset Anno(Lanno) $i 1 $txt
	lset Anno(Lanno) $i 2 $col
	if {[lindex $Anno(Lanno) $i 4] == 0} {
	    lset Anno(Lanno) $i 4 1
	}
    }

    # colors of the combobox of the control panel
    if {$col ni $Anno(LColorsUsed)} {
	lappend Anno(LColorsUsed) $col
	if {[info exists Anno(WComboCol)] && [winfo exists $Anno(WComboCol)]} {
	    $Anno(WComboCol) configure -values $Anno(LColorsUsed)
	}
    }
    ShowAnnotation

    return
}


proc QuitAnnotation {what} {
    # leave the annotation mode : 'ok' saves the changes,
    # 'dismiss' forgets them
    global Anno NomTextSeq

    AddAnnotation cancel
    if {$what eq "ok"} {
	ManageAnnotation save
	# and on the overviews of the instance
	RafraichitAnnotationsOverviews
    }
    catch {$NomTextSeq tag delete selZoneAnno}
    unset -nocomplain Anno

    BindModeNormal
    DetruitBoutonsOrdali

    # annotations are displayed again if the snapshot bar button
    # is on
    EffaceAnnotations
    if {[EtatBouton $::WOrdali(BoutAnno)]} {
	LoadSnapAnnotations
	DessineAnnotations All
	unset -nocomplain Anno
    }

    ChangeMode $::CurrentMode

    return
}


proc AfficheSnapshotAnnotations {} {
    # 'Annotations' button of the snapshot bar : show / hide the
    # annotations of the current snapshot
    global NomTextSeq Anno WOrdali

    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {[InSeqlabMode]} {
	FaireLire "Not available in Editor mode yet !"
	return
    }
    if {[QuelMode] eq "annotation"} {
	# the annotation tool manages the display itself
	return
    }

    set bt $WOrdali(BoutAnno)
    if {! [EtatBouton $bt]} {
	# button is raised : show
	LoadSnapAnnotations
	DessineAnnotations All
	unset -nocomplain Anno
	$bt configure -relief sunken -background red -foreground white
    } else {
	# button is sunken : hide
	EffaceAnnotations
	$bt configure -relief raised -background cyan -foreground black
    }
    update idletasks

    return
}


proc RafraichitAnnotations {} {
    # after a change of snapshot / redisplay : annotations of the
    # current snapshot, if the snapshot bar button is on
    global Anno

    if {! [ModeI] || ! [info exists ::WOrdali(BoutAnno)] || ! [winfo exists $::WOrdali(BoutAnno)]} {
	return
    }
    if {[QuelMode] eq "annotation"} {
	return
    }
    EffaceAnnotations
    if {[EtatBouton $::WOrdali(BoutAnno)]} {
	LoadSnapAnnotations
	DessineAnnotations All
	unset -nocomplain Anno
    }

    return
}


proc Annotations2Features {} {
    # annotations of the current snapshot -> feature SnapAnnotation
    # (Macsim/XML output)
    global ListeTypesDeFeatures TabSF Anno LNOrdali LNSeqlab

    # validated annotations of the snapshot (AnnoMac) : in the
    # annotation mode, its working state Anno is kept
    if {[info exists Anno]} {
	set SauveAnno [array get Anno]
    }
    ManageAnnotation "getall"
    set Lanno $Anno(Lanno)
    unset -nocomplain Anno
    if {[info exists SauveAnno]} {
	array set Anno $SauveAnno
    }

    if {[llength $Lanno] == 0} {
	return
    }

    if {[QuelMode] eq "seqlab"} {
	set LNoms $LNSeqlab
    } else {
	set LNoms $LNOrdali
    }

    # Create annotations as feature
    if {"SnapAnnotation" ni $ListeTypesDeFeatures} {
	lappend ListeTypesDeFeatures SnapAnnotation
    }
    foreach ann $Lanno {
	lassign $ann pkann txt col zon status
	foreach {d f} $zon {
	    lassign [split $d .] yseq xd
	    lassign [split $f .] yseq xf
	    set seq [lindex $LNoms $yseq-1]
	    if {[string trim $seq] eq ""} {
		continue
	    }
	    set score "$pkann.0"
	    lappend TabSF($seq,SnapAnnotation) [list "fstart" $xd fstop $xf fcolor $col fscore $score fnote "$txt" fcsys "global" ftarget "seq"]
	}
    }

    return
}


proc RemoveAnnotationFeatures {} {
    global TabSF ListeTypesDeFeatures

    array unset TabSF *,SnapAnnotation
    set i [lsearch $ListeTypesDeFeatures "SnapAnnotation"]
    if {$i != -1} {
	set ListeTypesDeFeatures [lreplace $ListeTypesDeFeatures $i $i]
    }

    return
}


proc Features2Annotations {aTab} {
    # feature SnapAnnotation (Macsim/XML input) -> annotations of
    # the current snapshot, written in the db.
    # Called while the file is read : positions start at 1, and
    # spaces of the notes are replaced by '_'
    global LNOrdali db

    array set TabA $aTab

    set Lann [array names TabA "*,SnapAnnotation"]
    if {[llength $Lann] == 0} {
	return
    }

    set Lpk {}
    foreach key $Lann {
	set seq [string range $key 0 [string last , $key]-1]
	foreach ft $TabA($key) {
	    DecortiqueUneFeature $ft dg fg col score note
	    set pk [expr {int($score)}]
	    lappend Lpk $pk
	    set TAnn($pk,col) $col
	    set TAnn($pk,txt) [string map {_ " "} $note]
	    lappend TAnn($pk,zon) [list $seq [expr {$dg-1}] [expr {$fg-1}]]
	}
    }

    set pkmac [MacCourant index]
    foreach pk [lsort -unique -integer $Lpk] {
	set txt $TAnn($pk,txt)
	set col $TAnn($pk,col)
	set zon $TAnn($pk,zon)
	$db eval {insert into annotation values(NULL, $pkmac, $txt, $col, $zon)}
    }

    return
}


proc FindTagPatch {tag x y} {
global NomTextSeq

set Lranges [$NomTextSeq tag ranges $tag]
set LgoodX [list]
foreach {p1 p2} $Lranges {
lassign [split $p1 .] y1 x1
lassign [split $p2 .] y2 x2
if {$x >= $x1 && $x < $x2} {
lappend LgoodX $y1
lappend Lx1 $x1
lappend Lx2 $x2
}
}
set LggodX [lsort -integer $LgoodX]
set jprev [lindex $LgoodX 0]
set jstart $jprev ; set jfin -1
if {$jprev == $y} {
set jy 1
} else {
set jy 0
}
foreach j [lrange $LgoodX 1 end] {
if {$j == $y} {set jy 1}
if {$j != ($jprev + 1)} {
if {$jy} {
set jfin $jprev
break
} else {
set jstart $j
}
}
set jprev $j
}
if {$jfin == -1} {
set jfin $jprev
}

# cree liste du patch
set x1 [lsort -unique -integer $Lx1]
set x2 [lsort -unique -integer $Lx2]
set Lres [list]
for {set y $jstart} {$y <= $jfin} {incr y} {
lappend Lres $y.$x1 $y.$x2
}

return $Lres
}


proc topo {} {
DecortiqueUnTFA /home/moumou/topo.tfa Ln Seq
foreach k [array names Seq] {
set s [set Seq($k)]
lappend Lg [string length $s]
set s [string map {- "" "\." ""} $s]
if {[string length $s] == 0} {
puts "vide $k"
}
if {[regexp {[^a-zA-Z0-9]} $s]} {
regsub -all {[a-zA-Z0-9]} $s "" s
puts "s= $s"
}
regsub -all {[a-zA-Z0-9]} $s "" s
if {$s ne ""} {puts "s= >$s<"}
}
puts "[DenombreLaListe $Lg]"
exit
}



