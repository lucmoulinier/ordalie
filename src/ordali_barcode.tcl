

#
#
# --- ordali_barcode.tcl
#
# Barcode : schematic view of the current snapshot. One lane per
# group of sequences (or one lane for the whole alignment) where
# the columns filled by residues in at least DS(Seuil) % of the
# sequences of the group are drawn in dark grey.
# Options : a feature, the PFAM domains, the PDB structures of
# each group.
#

proc BarcodeAlignment {} {
    global DS

    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {! [winfo exists .barcode]} {
	unset -nocomplain DS
	set DS(Pfam)    0
	set DS(AddPDB)  0
	set DS(AddGrps) 1
	set DS(FeatSel) "None"
	set DS(Seuil)   10
	BarcodeFrame
    } else {
	raise .barcode
	BarcodeMetAJourFeatures
    }

    BarcodeView

    return
}


proc BarcodeClose {} {
    global DS

    destroy .barcode
    unset -nocomplain DS

    return
}


proc BarcodeFrame {} {
    global DS

    set DS(StartX) 20
    set DS(StartY) 40
    set DS(LaneW)  800
    set DS(LaneH)  30
    set DS(YOffset) 10

    if {"FigF" ni [font names]} {
	font create FigF   -family Helvetica -size 14
	font create FigPDB -family Helvetica -size 10 -slant italic
    }
    if {"FPfam" ni [font names]} {
	font create FPfam -family Helvetica -size 10
    }

    set w .barcode
    set DS(Toplevel) $w
    toplevel $w
    wm title $w "Barcode"
    wm protocol $w WM_DELETE_WINDOW BarcodeClose

    frame $w.css
    grid $w.css -row 0 -column 0 -sticky news
    grid columnconfig $w 0 -weight 1
    grid rowconfig    $w 0 -weight 1

    set Can $w.css.can
    set DS(Can) $Can
    canvas $Can \
	-width 900 \
	-height 420 \
	-yscrollcommand "$w.css.scy set" \
	-xscrollcommand "$w.css.scx set" \
	-background white
    scrollbar $w.css.scy \
	-orient vertical \
	-command "$Can yview"
    scrollbar $w.css.scx \
	-orient horizontal \
	-command "$Can xview"
    grid $Can       -row 0 -column 0 -sticky news
    grid $w.css.scy -row 0 -column 1 -sticky ns
    grid $w.css.scx -row 1 -column 0 -sticky ew
    grid rowconfig    $w.css 0 -weight 1
    grid columnconfig $w.css 0 -weight 1

    frame $w.cb
    grid $w.cb -row 1 -column 0 -sticky ew -pady 5
    label $w.cb.lft \
	-text "Feature :"
    set DS(Combo) $w.cb.cbox
    ttk::combobox $w.cb.cbox \
	-state readonly \
	-textvariable DS(FeatSel)
    bind $w.cb.cbox <<ComboboxSelected>> BarcodeView
    BarcodeMetAJourFeatures
    checkbutton $w.cb.pfam \
	-text " PFAM " \
	-onvalue 1 \
	-offvalue 0 \
	-variable DS(Pfam) \
	-command BarcodeView
    checkbutton $w.cb.pdb \
	-text " PDB " \
	-onvalue 1 \
	-offvalue 0 \
	-variable DS(AddPDB) \
	-command BarcodeView
    checkbutton $w.cb.grp \
	-text " Groups " \
	-onvalue 1 \
	-offvalue 0 \
	-variable DS(AddGrps) \
	-command BarcodeView
    button $w.cb.print \
	-text "Print" \
	-background yellow \
	-command [list PrintCanvas $Can png]
    button $w.cb.close \
	-text "Close" \
	-background green1 \
	-command BarcodeClose
    grid $w.cb.lft   -row 0 -column 0 -padx {20 2}
    grid $w.cb.cbox  -row 0 -column 1 -padx {2 20}
    grid $w.cb.pfam  -row 0 -column 2
    grid $w.cb.pdb   -row 0 -column 3
    grid $w.cb.grp   -row 0 -column 4
    grid $w.cb.print -row 0 -column 5
    grid $w.cb.close -row 0 -column 6 -padx 20
    grid columnconfig $w.cb all -weight 1

    # drag the drawing
    bind $Can <ButtonPress-1> {%W scan mark %x %y}
    bind $Can <B1-Motion> {%W scan dragto %x %y 1}

    MesCouleurs $w
    FenetreAuCentre $w
    update idletasks
    
    return
}


proc BarcodeMetAJourFeatures {} {
    # features of the snapshot in the combobox
    global DS ListeTypesDeFeatures

    set Lfeat [list "None"]
    if {[info exists ListeTypesDeFeatures]} {
	foreach f $ListeTypesDeFeatures {
	    if {$f ni {"Clear" "None"}} {
		lappend Lfeat $f
	    }
	}
    }
    if {$DS(FeatSel) ni $Lfeat} {
	set DS(FeatSel) "None"
    }
    $DS(Combo) configure -values $Lfeat -width [PlusLongEltDe $Lfeat]

    return
}


proc BarcodeLesGroupes {} {
    # lanes : {name {sequences}} for each group, or the whole
    # alignment if Groups is unchecked or if there is no group
    global DS LNDG SDG LNOrdali ListePDB

    set Lg {}
    if {$DS(AddGrps)} {
	foreach g $LNDG {
	    if {$g in {"GroupeToutLeMonde" "bidon" "grise"}} {
		continue
	    }
	    if {[info exists SDG($g)] && $SDG($g) != {}} {
		# name given by "Clusters Names" if any
		set nom $g
		if {[info exists SDG(Equiv,$g)] && $SDG(Equiv,$g) ne ""} {
		    set nom $SDG(Equiv,$g)
		}
		lappend Lg [list $nom $SDG($g)]
	    }
	}
    }
    if {$Lg == {}} {
	set Ls {}
	foreach n $LNOrdali {
	    if {[string trim $n] ne ""} {
		lappend Ls $n
	    }
	}
	set Lg [list [list "all" $Ls]]
    }

    return $Lg
}


proc BarcodeView {args} {
    # draw everything again
    global DS LNOrdali LSOrdali

    if {! [winfo exists .barcode]} {
	return
    }
    set Can $DS(Can)
    $Can delete all

    # aligned sequences of the current snapshot
    array unset DS "Seq,*"
    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] ne ""} {
	    set DS(Seq,$n) $s
	}
    }
    set DS(AliLg) [LongueurDeLAlignement]
    set DS(Lanes) [BarcodeLesGroupes]

    BarcodeBackFigure
    BarcodeTraceAliFig
    if {$DS(FeatSel) ne "None"} {
	BarcodeTraceFeatureFig
    }
    if {$DS(Pfam)} {
	BarcodeDrawPfam
    }

    # the whole drawing can be scrolled
    lassign [$Can bbox all] x1 y1 x2 y2
    if {$x1 ne ""} {
	set x1 [expr {$x1-20}] ; set y1 [expr {$y1-20}]
	set x2 [expr {$x2+20}] ; set y2 [expr {$y2+20}]
	$Can configure -scrollregion [list $x1 $y1 $x2 $y2]
	# window wide / high enough for the drawing (screen limit)
	set wmax [expr {int(0.9*[winfo screenwidth $Can])}]
	set hmax [expr {int(0.7*[winfo screenheight $Can])}]
	$Can configure \
	    -width  [expr {min(max(int($x2-$x1),600),$wmax)}] \
	    -height [expr {min(max(int($y2-$y1),200),$hmax)}]
	$Can xview moveto 0
	$Can yview moveto 0
	# FenetreAuCentre fixed the size : the window takes the size
	# of the drawing, and stays inside the screen
	set w [winfo toplevel $Can]
	wm geometry $w ""
	update idletasks
	scan [wm geometry $w] "%dx%d+%d+%d" wc hc xw yw
	set xw [expr {max(0,min($xw,[winfo screenwidth $w]-[winfo reqwidth $w]-10))}]
	set yw [expr {max(0,min($yw,[winfo screenheight $w]-[winfo reqheight $w]-40))}]
	wm geometry $w +$xw+$yw
	# wait for the new size (Print grabs the window)
	update
    }

    return
}


proc BarcodeX {col} {
    # x of the left side of alignment column col (0 based)
    global DS

    return [expr {$DS(X0) + double($DS(LaneW))*$col/$DS(AliLg)}]
}


proc BarcodeBackFigure {} {
    # one grey lane per group, with its name and its PDB
    global DS ListePDB

    set Can $DS(Can)

    # room for the names
    set wn 0
    foreach lane $DS(Lanes) {
	set n [lindex $lane 0]
	set l [font measure FigF "$n ([llength [lindex $lane 1]])"]
	if {$l > $wn} {
	    set wn $l
	}
    }
    set DS(X0) [expr {$DS(StartX) + $wn + 10}]
    set x1 $DS(X0)
    set x2 [expr {$x1 + $DS(LaneW)}]
    set y1 $DS(StartY)

    # start - end col. number of the alignment
    $Can create text $x1 $y1 -anchor s -text "1" -font FigF -tags num
    $Can create text $x2 $y1 -anchor s -text $DS(AliLg) -font FigF -tags num

    foreach lane $DS(Lanes) {
	lassign $lane n Ls
	set y2 [expr {$y1 + $DS(LaneH)}]
	$Can create rectangle $x1 $y1 $x2 $y2 \
	    -fill LightGrey \
	    -outline black \
	    -tags [list lane "R$n"]
	set yn [expr {($y1 + $y2)/2.}]
	$Can create text [expr {$x1 - 10}] $yn \
	    -anchor e \
	    -font FigF \
	    -text "$n ([llength $Ls])" \
	    -tags [list "T$n"]
	if {$DS(AddPDB)} {
	    set Lp {}
	    foreach s $Ls {
		if {[info exists ListePDB] && $s in $ListePDB} {
		    lappend Lp [regsub -nocase {^PDB_} $s ""]
		}
	    }
	    if {$Lp != {}} {
		$Can create text [expr {$x2 + 10}] $yn \
		    -text [join $Lp " "] \
		    -anchor w \
		    -font FigPDB \
		    -tags pdb
	    }
	}
	set DS(Y,$n) [list $y1 $y2]
	set y1 [expr {$y2 + $DS(YOffset)}]
    }

    return
}


proc BarcodeTraceAliFig {} {
    # dark blocks : columns with residues in at least DS(Seuil) %
    # of the sequences of the group
    global DS

    set Can $DS(Can)
    foreach lane $DS(Lanes) {
	lassign $lane n Ls
	lassign $DS(Y,$n) y1 y2
	set Lseq {}
	foreach s $Ls {
	    if {[info exists DS(Seq,$s)]} {
		lappend Lseq $DS(Seq,$s)
	    }
	}
	set ns [llength $Lseq]
	if {! $ns} {
	    continue
	}
	set seuil [expr {$DS(Seuil)*$ns/100.}]
	set deb -1
	for {set i 0} {$i <= $DS(AliLg)} {incr i} {
	    set ok 0
	    if {$i < $DS(AliLg)} {
		set nr 0
		foreach s $Lseq {
		    if {[string index $s $i] ni {"." " " "-" ""}} {
			incr nr
		    }
		}
		set ok [expr {$nr > 0 && $nr >= $seuil}]
	    }
	    if {$ok && $deb == -1} {
		set deb $i
	    } elseif {! $ok && $deb != -1} {
		$Can create rectangle [BarcodeX $deb] $y1 [BarcodeX $i] $y2 \
		    -fill DarkSlateGrey \
		    -outline DarkSlateGrey \
		    -tags ali
		set deb -1
	    }
	}
    }

    return
}


proc BarcodeTraceFeatureFig {} {
    # items of the selected feature, for the sequences of each lane
    global DS TabSF

    set Can $DS(Can)
    set ft $DS(FeatSel)
    foreach lane $DS(Lanes) {
	lassign $lane n Ls
	lassign $DS(Y,$n) y1 y2
	# lower third of the lane : the barcode stays visible
	set y1 [expr {$y2 - $DS(LaneH)/3.}]
	set Lfaf {}
	foreach nom $Ls {
	    if {! [info exists TabSF($nom,$ft)]} {
		continue
	    }
	    foreach e $TabSF($nom,$ft) {
		DecortiqueUneFeature $e d f c tmp note
		lappend Lfaf [list $d $f $c]
	    }
	}
	foreach e [lsort -unique $Lfaf] {
	    lassign $e d f c
	    $Can create rectangle [BarcodeX $d] $y1 [BarcodeX [expr {$f+1}]] $y2 \
		-fill $c \
		-outline $c \
		-tags feat
	}
    }

    return
}


proc BarcodeTraitePfam {n} {
    # PFAM note -> {Id text}
    if {[regexp {^PROP_} $n]} {
	set n [string range $n 5 end]
    }
    set i [string first "_from_" $n]
    if {$i != -1} {
	set n [string range $n 0 $i-1]
    }

    set Id [string range $n 0 6]
    set tx [string range $n 8 end]

    return [list $Id $tx]
}


proc BarcodeDrawPfam {} {
    # PFAM domains : a coloured box around the lanes where the
    # domain is present, and its name above the lanes
    global DS TabSF

    set Can $DS(Can)

    # domains : extent in each lane
    set Lid {}
    foreach lane $DS(Lanes) {
	lassign $lane n Ls
	foreach nom $Ls {
	    foreach k [array names TabSF "$nom,PFAM*"] {
		foreach e $TabSF($k) {
		    DecortiqueUneFeature $e d f c tmp note
		    lassign [BarcodeTraitePfam $note] Id tx
		    if {$Id eq ""} {
			continue
		    }
		    if {$Id ni $Lid} {
			lappend Lid $Id
			set Pf($Id,col) $c
			set Pf($Id,txt) $tx
			set Pf($Id,dmin) $d
			set Pf($Id,fmax) $f
		    }
		    set Pf($Id,dmin) [expr {min($Pf($Id,dmin),$d)}]
		    set Pf($Id,fmax) [expr {max($Pf($Id,fmax),$f)}]
		    if {! [info exists Pf($Id,$n)]} {
			set Pf($Id,$n) [list $d $f]
		    } else {
			lassign $Pf($Id,$n) d0 f0
			set Pf($Id,$n) [list [expr {min($d0,$d)}] [expr {max($f0,$f)}]]
		    }
		}
	    }
	}
    }
    if {$Lid == {}} {
	return
    }

    # boxes around the lanes
    foreach Id $Lid {
	foreach lane $DS(Lanes) {
	    set n [lindex $lane 0]
	    if {! [info exists Pf($Id,$n)]} {
		continue
	    }
	    lassign $Pf($Id,$n) d f
	    lassign $DS(Y,$n) y1 y2
	    $Can create rectangle [BarcodeX $d] [expr {$y1-4}] [BarcodeX [expr {$f+1}]] [expr {$y2+4}] \
		-fill $Pf($Id,col) \
		-outline $Pf($Id,col) \
		-tags pfam
	}
    }
    $Can lower pfam

    # names above the lanes, on several rows if they overlap
    set Lrows {}
    set hl [font metrics FPfam -linespace]
    foreach Id [lsort -command [list BarcodeCmpPfam [array get Pf]] $Lid] {
	set xd [BarcodeX $Pf($Id,dmin)]
	set xf [BarcodeX [expr {$Pf($Id,fmax)+1}]]
	set txt [string map {_ " "} [string trim "$Id $Pf($Id,txt)"]]
	set wt [font measure FPfam $txt]
	set xc [expr {($xd+$xf)/2.}]
	set xg [expr {$xc - $wt/2. - 2}]
	set xr [expr {$xc + $wt/2. + 2}]
	# first row where it fits
	set r 0
	while {$r < [llength $Lrows] && $xg < [lindex $Lrows $r]} {
	    incr r
	}
	if {$r == [llength $Lrows]} {
	    lappend Lrows $xr
	} else {
	    lset Lrows $r $xr
	}
	set y [expr {$DS(StartY) - 20 - $r*($hl+4)}]
	set id [$Can create text $xc $y -text $txt -font FPfam -fill black -anchor s -tags pfamtxt]
	lassign [$Can bbox $id] bx1 by1 bx2 by2
	set ir [$Can create rectangle $bx1 $by1 $bx2 $by2 -fill $Pf($Id,col) -outline $Pf($Id,col) -tags pfamtxt]
	$Can itemconfigure $id -fill [CouleurTexteAnnotation $Pf($Id,col)]
	$Can raise $id
    }

    return
}


proc BarcodeCmpPfam {lPf a b} {
    # PFAM domains sorted by start
    array set Pf $lPf
    return [expr {$Pf($a,dmin) - $Pf($b,dmin)}]
}
