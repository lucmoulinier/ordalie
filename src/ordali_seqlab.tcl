



# ordali_seqlab.tcl



proc BindTextKey {w k} {
    set k [string toupper $k]
    set idx [$w cursor]
    lassign [split $idx .] y x
    set y [expr {$y - 1}]
    if {[string trim [lindex $::LNSeqlab $y]] eq ""} {
	return
    }
    set old_length [LongueurAlignement seqlab]

    $w chars $k $idx [tk::biotext::bufferNTimes empty]
    
    set Ns {}
    foreach s [$w output all] {
	lappend Ns [split $s ""]
    }
    set ::LSSeqlab $Ns
    
    if {$old_length != [LongueurAlignement seqlab]} {
	InitWRegle
	AfficheRegle
    }
    
    update idletasks

    return
}


proc BindTextSpace {w {NoGroup ""}} {
    set idx [$w cursor]
    lassign [split $idx .] y x
    set y [expr {$y-1}]

    set seqass [lindex $::LNSeqlab $y]
    if {[string trim $seqass] eq ""} {
	return
    }

    set old_length [LongueurAlignement seqlab]
    set nf [tk::biotext::bufferNTimes empty]
    if {$NoGroup eq ""} {
	$w chars "." $idx $nf
    } else {
	$w chars -nogroup "." $idx $nf
    }
    
    set ::LSSeqlab [lmap s [$w output all] {split $s ""}]

    if {[LongueurAlignement "seqlab"] != $old_length} {
	InitWRegle
	AfficheRegle
    }

    update idletasks

    return
}


proc BindSeqB1 {w x y} {

    SelectNomSeq "une" "@$x,$y"

    return
}


proc BindDeplace {w x y} {

    if {[$w curvalue] eq ""} {return}
    set n [TamponNFois vide]
    lassign [split [$w index active] ,] r c

    set nx [expr {$n*$x}]
    set ny [expr {$n*$y}]
    set cell "[expr {$r+${ny}}],[expr {$c+${nx}}]"

    $w configure -state normal

    $w activate $cell
    $w selection clear all
    $w selection set active

    $w configure -state disabled

    $w xview scroll ${nx} units
    CoupleY scroll "${ny}" units

    return
}


proc BindTextShiftLeft {w} {
    set n [TamponNFois vide]

    for {set i 0} {$i < $n} {incr i} {
	PousseAGauche
    }

    return
}


proc BindTextShiftRight {w} {

    set n [TamponNFois vide]
    for {set i 0} {$i < $n} {incr i} {
	PousseADroite
    }

    return
}


proc AssigneTagsCouleursDesAA {} {
    global NomTextSeq TagCouleurAA

    foreach t {STAC DE HN G P Q ILMV RK FYW} {
	foreach a [split $t ""] {
	    set TagCouleurAA($a) $t
	    set TagCouleurAA([string tolower $a]) $t
	}
    }

    set conftag [ExtraitTable "[TypeSeq]"]
    foreach c $conftag {
	lassign $c n f b
	$NomTextSeq tag configure Tag$n -foreground $f -background $b
    }
    
    return
}


proc PasteSeqsSel {} {

    global NomTextSeq
    global NomNomSeq
    global BufferRegion
    global LSSeqlab
    global LNSeqlab

    if {! [info exists BufferRegion] || $BufferRegion == {}} {return}
    set pos [$NomTextSeq index insert]
    lassign [split $pos "."] y r 

    set iw [expr {$y-1}]
    for {set j $iw} {$j < $iw+[llength $BufferRegion]} {incr j} {
	set s [string trim [lindex $LNSeqlab $j]]
	if {[SequenceLockee $s]} {return}
    }

    lassign [lindex $BufferRegion 0] d t s 
    set n [expr {[string length $s]-1}]
    set lm 0
    for {set j $iw ; set i 0} {$i < [llength $BufferRegion]} {incr i ; incr j} {
	set seq [string range [lindex $LSSeqlab $j] "end-$n" end]
	set lg [string length [string trimright $seq "."]]
	if {$lg > $lm} {set lm $lg}
    }

    AjouteDesGapsATous end $lm

    set np [expr {$n+1}]
    foreach e $BufferRegion {
	set yt [expr {$y - 1}]
	set s [lindex $LSSeqlab $yt]

	lassign $e d t s 
	lassign [split $d "."] tmp p 
	$NomTextSeq delete "$y.0 lineend -${np} chars" "$y.0 lineend"
	$NomTextSeq insert $y.$r $s
	set seq [string range $s 0 "end-${np}"]
	Stringinsert seq $r $s
	foreach {nm x1 x2} $t {
	    if {$x1 == -1} {set x1 $p}
	    if {$x2 == "Fin"} {set x2 [expr {$p+$n+1}]}
	    set a [expr {$r + ($x1 - $p)}]
	    set f [expr {$a + ($x2 - $x1)}]
	    $NomTextSeq tag add $nm $y.$a $y.$f
	}
	set LSSeqlab [lreplace $LSSeqlab $yt $yt $seq]

	incr y
    }

    $NomTextSeq edit separator
    EventNullPourNoms

    return
}



proc CopySeqsSel {} {

    global RegionSeqSel
    global NomTextSeq
    global NomNomSeq
    global LSSeqlab
    global LNSeqlab
    global BufferRegion

    if {$RegionSeqSel == {}} {return}
    foreach {d f} $RegionSeqSel {
	lassign [split $d "."] y x 
	incr y -1
	set s [string trim [lindex $LNSeqlab $y]]
	if {[SequenceLockee $s]} {return}
    }

    foreach {d f} $RegionSeqSel {
	set dmpT  [$NomTextSeq dump -tag $d $f]
	set LtagT [TagsDuDump $dmpT]
	set Seq   [$NomTextSeq get $d $f]
	lappend BufferRegion [list $d $LtagT $Seq]
    }

    return
}



proc CutSeqsSel {} {

    global RegionSeqSel
    global NomTextSeq
    global NomNomSeq
    global LSSeqlab
    global LNSeqlab
    global BufferRegion

    if {$RegionSeqSel == {}} {return}
    foreach {d f} $RegionSeqSel {
	lassign [split $d "."] y x 
	incr y -1
	set s [string trim [lindex $LNSeqlab $y]]
	if {[SequenceLockee $s]} {
	    FaireLire "Beware ! You must unlock the sequences\nin order to change their residue content"
	    return
	}
    }

    foreach {d f} $RegionSeqSel {
	set dmpT  [$NomTextSeq dump -tag $d $f]
	set LtagT [TagsDuDump $dmpT]
	set Seq   [$NomTextSeq get $d $f]
	lappend BufferRegion [list $d $LtagT $Seq]
	$NomTextSeq delete $d $f
	lassign [split $d "."] y x1 
	lassign [split $f "."] y x2 
	set nx [expr {$x2 - $x1}]
	set sx [string repeat "." $nx]
	$NomTextSeq insert "$y.0 lineend" $sx SPC
	incr y -1
	set s "[string replace [lindex $LSSeqlab $y] $x1 [expr {$x2-1}]]$sx"
	set LSSeqlab [lreplace $LSSeqlab $y $y $s]
    }

    update idletasks

    $NomTextSeq edit separator
    EventNullPourNoms

    return
}



proc PosSeqsRegion {} {
    global xIR yIR NomTextSeq RegionSeqSel

    if {$RegionSeqSel != {}} {
	$NomTextSeq tag remove InvS {*}$RegionSeqSel
	set RegionSeqSel {}
    }
    lassign [split [$NomTextSeq index active] ,] yIR xIR 

    return
}



proc InverseTagNomSB pos {

    global NomNomSeq
    global NomSeqSel

    if {[$NomNomSeq tag includes InvNm $pos]} {
	$NomNomSeq tag cell {} $pos
	set idx [lsearch $NomSeqSel $pos]
	set NomSeqSel [lreplace $NomSeqSel $idx $idx]
    } else {
	$NomNomSeq tag cell InvNm $pos
    }
    return
}



proc CutLesNomsSB {} {
    global LNSeqlab
    global LSSeqlab
    global NomNomSeq
    global NomTextSeq
    global BufferSeq
    global NomSeqSel

    if {$NomSeqSel == {}} {
	return
    }
    
    foreach e $NomSeqSel {
	lassign [split $e ,] y x
	lappend Lxy [list $x $y]
    }
    set Lxy [lsort -unique -integer -index 1 -decreasing $Lxy]
    
    CopyLesNomsSB
    
    $NomNomSeq  configure -state normal
    $NomTextSeq configure -state normal

    set Long [$NomTextSeq cget -rows]
    
    set if [lindex [lindex $Lxy 0] 1]
    set n 1
    set Ldel {}
    foreach e [lrange $Lxy 1 end] {
	lassign $e x i
	if {$i+1 == $if} {
	    incr n
	    set if $i
	} else {
	    lappend Ldel $if $n
	    set n 1
	    set if $i
	}
    }
    lappend Ldel $if $n
    
    foreach {i n} $Ldel {
	$NomTextSeq delete rows $i $n
	$NomNomSeq  delete rows $i $n
	set LSSeqlab [lreplace $LSSeqlab $i [expr {$i+$n-1}]]
	set LNSeqlab [lreplace $LNSeqlab $i [expr {$i+$n-1}]]
    }
    
    $NomNomSeq  configure -usecommand 1
    $NomTextSeq configure -usecommand 1
    $NomNomSeq  configure -state disabled
    $NomTextSeq configure -state disabled
    
    set NomSeqSel {}
    update idletasks

    return
}



proc CopyLesNomsSB {} {
    global LNSeqlab
    global LSSeqlab
    global NomSeqSel
    global BufferSeq

    if {$NomSeqSel == {}} {return}

    set BufferSeq {}
    foreach e $NomSeqSel {
	lassign [split $e ,] y x

	set Nom [string trim [lindex $LNSeqlab $y]]
	if {$Nom eq ""} {continue}
	set Seq [lindex $LSSeqlab $y]

	lappend BufferSeq [list $Nom $Seq]
    }

    return
}



proc PasteLesNomsSB {} {
    global NomNomSeq
    global NomTextSeq
    global BufferSeq
    global LNSeqlab
    global LSSeqlab
    global NomSeqSel
    global LookSeqs
    global LesPoidsDesSequences

    if {$BufferSeq == {}} {return}
    if {[llength $NomSeqSel] > 1} {
	FaireLire "Please select ONE sequence below which\nsequences should be inserted !"
	return
    }

    lassign [split $NomSeqSel ,] y x

    $NomNomSeq  configure -state normal
    $NomTextSeq configure -state normal
    $NomNomSeq  configure -usecommand 0
    $NomTextSeq configure -usecommand 0

    $NomNomSeq  clear tags

    $NomTextSeq clear cache
    $NomTextSeq insert row $y [llength $BufferSeq]
    $NomNomSeq  insert row $y [llength $BufferSeq]

    incr y
    foreach e $BufferSeq {
	lassign $e n s
	set Lx [lsearch -all $LNSeqlab $n]
	if {[lindex $Lx 0] ne ""} {
	    set nf 0
	    if {[regexp "__" $n]} {
		set te [string range $n 0 [expr {[string first "__" $n]-1}]]
	    } else {
		set te $n
	    }
	    set Lx [lsearch -all -regexp $LNSeqlab $te]
	    if {[lindex $Lx 0] ne ""} {
		set nf [expr {$nf+[llength $Lx]}]
		global LockSeqs
		set n "${te}__${nf}"
		set LockSeqs($n) 1
		set LesPoidsDesSequences($n) 1.
	    }
	}
	$NomNomSeq tag cell InvNm $y,0
	set LSSeqlab [linsert $LSSeqlab $y $s]
	set LNSeqlab [linsert $LNSeqlab $y $n]
	incr y
    }

    $NomNomSeq  configure -state disabled
    $NomTextSeq configure -state disabled
    $NomNomSeq  configure -usecommand 1
    $NomTextSeq configure -usecommand 1

    update idletasks

    return
}



proc TagSeqsGroupees {} {

    global ListeSeqsGroupees
    global LNSeqlab
    global NomNomSeq

    foreach t [array names ListeSeqsGroupees] {
	set Tcol "TC$t"
	set Ls [set ListeSeqsGroupees($t)]
	foreach s $Ls {
	    set i [lsearch $LNSeqlab $s]
	    $NomNomSeq tag cell $Tcol $i,0
	}
    }

    return
}



proc SelectNomSeqSB {quoi pos} {
    global NomSeqSel NomNomSeq PosInitNom LNSeqlab

    set LNoms $LNSeqlab

    set pos [$NomNomSeq index $pos]
    lassign [split $PosInitNom ,] y1 x1 
    lassign [split $pos ,] y2 x2 

    switch $quoi {
	"une" {
	    $NomNomSeq tag cell {} [$NomNomSeq tag cell InvNm]
	    TagSeqsGroupees
	    if {[lindex $LNoms $y2] ne ""} {
		set NomSeqSel $pos
		$NomNomSeq tag cell InvNm $y2,0
		$NomNomSeq tag raise InvNm
	    }
	}
	"ctr" {
	    if {$NomSeqSel == {}} {
		SelectNomSeqSB "une" $pos
		return
	    }
	    set ix [lsearch $NomSeqSel $pos]
	    if {$ix == -1} {
		lappend NomSeqSel $pos
	    } else {
		set NomSeqSel [lreplace $NomSeqSel $ix $ix]
	    }
	    InverseTagNomSB $pos
	}
	"shf" {
	    if {$NomSeqSel == {}} {
		SelectNomSeqSB "une" $pos
		return
	    }
	    if {$y2 < $y1} {
		set tmp $y2
		set y2  $y1
		set y1  $tmp
		incr y2 -1
	    } else {
		incr y1
	    }
	    for {set i $y1} {$i <= $y2} {incr i} {
		set idx [lsearch $NomSeqSel "$i,0"]
		if {$idx == -1} {
		    lappend NomSeqSel "$i,0"
		} else {
		    set NomSeqSel [lreplace $NomSeqSel $idx $idx]
		}
		InverseTagNomSB "$i,0"
	    }
	}
	"all" {
	    $NomNomSeq clear tags
	    set NomSeqSel {}
	    set i 0
	    foreach n $LNoms {
		if {[string trim $n] eq ""} {continue}
		$NomNomSeq tag cell InvNm $i,0
		lappend NomSeqSel "$i,0"
		incr i
	    }
	}
    }

    set PosInitNom $pos

    return
}



proc SelectSeqsRegion {xt yt} {
    global LNSeqlab xIR yIR
    global NomTextSeq RegionSeqSel

    lassign [split [$NomTextSeq index @${xt},${yt}] .] y x 
    if {[string trim [lindex $LNSeqlab [expr {$y-1}]]] eq ""} {
	return
    }

    if {$x > $xIR} {
	set xmin $xIR
	set xmax $x
    } else {
	set xmin $x
	set xmax $xIR
    }
    if {$y > $yIR} {
	set ymin $yIR
	set ymax $y
    } else {
	set ymin $y
	set ymax $yIR
    }

    if {$RegionSeqSel != {}} {
	eval $NomTextSeq tag remove InvS $RegionSeqSel
    }
    set RegionSeqSel {}
    for {set j $ymin} {$j <= $ymax} {incr j} {
	if {[string trim [lindex $LNSeqlab [expr {$j-1}]]] eq ""} {continue}
	lappend RegionSeqSel "$j.$xmin" "$j.$xmax"
    }

    eval $NomTextSeq tag add InvS $RegionSeqSel
    $NomTextSeq tag raise InvS

    return
}



proc SeqsGroupeSeqlabDe s {
    global ListeSeqsGroupees

    set gcou "none"
    foreach g [array names ListeSeqsGroupees] {
	if {$s in [set ListeSeqsGroupees($g)]} {
	    set gcou $g
	    break
	}
    }

    if {$gcou eq "none"} {
	return $s
    } else {
	return [set ListeSeqsGroupees($gcou)]
    }
}



proc PousseADroite {} {
    global LNSeqlab LSSeqlab NomTextSeq

    set w $NomTextSeq
    set idx [$w index active]
    lassign [split $idx ,] il ic 

    set seqass [string trim [lindex $LNSeqlab $il]]
    if {$seqass eq ""} {return}

    $NomTextSeq configure -state normal
    $NomTextSeq configure -usecommand 0

    set LongueurTotale [LongueurDeLAlignement seqlab]

    set Lseq [SeqsGroupeSeqlabDe $seqass]
    foreach s $Lseq {
	set i [lsearch $LNSeqlab $s]
	lappend LIxSeq $i
    }

    set ifin [NextGapDesSeqs $ic $LongueurTotale $LIxSeq]
    if {$ifin == $ic} {
	$NomTextSeq configure -state disabled
	$NomTextSeq configure -usecommand 1
	return
    }
    if {$ifin < 0} {
	AjouteDesGapsATous end
	set ifin "end"
    }

    foreach i $LIxSeq {
	set s [lindex $LSSeqlab $i]
	set s [lreplace $s $ifin $ifin]
	set s [linsert $s $ic "."]
	lset LSSeqlab $i $s
    }

    if {$ifin eq "end"} {
	InitWRegle
	AfficheRegle
    }

    $NomTextSeq activate $il,[expr {$ic+1}]
    $NomTextSeq selection clear all
    $NomTextSeq selection set $il,[expr {$ic+1}]
    $NomTextSeq configure -state disabled
    $NomTextSeq configure -usecommand 1

    update idletasks

    return
}



proc PousseAGauche {} {
    global LNSeqlab LSSeqlab NomTextSeq

    set w $NomTextSeq
    $w push left
    set idx [$w index active]
    lassign [split $idx ,] il ic

    set seqass [lindex $LNSeqlab $il]
    if {$seqass eq ""} {return}

    $w configure -state normal -usecommand 0

    set Lseq [SeqsGroupeSeqlabDe $seqass]
    foreach s $Lseq {
	set i [lsearch $LNSeqlab $s]
	lappend LIxSeq $i
    }

    set im [expr {$ic-1}]
    set x $im
    set Deb 0
    set ifin [NextGapDesSeqs $im 0 $LIxSeq]
    if {$ifin == $im} {
	$w configure -state disabled -usecommand 1
	return
    }
    if {$ifin < 0} {
	AjouteDesGapsATous 0
	set ifin 0
	set Deb 1
    }

    incr ic
    if {$Deb} {incr ic}
    set im [expr {$ic-2}]
    foreach i $LIxSeq {
	set s [lindex $LSSeqlab $i]
	set s [linsert $s $ic "."]
	set s [lreplace $s $ifin $ifin]
	lset LSSeqlab $i $s
    }

    if {$Deb} {
	InitWRegle
	AfficheRegle
    }

    $w activate $il,$im
    $w selection clear all
    $w selection set active
    $w configure -state disabled -usecommand 1

    return
}


proc DumpBiotext {} {
    set Ls [$::NomTextSeq output all]
    set Ns {}
    foreach s $Ls {
	lappend Ns [split $s ""]
    }

    set ::LSSeqlab $Ns

    return
}


proc SauveTempSeqlab {{nofile 0}} {
    global FSTemp LNSeqlab LNSTemp LSSTemp NomNomSeq NomTextSeq
    
    set LNSTemp [lmap n $LNSeqlab {string trim $n}]
    set LSSTemp [$NomTextSeq output all]

    set Ln {}
    set Ls {}
    foreach n $LNSTemp s $LSSTemp {
	if {$n ne ""} {
	    lappend Ln $n
	    lappend Ls $s
	}
    }

	if {! $nofile} {
	if {! [info exists FSTemp]} {
	    set FSTemp [DemandeEtSauveFichier tfa 0]
	}
	if {$FSTemp ne ""} {
	    EcritLeTfa $FSTemp $Ln $Ls
	}
    }
    
    return
}


proc EtatLockSeqs {} {
    if {! [InSeqlabMode]} {
	return
    }

    $::NomTextSeq lock $::LockSeqs

    return
}


proc SequenceLockee s {
    global LockSeqs

    return [set LockSeqs($s)]
}


proc RemoveColumnsOfGaps {} {
    $::NomTextSeq delete colsgaps
    set ::LSSeqlab [$::NomTextSeq output all]
    set ::LSSeqlab [lmap s $::LSSeqlab {split $s ""}]
    
    update idletasks
    
    # the alignment length has changed : update the ruler
    InitWRegle
    AfficheRegle

    return
}


proc ActionSeqlab {w action} {
    # editions otherwise done by the biotext class bindings,
    # followed by the update of LSSeqlab and of the ruler
    focus $w
    set old_length [LongueurAlignement seqlab]
    set n [::tk::biotext::bufferNTimes "empty"]
    switch $action {
	"backspace"  {$w delchars [$w cursor] $n}
	"sbackspace" {$w delchars -group [$w cursor] $n}
	"left"       {$w push left}
	"right"      {$w push right}
    }
    SyncSeqlab $w $old_length

    return
}


proc SyncSeqlab {w old_length} {
    # After an edition done by the biotext widget itself
    # (BackSpace, Shift-Left/Right ...) : LSSeqlab must follow
    # the widget, and the ruler the alignment length.
    set ::LSSeqlab [lmap s [$w output all] {split $s ""}]
    if {[LongueurAlignement seqlab] != $old_length} {
	InitWRegle
	AfficheRegle
    }
    update idletasks

    return
}


proc SeqlabFont {} {
    return
    if {[QuelMode] eq "seqlab"} {
	set sze [font configure SeqFont -size]
	set wgt [font configure SeqFont -weight]
	set fam [font configure SeqFont -family]
	
	set fam [string map {" " ""} $fam]
	
	#$::NomTextSeq font family "$fam" size $sze weight $wgt
    }
    
    return
}


proc LogSeqlab {clu seq aas} {
    if {! $clu && ! $seq && ! $aas} {
	return
    }
    AuLog @begin blob
    AuLog @title Editor Log
    if {$clu} {
	AuLog @text clustering has changed
    }
    if {$seq} {
	AuLog @text insertions/deletions have been edited
    }
    if {$aas} {
	AuLog @text aa sequences have been changed
    }
    AuLog @end

    return
}


proc EmulationSeqLab {} {
    global NomNomSeq NomTextSeq LockSeqs  LNOrdali LSOrdali LNSeqlab LSSeqlab Defauts ListeSeqsGroupees
    
    # Prepare sequences for editor
    set LNtmp $LNOrdali
    set LStmp $LSOrdali
    set LNSeqlab $LNOrdali
    set LSSeqlab [lmap s $LSOrdali {split $s ""}]
    array set ListeSeqsGroupees {}
    set LockSeqs $Defauts(LockSeqs)
    
    $NomTextSeq configure -state normal
    $NomTextSeq map on
    
    bind $NomTextSeq <M> {FromMenu %W search}
    
    update idletasks
    
    return
}


proc biotextbutton1 {w x y} {
    $w index @$x,$y
    focus $w

    return
}


# recompute features limits if alignments has been edited.
#
# A feature limit at column d of sequence n :
#  - on a residue of n : column of the same residue in the new
#    alignment (residues edited : matched by MapIndexResidu)
#  - on a gap of n, in a column with residues : same place in the
#    gap run of n, counting only the columns with residues
#    (ColonneGapDeplacee), else column of the residue of another
#    sequence at column d
#  - in a column without any residue, if these columns have been
#    removed (always when leaving the Editor : RemoveColumnsOfGaps) :
#    nearest column with a residue, after for the feature start,
#    before for its stop. A feature lying only on such columns
#    disappears with them. If the new alignment still has columns
#    without residues, all the columns are counted.
# Sequence data (columns of residues) are computed once per
# sequence : it took about one minute for I_test (43000 features),
# DonnePosGS and the residues comparison being done for each limit.

proc MapIndexResidu {old new i} {
    # old, new : sequences without gaps. i : index (from 0) of a
    # residue of old. Returns the index of the same residue in new,
    # residues being matched by the common prefix and suffix
    # (exact for one insertion/deletion/substitution region)
    return [MapIndexResiduPQ [PrefixeSuffixeCommuns $old $new] $i]
}


proc PrefixeSuffixeCommuns {old new} {
    # for MapIndexResiduPQ : "" if old and new are the same,
    # otherwise {p q lo ln} : lengths of the common prefix and
    # suffix, of old and of new
    if {$old eq $new} {
	return ""
    }
    set lo [string length $old]
    set ln [string length $new]
    set p 0
    while {$p < $lo && $p < $ln && [string index $old $p] eq [string index $new $p]} {
	incr p
    }
    set q 0
    while {$q < $lo-$p && $q < $ln-$p && [string index $old end-$q] eq [string index $new end-$q]} {
	incr q
    }

    return [list $p $q $lo $ln]
}


proc MapIndexResiduPQ {pq i} {
    if {$pq eq ""} {
	return $i
    }
    lassign $pq p q lo ln
    if {$i < $p} {
	return $i
    }
    if {$i >= $lo - $q} {
	return [expr {$i + $ln - $lo}]
    }
    # inside the edited region
    return [expr {min($i, $ln-1)}]
}


proc ColonneResidu {aSeq n d} {
    # new column of the residue at column d (a residue) of n,
    # -1 if it does not exist anymore
    upvar $aSeq Seq

    set k [lsearch -sorted -integer -exact $Seq($n,Lo) $d]
    if {$k < 0} {
	return -1
    }
    set k [MapIndexResiduPQ $Seq($n,pq) $k]
    if {$k < 0 || $k >= [llength $Seq($n,Ln)]} {
	return -1
    }

    return [lindex $Seq($n,Ln) $k]
}


proc ColonneGapDeplacee {aSeq n d Cum lgnew} {
    # d is a gap column of n (with residues in other sequences).
    # Returns its column in the new alignment : in the same run of
    # gaps, at the same distance from the following residue (from
    # the last residue if d is after it), counting only the columns
    # with residues (the others are removed).
    # -1 if the run of gaps is too short now.
    upvar $aSeq Seq

    set Lo $Seq($n,Lo)
    set Ln $Seq($n,Ln)
    set nres [llength $Lo]
    if {$nres == 0 || [llength $Ln] == 0} {
	return -1
    }
    # k : first residue after column d
    set k [expr {[lsearch -sorted -integer -bisect $Lo $d] + 1}]
    if {$k < $nres} {
	set kn [MapIndexResiduPQ $Seq($n,pq) $k]
	if {$kn >= [llength $Ln]} {
	    return -1
	}
	set ck [lindex $Lo $k]
	set c [expr {[lindex $Ln $kn] - ([lindex $Cum $ck] - [lindex $Cum $d])}]
	set cmin 0
	if {$kn > 0} {
	    set cmin [expr {[lindex $Ln $kn-1] + 1}]
	}
	# no gap left before this residue : the limit can not stay
	# on a gap
	if {$c < $cmin} {
	    return -1
	}
	return $c
    }

    set ce [lindex $Lo end]
    set c [expr {[lindex $Ln end] + [lindex $Cum $d+1] - [lindex $Cum $ce+1]}]

    return [expr {min($c, $lgnew - 1)}]
}


proc NouvelleColonneLimite {aSeq aColRes n d sens Cum lgold lgnew Vides} {
    # new column of a feature limit at column d of n. sens : 1 for
    # a feature start, -1 for a feature stop. Vides : 1 if the
    # columns without residues have been removed.
    # -1 if not found.
    upvar $aSeq Seq $aColRes ColAvecRes

    if {$lgold == 0} {
	return -1
    }
    set d [expr {max(0, min($d, $lgold - 1))}]

    # removed column without any residue : nearest column
    # with a residue
    while {$Vides && ! [info exists ColAvecRes($d)]} {
	incr d $sens
	if {$d < 0 || $d >= $lgold} {
	    return -1
	}
    }

    if {[string index $Seq($n,s) $d] ni {"." " " ""}} {
	return [ColonneResidu Seq $n $d]
    }

    # gap in n : its place in the gap run, else
    # the residue of another sequence in this column
    set c [ColonneGapDeplacee Seq $n $d $Cum $lgnew]
    if {$c >= 0 || ! [info exists ColAvecRes($d)]} {
	return $c
    }
    foreach na $ColAvecRes($d) {
	if {$na ne $n} {
	    set c [ColonneResidu Seq $na $d]
	    if {$c >= 0} {
		return $c
	    }
	}
    }

    return -1
}


proc UpdateFeaturesPositions {LNref LSref LNnew LSnew} {
    # LNref LSref : names and sequences of the alignment before
    # the change, LNnew LSnew : after. Moves the features of TabSF.
    global TabSF

    # sequences data, and columns with residues
    array set Seq {}
    array set ColAvecRes {}
    set Lnoms {}
    set lgold 0
    set lgnew 0
    foreach n $LNref s $LSref {
	set n [string trim $n]
	if {$n eq "" || [set ix [lsearch -exact $LNnew $n]] == -1} {
	    continue
	}
	set snew [lindex $LSnew $ix]
	set Seq($n,s) $s
	set Seq($n,Lo) [lmap p [regexp -all -inline -indices {[^. ]} $s] {lindex $p 0}]
	set Seq($n,Ln) [lmap p [regexp -all -inline -indices {[^. ]} $snew] {lindex $p 0}]
	set Seq($n,pq) [PrefixeSuffixeCommuns [string map {"." "" " " ""} $s] [string map {"." "" " " ""} $snew]]
	set Seq($n,change) [expr {$s ne $snew}]
	foreach c $Seq($n,Lo) {
	    lappend ColAvecRes($c) $n
	}
	lappend Lnoms $n
	set lgold [expr {max($lgold, [string length $s])}]
	set lgnew [expr {max($lgnew, [string length $snew])}]
    }
    # the columns without residues have been removed if there is
    # none in the new alignment
    array set ColNew {}
    foreach n $Lnoms {
	foreach c $Seq($n,Ln) {
	    set ColNew($c) 1
	}
    }
    set Vides [expr {[array size ColNew] == $lgnew}]
    array unset ColNew
    # Cum : Cum(c) = number of columns kept before column c
    set Cum [list 0]
    set nc 0
    for {set c 0} {$c < $lgold} {incr c} {
	if {! $Vides || [info exists ColAvecRes($c)]} {
	    incr nc
	}
	lappend Cum $nc
    }

    set Lperdues {}
    foreach n $Lnoms {
	# sequence unchanged : columns of its features do not change
	if {! $Seq($n,change)} {
	    continue
	}

	foreach elt [array names TabSF "${n},*"] {
	    set ftype [lindex [split $elt ,] 1]

	    set newft {}
	    foreach ft [set TabSF($elt)] {
		DecortiqueUneFeature $ft d f color score note csys target

		set dg [NouvelleColonneLimite Seq ColAvecRes $n $d  1 $Cum $lgold $lgnew $Vides]
		set fg [NouvelleColonneLimite Seq ColAvecRes $n $f -1 $Cum $lgold $lgnew $Vides]
		if {$dg < 0 || $fg < 0 || $dg > $fg} {
		    # only on removed columns : disappears with them.
		    # Otherwise it can not be placed : reported below
		    set d0 [expr {max(0, min($d, $lgold))}]
		    set f1 [expr {max(0, min($f+1, $lgold))}]
		    if {! $Vides || [lindex $Cum $f1] - [lindex $Cum $d0] > 0} {
			lappend Lperdues "$n $ftype [expr {$d+1}]-[expr {$f+1}]"
		    }
		    continue
		}
		set nl [list fstart $dg fstop $fg fcolor $color fscore $score fnote $note fcsys $csys]
		if {$target ne ""} {
		    # kept (it was lost : written in the MACSIM file)
		    lappend nl ftarget $target
		}
		lappend newft $nl
	    }
	    set TabSF($elt) $newft
	}
    }

    # (it showed a "Can't find a residue in column" dialog for
    # each limit : hundreds of them for I_test)
    if {$Lperdues ne {}} {
	set nb [llength $Lperdues]
	set Lv [lrange $Lperdues 0 9]
	if {$nb > 10} {
	    lappend Lv "..."
	}
	FaireLire "$nb feature(s) could not be placed in the new alignment\nand were removed :\n[join $Lv \n]"
    }

    return
}


proc VerifieChangementSeqlab {LNSeqlab LSSTemp} {
    global LNOrdali LSOrdali
    
    set ChClu 0 ; # Chgt ordre seqs
    set ChSeq 0 ; # Chgt +/- gaps
    set ChAas 0 ; # Chgt dans les aas de seqs

    if {$LNOrdali != $LNSeqlab} {
	set ChClu 1
    }
    foreach n $LNSeqlab s $LSSTemp {
	if {[string trim $n] eq ""} {
	    continue
	}
	
	set in [lsearch $LNOrdali $n]
	if {$in == -1} {
	    continue
	}
	
	set so  [lindex $LSOrdali $in]
	set sd  [string map {"." "" "Z" ""} $s]
	set sdo [string map {"." "" "Z" ""} $so]
	if {$sd ne $sdo} {
	    set ChAas 1
	}
	if {$s ne $so} {
	    set ChSeq 1
	}
    }
    
    return [list $ChClu $ChSeq $ChAas]
}


proc RetourFenetreOrdali {w opt {bdis ""}} {
    global Sequences LSOrdali LNOrdali LNSeqlab LSSeqlab FrmSequence NomTextSeq wtx wxx TScrollX TScrollY NomNomSeq ListeTypesDeFeatures ListeSeqsGroupees oldMode SeqChangeDansSeqlab LNSTemp LSSTemp LongueurTotale ShowFt CurrentMode Defauts

    # avoid interactions
    bindtags $NomNomSeq {}
    bindtags $NomTextSeq {}
    bind $NomNomSeq  ""
    bind $NomTextSeq ""
    update idletasks

    # disable the 'Dismiss' button
    if {$bdis ne ""} {
	$bdis configure -command ""
    }
    update idletasks
    
    FaireAttendre "Please wait ...\n\nLeaving Editor mode ..."

    trace remove variable ShowFt write ShowHideFeatureInSeqlab

    set SeqChangeDansSeqlab 0
    if {$opt ne "dismiss"} {
	# Just to be sure ...
	RemoveColumnsOfGaps
	SauveTempSeqlab 1
    
	lassign [VerifieChangementSeqlab $LNSeqlab $LSSTemp] ChClu ChSeq ChAas
	LogSeqlab $ChClu $ChSeq $ChAas
	set lgt [LongueurDeLAlignement seqlab]
	set seqEmpty [string repeat " " $lgt]

	# Gaps positions changed in sequences : move the features.
	# The reference is the alignment BEFORE edition (LNOrdali,
	# LSOrdali and Sequences are not modified yet)
	if {$ChSeq} {
	    UpdateFeaturesPositions $LNOrdali $LSOrdali $LNSTemp $LSSTemp
	}

	# Order, number (cut/paste) or gaps of sequences have changed :
	# re-assign globals variables from the editor
	if {$ChClu || $ChSeq} {
	    set LNOrdali $LNSTemp
	    unset -nocomplain Sequences
	    set LSOrdali {}
	    foreach n $LNOrdali s $LSSTemp {
		if {[string trim $n] eq ""} {
		    lappend LSOrdali $seqEmpty
		} else {
		    lappend LSOrdali $s
		    set Sequences([string trim $n]) $s
		}
	    }
	    VueEditee 1
	}

	# Sequences order has changed
	if {$ChClu} {
	    set SeqChangeDansSeqlab 1
	    FlagFeatureScore 1
	    MetAJourGroupes
	}

	if {$ChSeq} {
	    # Aminoacids in sequences have changed
	    if {$ChAas} {
		CalculeComposition
		CalculePI
		CalculeMolecularWeight

		LogSeqInfoGlobales
		LogLesCompositions
	    }
	}
	
	if {$ChClu || $ChSeq} {
	    CalculeLesPCIDuMac
	    LogPCI
	}
    }
    unset -nocomplain ListeSeqsGroupees
    
    FaireLaSuite

    destroy $w

    $NomTextSeq map off
    BindModeNormal
    BindMenuItems
    
    # Returning from seqlab mode
    ChangeMode $CurrentMode
    InSeqlabMode 0

    ChangeNomsAff $Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs
    MetAJourGroupes    

    return
}


proc TouchePressee {w t} {
    global LSSeqlab LNSeqlab

    set idx [$w index]
    lassign [split $idx ,] il ic
    set s [string trim [lindex $LNSeqlab $il]]
    if {$s eq ""} {return}

    set sq [lindex $LSSeqlab $il]
    set sq [lreplace $sq $ic $ic [string toupper $t]]
    lset LSSeqlab $il $sq

    $w chars $il,[expr {$ic+1}] $t

    return
}


proc NextGapDesSeqs {idep fin iseqs} {
    global LSSeqlab

    set def -1
    set sgap [string repeat "." [llength $iseqs]]
    set inext $def
    if {$fin > $idep} {
	set ajt 1
	set op "<="
    } else {
	set ajt -1
	set op ">="
    }

    set i $idep
    while {$i != $fin} {
	set Pilier ""
	foreach j $iseqs {
	    append Pilier [lindex [lindex $LSSeqlab $j] $i]
	}

	if {$Pilier eq $sgap} {
	    set inext $i
	    break
	}

	incr i $ajt
    }

    return $inext
}



proc AjouteDesGaps {{idp ""} {nb 1}} {
    global NomTextSeq LNSeqlab LSSeqlab ListeSeqsGroupees

    if {$idp eq ""} {set idp [$NomTextSeq index active]}
    lassign [split $idp ,] il ic

    set seqass [lindex $LNSeqlab $il]
    if {$seqass eq ""} {return}

    set Lseq [SeqsGroupeSeqlabDe $seqass]
    foreach s $Lseq {
	lappend LIxSeq [lsearch $LNSeqlab $s]
    }

    AjouteDesGapsATous end $nb

    set Rs [lrepeat $nb "."]
    foreach i $LIxSeq {
	set s [lindex $LSSeqlab $i]
	set s [linsert $s $ic {*}$Rs]
	set s [lrange $s 0 end-$nb]
	lset LSSeqlab $i $s
    }

    EnleveColonnesGaps

    return
}



proc AjouteDesGapsATous {pos {nb 1}} {
    global LSSeqlab LNSeqlab NomTextSeq

    $NomTextSeq insert cols $pos $nb

    set Rs [lrepeat $nb "."]
    foreach s $LSSeqlab n $LNSeqlab {
	if {[string trim $n] ne ""} {
	    set s [linsert $s $pos {*}$Rs]
	}
	lappend new $s
    }

    set LSSeqlab $new

    return
}



proc TrieGroupesSeqlab {a b} {
    if {[string range $a 1 end] >= [string range $b 1 end]} {
	return 1
    } elseif {[string range $a 1 end] == [string range $b 1 end]} {
	return 0
    } else {
	return -1
    }
}


proc CreeSeqlabGroup {gcou Lseqi} {
    global LNSeqlab ListeSeqsGroupees NomNomSeq NomTextSeq
    
    set iGrp [string range $gcou 1 end]
    # yw : y dans widget, yl y dans LNSeqlab
    set Liy {}
    set Totag {}
    foreach {s yw yl g} $Lseqi {
	lappend Liy $yl
	lappend ListeSeqsGroupees($gcou) $s
	lappend Totag $yw.0 $yw.end
    }
    # for Noms colors them according to group
    $NomNomSeq tag add TC$gcou {*}$Totag
    # for sequences, create a group
    $NomTextSeq group $iGrp $Liy

    return
}


proc DetruitSeqlabGroup {g} {
    global LNSeqlab ListeSeqsGroupees NomNomSeq NomTextSeq
    
    set Lixun {}
    set Ltags {}
    foreach s $ListeSeqsGroupees($g) {
	set ix [lsearch $LNSeqlab $s]
	lappend Lixun $ix
	set y [expr {$ix+1}]
	lappend Ltags $y.0 $y.end
    }
    if {$Ltags != {} } {
	$NomNomSeq  tag remove TC$g {*}$Ltags
	$NomTextSeq ungroup $Lixun
    }
    unset -nocomplain ListeSeqsGroupees($g)
    
    return
}

    
proc GroupeLesSequences {} {
# Plusieurs possibilites :
    # 1 on supprime tous les groupes touches, 
    # et on cree un nouveau groups avec les sequences selectionness
    # ==> 'Delete then Create'
    # 
    # 2 on cree un nouveau groupe avec les seqs selectionnees et on les enleve de leur groupe d'origine
    # ==> 'Keep and Create'
    # 
    # 3 on fait un groupe avec les seqs selectionnes + toutes celles des groupes qu'elles touchent
    # ==> 'fusion'

    global NomNomSeq NomTextSeq NomSeqSel Couleurs ListeSeqsGroupees LNSeqlab WNSeqlab

    if {[llength $NomSeqSel] < 2} {
	FaireLire "Please select at least 2 sequences first !"
	return
    }

    # 1 : find a name for the new group
    set i 1
    set gcou "G$i"
    while {[info exists ListeSeqsGroupees($gcou)]} {
	incr i
	set gcou "G$i"
    }
    set iGrp $i
    set bcoul [CouleurO2Ordali [CouleurDuGroupe $iGrp]]

    # define tag for new group
    $NomNomSeq configure -state normal
    $NomNomSeq tag configure TC$gcou -background $bcoul -foreground black

    # 2 : analyse selected sequences
    set Liy {} ; set Ly {}
    set InGroups {}
    # yw : y dans widget, yl y dans LNSeqlab
    set Lseqi {}
    foreach e $NomSeqSel {
	lassign [split $e .] yw x 
	lappend Lyw $yw
	set yl [expr {$yw-1}]
	lappend Lyl $yl
	set seqass [lindex $LNSeqlab $yl]
	set ing "g0"
	foreach g [array names ListeSeqsGroupees] {
	    if {$seqass in [set ListeSeqsGroupees($g)]} {
		lappend InGroups $seqass $yw $yl $g
		set ing $g
		break
	    }
	}
	lappend Lseqi $seqass $yw $yl $ing
    }

    ClearSelectionNoms
    if {[llength $InGroups] == 0} {
	# creation simple d'un groupe
	CreeSeqlabGroup $gcou $Lseqi
	set NomSeqSel {}
	$NomNomSeq configure -state disabled
	
	return
    }
    
    # Selected sequences already belong to a/some 
    # groups. Merge or create new group
    # 
    # 1 how many groups are touched ?
    set Lg {}
    foreach {s yw yl g} $InGroups {
	lappend Lg $g
    }
    set Lg [lsort -unique -dictionary $Lg]
    
    set choix [tk_dialog .chx "Merge/Create" "Some sequences already belong to group(s).\nDo you want to :" "" -1 "Delete group(s) then Create a new one" "Create group with selected seq." "Fuse group(s)" "Cancel"]
    
    # Create and Delete
    if {$choix == 0} {
	# Create and Delete
	# ungroup all seqs of selected groups
	set Lixun {}
	foreach g $Lg {
	    DetruitSeqlabGroup $g
	}
	
	# puts selected seqs in a new group
	CreeSeqlabGroup $gcou $Lseqi
    } elseif {$choix == 1} {
	# Create and Keep
	# remove seqs from their actual group
	set Lixun {} ; set Ltag {}
	foreach {s yw yl g} $InGroups {
	    lappend Lixun $yl
	    $NomNomSeq tag remove TC$g $yw.0 $yw.end
	    set ig [lsearch -exact $ListeSeqsGroupees($g) $s]
	    set ListeSeqsGroupees($g) [lreplace $ListeSeqsGroupees($g) $ig $ig]
	    update
	}
	$NomTextSeq ungroup $Lixun

	# check for groups with only one sequence
	foreach g $Lg {
	    if {[llength $ListeSeqsGroupees($g)] <= 1} {
		DetruitSeqlabGroup $g
	    }
	}
	
	# create a new group with selected seqs
	CreeSeqlabGroup $gcou $Lseqi
    } else {
	# Fusion
	# search for group with lower name
	set pg [lindex $Lg 0]
	# delete groups
	set Lfuse {}
	foreach g [lrange $Lg 1 end] {
	    # recup index des seqs du group
	    # celui ci sera detruit.
	    foreach s $ListeSeqsGroupes($g) {
		if {$s in $Lseqi} {continue}

		set il [lsearch -exact $LNSeqlab $s]
		set iw [expr {$il + 1}]
		lappend Lfuse $s $iw $il $g
	    }
	    DetruitSeqlabGroup $g
	}
	# rajoute seqs qui n'etaient pas dans 
	# un group
	foreach {s iw il g} $Lseqi {
	    if {$g eq "g0"} {
		lappend Lfuse $s $iw $il $g
	    }
	}

	# add all to lower group
	set Lyl {} ; set Ltag {}
	foreach {s yw yl gi} $Lfuse {
	    lappend Lyl $yl
	    lappend ListeSeqsGroupees($pg) $s
	    lappend Ltag $yw.0 $yw.end
	}
	# add seq with no group
	foreach {s yw yl g} $Lseqi {
	    if {$g eq "g0"} {
		lappend Lyl $yl
		lappend ListeSeqsGroupees($pg) $s
		lappend Ltag $yw.0 $yw.end
	    }
	}
	
	if {$Ltag != {}} {
	    set ipg [string range $pg 1 end]
	    $NomNomSeq tag add TC$pg {*}$Ltag
	    $NomTextSeq group $ipg $Lyl
	}
    }
    
    set NomSeqSel {}
    $NomNomSeq configure -state disabled

    return
}


proc DegroupeLesSequences {} {
    global NomSeqSel NomTextSeq NomNomSeq Couleurs ListeSeqsGroupees LNSeqlab

    if {[llength $NomSeqSel] == 0} {
	FaireLire "Beware !\nSelect sequences to ungroup first !"
	return
    }

    set Lyl {}
    set c -1
    # yw : pos in widget, yl pos in LNSeqlab
    foreach i $NomSeqSel {
	lassign [split $i .] yw x 
	set yl [expr {$yw-1}]
	set seqass [lindex $LNSeqlab $yl]
	set c -1
	foreach g [array names ListeSeqsGroupees] {
	    if {$seqass in [set ListeSeqsGroupees($g)]} {
		set c [lsearch [set ListeSeqsGroupees($g)] $seqass]
		break
	    }
	}
	if {$c == -1} {
	    continue
	}

	lappend Lyl $yl
	set LseqG [set ListeSeqsGroupees($g)]
	set LseqG [lreplace $LseqG $c $c]
	set ListeSeqsGroupees($g) $LseqG

	$NomNomSeq tag remove TC$g $yw.0 $yw.end
    }
    $NomTextSeq ungroup $Lyl
    update

    foreach g [array names ListeSeqsGroupees] {
	if {[llength [set ListeSeqsGroupees($g)]] <= 1} {
	    DetruitSeqlabGroup $g
	}
    }

    #ClearSelectionNoms
    $NomNomSeq configure -state disabled

    return
}


proc EnleveColonnesGaps {{LNom ""} {LSeq ""}} {
    global LNSeqlab LSSeqlab LNOrdali LSOrdali

    set qMode [QuelMode]
    if {$LNom eq ""} {
	if {$qMode eq "seqlab"} {
	    set LNom $LNSeqlab
	    set LSeq $LSSeqlab
	} else {
	    set LNom $LNOrdali
	    set LSeq $LSOrdali
	}
    }
    set LSeqIn $LSeq

    if {$qMode ne "seqlab"} {
	set new {}
	foreach s $LSeq {
	    lappend new [split $s ""]
	}
	set LSeq $new
    }

    # Longueur de sequence
    set i -1
    foreach n $LNom {
	incr i
	if {[string trim $n] eq ""} {continue}
	set Long [llength [lindex $LSeq $i]]
	break
    }

    for {set i 0} {$i < $Long} {incr i} {
	set p$i 1
    }

    foreach s $LSeq n $LNom {
	if {[string trim $n] eq ""} {continue}

	set i 0
	foreach c $s {
	    if {$c ne "."} {set p$i 0}
	    incr i
	}
    }

    set lnew {} ; set Li {}
    set NOtes 0 ; set ltmp $LSeq
    for {set i 0} {$i < $Long} {incr i} {
	if {[set p$i]} {lappend Li $i}
    }

    set Li [lreverse [lsort -integer $Li]]
    set NOtes [llength $Li]
    if {! $NOtes} {return $LSeqIn}

    foreach s $LSeq n $LNom {
	if {[string trim $n] ne ""} {
	    foreach i $Li {
		set s [lreplace $s $i $i]
	    }
	}
	if {$qMode ne "seqlab"} {
	    set s [join $s ""]
	}
	lappend lnew $s
    }
    set LSeq $lnew

    return $LSeq
}



proc AfficheGroupesDansSeqlab {} {

    global LNSeqlab
    global LSSeqlab
    global NomTextSeq
    global NomNomSeq
    global LNDG
    global SDG

    $NomNomSeq configure -state normal

    set Q 1
    set P 0
    set LStmp {}
    set LNtmp {}
    foreach g $LNDG {
	if {$g == "GroupeToutLeMonde"} {continue}
	$NomTextSeq insert $Q.0 " \n"
	$NomNomSeq  insert $Q.0 " \n"
	set LNSeqlab [linsert $LNSeqlab $P " "]
	lappend LStmp " "
	lappend LNtmp " "
	incr Q
	incr P

	foreach s [set SDG($g)] {
	    set i [lsearch $LNSeqlab $s]
	    set y [expr {$i+1}]
	    set dmpT  [$NomTextSeq dump -tag $y.0 $y.0 lineend]
	    set LtagT [TagsDuDump $dmpT]
	    set Seq   [$NomTextSeq get $y.0 "$y.0 lineend"]

	    lappend LNtmp $s
	    lappend LStmp $Seq

	    set LNSeqlab [lreplace $LNSeqlab $i $i]
	    set LNSeqlab [linsert $LNSeqlab $P $s]
	    $NomTextSeq delete $y.0 [expr {$y+1}].0
	    $NomTextSeq insert $Q.0 "${Seq}\n"
	    $NomNomSeq  delete $y.0 [expr {$y+1}].0
	    if {[regexp {^PDB_[0-9]} $s]} {
		set t PDB
	    } else {
		set t ""
	    }
	    $NomNomSeq  insert $Q.0 "$s\n" $t
	    foreach {t x1 x2} $LtagT {
		$NomTextSeq tag add $t $Q.$x1 $Q.$x2
	    }
	    incr Q
	    incr P
	}
    }

    set LNSeqlab $LNtmp
    set LSSeqlab $LStmp

    $NomNomSeq configure -state disabled

    return
}


proc fid {} {
    DecortiqueUnTFA TATATA.tfa Lta Tta
    DecortiqueUnTFA test.tfa Lts Tts
    foreach s $Lta {
	set sa $Tta($s)
	set st $Tts($s)
	if {$sa ne $st} {puts "ori $s diff"}
	set sa [string map {"\." ""} $sa]
	set st [string map {"\." ""} $st]
	if {$sa ne $st} {
	    puts "sa != st"
	    puts "[llength $sa]\n$sa"
	    puts "[llength $st]\n$st"
	} else {
	    puts "[string length $sa] [string length $st]"
	}
    }

    return
}


proc ClearingFeatureInSeqlab {} {
    # hide all currently displayed features
    global ShowFt

    # the trace on ShowFt (ShowHideFeatureInSeqlab) toggles the
    # feature : only the checked (displayed) ones are unchecked
    foreach {ft v} [array get ShowFt] {
	if {$v} {
	    set ShowFt($ft) 0
	}
    }
	
    return
}
    

proc ShowHideFeatureInSeqlab {{n1 ""} {n2 ""} {op ""}} {
    global ShowFt NomTextSeq

    # special cases :

    # show/hide
    if {$n1 eq "Show"} {
	$NomTextSeq tag state on
	return
    }
    if {$n1 eq "Hide"} {
	$NomTextSeq tag state off
	return
    }
    
    # show/hide a given feature.
    AppliqueFeature $n2
    
    return
}


proc GetActiveFeaturesInSeqlab {} {
    global ListeTypeseDeFeatures ShowFt FrmBtnFea
    
    if {[QuelMode] ne "feature"} {
	return
    }
    
    set Lfeats [LesBoutonsEnfonces]
    foreach ft $Lfeats {
	set ShowFt($ft) 1
    }
    
    return
}

