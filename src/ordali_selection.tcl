


#
#
# --- ordali_selection.tcl
#


proc CutLesNoms {} {
    global NomSeqSel LSOrdali LNOrdali LNSeqlab LSSeqlab NomsAffiches Defauts NomTextSeq NomNomSeq TScrollY

    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {$NomSeqSel == {}} {
	return
    }

    # store Y-scroll position
    lassign [$TScrollY get] ysc tmp
    
    if {[InSeqlabMode]} {
	set LNoms $LNSeqlab
	#set LSeqs $LSSeqlab
	set LSeqs [$NomTextSeq output all]
    } else {
	set LNoms $LNOrdali
	set LSeqs $LSOrdali
    }
    
    set LidxSeq {}
    set LidxWdg {}
    foreach elt $NomSeqSel {
	lassign [split $elt .] y x
	set iSeq [expr {$y-1}]
	if {[string trim [lindex $LNoms $iSeq]] ne ""} {
	    lappend LidxWdg $y
	    lappend LidxSeq $iSeq
	}
    }
    set LidxSeq [lsort -integer -decreasing $LidxSeq]
    set LidxWdg [lsort -integer -decreasing $LidxWdg]
    foreach iSeq $LidxSeq {
	set LNoms [lreplace $LNoms $iSeq $iSeq]
	set LSeqs [lreplace $LSeqs $iSeq $iSeq]
    }
    
    # Check if there is still ONE sequence left
    set nbr 0
    foreach n $LNoms {
	if {[string trim $n] ne ""} {
	    incr nbr
	    break
	}
    }
    if {$nbr ==0} {
	FaireLire "Error !\nYou can't cut all sequences. You must leave at least one sequence in the alignment.\nIf you want to cut all sequences (delete alignement), then close the file"
	return
    }

    CopyLesNoms
    
    $NomNomSeq configure -state normal
    $NomNomSeq cut $LidxWdg
    $NomNomSeq configure -state disabled
    RAZNomSeq

    set state [lindex [$NomTextSeq configure -state] end]
    $NomTextSeq configure -state normal
    $NomTextSeq cut $LidxWdg
    $NomTextSeq configure -state $state

    if {[InSeqlabMode]} {
	set LNSeqlab $LNoms
	set LSSeqlab [lmap s $LSeqs {split $s ""}]
    } else {
	set LNOrdali $LNoms
	set LSOrdali $LSeqs
	FlagFeatureScore 1
	MetAJourGroupes
    }
    
    VueEditee 1
    
    set NomSeqSel {}
    ChangeNomsAff $Defauts(NomsAffiches)
    #AfficheNomsEtSeqs
    #RepeintNomsEtSeqs
    
    # re-position at original Y
    CoupleY moveto $ysc

    return
}


proc TagGroupeDeLaLigne {w y} {
    # group colour tag (TC...) of line y of the names widget.
    # biotext 'tag names' ignores the index : use the ranges.
    foreach t [lsearch -all -inline -regexp [$w tag names] {^TC}] {
	if {[catch {set Lr [$w tag ranges $t]}]} {continue}
	foreach {p1 p2} $Lr {
	    if {[lindex [split $p1 .] 0] == $y} {
		return $t
	    }
	}
    }

    return ""
}


proc CopyLesNoms {} {
    global LNOrdali LSOrdali BufferSeq NomSeqSel LNSeqlab LSSeqlab NomNomSeq NomTextSeq

    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {$NomSeqSel == {}} {
	return
    }

    # if there is already something in cache, ask for what to do with.
    if {$BufferSeq != {}} {
	set chx [tk_dialog .chx "Warning !" "Warning !\nYou already have sequences in the clipboard ! Copying the selected sequences will discard the clipboard ones !" "" 0 "Discard" "Cancel"]
	if {$chx == 1} {
	    return 0
	}
    }
    
    if {[InSeqlabMode]} {
	set LNoms $LNSeqlab
	set LSeqs [lmap s $LSSeqlab {join  $s ""}]
    } else {
	set LNoms $LNOrdali
	set LSeqs $LSOrdali
    }
    
    set NomSeqSel [lsort -real $NomSeqSel]
    set LidxSeq {}
    set LidxWdg {}
    set BufferSeq {}
    foreach elt $NomSeqSel {
	lassign [split $elt .] y x
	set iSeq [expr {$y-1}]

	set Nom [lindex $LNoms $iSeq]
	if {[string trim $Nom] eq ""} {
	    continue
	}
	
	set Seq [lindex $LSeqs $iSeq]
	set TagNom [TagGroupeDeLaLigne $NomNomSeq $y]

	set TagSeq [$NomTextSeq tag names $elt]
	lappend LidxSeq $iSeq
	lappend LidxWdg $y
	lappend BufferSeq [list $Nom $Seq $TagNom $TagSeq]
    }

    $NomNomSeq configure -state normal
    $NomNomSeq  copy $LidxWdg
    $NomNomSeq configure -state disabled

    set state [lindex [$NomTextSeq configure -state] end]
    $NomTextSeq copy $LidxWdg
    $NomTextSeq configure -state $state

    return 1
}


proc PasteLesNoms {} {
    global LSOrdali LNOrdali Sequences LNSeqlab LSSeqlab NomSeqSel BufferSeq NomTextSeq NomNomSeq Defauts ListeSeqsGroupees TDesAccess TDesSeqnames TDesBId ListePDB
    
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {$BufferSeq == {}} {
	return
    }

    if {$NomSeqSel == {} || [llength $NomSeqSel] > 1} {
	FaireLire "Please select ONE sequence below which\nsequences should be inserted !"
	return
    }
    
    # keep track of Y-scrollbar position
    lassign [$::TScrollY get] ysc tmp

    # insertion point
    lassign [split $NomSeqSel .] yp xp
    
    if {[InSeqlabMode]} {
	set LNoms $LNSeqlab
	set LSeqs [lmap s $LSSeqlab {join $s ""}]
    } else {
	set LNoms $LNOrdali
	set LSeqs $LSOrdali
	VueEditee 1
    }

    # Ordali works with seq-names as unique ID
    set LIN {}
    set LIS {}
    set LIT {}
    foreach b $BufferSeq {
	lassign $b Nom Seq Tname
	lappend LIS $Seq
	
	# Check if pasted name is unique
	set LNtrim [lmap n $LNoms {string trim $n}]
	if {$Nom in $LNtrim || $Nom in $LIN} {
	    # Name already exists : make a copy named <name>__<k>
	    # (k not used in this alignment, nor in another snapshot)
	    set src $Nom
	    set baseName $Nom
	    if {[regexp {__[0-9]+$} $Nom]} {
		# the pasted name is already a copy !
		set baseName [string range $Nom 0 [string last "__" $Nom]-1]
	    }
	    set k 1
	    while {"${baseName}__$k" in $LNtrim || "${baseName}__$k" in $LIN || [info exists TDesSeqnames(${baseName}__$k)]} {
		incr k
	    }
	    set Nom "${baseName}__$k"
	    CopySequenceData $src $Nom
	    # record the new name
	    set TDesSeqnames($Nom) $Nom
	    # A copy of a PDB sequence can not be linked to the
	    # structure (PDB id and chain are taken from the name) :
	    # it is NOT added to ListePDB
	    set Tname ""
	}
	lappend LIN $Nom
	lappend LIT $Tname
    }
    
    # The copied sequences may come from another snapshot whose
    # alignment length is different : all sequences get the same
    # length, completed with gaps at their end
    set lgAli 0
    foreach n $LNoms s $LSeqs {
	if {[string trim $n] ne ""} {
	    set lgAli [expr {max($lgAli, [string length $s])}]
	}
    }
    set lgMax $lgAli
    foreach s $LIS {
	set lgMax [expr {max($lgMax, [string length $s])}]
    }
    set LIS [lmap s $LIS {
	set s [string map {" " "."} $s]
	append s [string repeat "." [expr {$lgMax - [string length $s]}]]
    }]
    if {$lgMax > $lgAli} {
	set LSeqs [lmap n $LNoms s $LSeqs {
	    if {[string trim $n] eq ""} {
		string repeat " " $lgMax
	    } else {
		set s [string cat $s [string repeat "." [expr {$lgMax - [string length $s]}]]]
		if {! [InSeqlabMode]} {
		    set Sequences([string trim $n]) $s
		}
		set s
	    }
	}]
    }
    if {$lgMax != [string length [lindex $BufferSeq 0 1]] || $lgMax != $lgAli} {
	FaireLire "Beware !\nThe pasted sequences come from an alignment of different length.\nSequences have been completed with gaps at their end."
    }

    # insertion point in widget
    $NomNomSeq configure -state normal
    $NomNomSeq  paste $yp
    set state [lindex [$NomTextSeq configure -state] end]
    $NomTextSeq configure -state normal
    $NomTextSeq paste $yp

    # BEWARE !
    # linsert inserts elements just BEFORE the specified index !
    set iWdg $yp
    set iSeq [expr {$yp-1}]
    foreach n $LIN s $LIS t $LIT {
	set LNoms [linsert $LNoms $iSeq+1 $n]
	set LSeqs [linsert $LSeqs $iSeq+1 $s]
	if {[InSeqlabMode]} {
	    if {$t ne ""} {
		set g [string range $t 2 end]
		lappend ListeSeqsGroupees($g) $n
	    }
	} else {
	    if {$t ne ""} {
		$NomNomSeq tag add $t $iWdg.0 $iWdg.end
	    }
	    set Sequences($n) $s
	}
	incr iSeq
	incr iWdg
    }

    if {[InSeqlabMode]} {
	set LNSeqlab $LNoms
	set LSSeqlab [lmap s $LSeqs {split $s ""}]
    } else {
	set LNOrdali $LNoms
	set LSOrdali $LSeqs
	FlagFeatureScore 1
	$NomTextSeq configure -state disabled
    }

    $NomNomSeq configure -state disabled
    
    set BufferSeq {}
    set NomSeqSel {}

    MetAJourGroupes
    ChangeNomsAff $Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNoms

    # re-position at original Y
    CoupleY moveto $ysc
    
    update idletasks
    
    return
}


proc FeatureSousLePointeur {posi} {
    # Displayed feature item under the pointer (in the alignment
    # widget). Returns {feature start stop} (alignment columns,
    # stop included), or "" if there is none.
    # biotext 'tag names' ignores the index : the displayed
    # features are found from the FX_<feature>_<color> tags, and the
    # item under the pointer is searched in TabSF.
    global NomTextSeq LNOrdali TabSF ListeTypesDeFeatures

    if {! [info exists ListeTypesDeFeatures]} {
	return ""
    }
    lassign [split [$NomTextSeq index $posi] .] y x
    set nom [string trim [lindex $LNOrdali $y-1]]
    if {$nom eq ""} {
	return ""
    }

    # tags from highest to lowest priority : the feature drawn on
    # top is taken first
    set Lft {}
    foreach t [lreverse [$NomTextSeq tag names]] {
	if {! [string match "FX_*" $t]} {
	    continue
	}
	foreach ft $ListeTypesDeFeatures {
	    if {$ft ni $Lft && [string match "FX_[string map {" " ""} $ft]_*" $t]} {
		lappend Lft $ft
	    }
	}
    }

    foreach ft $Lft {
	if {! [info exists TabSF($nom,$ft)]} {
	    continue
	}
	# last item drawn on top
	set res ""
	foreach e $TabSF($nom,$ft) {
	    DecortiqueUneFeature $e d f col sco note
	    if {$x >= $d && $x <= $f} {
		set res [list $ft $d $f]
	    }
	}
	if {$res ne ""} {
	    return $res
	}
    }

    return ""
}


proc SelectLaFeature {posi} {
    # <Control-Button-1> in residue range selection modes : select
    # the columns of the displayed feature item under the pointer
    global PositionInitiale NomTextSeq ZoneSelect

    set res [FeatureSousLePointeur $posi]
    if {$res eq ""} {
	return
    }
    lassign $res ft x1 x2
    lassign [split [$NomTextSeq index $posi] .] y x

    # zone already selected
    if {[info exists ZoneSelect] && [list $x1 $x2] in $ZoneSelect} {
	return
    }

    set PositionInitiale $y.$x1
    SelectLesColonnes $y.$x2
    set PositionInitiale "-1.-1"
    catch {$NomTextSeq tag remove Marque}

    return
}


proc SelectLesColonnes {pos2} {
    global ZoneSelect PositionInitiale LNOrdali NomTextSeq

    if {$PositionInitiale eq "-1.-1"} {
	return
    }

    lassign [split $PositionInitiale .] y1 x1
    if {[regexp {^@} $pos2] && [ModeI]} {
	set pos2 [$NomTextSeq index $pos2]
    }
    lassign [split $pos2 .] y2 x2

    if {$x1 > $x2} {
	set tmp $x1
	set x1 $x2
	set x2 $tmp
    }

    # a new range replaces a "Select All" selection
    set xfin [expr {[LongueurDeLAlignement]-1}]
    if {[info exists ZoneSelect] && [llength $ZoneSelect] == 1 && [lindex $ZoneSelect 0 0] == 0 && [lindex $ZoneSelect 0 1] == $xfin && ($x1 != 0 || $x2 != $xfin)} {
	DeselectToutesLesColonnes
    }

    lappend ZoneSelect [list $x1 $x2]
    set ZoneSelect [lsort -integer -index 0 $ZoneSelect]

    foreach pos $ZoneSelect {
	lassign $pos z1 z2
	if {$x1 == $z1 && $x2 > $z2} {
	    set i [lsearch $ZoneSelect $pos]
	    set ZoneSelect [lreplace $ZoneSelect $i $i]
	    break
	}
    }

    $NomTextSeq configure -state normal
    if {"Marque" in [$NomTextSeq tag names]} {
	$NomTextSeq tag remove Marque
    } else {
	$NomTextSeq tag configure Marque -background black -foreground black
    }

    $NomTextSeq tag configure slct -background LightGrey -foreground black

    # widget text y commence a 1
    set i 0
    set Ltotag {}
    foreach n $LNOrdali {
	incr i
	if {[string trim $n] ne ""} {
	    lappend Ltotag $i.$x1 $i.$x2
	}
    }
    $NomTextSeq tag add slct {*}$Ltotag
    
    $NomTextSeq configure -state disabled

    return
}


proc DeselectToutesLesColonnes {} {
    global ZoneSelect NomTextSeq

    unset -nocomplain ZoneSelect

    # biotext complains about unknown tags
    foreach t {Marque slct} {
	if {$t in [$NomTextSeq tag names]} {
	    $NomTextSeq tag remove $t
	}
    }

    return
}


proc DeselectLesColonnes {w pos} {
    global ZoneSelect LNOrdali

    if {! [info exists ZoneSelect]} {return}

    lassign [split [$w index $pos] .] y x

    $w tag remove Marque

    set NouvelleZone {}
    set Nf [llength $LNOrdali]
    foreach posi $ZoneSelect {
	lassign $posi x1 x2 

	if {$x >= $x1 && $x <= $x2} {
	    for {set i 0} {$i < $Nf} {incr i} {
		if {[lindex $LNOrdali $i] ne ""} {
		    $w tag remove slct [expr {$i+1}].$x1 [expr {$i+1}].[expr {$x2+1}]
		}
	    }
	} else {
	    lappend NouvelleZone [list $x1 $x2]
	}
    }
    set ZoneSelect $NouvelleZone

    return
}


proc StockPosition {{w ""} {pos ""}} {
    global PositionInitiale
    
    if {! [info exists PositionInitiale] || $pos eq ""} {
	set PositionInitiale "-1.-1"
    } else {
	if {$w ne ""} {
	    set pos [$w index $pos]
	}
	set PositionInitiale $pos
	PoseUneMarque $pos
    }

    return
}


proc SelectionneToutesColonnes {} {
    global NomTextSeq

    # all columns replace the current ranges
    DeselectToutesLesColonnes
    StockPosition "" 1.0
    if {"Marque" in [$NomTextSeq tag names]} {
	$NomTextSeq tag remove Marque
    }
	set fin 1.[expr {[LongueurDeLAlignement]-1}]

    SelectLesColonnes $fin

    return
}


proc PoseUneMarque {pos {what "all"}} {
    global NomTextSeq LNOrdali SDG GroupeDeLaSequence

    lassign [split [$NomTextSeq index $pos] .] y x
    if {[string trim [lindex $LNOrdali $y-1]] eq ""} {
	return
    }
    set sref [lindex $LNOrdali $y-1]
    
    switch $what {
	"all" {set Lnoms $LNOrdali}
	"group" {
	    set gref [set GroupeDeLaSequence($sref)]
	    set Lnoms [set SDG($gref)]
	}
	"seq" {set Lnoms $sref}
    }
    
    $NomTextSeq configure -state normal
    if {"Marque" in [$NomTextSeq tag names]} {
	$NomTextSeq tag remove Marque
    } else {
	$NomTextSeq tag configure Marque -background black -foreground black
    }
    set x1 $x ; set x2 [expr {$x+1}]
    foreach n $Lnoms {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}
	set i [expr {[lsearch $LNOrdali $n] + 1}]
	lappend Ly $i.$x1 $i.$x2
    }
    if {$Ly != {}} {
	$NomTextSeq tag add Marque {*}$Ly
    }
    if {! [InSeqlabMode]} {
	$NomTextSeq configure -state disabled
    }
    
    return
}


proc InverseTagNom {pos} {
    global NomSeqSel NomNomSeq
    
    lassign [split $pos .] y x
    $NomNomSeq configure -state normal
    if {$pos in $NomSeqSel} {
	# remove zone 
	$NomNomSeq tag remove InvNm $y.0 $y.end
	set ix [lsearch -exact $NomSeqSel $pos]
	set NomSeqSel [lreplace $NomSeqSel $ix $ix]
    } else {
	lappend NomSeqSel $pos
	$NomNomSeq tag add InvNm $y.0 $y.end
    }
    $NomNomSeq configure -state disabled
    
    return
}


proc TagNomsSelectionnes {} {
    if {$::NomSeqSel == {}} {
	return
    }
    
    set Ltotag {}
    foreach idx $::NomSeqSel {
	lassign [split $idx .] y x
	lappend Ltotag $y.0 $y.end
    }

    $::NomNomSeq configure -state normal
    if {"InvNm" ni [$::NomNomSeq tag names]} {
	$::NomNomSeq tag configure InvNm -background white -foreground black
    }
    $::NomNomSeq tag add InvNm {*}$Ltotag
    $::NomNomSeq configure -state disabled

    return
}


proc RAZNomSeq {} {
    $::NomNomSeq configure -state normal
    $::NomNomSeq tag remove InvNm
    $::NomNomSeq configure -state disabled
    
    return
}


proc LesSeqsDesSeqsSel {} {
    set Ls {}
    if {[InSeqlabMode]} {
	set LSeqs [$::NomTextSeq output all]
    } else {
	set LSeqs $::LSOrdali
    }

    foreach e $::NomSeqSel {
	lassign [split $e .] y x 
	incr y -1
	set seq [lindex $LSeqs $y]
	set tmp [string map [list "." "" " " ""] $seq]
	if {$tmp eq ""} {
	    continue
	}
	lappend Ls $seq
    }

    return $Ls
}


proc LesNomsDesSeqsSel {} {
    set Ln {}
    if {[InSeqlabMode]} {
	set LNoms $::LNSeqlab
    } else {
	set LNoms $::LNOrdali
    }

    foreach e $::NomSeqSel {
	lassign [split $e .] y x 
	incr y -1
	set nom [lindex $LNoms $y]
	if {[string trim $nom] ne ""} {
	    lappend Ln $nom
	}
    }

    return $Ln
}


proc SelectNomSeq {quoi posPixel} {
    global PosInitNom NomNomSeq NomSeqSel LNOrdali LNSeqlab

    if {"InvNm" in [$NomNomSeq tag names]} {
	$NomNomSeq tag raise InvNm
    }
    
    if {! [InSeqlabMode]} {
	set LNoms $LNOrdali
    } else {
	set LNoms $LNSeqlab
    }
    
    # posInitNom defined initially in BindingsOrdali
    lassign [split $PosInitNom .] yInit xInit
    if {[string index $posPixel 0] eq "@"} {
	set posCurrNom [$NomNomSeq index $posPixel]
    } else {
	set posCurrNom  $posPixel
    }
	lassign [split $posCurrNom .]        yCurr xCurr
    
    switch $quoi {
	"une" {
	    RAZNomSeq
	    
	    if {[string trim [lindex $LNoms $yCurr-1]] eq ""} {
		return
	    }
	    
	    set NomSeqSel $posCurrNom
	    $NomNomSeq configure -state normal
	    $NomNomSeq tag add InvNm $yCurr.0 $yCurr.end
	    $NomNomSeq configure -state disabled
	}
	"ctr" {
	    if {$NomSeqSel == {}} {
		SelectNomSeq "une" $posPixel
	    } else {
		InverseTagNom $posCurrNom
	    }
	}
	"shf" {
	    if {$NomSeqSel == {}} {
		SelectNomSeq "une" $posPixel
		return
	    }
	    
	    if {$yCurr < $yInit} {
		set tmp $yCurr
		set yCurr  $yInit
		set yInit  $tmp
	    }
	    for {set y $yInit} {$y <= $yCurr} {incr y} {
		if {[string trim [lindex $LNoms $y-1]] ne ""} {
		    if {"$y.0" ni $NomSeqSel} {
			lappend NomSeqSel "$y.0"
		    }
		}
	    }
	    set NomSeqSel [lsort -dictionary $NomSeqSel]
	    TagNomsSelectionnes
	}	    
	"all" {
	    RAZNomSeq
	    set NomSeqSel {}
	    set LtoTag {}
	    set i 0
	    foreach n $LNoms {
		incr i
		if {[string trim $n] ne ""} {
		    lappend LtoTag "$i.0" "$i.end"
		    lappend NomSeqSel "$i.0"
		}
	    }
	    $NomNomSeq configure -state normal
	    $NomNomSeq tag add InvNm {*}$LtoTag
	    $NomNomSeq configure -state disabled
	}
    }
    
    set PosInitNom $posCurrNom
    
    return
}


proc ClearSelectionNoms {} {
    if {"InvNm" in [$::NomNomSeq tag names]} {
	$::NomNomSeq configure -state normal
	$::NomNomSeq tag remove InvNm
	$::NomNomSeq configure -state disabled
    }
	set ::NomSeqSel {}

    return
}


proc ClearSelectionSequences {} {
    if {"slct" in [$::NomTextSeq tag names]} { 
	$::NomTextSeq tag remove slct
    }
    set ::ZoneSelect {}

    return
}


proc ClearSelections {} {
    ClearSelectionNoms
    # not needed with biotext
    ClearSelectionSequences

    return
}


proc tmpci {} {
    ChangeMode donnepci
    puts "mode [QuelMode]"
    SelectionneToutesColonnes
    DeselectToutesLesColonnes

    exit
}




