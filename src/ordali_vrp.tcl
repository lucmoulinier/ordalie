
# Dessine VRP des sequences selectionnees
#
# Adapte de vrpshow, Jean-Marie Wurtz
#

proc SetLabelStyle { w } {
    global Vrp

candidature    set style {}
    lappend style $Vrp(style1)
    if { $Vrp(styleItalic) } { lappend style italic }
    if { $Vrp(styleRoman) } { lappend style roman }
    if { $Vrp(styleUnderline) } { lappend style underline }

    set Vrp(fontStyle) [join $style " "]
    set Vrp(font) "$Vrp(fontFamily) $Vrp(fontSize) $Vrp(fontStyle)"

    $w.c itemconfigure label -font $Vrp(font)

    return
}


proc SetLabelSize { w size } {
    global Vrp

    set Vrp(fontSize) $size
    set Vrp(font) "$Vrp(fontFamily) $Vrp(fontSize) $Vrp(fontStyle)"
    $w.c itemconfigure label -font $Vrp(font)

    return
}


proc SetDotColor { w } {
    global Vrp

    set color [tk_chooseColor \
	    -title "Choose a dot color" \
	    -parent $w \
	    -initialcolor $Vrp(colDot)]

    if { ![string compare $color ""] == 0 } {
	set Vrp(colDot) $color
	$w.c itemconfigure dot -fill $color
    }

    return
}


proc SetLabelColor { w } {
    global Vrp

    set color [tk_chooseColor \
	    -title "Choose a label color" \
	    -parent $w \
	    -initialcolor $Vrp(colLabel)]

    if { ![string compare $color ""] == 0 } {
	set Vrp(colLabel) $color
	$w.c itemconfigure label -fill $color
    }

    return
}


proc ShowLabelevery { w every } {
    global Vrp

    set c $w.c

    for {set i 0 } { $i < $Vrp(Sz) } { incr i $every} {
	HitPointIndex $c $i
    }

    return
}


proc ReadHydrophb { file } {
    global Rosace VrpC

    if {! [info exists Rosace]} {InitialiseRosace}

    set VrpC(NbAA) 0
    set i 0
    foreach a [array names Rosace] {
	if {[regexp {Norm} $a]} {continue}

	lassign [set Rosace($a)] x y 
	set ny [expr {-1.0*$y}]
	set AA1name $a
	set VrpC(HydX,$AA1name) $x
	set VrpC(HydY,$AA1name) $ny 
	set VrpC(HydX,$i) $x
	set VrpC(HydY,$i) $ny 
	set VrpC(AA1name,$i) $a
	lappend Lx $x
	lappend Ly $ny

	incr VrpC(NbAA)
	incr i
    }
    set VrpC(MinX) [expr min([join $Lx ,])]
    set VrpC(MinY) [expr min([join $Ly ,])]
    set VrpC(MaxX) [expr max([join $Lx ,])]
    set VrpC(MaxY) [expr max([join $Ly ,])]

    return
}


proc VrpDeGroupe {g} {
    global Vrp VrpC ListeDesPiliersDuGroupe

    FaireAttendre "Please wait ...\nBuilding VRP for group $g"

    set xprev 0.0   ; set yprev 0.0
    set cmx 0.0     ; set cmy 0.0
    set minX  9999999. ; set minY  9999999.
    set maxX -9999999. ; set maxY -9999999.
    set newX {}     ; set newY {}

    set Vrp(seqSS)  {}
    set Vrp(SS)     {}
    set Vrp(AA1)    ""
    set Vrp(Sz) [LongueurDeLAlignement]
    set Vrp(Nb) {}

    if {! [info exists ListeDesPiliersDuGroupe]} {
	CreeLesPiliers
    }
    if {$g eq "All"} {set g "GroupeToutLeMonde"}

    set i 0
    set ntot [string length [lindex [set ListeDesPiliersDuGroupe($g)] 0]]
    foreach p [set ListeDesPiliersDuGroupe($g)] {
	set xt 0.0
	set yt 0.0
	set n 0
	foreach aa [split $p ""] {
	    if {$aa eq "." || $aa eq "X" || $aa eq "Z"} {continue}
	    set xt [expr {$xt + $VrpC(HydX,$aa)}]
	    set yt [expr {$yt + $VrpC(HydY,$aa)}]
	    incr n
	}
	# Attention !
	# Suppose : 1 colonne de E par exemple
	# on a donc sumX = n*E et ici n=ntot
	# x= sumX/ntot
	set x [expr {(1.0/$ntot) * $Vrp(ScaleOrig)*$xt + $xprev}]
	set y [expr {(1.0/$ntot) * $Vrp(ScaleOrig)*$yt + $yprev}]
	
	lappend newX $x
	lappend newY $y
	lappend Vrp(Nb) [expr {$i + 1}]

	set xprev $x
	set yprev $y

	set cmx [expr {$cmx + $x}]
	set cmy [expr {$cmy + $y}]
	incr i
    }
    set minX [expr min([join $newX ,])]
    set minY [expr min([join $newY ,])]
    set maxX [expr max([join $newX ,])]
    set maxY [expr max([join $newY ,])]

    set Vrp(X) [LissageParFenetre $newX 5]
    set Vrp(Y) [LissageParFenetre $newY 5]

    set Vrp(CmX) [expr {$cmx / ($Vrp(Sz)+1)}]
    set Vrp(CmY) [expr {$cmy / ($Vrp(Sz)+1)}]
    set Vrp(MinX) $minX
    set Vrp(MinY) $minY
    set Vrp(MaxX) $maxX
    set Vrp(MaxY) $maxY

    set Vrp(SzX) [expr {($Vrp(MaxX) - $Vrp(MinX))/2}]
    set Vrp(SzY) [expr {($Vrp(MaxY) - $Vrp(MinY))/2}]

    FaireLaSuite

    return
}


proc GenVrpFromData {laseq} {
    global Vrp VrpC

    set seq [string map [list . ""] $laseq]

    set xprev 0.0 ; set yprev 0.0
    set cmx 0.0   ; set cmy 0.0
    set minX  99999. ; set minY  99999.
    set maxX -99999. ; set maxY -99999.

    set Vrp(seqgen) $laseq
    set Vrp(seqAA1) $seq
    set Vrp(seqSS)  {}
    set Vrp(SS)     {}
    set Vrp(AA1)    [split $seq ""]
    set newX {} ; set newY {}
    set Vrp(Sz) [llength $Vrp(AA1)]
    set Vrp(Nb) {}

    for {set i 0} {$i < $Vrp(Sz)} {incr i} {
	set aa [lindex $Vrp(AA1) $i]
	set hx $VrpC(HydX,$aa)
	set hy $VrpC(HydY,$aa)
	set x [expr {$Vrp(ScaleOrig)*$hx + $xprev}]
	set y [expr {$Vrp(ScaleOrig)*$hy + $yprev}]

	lappend newX  $x
	lappend newY  $y
	lappend Vrp(Nb) [expr {$i + 1}]

	set xprev $x
	set yprev $y

	set cmx [expr {$cmx + $x}]
	set cmy [expr {$cmy + $y}]
    }
    set minX [expr min([join $newX ,])]
    set minY [expr min([join $newY ,])]
    set maxX [expr max([join $newX ,])]
    set maxY [expr max([join $newY ,])]
    
    set Vrp(X) $newX
    set Vrp(Y) $newY

    set Vrp(CmX) [expr {$cmx / ($Vrp(Sz)+1)}]
    set Vrp(CmY) [expr {$cmy / ($Vrp(Sz)+1)}]
    set Vrp(MinX) $minX
    set Vrp(MinY) $minY
    set Vrp(MaxX) $maxX
    set Vrp(MaxY) $maxY

    set Vrp(SzX) [expr {($Vrp(MaxX) - $Vrp(MinX))/2}]
    set Vrp(SzY) [expr {($Vrp(MaxY) - $Vrp(MinY))/2}]

    return
}


proc ConfigureVrp {c} {
    global Vrp

    set reg [$c bbox all]
    set border $Vrp(Border)
    set xmin [expr {[lindex $reg 0] - $border}]
    set ymin [expr {[lindex $reg 1] - $border}]
    set xmax [expr {[lindex $reg 2] + $border}]
    set ymax [expr {[lindex $reg 3] + $border}]

    $c configure -scrollregion [list $xmin $ymin $xmax $ymax]

    return
}


proc ScaleRest { w } {
    global Vrp

    set c $w.c
    set invScale [expr 1.0/$Vrp(Scale)]
    $c scale all $Vrp(CX) $Vrp(CY) $invScale $invScale


    set Vrp(Scale) 1.0

    return
}


proc RemoveAllLabels { w } {
    $w.c delete label

    return
}


proc DrawVrp {} {
    global Vrp

    set w .fvrp.f

    set Vrp(Scale) 1.0
    set c $Vrp(WCanvas)

    if {! [set Vrp(Overwrite)]} {
	$c delete all
	set Vrp(VId) 0
    } else {
	lassign [$c coords l0_0] xv yv t h
	$c move all [expr {-1.*$xv}] [expr {-1.*$yv}]
	incr Vrp(VId)
    }

    set xprev 0.0
    set yprev 0.0
    set first 1
    for {set i 0} {$i < $Vrp(Sz)} {incr i} {
	set x [lindex $Vrp(X) $i]
	set y [lindex $Vrp(Y) $i]
	if {$first} {
	    set col red
	    set d [expr {2*$Vrp(DotSz)}]
	    set first 0
	} else {
	    set d $Vrp(DotSz)
	    set col $Vrp(colDot)
	}
	$c create line $xprev $yprev $x $y \
		-tags [list ligne "l${Vrp(VId)}_$i"]
	set item [$c create oval \
		[expr {$xprev-$d}] \
		[expr {$yprev-$d}] \
		[expr {$xprev+$d}] \
		[expr {$yprev+$d}] \
		-width 1 -outline black \
		-fill $col \
		-tags [list "p${Vrp(VId)}_$i" dot]]
	set xprev $x
	set yprev $y
    }
    $c raise dot

    if {! [set Vrp(Overwrite)]} {
	set cx [expr {($Vrp(MinX) + $Vrp(MaxX))/2.0}]
	set cy [expr {($Vrp(MinY) + $Vrp(MaxY))/2.0}]
    } else {
	lassign [$c bbox all] Vrp(MinX) Vrp(MinY) Vrp(MaxX) Vrp(MaxY)
	set Vrp(Cmx) [expr {($Vrp(MinX) + $Vrp(MaxX))/2.0}]
	set Vrp(Cmy) [expr {($Vrp(MinY) + $Vrp(MaxY))/2.0}]
    }
    set Vrp(CX) $Vrp(CmX)
    set Vrp(CY) $Vrp(CmY)

    set item [$c create line $Vrp(MinX) $Vrp(MinY) $Vrp(MaxX) $Vrp(MaxY) \
	    -fill [$c cget -background] ]

    $c addtag scrollregion withtag $item
    ShowCenter $c $Vrp(CX) $Vrp(CY)

    set szx2 [expr {$Vrp(Width)/2.0}]
    set szy2 [expr {$Vrp(Height)/2.0}]

    $c move all [expr {$szx2 - $Vrp(CmX)}] [expr {$szy2 - $Vrp(CmY)}]

    set Vrp(CX) $szx2
    set Vrp(CY) $szy2

    ConfigureVrp $c

    # show the sequence
    set t $Vrp(WText)
    $t configure -state normal
    $t delete 0.0 end
    $t insert 1.0 $Vrp(seqAA1)
    $t configure -state disabled -insertwidth 0

    return
}


proc itemStartDrag {c x y} {
    global lastX lastY

    set lastX $x
    set lastY $y
    $c scan mark $x $y

    return
}


proc itemStartScale {c x y} {
    global lastX lastY

    set lastX $x
    set lastY $y

    return
}


proc itemScale {c x y} {
    global lastX lastY Vrp

    set dx [expr { $x - $lastX}]
    set dy [expr {-$y + $lastY}]
    set d [expr {sqrt($dx*$dx + $dy*$dy)}]
    if {$d < 10.} {return}

    if {$dy < 0} {set zoomIn 1} {set zoomIn 0}
    if {$zoomIn} {
	set scale [expr {1.0 + $d/500.0}]
    } else {
	set scale [expr {1.0/(1.0 + $d/500.0)}]
    }	    

    set Vrp(Scale) [expr {$Vrp(Scale) * $scale}]
    $c scale all $Vrp(CX) $Vrp(CY) $scale $scale

    ConfigureVrp $c
    set lastX $x
    set lastY $y

    return
}


proc ShowCenter {c x y} {

    set cent [$c find withtag center]

    if {[llength $cent] > 0 } {
	set crd [$c coords center]
	$c delete center
	set x1 [lindex $crd 0]
	set x2 [lindex $crd 2]
	set l [expr ($x2 - $x1)/2.0]
    } else {
	set l 10
    }
    $c create line [expr {$x - $l}] $y [expr {$x + $l}] $y -fill red -tags center
    $c create line $x [expr {$y - $l}] $x [expr {$y + $l}] -fill red -tags center

    return
}


proc SetCenter {c x y} {
    global Vrp

    set Vrp(CX) [$c canvasx $x]
    set Vrp(CY) [$c canvasy $y]
    ShowCenter $c $Vrp(CX) $Vrp(CY)

    return
}


proc SetCenterOfMass {c} {
    global Vrp

    SetCenter $c $Vrp(CmX) $Vrp(CmY)

    return
}


proc HitPointXY {c x y} {

    set Lt [$c gettags current]
    if {$Lt == {}} {return}

    set rex "^p${::Vrp(VId)}_\[0-9\]+\$"
    foreach elt $Lt {
	if {[regexp $rex $elt]} {
	    AddRemoveLabel $c $elt
	}
    }

    return
}


proc HitPointIndex {t index} {
    global Vrp

    set c $Vrp(WCanvas)
    set elt "p${Vrp(VId)}_$index"
    AddLabel $c $elt $index

    return
}


proc AddLabel {c elt index} {
    global Vrp

    set pos [$c coords $elt]
    set x1 [lindex $pos 2]
    set y1 [lindex $pos 3]
    # add if does not already exist
    if {[llength [$c find withtag t_$index]] == 0 } {
	$c create text $x1 $y1 -fill $Vrp(colLabel) \
		-font $Vrp(font) \
		-text "[lindex $Vrp(AA1) $index][lindex $Vrp(Nb) $index]" \
		-tags [list label t_$index] \
		-justify right -anchor sw
    }

    return
}


proc AddRemoveLabel {c elt} {
    global Vrp

    set t $Vrp(WText)

    set index [lindex [split $elt "_"] 1]

    set item [$c find withtag t_$index]
    #check if label exists
    if {[llength $item] == 0} {
	# add text
	AddLabel $c $elt $index
    } else {
	$c delete $item
    }
    $t see [$t index 1.$index]
    HighlightChar $t $index

    return
}


proc InitialiseVrp {} {
    global OrdEtcDir lastX lastY env Vrp

    set lastX 0
    set lastY 0

    set Vrp(gap) "-"
    set Vrp(CmX) 0
    set Vrp(CmY) 0
    set Vrp(MinX) 0
    set Vrp(MaxX) 0
    set Vrp(MinY) 0
    set Vrp(MaxY) 0
    set Vrp(SzX) 0
    set Vrp(SzY) 0
    set Vrp(ScaleOrig) 10.0

    set Vrp(Nb) {}
    set Vrp(AA1) {}
    set Vrp(X) {}
    set Vrp(Y) {}
    set Vrp(SS) {}
    set Vrp(Sz) 0

    #Graphic settings
    #set Vrp(font) {Helvetica 12 normal}
    set Vrp(fontFamily) Helvetica
    set Vrp(fontSize) 10
    set Vrp(fontStyle) normal
    set Vrp(font) "$Vrp(fontFamily) $Vrp(fontSize) $Vrp(fontStyle)"

    set Vrp(style1) normal
    set Vrp(styleItalic) 0
    set Vrp(styleRoman) 0
    set Vrp(styleUnderline) 0

    set Vrp(Scale)	1.0
    set Vrp(CX) 0.0
    set Vrp(CY) 0.0
    set Vrp(TrX) 0.0
    set Vrp(TrY) 0.0
    set Vrp(Border) 10.0
    set Vrp(File) "test.fle"
    set Vrp(fileType) fle
    set Vrp(Height) 400
    set Vrp(Width)  700
    set Vrp(DotSz) [expr {$Vrp(ScaleOrig)/4.0}]

    set Vrp(oldTag) ""
    set Vrp(oldTag1) ""
    set Vrp(oldTag2) ""
    set Vrp(showChar) red
    set Vrp(oldChar) lightblue
    set Vrp(BegRes) 0
    set Vrp(EndRes) 0

    set Vrp(colLabel) red
    set Vrp(colDot) SkyBlue2
    set Vrp(cursor) [. cget -cursor]
    set Vrp(busyCursor) watch

    set VrpC(NbAA) 0
    set VrpC(HydX,A) 0.0
    set VrpC(HydY,A) 0.0
    # landscape orientation
    set Vrp(printOrient) true
    set Vrp(seqSel) 0

    set Vrp(DataAA) [file join $OrdEtcDir "rosace.txt"]

    set Vrp(Overwrite) 0
    
    return
}


proc DessineVrpDe {} {
    global Vrp LNDG

    set s [set Vrp(seqSelName)]
    set i [lsearch [set Vrp(NameList)] $s]
    set Vrp(seqSel) $i
    
    if {$s eq "All"} {set s "GroupeToutLeMonde"}
    if {$s in $LNDG} {
	VrpDeGroupe $s
    } else {
	GenVrpFromData [set Vrp(Seq,$i)]
    }
    DrawVrp

    ColorieVrpSelon "" [set Vrp(UseFeat)]

    return
}


proc ResetColoriage {} {
    global Vrp

    set c $Vrp(WCanvas)
    $c itemconfigure ligne -fill black
    $c itemconfigure dot   -fill $Vrp(colDot)

    return
}


proc ColorieVrpSelon {w ft} {
    global TabSF Vrp

    ResetColoriage
    
    if {$ft eq "None"} {return}
    if {$ft eq "VientDuCombo"} {set ft $Vrp(UseFeat)}
    set n [set Vrp(seqSelName)]
    if {! [info exists TabSF($n,$ft)]} {return}

    set c $Vrp(WCanvas)
    set t $Vrp(WText)
    foreach f [set TabSF($n,$ft)] {
	DecortiqueUneFeature $f dg fg col score note
	set db [DonnePosGS $n $dg]
	set fn [DonnePosGS $n $fg]

	for {set i $db} {$i < $fn} {incr i} {
	    set line [$c find withtag "l${Vrp(VId)}_$i"]
	    $c itemconfigure $line -fill $col
	    set dot [$c find withtag "p${Vrp(VId)}_$i"]
	    $c itemconfigure $dot -fill $col
	}
    }

    return
}


proc FenetreVrp {} {
    global ListeTypesDeFeatures Vrp

    set w .fvrp
    catch {destroy $w}
    toplevel $w
    wm title $w "Ordalie Vrp ..."
    wm iconname $w "vrp"
    grid columnconfig $w 0 -weight 1
    grid rowconfig    $w 0 -weight 1
    
    frame $w.f
    grid $w.f -row 0 -column 0 -sticky news
    grid columnconfig $w.f 0 -weight 1
    grid rowconfig    $w.f 0 -weight 1
    set w .fvrp.f

    # frame canvas du vrp
    frame $w.vrp
    set c $w.vrp.c
    set Vrp(WCanvas) $c
    scrollbar $w.vrp.vscroll \
	-command "$c yview " \
	-width 8
    scrollbar $w.vrp.hscroll \
	-orient horiz \
	-command "$c xview " \
	-width 8
    canvas $c \
	-scrollregion [list 0 0 $Vrp(Width) $Vrp(Height)] \
	-width $Vrp(Width) \
	-height $Vrp(Height) \
	-cursor hand2 \
	-background white \
	-xscrollcommand "$w.vrp.hscroll set " \
	-yscrollcommand "$w.vrp.vscroll set "
    
    grid $w.vrp.c       -row 0 -column 0 -sticky news
    grid $w.vrp.vscroll -row 0 -column 1 -sticky ns
    grid $w.vrp.hscroll -row 1 -column 0 -sticky ew
    grid $w.vrp -row 0 -column 0 -sticky news -padx 5 -pady 5
    grid rowconfig    $w.vrp 0 -weight 1 -minsize 0
    grid columnconfig $w.vrp 0 -weight 1 -minsize 0
    grid columnconfig $w.vrp 1 -weight 0 -minsize 0
    
    # Frame de controle
    set w $w.bot
    frame $w
    # frame de la sequence de la proteine
    set t $w.text
    frame $t
    set Vrp(WText) $t.txt
    text $t.txt \
	-xscrollcommand "txtScroll $t" \
	-setgrid true \
	-height 1 -wrap none \
	-background white
    # show residue number begin end
    label $t.resbeg \
	-text [format "%4d" $Vrp(BegRes)] \
	-width 4
    label $t.resend \
	-text [format "%-4d" $Vrp(EndRes)] \
	-width 4
    scrollbar $t.scroll -orient horiz \
	-command "scrollTxt $t" \
	-width 8
    
    grid $t.resbeg -row 0 -column 0 -sticky e
    grid $t.txt    -row 0 -column 1 -sticky ew
    grid $t.resend -row 0 -column 2 -sticky w
    grid $t.scroll -row 1 -column 1 -sticky ew
    grid $t -row 0 -column 0 -columnspan 2 -sticky ew -pady {2 5}
    grid columnconfig $t 1 -weight 1
    
    # frame seq et feat
    set wb $w
    frame $wb.sf -relief groove
    label $wb.sf.lseq \
	-text "Sequence "
    set wsq [PlusLongEltDe [set Vrp(NameList)]]
    ttk::combobox $wb.sf.cseq \
	-background white \
	-state readonly \
	-textvariable Vrp(seqSelName) \
	-width $wsq \
	-values $Vrp(NameList)
    $wb.sf.cseq index 0
    bind $wb.sf.cseq <<ComboboxSelected>> [list DessineVrpDe]
    checkbutton $wb.sf.over \
	-text "Overdraw " \
	-anchor w -justify left \
	-onvalue 1 \
	    -offvalue 0 \
	    -variable Vrp(Overwrite)
    label $wb.sf.lfeat \
	    -text "Feature"
    set wft [PlusLongEltDe $ListeTypesDeFeatures]
    set Vrp(ListFeat) [linsert $ListeTypesDeFeatures 0 "None"]
    set Vrp(UseFeat) [lindex $Vrp(ListFeat) 0]
    ttk::combobox $wb.sf.cfea \
	    -background white \
	    -state readonly \
	    -textvariable Vrp(UseFeat) \
	    -width $wft \
	    -values $Vrp(ListFeat)
    $wb.sf.cfea index 0
    bind $wb.sf.cfea <<ComboboxSelected>> [list ColorieVrpSelon %W VientDuCombo]
    
    grid $wb.sf.lseq  -row 0 -column 0 -sticky ew
    grid $wb.sf.cseq  -row 0 -column 1 -sticky ew
    grid $wb.sf.over  -row 1 -column 0 -columnspan 2 -sticky w
    grid $wb.sf.lfeat -row 0 -column 2 -sticky ew -padx {10 1}
    grid $wb.sf.cfea  -row 0 -column 3 -sticky ew
    grid $wb.sf -row 1 -column 0 -sticky w
    grid columnconfig $wb.sf {1 3} -weight 1

    # frame boutons
    frame $wb.fb
    button $wb.fb.circle \
	    -text "Circle" \
	    -bg cyan \
	    -command [list VrpCircle]
    button $wb.fb.print \
	    -text "Print" \
	    -bg yellow \
	    -command [list Printcanvas $Vrp(WCanvas) png]
    button $wb.fb.close \
	    -text "Close" \
	    -bg green1 \
	    -command [list destroy .fvrp]
    grid $wb.fb.circle -row 0 -column 0 -sticky ew -ipadx 2
    grid $wb.fb.print -row 0 -column 1 -sticky ew -ipadx 2
    grid $wb.fb.close -row 0 -column 2 -sticky ew -ipadx 2
    grid $wb.fb -row 1 -column 1 -sticky e 

    grid $w -row 1 -column 0 -sticky ew -padx 5 -pady 5
    grid columnconfig $w all -weight 1

    BindingsVrp $Vrp(WCanvas) $Vrp(WText)

    MesCouleurs .fvrp
    FenetreAuCentre .fvrp

    update idletasks

    return
}


proc txtScroll { t first last } {
    global Vrp

    set ts $t.scroll
    #	puts "\nin txtScroll from text $t"

    set beg [expr $first*$Vrp(Sz)]
    set end [expr $last*$Vrp(Sz)]

    set beg [expr int($beg+0.5)]
    set end [expr int($end+0.5)]

    if { $beg != $end } {
	incr beg
	incr end
    }
    $t.resbeg configure -text [format "%4d" $beg]
    $t.resend configure -text [format "%-4d" $end]
    $ts set $first $last

    return
}


proc scrollTxt {t args} {
    $::Vrp(WText) xview {*}$args

    return
}


proc BindingsVrp {c t} {

    bind $c <Shift-2>   [list SetCenter $c %x %y]
    bind $c <Shift-3>   [list SetCenterOfMass $c ]

    bind $c <ButtonPress-1> {%W scan mark %x %y}
    bind $c <B1-Motion>     {%W scan dragto %x %y 1}
    bind $c <1>             [list HitPointXY $c %x %y]
    bind $c <Button-3> [list itemStartScale $c %x %y]
    bind $c <B3-Motion> [list itemScale $c %x %y]

    bind $c <4>             {%W yview scroll -1 units}
    bind $c <5>             {%W yview scroll  1 units}
    bind $c <Control-4>     {%W xview scroll -1 units}
    bind $c <Control-5>     {%W xview scroll  1 units}

    $t tag bind current <1> [list HighlightChar $t]
    bind $t <1> [list ShowCharOnVrp $t %x %y]
    $t configure -cursor left_ptr

    return
}


proc HighlightChar {t index} {
    global Vrp

    set tg "show_$index"
    if {$Vrp(oldTag1) ne "" } {
	$t tag configure $Vrp(oldTag1) -background $Vrp(oldChar)
    }
    if {$Vrp(oldTag2) ne "" } {
	$t tag configure $Vrp(oldTag2) -background [$t cget -background]
    }

    $t tag add $tg 1.$index
    $t tag configure $tg -background $Vrp(showChar)

    set Vrp(oldTag2) $Vrp(oldTag1)
    set Vrp(oldTag1) $tg

    return
}


proc ShowCharOnVrp {t x y} {

    set cpos [$t index @$x,$y]
    set index [lindex [split $cpos .] 1]

    HitPointIndex $t $index
    HighlightChar $t $index

    return
}


proc Ordali_Vrp {} {
    global Vrp NomTextSeq NomNomSeq NomSeqSel LNDG LNOrdali LSOrdali

    if {! [ModeI]} {return}
    if {[TypeAli] eq "pasdali"} {return}
    if {! [info exists NomSeqSel] || ! [llength $NomSeqSel]} {
	set Lnoms $LNOrdali
	set Lseqs $LSOrdali
    } else {
	set Lnoms [LesNomsDesSeqsSel]
	set Lseqs [LesSeqsDesSeqsSel]
    }

    InitialiseVrp
    ReadHydrophb $Vrp(DataAA)

    # Initialisation du tableau VRP
    # Bidouille pour caser les Vrp des groupes
    # On les mets toujours en debut de liste
    # Ils ont les indices 0 -> Nbg
    set i 0
    foreach g $LNDG {
	if {$g eq "grise" || $g eq "bidon"} {break}
	if {$g eq "GroupeToutLeMonde"} {set g "All"}
	set Vrp(Name,$i) $g
	set Vrp(Name,$g) $i
	lappend Vrp(NameList) $g
	incr i
    }

    set IStart $i
    foreach n $Lnoms s $Lseqs {
	if {$n eq ""} {continue}

	set Vrp(Name,$i) $n
	set Vrp(Name,$n) $i
	set Vrp(Seq,$i)  $s
	lappend Vrp(NameList) $n
	incr i
    }
    set Vrp(NbSeq) $i
    set Vrp(seqSelName) $Vrp(Name,$IStart)

    FenetreVrp

    GenVrpFromData [set Vrp(Seq,$IStart)]
    DrawVrp

    return
}


proc VrpCircle {} {
    global VrpC
    
    if {[winfo exists .vrpcircle]} {
	return
    }
    
    set VrpC(AA1name,1) {}
    
    set WinScale 20.0
    set VrpC(Radius) [expr {abs($VrpC(MaxX))}]
    if { abs($VrpC(MinX)) > abs($VrpC(MaxX)) } {
	set VrpC(Radius) [expr {abs($VrpC(MinX))}]
    }
    if { $VrpC(Radius) < abs($VrpC(MinY)) } {
	set VrpC(Radius) [expr {abs($VrpC(MinY))}]
    }
    if { $VrpC(Radius) < abs($VrpC(MaxY)) } {
	set VrpC(Radius) [expr {abs($VrpC(MaxY))}]
    }
    set VrpC(Radius) [expr {int($VrpC(Radius)+0.5)}]
    set VrpC(Delta) 10
    set VrpC(CentX) [expr int( $VrpC(Radius) * $WinScale + 0.5) ]
    set VrpC(CentX) [expr $VrpC(CentX) + $VrpC(Delta)]
    set VrpC(Radius) $VrpC(CentX)
    set VrpC(CentY) $VrpC(CentX)
    set WinX [expr 2*$VrpC(CentX)]
    set WinY [expr 2*$VrpC(CentY)]

    set font "Helvetica 10 normal"
    
    # fenetre cercle VRP
    set w .vrpcircle
    toplevel $w
    wm title $w "Vrp Circle"
    
    set c $w.c
    canvas $c \
	-scrollregion [list 0 0 $WinX $WinY] \
	-width $WinX -height $WinY \
	-relief sunken \
	-borderwidth 2 \
	-background white
    button $w.print \
	-text "Print" \
	-background yellow \
	-command [list PrintCanvas $c png]
    button $w.close \
	-text "Close" \
	-background green1 \
	-command [list destroy $w]
    grid $c -row 0 -column 0 -columnspan 2 -sticky news -padx 5 -pady 5
    grid $w.print -row 1 -column 0 -sticky w -padx 5 -pady 10
    grid $w.close -row 1 -column 1 -sticky e -padx 5 -pady 10
    grid columnconfig $w all -weight 1
    
    set blue DeepSkyBlue3
    set red red
    set bisque bisque3
    set green SeaGreen3
    
    #set blue black
    #set red black
    #set bisque black
    #set green black
    
    set x1 $VrpC(Delta)
    set y1 $VrpC(Delta)
    set x2 [expr $WinX - $VrpC(Delta) ]
    set y2 [expr $WinY - $VrpC(Delta) ]
    
    # cercle et lignes
    $c create oval $x1 $y1 $x2 $y2 -outline $red -width 1
    $c create line $VrpC(CentX) $VrpC(Delta) $VrpC(CentX) [expr $WinY-$VrpC(Delta)] -fill $red
    $c create line $VrpC(Delta) $VrpC(CentY) [expr $WinX-$VrpC(Delta)] $VrpC(CentY) -fill $red

    for {set i 0 } { $i < $VrpC(NbAA) } { incr i } {
	set x [expr $VrpC(HydX,$i)*$WinScale + $VrpC(CentX)]
	set y [expr -$VrpC(HydY,$i)*$WinScale+$VrpC(CentY)]

	$c create line $VrpC(CentX) $VrpC(CentY) $x $y -arrow last
	
	if { ( $x >= $VrpC(CentX) ) } {
	    set anchor [ expr "{$y} >= $VrpC(CentY) ? {nw} : {sw} " ]
	} else {
	    set anchor [ expr "{$y} >= $VrpC(CentY) ? {ne} : {se}" ]
	}
	$c create text $x $y  -text $VrpC(AA1name,$i) -anchor $anchor
    }
    set lastX 0
    set lastY 0

    FenetreAuCentre $w


    return
}

