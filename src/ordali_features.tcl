

#
# --- ordali_feature.tcl
#


# Selected zones are stored as "y.x1 y.x2" with x2 EXCLUDED
# (LItemSel, ZonesSel, LRanges ...), but the biotext widget
# includes the last column of a tag : convert when tagging and
# when reading the 'slct' tag.
proc SlctAjoute {Lzones} {
    global NomTextSeq

    set Lt {}
    foreach {p1 p2} $Lzones {
	lassign [split $p1 .] y x1
	lassign [split $p2 .] y x2
	lappend Lt $y.$x1 $y.[expr {$x2-1}]
    }
    if {$Lt != {}} {
	$NomTextSeq tag add slct {*}$Lt
	$NomTextSeq tag raise slct
    }

    return
}


proc SlctZones {} {
    global NomTextSeq

    set Lz {}
    if {[catch {set Lt [$NomTextSeq tag ranges slct]}]} {
	return {}
    }
    foreach {p1 p2} $Lt {
	lassign [split $p2 .] y x2
	lappend Lz $p1 $y.[expr {$x2+1}]
    }

    return $Lz
}


proc SlctEfface {} {
    # biotext : 'tag remove <tag>' without index removes all
    catch {$::NomTextSeq tag remove slct}

    return
}


proc RetourEditFeatures {what} {
    global TabSF TSFori LTFori ListeTypesDeFeatures EFeat CurrentMode

    if {$what ne "save"} {
	# Cancel : restore features as they were
	unset -nocomplain TabSF
	array set TabSF [array get TSFori]
	set ListeTypesDeFeatures $LTFori
    }

    # 'array get' order is not reliable : sort by key
    if {[lsort -stride 2 -index 0 [array get TabSF]] ne [lsort -stride 2 -index 0 [array get TSFori]]} {
	VueEditee 1
    }

    # Verify for empty features
    set i 0
    set Li {}
    foreach f $ListeTypesDeFeatures {
	if {! [llength [array names TabSF "*,$f"]]} {
	    lappend Li $i
	}
	incr i
    }
    if {[llength $Li]} {
	set Li [lsort -integer -decreasing $Li]
	foreach i $Li {
	    # a conservation feature without items : its scores go too,
	    # otherwise CreeVue creates it again when the file is opened
	    set f [lindex $ListeTypesDeFeatures $i]
	    if {[string match "Cons-*" $f]} {
		array unset ::ScoreMeth "$f,*"
	    }
	    set ListeTypesDeFeatures [lreplace $ListeTypesDeFeatures $i $i]
	}
    }
    # conservation features deleted with "Delete Feature"
    foreach f $LTFori {
	if {[string match "Cons-*" $f] && $f ni $ListeTypesDeFeatures} {
	    array unset ::ScoreMeth "$f,*"
	}
    }

    # the feature summary uses EFeat too
    if {[info exists EFeat(SumWindow)] && [winfo exists $EFeat(SumWindow)]} {
	RetourFeatSummary
    }
    SlctEfface
    unset -nocomplain EFeat TSFori LTFori
    # the context menu of the editor is bound to the sequences
    # widget itself : BindModeNormal does not remove it
    bind $::NomTextSeq <Button-3> {}
    
    # clear display
    AppliqueFeature "Clear"

    # back to normal
    BindModeNormal
    DetruitBoutonsOrdali

    if {$ListeTypesDeFeatures != {} && $CurrentMode eq "ordali"} {
	set CurrentMode "feature"
    }
    ChangeMode $CurrentMode

    return
}


proc ShowContextMenuFeat {} {
    # Features Editor only
    if {! [info exists ::EFeat(ContextMenu)]} {
	return
    }
    CreateContextMenuFeature
    set m [set ::EFeat(ContextMenu)]

    set w [winfo parent $m]
    lassign [winfo pointerxy $w] x y
    tk_popup $m $x $y

    return
}


proc CreateContextMenuFeature {} {
    global EFeat

    set m [set EFeat(ContextMenu)]
    # destroy any pre-exising menu with the same name
    destroy $m

    # create new menus
    menu $m -tearoff 0
    if {$EFeat(LItemSel) == {} && [info exists EFeat(ZonesSel)] && $EFeat(ZonesSel) != {}} {
	# a region is selected : it can become a new item
	$m add command -label "Define New ..." -command {CmdsMenuFeatures "define"}
	$m add separator
	$m add command -label "Clear selection ..." -command {CmdsMenuFeatures "clearsel"}
    } elseif {$EFeat(LItemSel) == {} } {
	$m add command -label "Select Item ..." -command {CmdsMenuFeatures "selitem"}
	$m add command -label "Select All Items ..." -command {CmdsMenuFeatures "selitall"}
	$m add command -label "Select region ..." -command {CmdsMenuFeatures "selreg"}
	$m add separator
	$m add command -label "Clear selection ..." -command {CmdsMenuFeatures "clearsel"}
    } else {
	$m add command -label "Edit Item ..." -command {CmdsMenuFeatures "edit"}
	$m add command -label "Define New ..." -command {CmdsMenuFeatures "define"}
	$m add command -label "Delete selected Items ..." -command {CmdsMenuFeatures "delete"}
	$m add command -label "Propagate Item to this group" -command {CmdsMenuFeatures "propagitem"}
	$m add command -label "Propagate Item to all" -command {CmdsMenuFeatures "propagall"}
	$m add separator
	$m add command -label "Clear selection ..." -command {CmdsMenuFeatures "clearsel"}
    }

    return
}


proc SelectSeqRegion {pos what {what2 ""}} {
    global NomTextSeq SDG LNDG LNOrdali LSOrdali EFeat GroupeDeLaSequence

    if {$what eq "stock"} {
	set pos [$NomTextSeq index $pos]
	lassign [split $pos .] y x
	if {[string trim [lindex $LNOrdali $y-1]] eq ""} {return}
	set EFeat(PosInit) $pos
	# zones already selected before this one
	if {! [info exists EFeat(ZonesSel)]} {
	    set EFeat(ZonesSel) {}
	}
	set EFeat(ZonesBase) $EFeat(ZonesSel)

	switch $what2 {
	    "group" {
		set nom [lindex $LNOrdali $y-1]
		set EFeat(gref) [set GroupeDeLaSequence($nom)]
	    }
	    "all" {
		set EFeat(Ly) {}
		set i -1
		foreach n $LNOrdali {
		    incr i
		    if {$n eq ""} {continue}
		    set y [expr {$i+1}]
		    lappend EFeat(Ly) $y
		}
	    }
	}
	if {$what2 eq ""} {set what2 "seq"}
	PoseUneMarque $pos $what2

	return
    }

    if {$EFeat(PosInit) eq ""} {return}

    lassign [split $EFeat(PosInit) .] yi xi
    set pos [$NomTextSeq index $pos]
    lassign [split $pos .] yf xf
    # zone from xi to xf included, whatever the drag direction
    if {$xf < $xi} {
	lassign [list $xf $xi] xi xf
    }
    incr xf

    # previous zones + current one (not every motion step)
    set toTag $EFeat(ZonesBase)
    switch $what {
	"motion" {
	    SlctEfface
	    catch {$NomTextSeq tag remove Marque}
	    switch $what2 {
		"seq" {
		    lappend toTag $yi.$xi $yi.$xf
		}
		"group" {
		    if {$EFeat(gref) eq ""} {return}
		    foreach s [set SDG($EFeat(gref))] {
			set y [expr {[lsearch $LNOrdali $s]+1}]
			lappend toTag $y.$xi $y.$xf
		    }
		}
		"all" {
		    foreach y $EFeat(Ly) {
			lappend toTag $y.$xi $y.$xf
		    }
		}
	    }
	    SlctAjoute $toTag
	    set EFeat(ZonesSel) $toTag
	}
	"seq" {
	    set EFeat(PosInit) ""
	}
	"group" {
	    set EFeat(gref) ""
	    set EFeat(PosInit) ""
	}
	"all" {
	    set EFeat(Ly) {}
	    set EFeat(PosInit) ""
	}
    }

    return
}


proc ChangeFeatureForEditing {{w ""}} {
    global NomTextSeq EFeat NomNomSeq

    if {$w eq ""} {
	set w $EFeat(FeatCombo)
    }
    set feat [$w get]

    # keep selection
    set Lslct [$NomTextSeq tag ranges slct]
    AppliqueFeature "Clear"
    if {$feat ne "None"} {
	AppliqueFeature $feat
    }

    # comment/uncomment to keep selection
    #set Lslct {}
    $NomTextSeq configure -state normal
    $NomTextSeq tag configure slct -background LightGrey -foreground black
    if {$Lslct != {}} {
	# "Clear" keeps slct : without remove, its ranges double each time
	$NomTextSeq tag remove slct
	$NomTextSeq tag add slct {*}$Lslct
    }
    $NomTextSeq configure -state disabled

    if {[info exists EFeat(Bindings)] && $EFeat(Bindings) != {}} {
	bindtags $NomTextSeq $EFeat(Bindings)
    }

    return
}


proc AcceptNewValues {w type what} {
    global EFeat LNOrdali TabSF ListeTypesDeFeatures NomTextSeq Sequences

    set EFeat(COk) 0
    if {$what eq "dismiss"} {
	destroy [winfo toplevel $w]

	#ChangeFeatureForEditing

	return
    }

    set nc "" ; set nn "" ; set ns ""
    set nx1 "" ; set nx2 ""
    # residue ranges
    if {$type eq "newf"} {
	# residue range corresponds to selection
	set Lt [SlctZones]
	if {$Lt == {}} {
	    FaireLire "Please do a selection first !"

	    return
	}
	set Lpos $Lt
    } else {
	set nx1 "" ; set nx2 ""
	if {$EFeat(ZoneX1) ne "" || $EFeat(ZoneX2) ne ""} {
	    if {! [string is integer -strict $EFeat(ZoneX1)] || ! [string is integer -strict $EFeat(ZoneX2)]} {
		FaireLire "Beware !\nRange should contain integer values"
		return
	    }
	    # columns of the ruler (start at 1)
	    set nx1 [expr {min($EFeat(ZoneX1),$EFeat(ZoneX2)) - 1}]
	    set nx2 [expr {max($EFeat(ZoneX1),$EFeat(ZoneX2)) - 1}]
	    if {$nx1 < 0 || $nx2 >= [LongueurDeLAlignement]} {
		FaireLire "Beware !\nRange should be between 1 and [LongueurDeLAlignement]"
		return
	    }
	}
	# all selected items
	set Lpos {}
	foreach e $EFeat(LItemSel) {
	    lappend Lpos {*}[lindex $e 0]
	}
    }

    # check color
    if {$EFeat(Color) != ""} {
	if {[CouleurPlusProcheDeTkCol $EFeat(Color)] == -1} {
	    FaireLire "Beware !\nThe color specified does not exist !"
	    return
	}
	set nc $EFeat(Color)
    }

    # check score
    if {$EFeat(Score) != ""} {
	if {! [string is double -strict $EFeat(Score)]} {
	    FaireLire "Beware !\n Score should be a real number"
	    return
	}
	# a real number, as read back from the database
	set ns [expr {double($EFeat(Score))}]
    }

    # Note
    if {$EFeat(Note) != ""} {
	set nn [string trim $EFeat(Note)]
    }

    # current feature
    if {$type eq "newf"} {
	set ft $EFeat(Name)
	if {$ft eq ""} {
	    FaireLire "Beware !\nA feature should have a name !"
	    return
	}
	set ft [string map [list " " "_"] $ft]
	if {$ft eq "None"} {
	    FaireLire "Beware !\nPlease give a name to the feature !"
	    return
	}
	if {$nc eq ""} {
	    FaireLire "Beware !\nPlease give a color to the feature !"
	    return
	}
	if {$ns eq ""} {
	    set ns 0.0
	}

	# update combo if necessary
	if {$ft ni $ListeTypesDeFeatures} {
	    lappend ListeTypesDeFeatures $ft
	    set ListeTypesDeFeatures [lsort -unique $ListeTypesDeFeatures]
	    set EFeat(FTypes) [linsert $ListeTypesDeFeatures 0 "None"]
	    $EFeat(FeatCombo) configure -values $EFeat(FTypes)
	    set EFeat(Feat) $ft
	}
    } else {
	set ft $EFeat(Feat)
    }

    foreach {p1 p2} $Lpos {
	lassign [split $p1 .] y x1
	lassign [split $p2 .] y x2
	incr x2 -1
	set nom [lindex $LNOrdali $y-1]

	if {$type eq "newf"} {
	    # New Featue
	    set nx1 $x1 ; set nx2 $x2
	    if {[string index [set Sequences($nom)] $nx1] eq "." || [string index [set Sequences($nom)] $nx2] eq "."} {set cs "global"} {set cs "local"}
	    lappend TabSF(${nom},$ft) [list fstart $nx1 fstop $nx2 fcolor $nc fscore $ns fnote $nn fcsys $cs]
	} else {
	    # Edit Item : values not given keep those of THIS item
	    if {! [info exists TabSF(${nom},$ft)]} {
		continue
	    }
	    set Lf [set TabSF(${nom},$ft)]
	    set i 0
	    set new ""
	    foreach e $Lf {
		DecortiqueUneFeature $e d f c s n cs
		if {$d == $x1 && $f == $x2} {
		    set ix1 [expr {$nx1 eq "" ? $x1 : $nx1}]
		    set ix2 [expr {$nx2 eq "" ? $x2 : $nx2}]
		    set ic  [expr {$nc eq "" ? $c : $nc}]
		    set is  [expr {$ns eq "" ? $s : $ns}]
		    set in  [expr {$nn eq "" ? $n : $nn}]
		    if {$cs eq "local"} {
			if {[string index [set Sequences($nom)] $ix1] eq "." || [string index [set Sequences($nom)] $ix2] eq "."} {set cs "global"} {set cs "local"}
		    }
		    set new [list fstart $ix1 fstop $ix2 fcolor $ic fscore $is fnote $in fcsys $cs]
		    break
		}
		incr i
	    }
	    if {$new eq ""} {
		continue
	    }
	    set Lf [lreplace $Lf $i $i $new]
	    set TabSF($nom,$ft) $Lf
	}
    }
    if {$type eq "edit"} {
	set EFeat(LItemSel) {}
    } else {
    }
    set EFeat(COk) 1

    destroy [winfo toplevel $w]

    SlctEfface

    ChangeFeatureForEditing
    VueEditee 1

    return
}


proc SetFeatValue {w what} {
    global EFeat

    set v $::EFeat(C$what)
    if {$v eq "Select"} {return}
    switch $what {
	"Name" {
	    SetupDefineFeature $w
	    if {$v ni $::EFeat(FTypes)} {
		lappend ::EFeat(FTypes) $v
		$::EFeat(CbName) configure -values $::EFeat(FTypes)
		$::EFeat(FeatCombo) configure -values $::EFeat(FTypes)
	    }
	    set ::EFeat(Name) $v
	}
	"Range" {
	    lassign $v x1 x2
	    set ::EFeat(ZoneX1) $x1
	    set ::EFeat(ZoneX2) $x2
	}
	"Color" {
	    if {$v eq "More Colors"} {
		set v [tk_chooseColor -title "Choose new feature color"]
		if {$v eq ""} {return}
	    }
	    if {$v ni $EFeat(Lcolor)} {
		set EFeat(Lcolor) [linsert $EFeat(Lcolor) end-1 $v]
		$EFeat(CbColor) configure -values $EFeat(Lcolor)
		set EFeat(CColor) $v
	    }
	    set EFeat(Color) $v
	}
	default {
	    set ::EFeat($what) $v
	}
    }

    return
}


proc EditFeatureItem {} {
    global EFeat LNOrdali TabSF

    set EFeat(COk) 0
    if {$EFeat(LItemSel) == {} } {
	FaireLire "Please select features before to edit them !"

	return
    }

    set Lx1x2  {}
    set Lcolor {}
    set Lscore {}
    set Lnote  {}
    foreach e $EFeat(LItemSel) {
	lassign $e zones noteRef ft
	foreach {p1 p2} $zones {
	    lassign [split $p1 .] y x1
	    lassign [split $p2 .] y x2
	    incr x2 -1

	    set nom [lindex $LNOrdali $y-1]
	    foreach e [set TabSF(${nom},$ft)] {
		DecortiqueUneFeature $e d f col score note csys
		lappend Lcolor $col
		lappend Lnote $note
		lappend Lscore $score
		if {$d == $x1 && $f == $x2} {
		    lappend Lx1x2 [list $x1 $x2]
		}
	    }
	}
    }

    # unique ranges (start AND stop)
    set Lx1x2  [lsort -unique $Lx1x2]
    set Lcolor [lsort -unique $Lcolor]
    set Lscore [lsort -unique -real $Lscore]
    set Lnote  [lsort -unique $Lnote]

    set EFeat(Lx1x2)  [linsert $Lx1x2 0 "Select"]
    set EFeat(Lcolor) [linsert $Lcolor 0 "Select"]
    set EFeat(Lnote)  [linsert $Lnote 0 "Select"]
    set EFeat(Lscore) [linsert $Lscore 0 "Select"]

    WindowEditItem edit

    ChangeFeatureForEditing

    return
}


proc WindowSelectItemBy {} {

    set w .itemby
    toplevel $w
    wm title $w "Select Items by ..."
    wm iconname $w "Select"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    label $w.titre \
	-text "Select Items by ..."
    -justify left -anchor w

    frame $w.f
    checkbutton $w.f.lr \
	-text "Range : " \
	-variable EFeat(UseRange) \
	-onvalue 1 -offvalue 0 \
	-justify right -anchor w
    entry $w.f.ex1 \
	-width 6 \
	-bg white -fg black \
	-justify right \
	-textvariable EFeat(ZoneX1)
    entry $w.f.ex2 \
	-width 6 \
	-bg white -fg black \
	-justify right \
	-textvariable EFeat(ZoneX2)
    label $w.f.lo \
	-justify right -anchor w \
	-text "or"
    checkbutton $w.f.ca \
	-text "all alignment" \
	-onvalue 1 \
	-offvalue 0 \
	-textvariable EFeat(AllAli)
    checkbutton $w.f.lco \
	-text "Color : " \
	-variable EFeat(UseColor) \
	-onvalue 1 -offvalue 0 \
	entry $w.f.eco \
	-bg white -fg black \
	-justify right \
	-textvariable EFeat(Color)
    -justify right -anchor w

    frame $w.fb
    button $w.fb.ok \
	-text " OK " \
	-bg green1 \
	-command [list AcceptNewValues $w $type ok]
    button $w.fb.dis \
	-text "Dismiss" \
	-bg red \
	-command [list AcceptNewValues $w $type dismiss]

    grid $w.fb.dis -row 0 -column 0 -sticky w
    grid $w.fb.ok  -row 0 -column 1 -sticky e
    grid columnconfig $w.fb all -weight 1

    return
}


proc WindowEditItem {type} {
    global EFeat

    # empty fields : values of the previous edition must not be
    # applied again (empty = unchanged)
    foreach k {Color Score Note ZoneX1 ZoneX2} {
	set EFeat($k) ""
    }
    if {$type eq "newf"} {
	set EFeat(Name) ""
    }

    set w .wedtf
    toplevel $w
    wm title $w "Feature Item Editor"
    wm iconname $w "Feature Editor"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    label $w.titre \
	-text "Item Edition" \
	-justify left -anchor w

    frame $w.f
    set ft $EFeat(Feat)
    if {$type eq "edit"} {
	label $w.f.lnm \
	    -text "Feature Name : " \
	    -justify right -anchor w
	label $w.f.lft \
	    -text " $ft " \
	    -justify left -anchor w
    } else {
	label $w.f.lm \
	    -text "Feature Name : " \
	    -justify right -anchor w
	entry $w.f.em \
	    -bg white -fg black \
	    -textvariable EFeat(Name)
	set wdt [PlusLongEltDe $EFeat(FTypes)]
	set EFeat(CbName) $w.f.cm
	ttk::combobox $w.f.cm \
	    -state readonly \
	    -width $wdt \
	    -background white \
	    -values $EFeat(FTypes) \
	    -textvariable EFeat(CName)
	$w.f.cm current 0
	bind $w.f.cm <<ComboboxSelected>> [list SetFeatValue %W Name]
    }

    # Zone
    label $w.f.lz \
	-text "Residue Range : " \
	-justify right -anchor w
    if {[llength $EFeat(Lx1x2)] > 2} {
	# several ranges : they are not changed
	set EFeat(ZoneX1) ""
	set EFeat(ZoneX2) ""
	label $w.f.lx \
	    -text "multiple zones" \
	    -justify left -anchor w
    } else {
	# columns shown as on the ruler (start at 1)
	lassign [lindex $EFeat(Lx1x2) 1] EFeat(ZoneX1) EFeat(ZoneX2)
	if {$EFeat(ZoneX1) ne ""} {
	    incr EFeat(ZoneX1)
	    incr EFeat(ZoneX2)
	}
	entry $w.f.ex1 \
	    -width 6 \
	    -bg white -fg black \
	    -justify right \
	    -textvariable EFeat(ZoneX1)
	entry $w.f.ex2 \
	    -width 6 \
	    -bg white -fg black \
	    -justify right \
	    -textvariable EFeat(ZoneX2)
	#set wdt [PlusLongEltDe $EFeat(Lx1x2)]
	#ttk::combobox $w.f.cz \
	    -state readonly \
	    -width $wdt \
	    -background white \
	    -values $EFeat(Lx1x2) \
	    -textvariable EFeat(CRange)
	#$w.f.cz current 0
	#bind $w.f.cz <<ComboboxSelected>> [list SetFeatValue %W Range]
    }

    # Color
    label $w.f.lc \
	-text "Item Color : " \
	-justify right -anchor w
    entry $w.f.ec \
	-bg white -fg black \
	-textvariable EFeat(Color)
    set wdt [PlusLongEltDe $EFeat(Lcolor)]
    set EFeat(CbColor) $w.f.cc
    ttk::combobox $w.f.cc \
	-state readonly \
	-width $wdt \
	-background white \
	-values $EFeat(Lcolor) \
	-textvariable EFeat(CColor)
    $w.f.cc current 0
    bind $w.f.cc <<ComboboxSelected>> [list SetFeatValue %W Color]

    # Score
    label $w.f.ls \
	-text "Score : " \
	-justify right -anchor w
    entry $w.f.es \
	-bg white -fg black \
	-justify right \
	-textvariable EFeat(Score)
    set wdt [PlusLongEltDe $EFeat(Lscore)]
    set EFeat(CbScore) $w.f.cs
    ttk::combobox $w.f.cs \
	-state readonly \
	-width $wdt \
	-background white \
	-values $EFeat(Lscore) \
	-textvariable EFeat(CScore)
    $w.f.cs current 0
    bind $w.f.cs <<ComboboxSelected>> [list SetFeatValue %W Score]

    # Note
    label $w.f.ln \
	-text "Note : " \
	-justify right -anchor w
    entry $w.f.en \
	-bg white -fg black \
	-textvariable EFeat(Note)
    set wdt [PlusLongEltDe $EFeat(Lnote)]
    set EFeat(CbNote) $w.f.cn
    ttk::combobox $w.f.cn \
	-state readonly \
	-width $wdt \
	-background white \
	-values $EFeat(Lnote) \
	-textvariable EFeat(CNote)
    $w.f.cn current 0
    bind $w.f.cn <<ComboboxSelected>> [list SetFeatValue %W Note]

    if {$type eq "edit"} {
	grid $w.f.lnm -row 0 -column 0 -sticky e
	grid $w.f.lft -row 0 -column 1 -columnspan 2 -sticky w
    } else {
	grid $w.f.lm -row 0 -column 0 -sticky e
	grid $w.f.em -row 0 -column 1 -sticky w
	grid $w.f.cm -row 0 -column 2 -sticky ew
    }
    grid $w.f.lz    -row 1 -column 0 -sticky e
    if {[llength $EFeat(Lx1x2)] > 2} {
	grid $w.f.lx    -row 1 -column 1 -columnspan 2 -sticky w
    } else {
	grid $w.f.ex1   -row 1 -column 1 -sticky w
	grid $w.f.ex2   -row 1 -column 2 -sticky w
    }
    # color
    grid $w.f.lc    -row 2 -column 0 -sticky e
    grid $w.f.ec    -row 2 -column 1 -sticky e
    grid $w.f.cc    -row 2 -column 2 -sticky ew
    # score
    grid $w.f.ls    -row 3 -column 0 -sticky e
    grid $w.f.es    -row 3 -column 1 -sticky e
    grid $w.f.cs    -row 3 -column 2 -sticky ew
    # note
    grid $w.f.ln    -row 4 -column 0 -sticky e
    grid $w.f.en    -row 4 -column 1 -sticky e
    grid $w.f.cn    -row 4 -column 2 -sticky ew
    grid columnconfig $w.f 2 -weight 1

    frame $w.fb
    button $w.fb.ok \
	-text " OK " \
	-bg green1 \
	-command [list AcceptNewValues $w $type ok]
    button $w.fb.dis \
	-text "Dismiss" \
	-bg red \
	-command [list AcceptNewValues $w $type dismiss]

    grid $w.fb.dis -row 0 -column 0 -sticky w
    grid $w.fb.ok  -row 0 -column 1 -sticky e
    grid columnconfig $w.fb all -weight 1

    grid $w.titre -row 0 -column 0 -sticky ew -padx 10 -pady {10 15}
    grid $w.f     -row 1 -column 0 -sticky news -padx 10
    grid $w.fb    -row 2 -column 0 -sticky news -padx 10 -pady {25 10}
    grid columnconfig $w all -weight 1

    grab $w

    FenetreAuCentre $w
    tkwait window $w

    return
}


proc processSelectItemBy {} {



    return
}


proc SelectItemFeatureForEditing {what pos} {
    global NomTextSeq LNOrdali GroupeDeLaSequence EFeat TabSF SDG

    set ft $EFeat(Feat)
    if {$ft eq "" || $ft eq "None"} {return}

    # reference
    set posi [$NomTextSeq index $pos]
    lassign [split $posi .] y x
    set Lnoms [lmap n $LNOrdali {string trim $n}]
    set nom [lindex $Lnoms $y-1]
    if {$nom eq "" || ! [info exists TabSF($nom,$ft)]} {return}

    # clicked item : the last one (drawn on top) covering column x
    # (biotext has no 'tag prevrange' and 'tag names' ignores
    # the index, so items are searched in TabSF)
    set ref ""
    foreach e $TabSF($nom,$ft) {
	DecortiqueUneFeature $e d f col sco note csys
	if {$x >= $d && $x <= $f} {
	    set ref $e
	}
    }
    if {$ref eq ""} {return}
    DecortiqueUneFeature $ref d f col sco noteRef csys

    switch $what {
	"seq" {
	    set Ln [list $nom]
	}
	"group" {
	    set Ln [set SDG([set GroupeDeLaSequence($nom)])]
	}
	"all" {
	    set Ln [lsearch -all -inline -not -exact $Lnoms ""]
	}
    }

    # same item (same note, covering column x) in the sequences
    set toTag {}
    foreach n $Ln {
	if {! [info exists TabSF($n,$ft)]} {continue}
	set yn [expr {[lsearch -exact $Lnoms $n]+1}]
	foreach e $TabSF($n,$ft) {
	    DecortiqueUneFeature $e d f col sco note csys
	    if {$note eq $noteRef && $x >= $d && $x <= $f} {
		lappend toTag $yn.$d $yn.[expr {$f+1}]
		break
	    }
	}
    }
    if {$toTag == {}} {return}

    # select the regions
    SlctAjoute $toTag
    update idletasks

    set EFeat(LRanges) $toTag
    lappend EFeat(LZonesT) $toTag
    lappend EFeat(LItemSel) [list $toTag $noteRef $ft]

    return
}


proc SelectAllItemFeatureForEditing {what pos} {
    global NomTextSeq LNOrdali GroupeDeLaSequence EFeat SDG TabSF

    set ft [set EFeat(Feat)]
    # reference
    set posi [$NomTextSeq index $pos]
    lassign [split $posi .] y x
    set nom [lindex $LNOrdali $y-1]
    if {$nom eq ""} {return}

    set toTag {}
    switch $what {
	"seq" {
	    set Ln $nom
	}
	"group" {
	    set gref [set GroupeDeLaSequence($nom)]
	    set Ln [set SDG($gref)]
	}
	"all" {
	    set gref GroupeToutLeMonde
	    set Ln [set SDG($gref)]
	}
    }

    # select all items of the feature for the given names
    foreach n $Ln {
	if {! [info exists TabSF($n,$ft)]} {
	    continue
	}

	set y [expr {[lsearch $LNOrdali $n] +1}]
	foreach f [set TabSF($n,$ft)] {
	    DecortiqueUneFeature $f dg fg col sco note csys
	    incr fg
	    lappend toTag $y.$dg $y.$fg
	    lappend EFeat(LItemSel) [list [list $y.$dg $y.$fg] $note $ft]
	}
    }
    if {$toTag == {}} {return}

    # tag the items as selected
    SlctAjoute $toTag
    update idletasks

    set EFeat(LRanges) $toTag
    lappend EFeat(LZonesT) $toTag

    return
}


proc DeleteFeature {what pos} {
    global EFeat TabSF NomTextSeq LNOrdali SDG GroupeDeLaSequence ListeTypesDeFeatures

    if {$EFeat(Feat) eq "None"} {return}

    if {$what ne "all"} {
	set pos [$NomTextSeq index $pos]
	lassign [split $pos .] y x
	set nom [lindex $LNOrdali $y-1]
	if {$nom eq ""} {return}
    }

    set ft [set EFeat(Feat)]

    switch $what {
	"seq" {
	    array unset TabSF "${nom},$ft"
	}
	"group" {
	    set g [set GroupeDeLaSequence($nom)]
	    foreach n [set SDG($g)] {
		array unset TabSF "${n},$ft"
	    }
	}
	"all" {
	    # la feature disparait completement !!
	    array unset TabSF "*,$ft"
	    set i [lsearch $ListeTypesDeFeatures $ft]
	    set ListeTypesDeFeatures [lreplace $ListeTypesDeFeatures $i $i]
	    set EFeat(FTypes) [linsert $ListeTypesDeFeatures 0 "None"]
	    $EFeat(FeatCombo) configure -values $EFeat(FTypes)
	    $EFeat(FeatCombo) current 0
	    set ft ""
	}
    }
    update

    AppliqueFeature "Clear"
    if {$ft ne ""} {
	AppliqueFeature $ft
    }

    return
}


proc DeleteSelected {} {
    global EFeat TabSF NomTextSeq LNOrdali SDG GroupeDeLaSequence

    if {$EFeat(LItemSel) == {} } {
	FaireLire "Please select items before to delete them !"

	return
    }

    foreach e $EFeat(LItemSel) {
	lassign $e zones noteRef ft
	foreach {p1 p2} $zones {
	    lassign [split $p1 .] y x1
	    lassign [split $p2 .] y x2
	    incr x2 -1

	    set nom [string trim [lindex $LNOrdali $y-1]]
	    if {! [info exists TabSF(${nom},$ft)]} {
		continue
	    }
	    set i 0 ; set Li {}
	    foreach e [set TabSF(${nom},$ft)] {
		DecortiqueUneFeature $e d f col score note csys
		if {$x1 == $d && $x2 == $f && $note eq $noteRef} {
		    lappend Li $i
		}
		incr i
	    }

	    if {[set Li [lsort -unique -integer -decreasing $Li]] == {} } {
		# already deleted (item selected twice)
		continue
	    }
	    set Lf [set TabSF(${nom},$ft)]
	    foreach i $Li {
		set Lf [lreplace $Lf $i $i]
	    }
	    set TabSF(${nom},$ft) $Lf
	}
    }

    SlctEfface
    set EFeat(LItemSel) {}

    ChangeFeatureForEditing
    VueEditee 1

    return
}


proc DeleteFeatItem {what pos} {
    global EFeat TabSF NomTextSeq LNOrdali SDG GroupeDeLaSequence

    set pos [$NomTextSeq index $pos]
    lassign [split $pos .] y x
    set nom [lindex $LNOrdali $y-1]
    if {$nom eq ""} {return}

    set ft [set EFeat(Feat)]
    set Ltag [$NomTextSeq tag names $pos]
    if {$Ltag == {}} {return}

    # last tag has highest priority
    set tg [lindex $Ltag end]
    # define what to delete
    set Ly {}
    switch $what {
	"seq" {
	    set Ly $y
	}
	"group" {
	    set g [set GroupeDeLaSequence($nom)]
	    foreach s [set SDG($g)] {
		lappend Ly [expr {[lsearch $LNOrdali $s]+1}]
	    }
	}
	"all" {
	    set i 0
	    foreach s $LNOrdali {
		incr i
		if {$s ne ""} {lappend Ly $i}
	    }
	}
    }

    set Dptrn "FDisp_${EFeat(Feat)}_"
    set Fptrn "FX_${EFeat(Feat)}_"
    array set ToDel {}
    set Lt {}
    foreach y $Ly {
	set nom [lindex $LNOrdali $y-1]

	# do it once. Same tag to delete for all
	# selected sequences
	if {$Lt == {} } {
	    # Take tage at x.
	    # Tags are sorted from lowest
	    # to highest priority
	    set Lt [lreverse [$NomTextSeq tag names $y.$x]]
	    # take the first for "FDisp" and "FX"
	    if {[set tF [lsearch -inline -regexp $Lt $Fptrn]] ne ""} {
		set tagcol [string range $tF [string length "$Fptrn"] end]
	    }
	    if {[set tD [lsearch -inline -regexp $Lt $Dptrn]] ne ""} {
		set tagnot [string range $tD [string length "$Dptrn"] end]
	    }

	    # nothing found, return
	    if {$tD eq "" || $tF eq ""} {return}
	}

	# Determine which item is concerned
	set LixFeat {}
	set ix -1
	foreach e [set TabSF(${nom},$ft)] {
	    incr ix
	    DecortiqueUneFeature $e d f col sco not
	    set notsp [string map [list " " "_"] $not]
	    if {! ($x <= $f && $x >= $d && $col == $tagcol && $notsp == $tagnot)} {continue}

	    # search for tD tag (display)
	    foreach {p1 p2} [$NomTextSeq tag ranges $tD] {
		lassign [split $p1 .] y1 x1
		lassign [split $p2 .] y2 x2
		incr x2 -1
		if {$y1 != $y2 || $x1 != $d || $x2 != $f} {continue}
		lappend LixFeat $ix
	    }
	    # search for tF tag (color)
	    foreach {p1 p2} [$NomTextSeq tag ranges $tD] {
		lassign [split $p1 .] y1 x1
		lassign [split $p2 .] y2 x2
		incr x2 -1
		if {$y1 != $y2 || $x1 != $d || $x2 != $f} {continue}
		lappend LixFeat $ix
	    }
	}

	if {[set LixFeat [lsort -unique -integer -decreasing $LixFeat]] == {} } {
	    FaireLire "Probleme ! je ne trouve pas l item !! bordel fait chier !"
	    return
	}
	set Lf [set TabSF(${nom},$ft)]
	foreach i $LixFeat {
	    set Lf [lreplace $Lf $i $i]
	}
	set TabSF(${nom},$ft) $Lf
    }

    ChangeFeatureForEditing

    return -code break
}


proc ExtendFeatTo {to} {
    global NomTextSeq SDG TabSF EFeat Sequences LNOrdali GroupeDeLaSequence

    if {$EFeat(LItemSel) == {} } {
	FaireLire "No features items selected !"
	return
    }

    if {[llength $EFeat(LItemSel)] > 1} {
	FaireLire "Beware !\nMultiple Items have been selected !\nPlease selected only ONE item to be propagated !"
	return
    }
    lassign [lindex $EFeat(LItemSel) 0] zones noteRef ft
    if {[llength $zones] > 2} {
	FaireLire "Beware !\nMultiple Items have been selected !\nPlease selected only ONE item to be propagated !"
	return
    }

    # search for the true items inside the selected
    set BonFt {}
    lassign $zones p1 p2
    lassign [split $p1 .] y x1
    lassign [split $p2 .] y x2
    incr x2 -1
    set nom [string trim [lindex $LNOrdali $y-1]]
    foreach f [set TabSF($nom,$ft)] {
	DecortiqueUneFeature $f dg fg col sco note csys
	if {$x1 == $dg && $x2 == $fg && $note eq $noteRef} {
	    lappend BonFt [list $nom $f]
	}
    }

    # propagation
    # to = 'group' or 'all'
    foreach e $BonFt {
	lassign $e nomRef feat
	if {$to eq "group"} {
	    set gref [set GroupeDeLaSequence($nomRef)]
	} else {
	    set gref GroupeToutLeMonde
	}
	DecortiqueUneFeature $feat dg fg col sco note csys0
	foreach n [set SDG($gref)] {
	    if {$n eq $nomRef} {
		continue
	    }
	    # a local item on a gap of this sequence becomes global
	    set csys $csys0
	    if {$csys eq "local" && ([string index $Sequences($n) $dg] eq "." || [string index $Sequences($n) $fg] eq ".")} {
		set csys "global"
	    }
	    set new [list fstart $dg fstop $fg fcolor $col fscore $sco fnote $note fcsys $csys]
	    # do not duplicate the item
	    if {[info exists TabSF($n,$ft)] && $new in $TabSF($n,$ft)} {
		continue
	    }
	    lappend TabSF($n,$ft) $new
	}
    }

    SlctEfface
    set EFeat(LItemSel) {}
    ChangeFeatureForEditing
    VueEditee 1

    return
}


proc DrawFeatSum {nom x0 y xd xf {Etiquette 1}} {
    global EFeat TabSF

    set PAD $EFeat(PAD)
    set Lfeat {}

    # features to be drawn
    foreach e [lsort [array names EFeat "LFeat,*"]] {
	# feature names may contain a comma
	set ft [string range $e [string length "LFeat,"] end]
	if {$EFeat($e)} {
	    lappend Lfeat $ft
	}
    }

    # x0 est position a droite du champ nom
    set wl $EFeat(WdtL)

    foreach ft $Lfeat {
	set x $x0
	set yl [expr {$y+$EFeat(HgtL) - 1}]
	if {$Etiquette} {
	    $PAD create text $x $y \
		-justify right \
		-anchor ne \
		-text "$ft" \
		-font FontFeat
	}
	incr x [expr {2 + 2 + $EFeat(WdtCmpt)}]
	if {! [info exists TabSF($nom,$ft)]} {
	    set y [expr {$yl+1}]
	    continue
	}

	foreach e [set TabSF($nom,$ft)] {
	    DecortiqueUneFeature $e d f col sco not
	    if {$f < $xd} {continue}
	    if {$d > $xf} {continue}

	    if {$d < $xd} {
		set xcd $xd
	    } else {
		set xcd $d
	    }
	    if {$f > $xf} {
		set xcf $xf
	    } else {
		set xcf $f
	    }

	    # xcd et xcf sont en CARACTERES unites
	    # xpd et xpf sont en PIXELS unites
	    set xpd [expr {$x + ($xcd-$xd)*$wl}]
	    set xpf [expr {$x + ($xcf-$xd+1)*$wl}]
	    set id [$PAD create rectangle \
			$xpd $y $xpf $yl \
			-fill $col \
			-outline $col]
	    $PAD itemconfig $id \
		-tags [list TNote Note$id Tx@$not TCoord@${ft}@${nom}@${d}@$f]
	}
	set y [expr {$yl+1}]
    }

    return $y
}


proc TracageFeatureSummary {} {
    global EFeat LNOrdali Sequences

    set PAD $EFeat(PAD)
    $PAD delete all

    # Liste seq a tracer
    set Lnoms {} ; set Lseqs {}
    foreach n $LNOrdali {
	if {$n eq "" || ! $EFeat(LMSeq,$n)} {continue}
	lappend Lnoms $n
	lappend Lseqs [set Sequences($n)]
	lappend Lnaff $EFeat(NSeq,$n)
    }

    # nothing to draw
    if {$Lnoms == {} } {return}

    set lgnoms [PlusLongEltDe $Lnaff val]
    set EFeat(WdtNoms) [font measure FontFeat $lgnoms]
    set EFeat(WdtL)    [font measure FontFeat "Z"]
    set EFeat(HgtL)    [lindex [font metrics FontFeat] 5]
    set OffX 10 ; set OffY 10
    # calcule place pour compteur pos
    set EFeat(WdtCmpt) [expr {[string length [LongueurDeLAlignement]] * $EFeat(WdtL)}]
    # calcule place pour le texte de seq
    set nChar [expr {($EFeat(FWidth) - 2*$OffX - $EFeat(WdtNoms) - 2*$EFeat(WdtCmpt) - 3*2)/$EFeat(WdtL)}]
    set WdtSeq [expr {$nChar * $EFeat(WdtL)}]

    set d 0 ; set f [expr {$nChar-1}]
    set slgt [LongueurDeLAlignement]
    set xPos [expr {$OffX + $EFeat(WdtNoms)}]
    set yPos $OffY
    while {$d < $slgt} {
	if {$f >= $slgt} {
	    set f [expr {$slgt-1}]
	}

	# on aligne a droite, on se positionne
	# a la fin du nom
	foreach n $Lnoms s $Lseqs naf $Lnaff {
	    $PAD create text $xPos $yPos \
		-anchor ne -justify right \
		-text "$naf" -font FontFeat
	    # DonnePosGS gives ix strting at 1 !
	    set deb [DonnePosGS $n $d]
	    set fin [DonnePosGS $n $f]
	    incr xPos [expr {2 + $EFeat(WdtCmpt)}]
	    $PAD create text $xPos $yPos \
		-anchor ne -justify right \
		-text "$deb" -font FontFeat
	    incr xPos 2
	    $PAD create text $xPos $yPos \
		-anchor nw -justify left \
		-text "[string range $s $d $f]" \
		-font FontFeat
	    incr xPos $WdtSeq
	    incr xPos 2
	    $PAD create text $xPos $yPos \
		-anchor nw -justify left \
		-text "$fin" -font FontFeat
	    incr yPos $EFeat(HgtL)
	    set xPos [expr {$OffX + $EFeat(WdtNoms)}]
	    set yPos [DrawFeatSum $n $xPos $yPos $d $f]
	}
	incr d $nChar ; incr f $nChar
	incr yPos [expr {$EFeat(HgtL)+1}]
    }

    lassign [$PAD bbox all] xm ym xx yx
    set wd [expr {$xx - $xm + 2*$OffX}]
    set hg [expr {$yx - $ym + 2*$OffY}]
    $PAD configure -scrollregion [list 0 0 $wd $hg]

    ShowFeatNote

    return
}


proc ChangeFontEFeat {s} {
    global EFeat

    if {$s != [font configure FontFeat -size]} {
	font configure FontFeat -size $s
	TracageFeatureSummary
    }

    return
}


proc RetourFeatSummary {} {
    destroy $::EFeat(SumWindow)
    font delete FontFeat

    return
}


proc UpdateListboxSeqFeat {} {
    global EFeat TDesSeqnames TDesAccess TDesBId LNOrdali

    foreach n $LNOrdali {
	if {$n ne ""} {
	    switch $EFeat(NomsAff) {
		"Accession" {set naf [set TDesAccess($n)]}
		"Seq. Name" {set naf [set TDesSeqnames($n)]}
		"Bank Id"  {set naf [set TDesBId($n)]}
	    }
	    set EFeat(NSeq,$n) $naf
	} else {
	    set naf $n
	}
	lappend Lnaff $naf
    }
    set EFeat(ListboxListe) $Lnaff

    TracageFeatureSummary

    return
}


proc PickSeq {Li} {
    global EFeat LNOrdali

    for {set i 0} {$i < [llength $LNOrdali]} {incr i} {
	set n [lindex $LNOrdali $i]
	if {$n eq ""} {continue}
	if {$i ni $Li} {
	    set EFeat(LMSeq,$n) 0
	    $EFeat(Listbox) itemconfigure $i -background white -foreground black
	} else {
	    set EFeat(LMSeq,$n) 1
	    $EFeat(Listbox) itemconfigure $i -background black -foreground white
	}
    }
    TracageFeatureSummary

    return
}


proc ShowFeatNote {} {
    global EFeat

    set PAD $EFeat(PAD)
    set Li [$PAD find withtag TNote]
    if {$EFeat(ShowNote)} {
	foreach i $Li {
	    set note [string range [lsearch -regexp -inline [$PAD gettags $i] {^Tx@}] 3 end]
	    InitBalloonOnItem $PAD $i $note
	}
    } else {
	foreach i $Li {
	    $PAD bind $i <Enter> ""
	    $PAD bind $i <Leave> ""
	}
    }

    return
}


proc CentreAliOnFeat {x y} {
    set PAD [set ::EFeat(PAD)]
    set Lt [$PAD gettags [$PAD find withtag current]]
    set lc [lsearch -inline -regexp $Lt {^TCoord}]
    lassign [split $lc @] tmp type nom d f
    set y [expr {[lsearch $::LNOrdali $nom] + 1}]
    set x [expr {int(1.0*($f-$d)/2)+$d}]

    focus -force [winfo toplevel $::NomTextSeq]
    raise [winfo toplevel $::NomTextSeq]

    $::NomTextSeq  see $y.$x
    $::NomNomSeq   see $y.1
    $::WTexteRegle see  1.$x
    update idletasks

    return -code break
}


proc ChercheNomDansListe {} {
    global EFeat

    set SearchNom [string trim $EFeat(SearchNom)]
    if {$SearchNom eq ""} {return}
    set Ln $EFeat(ListboxListe)
    # search a substring, not a regexp (names contain dots ...)
    set Li {}
    set i 0
    foreach n $Ln {
	if {[string first [string tolower $SearchNom] [string tolower $n]] > -1} {
	    lappend Li $i
	}
	incr i
    }
    if {$Li eq ""} {return}

    # next hit at each <Return>
    if {! [info exists EFeat(SNOld)] || $EFeat(SNOld) ne $SearchNom} {
	set EFeat(IdPosSearch) 0
	set EFeat(SNOld) $SearchNom
    } else {
	incr EFeat(IdPosSearch)
	if {$EFeat(IdPosSearch) >= [llength $Li]} {
	    set EFeat(IdPosSearch) 0
	}
    }

    set ix [lindex $Li $EFeat(IdPosSearch)]
    $EFeat(Listbox) yview $ix
    $EFeat(Listbox) activate $ix

    return
}


proc FeatureSummary {} {
    global EFeat NomSeqSel LNOrdali LSOrdali Defauts ListeTypesDeFeatures TabSF

    if {! [info exists TabSF]} {
	FaireLire "No features in this alignment !"
	return
    }

    set w ".fitsum"
    if {[winfo exists $w]} {
	raise $w
	return
    }

    set EFeat(SumWindow) $w
    toplevel $w
    wm title $w "Features Summary"
    wm iconname $w "Feat. Sum."
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    if {[winfo exists .fattendre]} {lower $w .fattendre}

    # inits
    set EFeat(ShowNote) 0
    set EFeat(FontSize) [set Defauts(FontSizeTree)]
    set EFeat(FontWght) [set Defauts(FontWghtTree)]
    if {"FontFeat" ni [font names]} {
	font create FontFeat -family "Courier" -size $EFeat(FontSize)
    }

    # frame canvas + scrollbars
    frame $w.fc
    set EFeat(PADWdt)  [set Defauts(CanvasWSFeat)]
    set EFeat(PADHgt)  [set Defauts(CanvasHSFeat)]
    set EFeat(FWidth)  [set Defauts(FWidthSFeat)]
    set EFeat(FHeight) [set Defauts(FHeightSFeat)]
    set wc "$w.fc.c"
    set EFeat(PAD) $wc
    set wdt [PlusLongEltDe $LNOrdali]
    set wdt [expr {$wdt < 20 ? $wdt : 20}]
    set EFeat(Listbox) $w.fc.lsb
    set EFeat(ListboxListe) {}
    listbox $w.fc.lsb \
	-listvariable EFeat(ListboxListe) \
	-width $wdt \
	-font SeqFont \
	-selectmode extended \
	-yscrollcommand "$w.fc.vb set"
    bind $w.fc.lsb <<ListboxSelect>> {PickSeq [%W curselection]}
    scrollbar $w.fc.vb \
	-command "$w.fc.lsb yview" \
	-width 8
    entry $w.fc.ent \
	-background white \
	-bd 2 -relief groove \
	-font SeqFont \
	-width $wdt \
	-textvariable EFeat(SearchNom)
    bind $w.fc.ent <Return> [list ChercheNomDansListe]
    canvas $w.fc.c \
	-width  [set EFeat(FWidth)] \
	-height [set EFeat(FHeight)] \
	-scrollregion [list 0 0 [set EFeat(PADWdt)] [set EFeat(PADHgt)]] \
	-cursor hand2 \
	-background white \
	-relief groove \
	-xscrollcommand "$w.fc.hs set" \
	-yscrollcommand "$w.fc.vs set"
    scrollbar $w.fc.vs \
	-command "$wc yview" -width 8
    scrollbar $w.fc.hs \
	-orient horiz \
	-command "$wc xview" -width 8

    grid $w.fc.lsb -row 0 -column 0 -sticky ns
    grid $w.fc.ent -row 1 -column 0 -sticky ew
    grid $w.fc.vb  -row 0 -column 1 -sticky ns -padx {0 5}
    grid $w.fc.c   -row 0 -column 2 -sticky news
    grid $w.fc.vs  -row 0 -column 3 -sticky ns
    grid $w.fc.hs  -row 1 -column 2 -sticky ew
    grid $w.fc -row 0 -column 0 -sticky news -padx 5 -pady {5 1}
    grid rowconfig    $w.fc 0 -weight 1
    grid columnconfig $w.fc {0 2} -weight 1

    # Frame control
    frame $w.fb -bd 2 -relief groove
    # frame noms
    set wn $w.fb.fnm
    frame $wn
    label $wn.shw \
	-text "Show " \
	-anchor w -justify left
    spinbox $wn.nsf \
	-readonlybackground white \
	-state readonly \
	-textvariable EFeat(NomsAff) \
	-width 9 \
	-values {"Seq. Name" Accession "Bank Id"} \
	-command [list UpdateListboxSeqFeat]
    set EFeat(NomsAff) "Seq. Name"
    label $wn.lsz \
	-text "Font size " \
	-anchor w \
	-justify left
    spinbox $wn.ssz \
	-width 3 \
	-readonlybackground white \
	-state normal \
	-textvariable EFeat(FontSize) \
	-values {6 8 10 12 14 16 18 20 22 24} \
	-command [list ChangeFontEFeat %s]
    grid $wn.shw -row 0 -column 0 -sticky w
    grid $wn.nsf -row 0 -column 1 -sticky e -padx {1 5}
    grid $wn.lsz -row 0 -column 2 -sticky e -padx {5 1}
    grid $wn.ssz -row 0 -column 3 -sticky w
    grid $wn -row 0 -column 0 -sticky nw -pady 2 -padx 2
    grid columnconfig $wn {1 3} -weight 1

    # frame features
    set wb $w.fb.fft
    frame $wb
    set wdt [PlusLongEltDe $ListeTypesDeFeatures]
    menubutton $wb.mft \
	-relief raised \
	-width $wdt \
	-text "Features" \
	-menu $wb.mft.feat
    menu $wb.mft.feat -tearoff 0
    # Switch on features used
    foreach f [ListeDesFeaturesUtilisees] {
	set EFeat(LFeat,$f) 1
    }
    foreach f $ListeTypesDeFeatures {
	$wb.mft.feat add checkbutton -label "$f" -variable EFeat(LFeat,$f) -onvalue 1 -offvalue 0 -command [list TracageFeatureSummary]
    }
    grid $wb.mft -column 0 -row 0 -sticky ew
    grid $wb -row 0 -column 1 -sticky new -padx 2 -pady 2
    grid columnconfig $w.fb.fft all -weight 1

    # Control : show note
    set wn $w.fb.fctrl
    frame $wn
    checkbutton $wn.ckn \
	-relief flat \
	-anchor w -justify left \
	-text "Notes as Balloon " \
	-onvalue 1 -offvalue 0 \
	-variable EFeat(ShowNote) \
	-command {ShowFeatNote}
    grid $wn.ckn -row 0 -column 0 -columnspan 2 -sticky ew
    grid $wn -column 2 -row 0 -sticky w -pady 2 -padx 5

    # frame buttons
    set wp $w.fb.fokpt
    frame $wp
    button $wp.bok \
	-background green1 \
	-text " Close " \
	-command [list RetourFeatSummary]
    button $wp.prt \
	-background yellow \
	-text " Print " \
	-command [list PrintCanvas $wc png]
    grid $wp.prt -column 0 -row 0 -sticky ew
    grid $wp.bok -column 1 -row 0 -sticky ew
    grid columnconfig $wp 0 -weight 1
    grid $wp -row 0 -column 3 -sticky nse -pady 2 -padx 2

    grid $w.fb -row 1 -column 0 -sticky ew -padx 5 -pady 5
    grid columnconfig $w.fb 3 -weight 1
    grid columnconfig $w 0 -weight 1
    grid rowconfig    $w 0 -weight 1

    # bindings divers (et d'ete)
    set PAD [set EFeat(PAD)]
    bind $PAD <ButtonPress-1> {%W scan mark %x %y}
    bind $PAD <B1-Motion> {%W scan dragto %x %y 1}
    bind $PAD <4> {eval %W yview scroll -1 units}
    bind $PAD <5> {eval %W yview scroll  1 units}
    bind $PAD <Control-4> {eval %W xview scroll -1 units}
    bind $wc <Control-5> {eval %W xview scroll  1 units}
    $PAD bind TNote <Double-1> {CentreAliOnFeat %x %y}

    # initialize listbox
    # seq. selected in main window are set here too
    set EFeat(ListboxListe) $LNOrdali
    foreach n $LNOrdali {
	if {$n ne ""} {
	    set EFeat(LMSeq,$n) 0
	    set EFeat(NSeq,$n) $n
	}
    }
    foreach e $NomSeqSel {
	lassign [split $e .] y x
	set n [lindex $LNOrdali $y-1]
	if {$n eq ""} {continue}
	set EFeat(LMSeq,$n) 1
	# listbox indices start at 0
	$EFeat(Listbox) itemconfigure [expr {$y-1}] -background black -foreground white
    }

    # names shown in the listbox, then draw
    UpdateListboxSeqFeat

    MesCouleurs $w
    FenetreAuCentre $w

    return $w
}


proc SetupDefineFeature {w} {
    global EFeat LNOrdali TabSF

    set ft [$w get]
    set Lcolor {}
    set Lscore {}
    set Lnote  {}

    foreach nom $LNOrdali {
	if {$nom eq "" || ! [info exists TabSF(${nom},$ft)]} {continue}

	foreach e [set TabSF(${nom},$ft)] {
	    DecortiqueUneFeature $e d f col score note csys
	    lappend Lcolor $col
	    lappend Lnote  $note
	    lappend Lscore $score
	}
    }
    set Lcolor [lsort -unique $Lcolor]
    set Lscore [lsort -unique $Lscore]
    set Lnote  [lsort -unique $Lnote]

    set Lcolor [linsert $Lcolor 0 "Select"]
    set EFeat(Lcolor) [linsert $Lcolor end "More Colors"]
    set EFeat(Lnote)  [linsert $Lnote 0 "Select"]
    set EFeat(Lscore) [linsert $Lscore 0 "Select"]

    $EFeat(CbColor) configure -values $EFeat(Lcolor)
    $EFeat(CbScore) configure -values $EFeat(Lscore)
    $EFeat(CbNote) configure -values $EFeat(Lnote)

    return
}


proc DefineNewFeature {} {
    global EFeat

    set Lp [SlctZones]
    if {$Lp == {} } {
	FaireLire "Beware !\nYou should first select a region !"
	return
    }

    set Lx1x2 "Select"
    foreach {p1 p2} $Lp {
	lassign [split $p1 .] y1 x1
	lassign [split $p2 .] y2 x2
	incr x2 -1

	lappend Lx1x2 [list $x1 $x2]
    }

    set EFeat(Lcolor) "Select"
    set EFeat(Lscore) "Select"
    set EFeat(Lnote)  "Select"
    set EFeat(Lx1x2)  $Lx1x2

    WindowEditItem newf

    return
}


proc CmdsMenuFeatures {what} {
    global EFeat

    set EFeat(Bindings) [bindtags $::NomTextSeq]
    switch $what {
	"selitem" {
	    set EFeat(LItemSel) {}
	    set EFeat(LZonesT)  {}
	    bindtags $::NomTextSeq [list BWhS BEFSelitem $::NomTextSeq all]
	}
	"selitall" {
	    set EFeat(LItemSel) {}
	    set EFeat(LZonesT)  {}
	    bindtags $::NomTextSeq [list BEFSelitall BWhS $::NomTextSeq all]
	}
	"selreg" {
	    set EFeat(ZonesSel) {}
	    bindtags $::NomTextSeq [list BEFSelreg BWhS $::NomTextSeq all]
	}
	"clearsel" {
	    SlctEfface

	    set EFeat(LItemSel) {}
	    set EFeat(Bindings) {}
	    set EFeat(ZonesSel) {}
	    bindtags $::NomTextSeq $::EFeat(BindInit)
	}
	"edit" {
	    EditFeatureItem
	    if {$EFeat(COk)} {
		bindtags $::NomTextSeq $::EFeat(BindInit)
	    }
	}
	"define" {
	    DefineNewFeature
	    bindtags $::NomTextSeq $::EFeat(BindInit)
	    set EFeat(Bindings) {}
	}
	"propagitem" {
	    bindtags $::NomTextSeq $::EFeat(BindInit)
	    ExtendFeatTo group
	}
	"propagall" {
	    bindtags $::NomTextSeq $::EFeat(BindInit)
	    ExtendFeatTo all
	}
	"delete" {
	    DeleteSelected
	    bindtags $::NomTextSeq $::EFeat(BindInit)
	}
	"delfeat" {
	    bindtags $::NomTextSeq [list BEFDelfeat BWhS $::NomTextSeq all]
	}
    }

    return
}


proc BindingsFeatEditor {} {
    global EFeat NomTextSeq

    set EFeat(PosInit) ""

    # Edit feature
    bind BEFEdit <1>         {EditFeatureItem seq @%x,%y ; break}
    bind BEFEdit <Control-1> {EditFeatureItem group @%x,%y ; break}
    bind BEFEdit <Shift-1>   {EditFeatureItem all @%x,%y ; break}

    # Delete ITEM
    #bind BEFDelete <1> {DeleteFeatItem seq @%x,%y ; break}
    #bind BEFDelete <Control-1> {DeleteFeatItem group @%x,%y ; break}
    #bind BEFDelete <Shift-1> {DeleteFeatItem all @%x,%y ; break}

    # Delete FEATURE
    bind BEFDelfeat <1> {DeleteFeature seq @%x,%y ; break}
    bind BEFDelfeat <Control-1> {DeleteFeature group @%x,%y ; break}
    bind BEFDelfeat <Shift-1> {DeleteFeature all @%x,%y ; break}

    # select item
    bind BEFSelitem <1>         {SelectItemFeatureForEditing seq @%x,%y ; break}
    bind BEFSelitem <Control-1> {SelectItemFeatureForEditing group @%x,%y ; break}
    bind BEFSelitem <Shift-1>   {SelectItemFeatureForEditing all @%x,%y ; break}

    # select ALL items
    bind BEFSelitall <1> {SelectAllItemFeatureForEditing seq @%x,%y ; break}
    bind BEFSelitall <Control-1> {SelectAllItemFeatureForEditing group @%x,%y ; break}
    bind BEFSelitall <Shift-1> {SelectAllItemFeatureForEditing all @%x,%y ; break}

    # select region
    bind BEFSelreg <ButtonPress-1> [list SelectSeqRegion @%x,%y stock]
    bind BEFSelreg <B1-Motion> [list SelectSeqRegion @%x,%y motion seq]
    bind BEFSelreg <ButtonRelease-1> [list SelectSeqRegion @%x,%y seq]

    bind BEFSelreg <Control-ButtonPress-1> {SelectSeqRegion @%x,%y stock group ; break}
    bind BEFSelreg <Control-B1-Motion> {SelectSeqRegion @%x,%y motion group ; break}
    bind BEFSelreg <Control-ButtonRelease-1> {SelectSeqRegion @%x,%y group ; break}

    bind BEFSelreg <Shift-ButtonPress-1> {SelectSeqRegion @%x,%y stock all ; break}
    bind BEFSelreg <Shift-B1-Motion> {SelectSeqRegion @%x,%y motion all ; break}
    bind BEFSelreg <Shift-ButtonRelease-1> {SelectSeqRegion @%x,%y all ; break}

    # Propagate
    # an item
    bind BEFPropi <Control-1> {ExtendFeatTo item group @%x,%y ; break}
    bind BEFPropi <Shift-1> {ExtendFeatTo item all @%x,%y ; break}
    # a feature
    bind BEFPropf <Control-1> {ExtendFeatTo all group @%x,%y ; break}
    bind BEFPropf <1> {ExtendFeatTo all all @%x,%y ; break}

    return
}


proc WindowAskFeatureSelection {fileOut} {
    global ListeTypesDeFeatures TTmp

    if {$ListeTypesDeFeatures == {}} {
	return {}
    }

    set w .askfeatures
    if {[winfo exists $w]} {
	raise $w
	return {}
    }

    toplevel $w
    wm title $w "Select Features to Save ..."
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    set wl "$w.flab"
    frame $wl
    grid $wl -row 0 -column 0 -sticky w -padx 5 -pady 5
    
    set txt "Select features to be saved :"
    label $wl.lab \
	-font TitleFont \
	-width 25 \
	-text "$txt" \
	-relief flat \
	-justify left
    grid $wl.lab -row 0 -column 0 -sticky ew

    set wc "$w.fchx"
    frame $wc
    grid $wc -row 1 -column 0 -padx 5 -pady 5

    set irow 0
    set icol 0
    set ifeat 0
    foreach feat $ListeTypesDeFeatures {
	if {$feat eq "Clear"} {
	    continue
	}
	set TTmp($feat) 0
	
	set chxb "$wc.feat$ifeat"
	checkbutton $chxb \
	    -text $feat \
	    -variable TTemp($feat) \
	    -relief flat \
	    -highlightthickness 0 \
	    -onvalue 1 \
	    -offvalue 0
	grid $chxb -row $irow -column $icol -ipadx 2
	incr irow
	if {$irow == 3} {
	    set irow 0
	    incr icol
	}
	incr ifeat
    }

    set wb "$w.fbut"
    frame $wb
    grid $wb -row 2 -column 0 -sticky ew -padx 10 -pady 20

    button $wb.bcl \
	-text "Cancel" \
	-background "red" \
	-command [list set Lfeat \[EndWindowAskFeatureSelection "$w" cancel\]]

    button $wb.bok \
	-text " OK " \
	-background green1 \
	-command [list set Lfeat \[EndWindowAskFeatureSelection "$w" ok\]]

    grid $wb.bcl -row 0 -column 0 -sticky w
    grid $wb.bok -row 0 -column 1 -sticky e

    FenetreAuCentre $w

    tkwait window $w

    unset TTmp

	return $Lfeat
}


proc WindowWriteFeatureFile {} {
    global Defauts ListeTypesDeFeatures WFeat
    
    if {$ListeTypesDeFeatures == {}} {
	FaireLire "There is no features to export !"
	return
    }

    set w .writefeat
    set WFeat(win) $w
    if {[winfo exists $w]} {
	raise $w
	return
    }

    # defaults
    if {! [info exists WFeat(seqs)]} {
	set WFeat(seqs) "all"
    }
    if {! [info exists WFeat(file)] || $WFeat(file) eq ""} {
	set WFeat(file) "[file rootname [set Defauts(Fichier[TypeAli])]].feat"
    }

    toplevel $w
    wm title $w "Save feature as..."
    wm iconname $w "Save"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    frame $w.f
    grid $w.f -column 0 -row 0 -sticky news

    set wf $w.f
    label $wf.labgen \
	-font TitleFont \
	-fg $Defauts(ForeAppli) \
	-text "Select features and sequences to be saved" \
	-anchor w -justify left
    grid $wf.labgen -row 0 -column 0 -sticky ew -padx 5 -pady {5 20}

    frame $wf.fv
    grid $wf.fv -row 1 -column 0 -sticky ew -padx 5
    label $wf.fv.labselfeat \
	-text "Feature(s) to save :" \
	-fg $Defauts(ForeAppli) \
	-justify left -anchor w
    menubutton $wf.fv.mctr \
	-relief raised \
	-text "Choose ..." \
	-direction above \
	-menu $wf.fv.mctr.featlist
    menu $wf.fv.mctr.featlist -tearoff 0
    foreach f $ListeTypesDeFeatures {
	$wf.fv.mctr.featlist add checkbutton -label "$f" -variable WFeat(LFeat,$f) -onvalue 1 -offvalue 0 
    }

    grid $wf.fv.labselfeat -row 0 -column 0
    grid $wf.fv.mctr -row 0 -column 1

    frame $wf.fseq 
    grid $wf.fseq -row 2 -column 0 -sticky ew -padx 5

    label $wf.fseq.labseq \
	-fg $Defauts(ForeAppli) \
	-text "Sequences to consider :" \
	-justify left -anchor w
    radiobutton $wf.fseq.seqsel \
	-text "selected sequences" \
	-variable WFeat(seqs) \
	-relief flat \
	-value "selected"
    radiobutton $wf.fseq.seqall \
	-text "all sequences" \
	-relief flat \
	-variable WFeat(seqs) \
	-value "all"
    grid $wf.fseq.labseq -row 0 -column 0 -sticky w -padx 5
    grid $wf.fseq.seqsel -row 1 -column 0 -sticky w -padx 15
    grid $wf.fseq.seqall -row 2 -column 0 -sticky w -padx 15 

    frame $wf.ffile
    grid $wf.ffile -row 3 -column 0 -sticky ew -padx 5

    label $wf.ffile.lab \
	-text "File name" \
	-fg $Defauts(ForeAppli) \
	-justify left -anchor w
    entry $wf.ffile.ent \
	-width 15 \
	-textvariable WFeat(file)
    grid $wf.ffile.lab -row 0 -column 0 -sticky w
    grid $wf.ffile.ent -row 0 -column 1 -sticky w -padx 10

    ttk::frame $wf.fbut \
	-style FrmBtnCtrl.TFrame
    grid $wf.fbut -row 4 -column 0 -sticky ew -padx 5 -pady {20 5}
    button $wf.fbut.cancel \
	-text "Cancel" \
	-bg red \
	-command [list WriteFeatureFile cancel]
    button $wf.fbut.ok \
	-text " OK " \
	-bg green1 \
	-command [list WriteFeatureFile ok]
    grid $wf.fbut.cancel -row 0 -column 0 -sticky w -padx 20
    grid $wf.fbut.ok -row 0 -column 1 -sticky e -padx 20

    FenetreAuCentre $w
    update idletasks
    
    return
}


proc WriteFeatureFile {what} {
    global LNOrdali TabSF ListeTypesDeFeatures WFeat NomSeqSel

    if {$what eq "cancel"} {
	destroy $WFeat(win)
	update idletasks
	return
    }
    
    #check requirements
    if {$WFeat(file) eq ""} {
	FaireLire "Output File name is not defined !"
	return
    }    
    
    if {$WFeat(seqs) eq "selected" && $NomSeqSel == {}} {
	FaireLire "No sequences selected !"
	return
    }
    # Create list of sequences
    set Lseqs {}
    if {$WFeat(seqs) eq "selected"} {
	foreach idx $NomSeqSel {
	    lassign [split $idx .] y tmp
	    lappend Lseqs [string trim [lindex $LNOrdali $y-1]]
	}
    } else {
	# Take all sequences
	set Lseqs [lmap n $LNOrdali {string trim $n}]
    }
    
    #check if at least one feature is selected
    set isFeat 0
    foreach feat [array names WFeat "LFeat,*"] { 
	incr isFeat $WFeat($feat)
    }
    if {! $isFeat} {
	FaireLire "No feature selected !"
	return
    }

    # Now export everything
    set Llignes {}
    foreach feat [array names WFeat "LFeat,*"] {
	if {! $WFeat($feat)} {
	    continue
	}
	# feature names may contain a comma
	set feat [string range $feat [string length "LFeat,"] end]

	lappend Llignes "FEATURE $feat"
	lappend Llignes ""
	foreach seq $Lseqs {
	    if {! [info exists TabSF($seq,$feat)]} {
		continue
	    }
	    foreach ft $TabSF($seq,$feat) {
		DecortiqueUneFeature $ft dg fg col score note csys
		# a local element starting or ending on a gap of its
		# sequence has no residue number there : written in
		# alignment columns, as the propagation does
		if {$csys eq "local" && ([string index $::Sequences($seq) $dg] eq "." || [string index $::Sequences($seq) $fg] eq ".")} {
		    set csys "global"
		}
		# coordinates in file start at 1 (see ReadRawFeatureFile)
		if {$csys eq "local"} {
		    # position in the sequence without gaps
		    # (PDB residue number for PDB sequences)
		    set dg [DonnePosGS $seq $dg]
		    set fg [DonnePosGS $seq $fg]
		} else {
		    # column in the alignment
		    incr dg
		    incr fg
		}
		lappend Llignes "$seq;$csys;$dg;$fg;$col;$score;$note"
	    }
	}
	lappend Llignes ""
    }

    if {[catch {
	set o [open $WFeat(file) w]
	puts $o [join $Llignes \n]
	close $o
    } Msg]} {
	FaireLire "Error !\nCan't write file $WFeat(file) :\n$Msg"
	return
    }

    destroy $WFeat(win)
    unset WFeat
    update idletasks
    
    return
}


proc EndWindowAskFeatureSelection {w what fileOut} {
    global ListeTypesDeFeatures TTmp

    set Lfeat {}
    if {$what eq "ok"} {
	foreach feat $ListeTypesDeFeatures {
	    if {$feat eq "Clear"} {
		continue
	    }
	    if {$TTmp($feat)} {
		lappend Lfeat $feat
	    }
	}

	WriteFeatureFile $fileOut $Lfeat
    }

    destroy $w


    return $Lfeat
}


proc InterfaceWriteFeatureFile {{Lfeat {}} {fileOut ""}} {
    if {$fileOut eq ""} {
	set fileOut [DemandeEtSauveFichier *]
	if {$fileOut eq ""} {
	    return
	}
    }

    if {$Lfeat == {}} {
	WindowAskFeatureSelection $fileOut
    } else {
	WriteFeatureFile $fileOut $Lfeat
    }

    return
}


proc checkwritefeature {} {
    global WFeat NomSeqSel ListeTypesDeFeatures

    puts "[join $ListeTypesDeFeatures \n]"
    WindowWriteFeatureFile
    
    foreach f $ListeTypesDeFeatures {
	set WFeat(LFeat,$f) 1
    }
    
    set NomSeqSel [list 3.0 4.05.0]
    set WFeat(seqs) "all"
    set WFeat(file) testw.feat

    package require Img
    update idletasks
    set img [image create photo -format window -data $WFeat(win)]
    $img write window_writefeature.png
    
    
    WriteFeatureFile ok

    exit
}

proc ReadRawFeatureFile {{file ""}} {
    global LNOrdali Sequences TabSF ListeTypesDeFeatures EFeat SDG GroupeDeLaSequence

    # format :
    # FEATURE <FeatName> ?PROPAGATE? ?all|group?
    # <seq. name>;<coords. syst.>;<start>;<stop>;<color>;<score>;<note>"
    #

    if {$file eq ""} {
	set file [DemandeEtOuvreFichier txt 1]
	# Cancel in the file dialog : nothing to do
	if {$file eq ""} {return}
    }
    if {$file eq "" || ! [file exists $file]} {
	FaireLire "Error !\n Bad file specified !"
	return
    }

    #    FaireAttendre "Please wait ...\nParsing feature file ..."

    array set TFtmp {}
    set Ll [LesLignesDuFichier $file]
    set Lg {}
    set feat ""
    set pro ""
    # feature types are added to ListeTypesDeFeatures only
    # if the file is read up to the end
    set LnewFeat {}
    foreach l $Ll {
	regsub -all { +} [string trim $l] " " l
	if {$l eq "" || [string first "#" $l] == 0} {
	    continue
	}

	if {[regexp -nocase {^FEATURE} $l]} {
	    # start a new feature
	    set Ld [split $l " "]
	    if {[llength $Ld] != 2 && [llength $Ld] !=4} {
		FaireLire "Error !\nFeature declaration format is not correct:\n$l\n\n Please see documentation !"
		return
	    }

	    set feat [lindex $Ld 1]
	    set feat [string map {"." ","} $feat]
	    lappend LnewFeat $feat

	    # propagation ?
	    set pro ""
	    if {[llength $Ld] ==4} {
		set pro [string tolower [lindex $Ld 3]]
		if {$pro ni {group all} }  {
		    FaireLire "Error ! Feature propagation target unknown ($pro) while declaring feature:\n$l\n\n Should be \"all\" or \"group\".\nFeature reading cancelled !"

		    return
		}
	    }

	    # everything done for feature declaration
	    continue
	}

	# now read feature definition
	if {$feat eq ""} {
	    FaireLire "Error !\nFeature definition found before any FEATURE declaration :\n$l\nFeature discarded !"
	    continue
	}
	set Lv [split $l "\;"]
	# the note (last field) may contain ';'
	if {[llength $Lv] > 7} {
	    set Lv [list {*}[lrange $Lv 0 5] [join [lrange $Lv 6 end] "\;"]]
	}
	if {[llength $Lv] != 7} {
	    FaireLire "Error !\nFeature specification is of the form:\n<seq. name>;<coords. syst.>;<start>;<stop>;<color>;<score>;<note>"
	    continue
	}

	lassign $Lv nom csys d f col score note
	set nom  [string map {" " ""} $nom]
	set csys [string tolower [string map {" " ""} $csys]]
	set d    [string map {" " ""} $d]
	set f    [string map {" " ""} $f]
	set col  [string map {" " ""} $col]
	set sco  [string map {" " ""} $score]

	# check if name is present in alignment
	if {[lsearch $LNOrdali $nom] == -1} {
	    FaireLire "Sequence named $nom not present in the alignment !\nFeature discarded !"
	    continue
	}

	# check coords system
	if {$csys ni {"local" "global"}} {
	    FaireLire "Error !\nthe suplied coordinate system >$csys< is incorrect !\nCoordinate system should be either 'local' or 'global' !\nFeature is discarded"
	    continue
	}
	
	# Check if score is double
	if {$sco eq ""} {
	    set sco 0.0
	}
	if {! [string is double $sco]} {
	    FaireLire "Error ! Score should be a real number !\n>$l<\n\nFeature is discarded"
	    continue
	}

	# check if start and stop are valid
	if {! [string is integer -strict $d] || ! [string is integer -strict $f]} {
	    FaireLire "Error !\nStart and Stop positions should be integers values !\nFeature discarded"
	    continue
	}

	# PDB residue numbers may be zero or negative (checked below)
	if {($d < 1 || $f < 1) && ! ($csys eq "local" && $nom in $::ListePDB)} {
	    FaireLire "Error !\nStart and Stop can't be zero or negative !\nFeature discarded !"
	    continue
	}

	if {$d > $f} {
	    lassign [list $f $d] d f
	}

	# convert coordinates (start at 1) to alignment
	# columns (start at 0)
	set seq [set Sequences($nom)]
	set sdg [string map {"." ""} $seq]
	if {$csys eq "local"} {
	    if {$nom in $::ListePDB} {
		# PDB sequence : local coordinates are PDB residue numbers
		set mol [DonneIdDeAccessPDB $nom]
		set chn [DonneChainDeAccessPDB $nom]
		set Lres [$mol _resnumber -chain $chn -polymer]
		if {$d ni $Lres || $f ni $Lres} {
		    FaireLire "Error !\nFor PDB sequence $nom, LOCAL coordinates $d or $f are not residue numbers of the structure !\nFeature discarded !"
		    continue
		}
		set d [DonnePosSG $nom $d]
		set f [DonnePosSG $nom $f]
	    } else {
		set lgdegap [string length $sdg]
		if {$d > $lgdegap || $f > $lgdegap} {
		    FaireLire "Error !\nOne of the coordinates for sequence $nom defined as LOCAL is greater than sequence length !\nFeature discarded !"
		    continue
		}
		set d [DonnePosSG $nom [expr {$d-1}]]
		set f [DonnePosSG $nom [expr {$f-1}]]
	    }
	} else {
	    # global coordinates system
	    set lgt [string length $seq]
	    if {$d > $lgt || $f > $lgt} {
		FaireLire "Error !\nIn sequence $nom Start or Stop GLOBAL coordinates are greater than alignment length $lgt !\nFeature discarded !"
		continue
	    }
	    incr d -1
	    incr f -1
	}

	if {$pro eq "all"} {
	    lappend Lg [list $nom $feat "GroupeToutLeMonde"]
	} elseif {$pro eq "group"} {
	    lappend Lg [list $nom $feat [set GroupeDeLaSequence($nom)]]
	}
	lappend TFtmp(${nom},$feat) [list fstart $d fstop $f fcolor $col fscore $sco fnote $note fcsys $csys]
    }

    # propagate if needed
    if {$Lg ne ""} {
	set Lg [lsort -unique $Lg]
	foreach ng $Lg {
	    lassign $ng nom feat grp
	    foreach ft [set TFtmp($nom,$feat)] {
		DecortiqueUneFeature $ft d f col sco note csys0

		foreach s [set SDG($grp)] {
		    # Check if feature can be propagted in this sequence
		    if {$s eq $nom} {
			continue
		    }

		    # we are in global coords, check in local.
		    set csys $csys0
		    if {$csys eq "local"} {
			if {[string index [set Sequences($s)] $d] eq "." || [string index [set Sequences($s)] $f] eq "."} {
			    # As one the coordinates match with a gap in the sequence, change the coordinate system from local to gloabl
			    set csys "global"
			}
		    }
		    lappend TabSF($s,$feat) [list fstart $d fstop $f fcolor $col fscore $sco fnote $note fcsys $csys]
		}
	    }
	}
    }

    # add previously defined features
    set nFt 0
    foreach k [array names TFtmp] {
	foreach ft [set TFtmp($k)] {
	    # do not duplicate a feature already there
	    if {[info exists TabSF($k)] && $ft in $TabSF($k)} {
		continue
	    }
	    lappend TabSF($k) $ft
	    incr nFt
	}
    }

    # keep only feature types with at least one feature
    foreach ft $LnewFeat {
	if {[array names TabSF "*,$ft"] ne ""} {
	    lappend ListeTypesDeFeatures $ft
	}
    }
    set ListeTypesDeFeatures [lsort -unique $ListeTypesDeFeatures]
    if {$nFt || $Lg ne ""} {
	VueEditee 1
    }
    if {$feat eq ""} {
	FaireLire "No feature found in file $file !"
	return
    }

    # update feature in Mode window
    if {[info exists EFeat(FeatCombo)] && [winfo exists $EFeat(FeatCombo)]} {
	set EFeat(FTypes) [linsert $ListeTypesDeFeatures 0 "None"]
	set wdt [PlusLongEltDe $ListeTypesDeFeatures]
	$EFeat(FeatCombo) configure -values $EFeat(FTypes)
	set EFeat(Feat) $feat

	ChangeFeatureForEditing
    } else {
	# not in Feature Mode
	ChangeMode
    }

    return
}



