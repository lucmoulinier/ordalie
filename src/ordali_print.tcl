
#rR ordali_print.tcl





proc AjouteAuDumpText {k v i} {

    global DumpText

    append DumpText $v
    return
}



proc AjouteAuDumpNoms {k v i} {

    global DumpNoms

    append DumpNoms $v
    return
}



proc PrintSetup {{how ""}} {
    global PrmPrt

    if {! [ModeI]} {
	return
    }

    set w .prtset
    if {$how == "destroy" && [winfo exists $w]} {
	destroy $w
	return
    }

    if {$how eq "defauts"} {
	set PrmPrt(Format)      "jpeg"
	set PrmPrt(Papier)      "A4"
	set PrmPrt(Orientation) "landscape"
	set PrmPrt(Area)        "all"
	set PrmPrt(Ruler)       1
	set PrmPrt(ResidueNbr)  1
	# default print font size : 8
	set fontsize            8
	set fontwght            [font configure SeqFont -weight]
	set PrmPrt(FontSize)    $fontsize
	set PrmPrt(FontWght)    $fontwght

	return
    }

    set font "Helvetica 10"

    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    toplevel $w
    wm title $w "Print Setup"
    wm iconname $w "Setup"

    grid rowconfig    $w 0   -weight 0
    grid columnconfig $w all -weight 1

    labelframe $w.label \
	-text "Print Setup" \
	-font TitleFont \
	-fg blue \
	-labelanchor nw
    grid $w.label -row 0 -column 0 -sticky w -pady 10 -padx 10

    # Output format
    frame $w.fout
    grid $w.fout -row 1 -column 0 -padx 10 -pady {5 1}
    grid rowconfig    $w.fout 0   -weight 0
    grid columnconfig $w.fout all -weight 1

    label $w.fout.lblout \
	    -text "Output format :" \
	-fg blue \
	    -justify left \
	    -anchor w
    frame $w.fout.ffmt
    grid rowconfig    $w.fout.ffmt 0 -weight 0
    grid columnconfig $w.fout.ffmt all -weight 1
    radiobutton $w.fout.ffmt.ps \
	    -text "PostScript" \
	    -variable PrmPrt(Format) \
	    -relief flat \
	    -value "ps" \
	-anchor w -justify left
    radiobutton $w.fout.ffmt.jpeg \
	-text "JPEG" \
	-variable PrmPrt(Format) \
	-relief flat \
	    -value "jpeg" \
	-anchor w -justify left
    radiobutton $w.fout.ffmt.png \
	-text "PNG" \
	-variable PrmPrt(Format) \
	-relief flat \
	-value "png" \
	-anchor w -justify left
    grid $w.fout.ffmt.ps   -row 0 -column 0 -sticky ew
    grid $w.fout.ffmt.jpeg -row 0 -column 1 -sticky ew
    grid $w.fout.ffmt.png  -row 0 -column 2 -sticky ew

    grid $w.fout.lblout -row 0 -column 0 -sticky ew
    grid $w.fout.ffmt   -row 0 -column 1 -sticky ew

    # options du papier
    label $w.control \
	-text "Paper options ---" \
	-anchor w -justify left \
	-fg blue 
    grid $w.control -row 2 -column 0 -padx 10 -pady 5 -sticky ew
    grid rowconfig    $w.control 0   -weight 0
    grid columnconfig $w.control all -weight 1

    label $w.control.lblsize \
	-text "Paper size :" \
	-fg blue \
    -justify left -anchor w
    frame $w.control.fsz
    grid rowconfig    $w.control.fsz 0   -weight 0
    grid columnconfig $w.control.fsz all -weight 1

    radiobutton $w.control.fsz.sa4 \
	-text "A4" \
	-variable PrmPrt(Papier) \
	-relief flat \
	-value "A4" \
	-anchor w -justify left
    radiobutton $w.control.fsz.sa3 \
	-text "A3" \
	-variable PrmPrt(Papier) \
	-relief flat \
	-value "A3" \
	-anchor w -justify left
    radiobutton $w.control.fsz.sus \
	-text "US" \
	-variable PrmPrt(Papier) \
	-relief flat \
	-value "US" \
	-anchor w -justify left
    radiobutton $w.control.fsz.sno \
	-text "Unlimited" \
	-variable PrmPrt(Papier) \
	-relief flat \
	-value "unlimited" \
	-anchor w -justify left
    grid $w.control.fsz.sa4 -row 0 -column 0 -sticky ew
    grid $w.control.fsz.sa3 -row 0 -column 1 -sticky ew
    grid $w.control.fsz.sus -row 0 -column 2 -sticky ew
    grid $w.control.fsz.sno -row 0 -column 3 -sticky ew

    grid $w.control.lblsize -row 0 -column 0 -sticky ew -padx {5 1}
    grid $w.control.fsz     -row 0 -column 1 -columnspan 2 -sticky ew

    label $w.control.lblori \
	    -text "Orientation :" \
	-fg blue \
	-justify left -anchor w
    radiobutton $w.control.land \
	-text "landscape" \
	-variable PrmPrt(Orientation) \
	-relief flat \
	-value "landscape" \
	-anchor w -justify left
    radiobutton $w.control.pays \
	-text "portrait" \
	-variable PrmPrt(Orientation) \
	-relief flat \
	-value "portrait" \
-anchor w -justify left

    grid $w.control.lblori -row 1 -column 0 -sticky ew -padx {5 1}
    grid $w.control.land   -row 1 -column 1 -sticky ew
    grid $w.control.pays   -row 1 -column 2 -sticky ew

    label $w.control.fntl \
	-text "Font size : CourierNew " \
	-justify left -anchor w \
	-fg blue \
    -width 20
    tk_optionMenu $w.control.fnts PrmPrt(FontSize) 6 8 10 12 14 16
    tk_optionMenu $w.control.fntc PrmPrt(FontWght) normal bold

    grid $w.control.fntl -row 2 -column 0 -sticky ew -padx {5 1}
    grid $w.control.fnts -row 2 -column 1 -sticky ew
    grid $w.control.fntc -row 2 -column 2 -sticky ew

    # options du texte
    label $w.ctrali \
	-text "Multiple Alignment options ---" \
-relief flat \
    -anchor w -justify left
    grid $w.ctrali -row 3 -column 0 -padx 10 -pady 10 -sticky ew
    grid rowconfig    $w.ctrali 0   -weight 0
    grid columnconfig $w.ctrali all -weight 1

    label $w.ctrali.lblare \
	-text "Print Area :" \
	-fg blue \
    -justify left -anchor w \
	-width 20
    radiobutton $w.ctrali.alla \
	-text "All" \
	-variable PrmPrt(Area) \
	-relief flat \
	-value "all" \
	-anchor w -justify left
    radiobutton $w.ctrali.wind \
	-text "window"  \
	-variable PrmPrt(Area) \
	-relief flat \
	-value "window" \
	-anchor w -justify left
    radiobutton $w.ctrali.slct \
	-text "selected"  \
	-variable PrmPrt(Area) \
	-relief flat \
	-value "selected" \
	-anchor w -justify left

    grid $w.ctrali.lblare -row 0 -column 0 -sticky ew -padx {5 1}
    grid $w.ctrali.alla   -row 0 -column 1 -sticky ew
    grid $w.ctrali.wind   -row 0 -column 2 -sticky ew
    grid $w.ctrali.slct   -row 0 -column 3 -sticky ew

    label $w.ctrali.lblrul \
	-text "Ruler on every page" \
	-justify left -anchor w \
	-width 20
    radiobutton $w.ctrali.rul1 \
	-text "Yes" \
	-variable PrmPrt(Ruler) \
	-relief flat \
	-value 1 \
	-anchor w -justify left
    radiobutton $w.ctrali.rul0 \
	-text "No"  \
	-variable PrmPrt(Ruler) \
	-relief flat \
	-value 0 \
	-anchor w -justify left

    grid $w.ctrali.lblrul -row 1 -column 0 -sticky ew -padx {5 1}
    grid $w.ctrali.rul1   -row 1 -column 1 -sticky ew
    grid $w.ctrali.rul0   -row 1 -column 2 -sticky ew

    label $w.ctrali.lblnbr \
	-text "Residue numbering" \
	-fg blue \
    -justify left -anchor w
    radiobutton $w.ctrali.nbr1 \
	-text "Yes" \
	-variable PrmPrt(ResidueNbr) \
	-relief flat \
	-value 1 \
	-relief flat \
    -anchor w -justify left
    radiobutton $w.ctrali.nbr0 \
	-text "No"  \
	-variable PrmPrt(ResidueNbr) \
	-relief flat \
	-value 0 \
	-anchor w -justify left \
	    -relief flat
    grid $w.ctrali.lblnbr -row 2 -column 0 -sticky ew -padx {5 1}
    grid $w.ctrali.nbr1   -row 2 -column 1 -sticky ew
    grid $w.ctrali.nbr0   -row 2 -column 2 -sticky ew

    ttk::frame $w.btn \
	-style FrmBtnCtrl.TFrame
    button $w.btn.print \
	    -text "Print" \
	    -background cyan \
	    -command [list BonPrintOrdali]
    button $w.btn.defts \
	    -text "Defauts" \
	    -background yellow \
	    -command [list PrintSetup defauts]
    button $w.btn.retour \
	    -text "Dismiss" \
	    -background red \
	    -command [list PrintSetup destroy]
    grid $w.btn.retour -row 0 -column 0 -sticky w -padx {10 1}
    grid $w.btn.defts -row 0 -column 1
    grid $w.btn.print -row 0 -column 2 -sticky e -padx {1 10}
    grid columnconfig $w.btn all -weight 1
    grid $w.btn -row 4 -column 0 -pady 20 -sticky ew

    grid columnconfig $w all -weight 1

    update idletasks
    MesCouleurs $w
    FenetreAuCentre $w

    return
}



proc DimensionsPapier {} {
    global PrmPrt

    switch [set PrmPrt(Papier)] {
	"A4" {
	    set x 21.
	    set y 29.7
	}
	"A3" {
	    set x 29.7
	    set y 42.
	}
	"US" {
	    set x 21.6
	    set y 27.9
	}
	"unlimited" {
	    set x -1
	    set y -1
	}
    }

    if {[set PrmPrt(Orientation)] == "landscape"} {
	set tmp $y
	set y $x
	set x $tmp
    }

    # enleve 1cm de marges
    set x [expr {$x - 2.}]
    set y [expr {$y - 2.}]

    # on est en 72 points par pouces, soit par 2.54 cm
    set xP [expr {int(double($x)/2.54 * 72)}]
    set yP [expr {int(double($y)/2.54 * 72)}]

    return [list $xP $yP]
}


proc DecoupeYEnPages {dimy} {
    global NomNomSeq PrmPrt Sequences

    set FonteMetrics  [font metrics FntPrt]
    set HauteurLettre [lindex $FonteMetrics 5]
    set LargeurLettre [font measure FntPrt "Z"]

    set XLen $PrmPrt(LgNoms)
    set NSeqs $PrmPrt(NbSeqs)
    if {$dimy >= 0} {
	# complete lines only, and no empty last page
	set NSeqParPage [expr {max(1, int($dimy/$HauteurLettre))}]
	set NPagesY     [expr {($NSeqs + $NSeqParPage - 1)/$NSeqParPage}]
    } else {
	set NPagesY 1
	set NSeqParPage $NSeqs
    }
    set DecalX      [expr {$XLen*$LargeurLettre}]

    return [list $NPagesY $NSeqParPage $DecalX]
}


proc DecoupeXEnPages {dimx} {
    global NomTextSeq Sequences PrmPrt

    if {$PrmPrt(ColRes)} {
	set size $PrmPrt(FontSize)
	set HauteurLettre [image height CN_${size}_A]
	set LargeurLettre [image width  CN_${size}_A]
    } else {
	set FonteMetrics [font metrics FntPrt]
	set HauteurLettre [lindex $FonteMetrics 5]
	set LargeurLettre [font measure FntPrt "Z"]
    }
    set XLen  $PrmPrt(LgSeqs)
    set NSeqs $PrmPrt(NbSeqs)

    if {$dimx >= 0} {
	# complete columns only, and no empty last page
	set NColParPage [expr {max(1, int($dimx/$LargeurLettre))}]
	set NPagesX     [expr {($XLen + $NColParPage - 1)/$NColParPage}]
    } else {
	set NColParPage $XLen
	set NPagesX 1
    }

    return [list $NPagesX $NColParPage]
}


proc TraiteTag {Lt} {
    set res [list]
    foreach {k v i} $Lt {
	if {[regexp {^FX\_} $v]} {
	    set bg [$::NomTextSeq tag cget $v -background]
	    set fg [$::NomTextSeq tag cget $v -foreground]
	    
	    lappend res [list $k $fg $bg $i]
	}
    }

    return $res
}


proc SequenceTaggee {y xd xf} {
    # features of printed line y, between the columns xd and xf of
    # the printed area. TabSF uses the internal names and the columns
    # of the whole alignment : the area starts at column PrmPrt(xD).
    global TabSF PrmPrt NomTextSeq

    set x0 $PrmPrt(xD)
    set xd [expr {$xd + $x0}]
    set xf [expr {$xf + $x0}]
    set Lf [lreverse [ListeDesFeaturesUtilisees]]
    set n [string trim [lindex $PrmPrt(LNOri) $y]]
    set Ltags [list]
    set ti -1
    foreach ft $Lf {
	incr ti
	if {$n eq "" || ! [info exists TabSF($n,$ft)]} {
	    continue
	}

	# sorted by start (no -unique : features may start at the
	# same column)
	foreach f [lsort -integer -index 1 [set TabSF($n,$ft)]] {
	    DecortiqueUneFeature $f dg fg col sco note
	    if {$dg <= $xf && $fg >= $xd} {
		set x1 [expr {max($dg, $xd) - $x0}]
		set x2 [expr {min($fg, $xf) - $x0}]
		lappend Ltags [list $x1 $x2 $col $ti]
	    }
	}
    }

    return $Ltags
}


proc DumpLeCarre {xd yd xf yf} {
    global TabSF PrmPrt

    set Ltags [list]
    if {[QuelMode] ne "feature"} {
	return $Ltags
    }

    set Lf [LesBoutonsEnfonces]
    puts "Lf $Lf"
    puts "yd $yd yf $yf"
    set i $yd
    foreach n [lrange $PrmPrt(LNoms) $yd $yf] {
	foreach ft $Lf {
	    if {! [info exists TabSF($n,$ft)]} {
		continue
	    }
	    foreach f [set TabSF($n,$ft)] {
		DecortiqueUneFeature $f dg fg col sco note
		if {$dg <= $xf && $fg >= $xd} {
		    if {$dg < $xd} {
			set x1 $xd
		    } else {
			set x1 $dg
		    }
		    if {$fg > $xf} {
			set x1 $xf
		    } else {
			set x2 $fg
		    }
		    lappend Ltags [list $i $x1 $x2 $col]
		}
	    }
	}
	incr i
    }
    puts [join $Ltags \n]

    return $Ltags


    set dump ""
    set dptg ""
    set dptx ""
    for {set i $yd} {$i <= $yf} {incr i} {
	
	set d [$NomTextSeq dump -text -tag $i.$xd $i.$xf]
	set TOn 0
	foreach {k v ix} $d {
	    if {! [regexp {\.} $ix]} {
		set ix "$i.$ix"
	    }
	    switch $k {
		"tagon" {
		    if {$v eq "Back"} {continue}
		    if {! [regexp {^FX_} $v] && ! [regexp {^Tag} $v]} {continue}
		    set TOn 1
		}
		"tagoff" {
		    if {$v eq "Back"} {continue}
		    if {! [regexp {^FX_} $v] && ! [regexp {^Tag} $v]} {continue}
		    if {! $TOn} {lappend LDump $k $v "$i.$xd"}
		    set TOn 0
		}
	    }
	    #puts "$k $v $ix"
	    lappend LDump $k $v $ix
	}
	if {$TOn} {lappend LDump $k $v "$i.$xf"}
    }

    return $LDump
}


proc MetDumpSurCanvas {LDumpText K DNx NXPP NXP NYPP NYP} {
    global PrmPrt NomTextSeq

    set FonteMetrics  [font metrics FntPrt]
    set HauteurLettre [lindex $FonteMetrics 5]
    set LargeurLettre [font measure FntPrt "Z"]

    incr NXP -1
    incr NYP -1
    set Tagon 0
    set fg "black"
    set bg "white"
    foreach {k v i} $LDumpText {
	switch $k {
	    "text" {
		set Texte $v
		lassign [split $i .] yD xD 
		set xCD [expr {$DNx+($xD+1)*$LargeurLettre-$NXP*$NXPP}]
		set yCD [expr {($yD-1)*$HauteurLettre-$NYP*$NYPP}]
		$K create text $xCD $yCD \
			-font FntPrt \
			-anchor nw \
			-tag ItemText \
			-text $Texte \
			-fill $fg
	    }
	    "tagon" {
		set fg [$NomTextSeq tag cget $v -foreground]
		set bg [$NomTextSeq tag cget $v -background]
		lassign [split $i .] yD xD 
		set Texte ""
		if {$fg eq ""} {set fg "black"}
		if {$Tagon} {
		    set fg "black"
		    set bg "white"
		}
		set Tagon 1
	    }
	    "tagoff" {
		if {! $Tagon} {continue}

		set Tagon 0
		lassign [split $i .] yF xF 
		if {$yF != $yD} {
		    if {$Texte ne ""} {
			set yF $yD
			set xF [expr {$xD+[string length $Texte]}]
		    } else {
			set fg "black"
			set bg "white"
			continue
		    }
		}

		set xCD [expr {$DNx+($xD+1)*$LargeurLettre-$NXP*$NXPP}]
		set xCF [expr {$DNx+($xF+1)*$LargeurLettre-$NXP*$NXPP}]
		set yCD [expr {($yD-1)*$HauteurLettre-$NYP*$NYPP}]
		set yCF [expr {$yD*$HauteurLettre-$NYP*$NYPP}]

		set id [$K create rectangle $xCD $yCD $xCF $yCF \
			-fill $bg \
			-width 0 ]
		set fg "black"
		set bg "white"
	    }
	}
    }

    $K raise ItemText

    return
}


proc MetTagsSurCanvas {K DNx DX FX DY FY} {
    global PrmPrt NomTextSeq
    
    set size $PrmPrt(FontSize)
    if {$PrmPrt(ColRes)} {
	set cW [image width  CN_${size}_A]
	set cH [image height CN_${size}_A]
    } else {
	set cW $PrmPrt(WdLet)
	set cH $PrmPrt(HgLet)
    }
    
    for {set y $DY ; set j 0} {$y <= $FY} {incr y ; incr j} {
	set s [lindex $PrmPrt(LSeqs) $y]
	set yp [expr {$j*$cH}]
	if {$PrmPrt(ColRes)} {
	    set x0 $DNx
	} else {
	    set x0 [expr {$DNx-1}]
	}
	for {set x $DX ; set i 0} {$x <= $FX} {incr x ; incr i} {
	    set c [string index $s $x]
	    if {$c eq " "} {set c ""}
	    set xp [expr {$x0+$i*$cW}]
	    if {$PrmPrt(ColRes)} {
		$K create image $xp $yp \
			-image CN_${size}_$c \
			-anchor nw
	    } else {
		$K create text $xp $yp \
			-text $c \
			-font FntPrt \
			-anchor nw \
			-tags [list LaSeq "S$x.$y"]
	    }
	}
	set Lst [SequenceTaggee $y $DX $FX]
	set xd $DX
	foreach t $Lst {
	    lassign $t x1 x2 col itag
	    set x1l [expr {$DNx + ($x1-$xd)*$cW}]
	    set x2l [expr {$DNx + ($x2-$xd+1)*$cW}]
	    if {$col eq "black"} {
		$K itemconfigure "S$x1.$y" -fill white
	    }
	    set yf [expr {$yp+$cH-1}]
	    $K create rectangle $x1l $yp $x2l $yf \
		    -fill $col \
		    -outline $col \
		    -tags UnTag
	}
    }
    #$K lower UnTag
    $K raise LaSeq
    update idletasks

    return

    foreach {k v i} $LDumpText {
	switch $k {
	    "text" {
		set Texte $v
		lassign [split $i .] yD xD 
		set xCD [expr {$DNx+($xD+1)*$LargeurLettre-$NXP*$NXPP}]
		set yCD [expr {($yD-1)*$HauteurLettre-$NYP*$NYPP}]
		$K create text $xCD $yCD \
			-font FntPrt \
			-anchor nw \
			-tag ItemText \
			-text $Texte \
			-fill $fg
	    }
	    "tagon" {
		set fg [$NomTextSeq tag cget $v -foreground]
		set bg [$NomTextSeq tag cget $v -background]
		lassign [split $i .] yD xD 
		set Texte ""
		if {$fg eq ""} {set fg "black"}
		if {$Tagon} {
		    set fg "black"
		    set bg "white"
		}
		set Tagon 1
	    }
	    "tagoff" {
		if {! $Tagon} {continue}

		set Tagon 0
		lassign [split $i .] yF xF 
		if {$yF != $yD} {
		    if {$Texte ne ""} {
			set yF $yD
			set xF [expr {$xD+[string length $Texte]}]
		    } else {
			set fg "black"
			set bg "white"
			continue
		    }
		}

		set xCD [expr {$DNx+($xD+1)*$LargeurLettre-$NXP*$NXPP}]
		set xCF [expr {$DNx+($xF+1)*$LargeurLettre-$NXP*$NXPP}]
		set yCD [expr {($yD-1)*$HauteurLettre-$NYP*$NYPP}]
		set yCF [expr {$yD*$HauteurLettre-$NYP*$NYPP}]

		set id [$K create rectangle $xCD $yCD $xCF $yCF \
			-fill $bg \
			-width 0 ]
		set fg "black"
		set bg "white"
	    }
	}
    }

    $K raise ItemText

    return
}


proc CalculeNoRes {yd yf xf} {
    # number of the last residue of each printed line yd..yf (indices
    # start at 0) at the column xf of the printed area
    global PrmPrt

    set xg [expr {$xf + $PrmPrt(xD)}]
    set dump ""
    set fmt "% -5d"
    foreach n [lrange $PrmPrt(LNOri) $yd $yf] {
	set n [string trim $n]
	if {$n eq "" || ! [info exists ::Sequences($n)]} {
	    append dump "\n"
	} else {
	    append dump "[format $fmt [DonnePosGS $n $xg]]\n"
	}
    }

    return $dump
}


proc NamesSeqsToPrint {} {
    # Returns 0 if there is nothing to print
    global PrmPrt NomNomSeq LNOrdali NomTextSeq NomsAffiches LSOrdali LongueurTotale NomSeqSel ZoneSelect

    set LNoms $NomsAffiches
    set LNOri $LNOrdali
    if {[QuelMode] eq "seqlab"} {
	set LSeqs [$NomTextSeq output all]
	set LongueurTotale [string length [lindex $LSeqs 0]]
	set LNOri $::LNSeqlab
    } else {
	set LSeqs $LSOrdali
    }

    switch $PrmPrt(Area) {
	"window" {
	    # Y visible zone
	    lassign [split [$NomNomSeq index @0,0] .] yD x
	    set ny [$NomNomSeq cget -height]
	    set yF [expr {$yD+$ny}]
	    set LNoms [lrange $LNoms $yD-1 $yF-1]
	    set LSeqs [lrange $LSeqs $yD-1 $yF-1]
	    set LNOri [lrange $LNOri $yD-1 $yF-1]
	    # X visible zone
	    lassign [$NomTextSeq xview] p1 p2
	    set xD [expr {int($p1*$LongueurTotale)}]
	    set xF [expr {min(int($p2*$LongueurTotale), $LongueurTotale-1)}]
	}
	"all" {
	    set xD 0 ; set yD 0
	    set xF [expr {$LongueurTotale-1}]
	    set yF [expr {[llength $LNoms]-1}]
	}
	"selected" {
	    # selected sequences (all if none) and columns of the
	    # selected zones (all if none)
	    set Ly {}
	    if {[info exists NomSeqSel]} {
		foreach e $NomSeqSel {
		    lappend Ly [expr {[lindex [split $e .] 0] - 1}]
		}
	    }
	    set Ly [lsort -integer -unique $Ly]
	    set xD 0
	    set xF [expr {$LongueurTotale-1}]
	    if {[info exists ZoneSelect] && $ZoneSelect != {}} {
		set Lx [concat {*}$ZoneSelect]
		set xD [tcl::mathfunc::min {*}$Lx]
		set xF [tcl::mathfunc::max {*}$Lx]
	    }
	    if {$Ly == {} && (! [info exists ZoneSelect] || $ZoneSelect == {})} {
		FaireLire "Nothing is selected !\nPlease select sequences and/or columns first."
		return 0
	    }
	    if {$Ly != {}} {
		set LNoms [lmap y $Ly {lindex $LNoms $y}]
		set LSeqs [lmap y $Ly {lindex $LSeqs $y}]
		set LNOri [lmap y $Ly {lindex $LNOri $y}]
	    }
	}
    }

    # displayed names are padded with spaces : use their real length
    set LNoms [lmap n $LNoms {string trimright $n}]
    set PrmPrt(LgNoms) [PlusLongEltDe $LNoms]
    set LNtmp [list] ; set LStmp [list] ; set LOtmp [list]
    set sgap [string repeat " " $LongueurTotale]
    set ngap [string repeat " " $PrmPrt(LgNoms)]
    set i -1 ; set iend [expr {[llength $LNoms]-1}]
    foreach n $LNoms s $LSeqs o $LNOri {
	incr i
	if {[string trim $n] eq "" && ($i == 0 || $i == $iend)} {
	    continue
	}
	if {[string trim $n] eq ""} {
	    set s $sgap
	    set n $ngap
	    set o ""
	}
	lappend LNtmp $n
	lappend LStmp [string range $s $xD $xF]
	lappend LOtmp $o
    }

    set PrmPrt(NbSeqs) [llength $LNtmp]
    set PrmPrt(LgSeqs) [expr {$xF-$xD+1}]
    set PrmPrt(xD)     $xD

    set PrmPrt(LSeqs) $LStmp
    set PrmPrt(LNoms) $LNtmp
    set PrmPrt(LNOri) $LOtmp

    return [expr {$PrmPrt(NbSeqs) > 0}]
}


proc LoadingFontImages {} {
    global OrdEtcDir

    set size [font configure FntPrt -size]
    set Lf [glob [file join $OrdEtcDir CN $size *.png]]
    foreach f $Lf {
	set img [file rootname [file tail $f]]
	if {$img eq "CN_${size}_Space"} {
	    set img "CN_${size}_"
	}
	image create photo $img -file $f
    }

    return
}


proc BonPrintOrdali {} {
    global Defauts PrmPrt DumpNoms DumpText NomNomSeq NomTextSeq Sequences LongueurTotale WTexteRegle

    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {! [info exists PrmPrt]} {
	PrintSetup defauts
    }
    PrintSetup "destroy"

    # output files : <base>.<page x>.<page y>.<format>
    set format [set PrmPrt(Format)]
    set file "Fichier[TypeAli]"
    set pfile [file rootname [file tail [set Defauts($file)]]]
    set fout [DemandeEtSauveFichier $format 0 $pfile]
    if {$fout eq ""} {
	return
    }
    set base [file rootname $fout]

    # a previous error may have left the temporary window/font
    catch {destroy .prttmp}
    catch {font delete FntPrt}
    font create FntPrt -family Courier -size [set PrmPrt(FontSize)] -weight [set PrmPrt(FontWght)]

    set Lfiles {}
    set pb [catch {
	set PrmPrt(ColRes) 0
	if {[InSeqlabMode] || ([info exists ::Toggle(MapRes)] && $::Toggle(MapRes))} {
	    set PrmPrt(ColRes) 1
	    LoadingFontImages
	}

	set FonteMetrics [font metrics FntPrt]
	set HauteurLettre [lindex $FonteMetrics 5]
	set LargeurLettre [font measure FntPrt "Z"]
	set PrmPrt(HgLet) $HauteurLettre
	set PrmPrt(WdLet) $LargeurLettre
	# width of a column (residue images or font)
	if {$PrmPrt(ColRes)} {
	    set cW [image width CN_$PrmPrt(FontSize)_A]
	} else {
	    set cW $LargeurLettre
	}
	lassign [DimensionsPapier] DimXPapier DimYPapier

	if {! [NamesSeqsToPrint]} {
	    error "nothing to print"
	}
	set LNoms $PrmPrt(LNoms)
	set LSeqs $PrmPrt(LSeqs)

	# Decoupage en Y
	set DimY $DimYPapier
	if {$DimY >= 0 && [set PrmPrt(Ruler)]} {
	    set DimY [expr {$DimY - 2*$HauteurLettre}]
	}
	lassign [DecoupeYEnPages $DimY] NPagesY NSeqsParPage DecalYNom

	# Decoupage en X
	# Calcule place pour mettre noms
	set DecalXNom [expr {($PrmPrt(LgNoms) + 3) * $LargeurLettre}]
	set DimX $DimXPapier
	if {$DimX >= 0} {
	    set DimX [expr {$DimXPapier - $DecalXNom}]
	    if {[set PrmPrt(ResidueNbr)]} {
		set DimX [expr {$DimX - 7*$LargeurLettre}]
	    }
	}
	lassign [DecoupeXEnPages $DimX] NPagesX NColsParPage

	# ruler of the printed area
	set LRegle [$WTexteRegle output all]

	set law .prttmp
	toplevel $law
	set K "$law.c"
	pack [canvas $K -background white -highlightthickness 0]

	if {$DimXPapier < 0} {
	    # unlimited : the page contains everything
	    set DimXPapier [expr {$DecalXNom + ($NColsParPage+8)*$cW + 20}]
	    set DimYPapier [expr {($NSeqsParPage+3)*$HauteurLettre + 20}]
	}

	for {set i 1} {$i <= $NPagesX} {incr i} {
	    set DebutX [expr {($i-1) * $NColsParPage}]
	    set FinX   [expr {$i * $NColsParPage - 1}]
	    if {$FinX >= $PrmPrt(LgSeqs)} {
		set FinX [expr {$PrmPrt(LgSeqs)-1}]
	    }

	    for {set j 1} {$j <= $NPagesY} {incr j} {
		set file "$base.$i.$j.$format"
		$K delete all
		# the window can not be larger than the screen (it is
		# grabbed by PrintCanvas, which scrolls a bigger page)
		$K configure \
		    -width  [expr {min($DimXPapier, [winfo screenwidth .]-100)}] \
		    -height [expr {min($DimYPapier, [winfo screenheight .]-150)}] \
		    -scrollregion [list 0 0 $DimXPapier $DimYPapier]
		set DebutY [expr {($j-1)*$NSeqsParPage}]
		set FinY   [expr {$j * $NSeqsParPage-1}]
		set DumpNoms [join [lrange $LNoms $DebutY $FinY] \n]
		set IdN [$K create text 0 0 \
			     -font FntPrt \
			     -anchor nw \
			     -text $DumpNoms]
		set BBNom [$K bbox $IdN]
		set DecalYNom [lindex $BBNom 3]

		MetTagsSurCanvas $K $DecalXNom $DebutX $FinX $DebutY $FinY

		if {[set PrmPrt(Ruler)]} {
		    # character by character, aligned on the columns
		    set gD [expr {$PrmPrt(xD) + $DebutX}]
		    set gF [expr {$PrmPrt(xD) + $FinX}]
		    set yr $DecalYNom
		    foreach lg $LRegle {
			set l [string range $lg $gD $gF]
			# numbers cut by the page limits are removed
			if {$gD > 0 && [string index $lg $gD-1] ni {" " ""}} {
			    regsub {^[^ ]+} $l [string repeat " " [string length [lindex [regexp -inline {^[^ ]+} $l] 0]]] l
			}
			if {[string index $lg $gF+1] ni {" " ""}} {
			    set m [lindex [regexp -inline {[^ ]+$} $l] 0]
			    regsub {[^ ]+$} $l [string repeat " " [string length $m]] l
			}
			set k 0
			foreach c [split $l ""] {
			    if {$c ne " "} {
				$K create text [expr {$DecalXNom + $k*$cW}] $yr \
				    -font FntPrt -anchor nw -text $c
			    }
			    incr k
			}
			incr yr $HauteurLettre
		    }
		}
		if {[set PrmPrt(ResidueNbr)]} {
		    # just after the last column of the page
		    set DumpResidus [CalculeNoRes $DebutY $FinY $FinX]
		    set xNum [expr {$DecalXNom + ($FinX-$DebutX+2)*$cW}]
		    $K create text $xNum 0 \
			-font FntPrt \
			-anchor nw \
			-text $DumpResidus
		}

		update idletasks

		if {$format eq "ps"} {
		    set Channel [open $file w]
		    $K postscript \
			-channel $Channel \
			-rotate [expr {[set PrmPrt(Orientation)] eq "landscape"}]
		    close $Channel
		} else {
		    image delete [PrintCanvas $K $format $file]
		}
		lappend Lfiles $file
	    }
	    update
	}
    } Msg]

    # always clean up
    catch {destroy .prttmp}
    catch {font delete FntPrt}

    if {$pb} {
	if {$Msg ne "nothing to print"} {
	    FaireLire "Error while printing :\n$Msg"
	}
	return
    }

    set n [llength $Lfiles]
    FaireLire "$n page[expr {$n > 1 ? "s" : ""}] written :\n[join [lrange $Lfiles 0 9] \n][expr {$n > 10 ? "\n..." : ""}]"

    return $Lfiles
}


