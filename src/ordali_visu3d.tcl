


#
#
# --- ordali_visu3d.tcl
#
#


proc IlFautVoir cmd {
    global VersViewer
    global COmac
    global Cras

    # O macro file

    if {$VersViewer == "VersOmac"} {
	if {[regexp "DebutDb" $cmd]} {
	    global LCOTmp
	    global NomDb
	    global NomMc

	    set LCOTmp {}
	    set NomDb [string trim [string range $cmd 8 end]]
	    set NomMc ""

	    return
	}
	if {[regexp "DebutMc" $cmd]} {
	    global LCOTmp
	    global NomMc
	    global NomDb

	    set LCOTmp {}
	    set NomMc [string trim [string range $cmd 8 end]]
	    set NomDb ""
	    return
	}
	if {$cmd == "FinDbMc"} {
	    global COmac
	    global LCOTmp
	    global NomDb
	    global NomMc

	    set nl [llength $LCOTmp]
	    if {$NomDb == ""} {
		set nom "@$NomMc"
	    } else {
		set nom "$NomDb"
	    }
	    puts $COmac "$nom T $nl 50"
	    foreach c $LCOTmp {
		puts $COmac $c
	    }
	    unset LCOTmp
	    set NomDb ""
	    set NomMc ""
	    return
	}
	if {$cmd == "FinOMac"} {
	    close $COmac
	} else {
	    global LCOTmp
	    if {![info exists LCOTmp]} {
		puts $COmac $cmd
	    } else {
		lappend LCOTmp $cmd
	    }
	}
	return
    }

    $VersViewer $cmd

    return
}


proc DownloadStructures {} {
    global ListePDB StrucAVoir Defauts

    if {! [llength $StrucAVoir]} {return}
    if {[set Defauts(DownloadPDB)] in {"none" "internet"}} {
	return
    }

    foreach s $StrucAVoir {
	set chn [DonneChainDeAccessPDB $s]
	set mol [DonneIdDeAccessPDB $s]

	set Lv [info globals "PDB_${mol}*"]
	foreach v $Lv {eval catch {unset $v}}
    }

    AfficheDownloadPDB

    return
}



proc PrepareViewer {} {
    global VersViewer
    global Defauts

    set viewer [set Defauts(Viewer)]
    if {$viewer eq "O macro file"} {set viewer "Omac"}
    set VersViewer "Vers[string trim $viewer]"

    return
}


proc VisualiseStructure {} {
    global Defauts ListePDB StrucAVoir

    if {0 && [string range [::platform::generic] 0 5] eq "macosx"} {
	FaireLire "Apple does not support OpenGL anymore.\nThis option is not available on this platform"

	return
    }

    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {[QuelMode] eq "seqlab"} {
	FaireLire "Not available in Editor mode !"
	return
    }

    if {! [llength $ListePDB]} {
	FaireLire "No structures to display !"
	return
    } else {
	set StrucAVoir {}
	foreach elt $ListePDB {
	    lassign $elt mol pdb
	    lappend StrucAVoir $mol
	}
    }

    set Ltop [winfo children .]
    if {".fcviewer" in $Ltop} {
	return
    }

    FaireAttendre "Please wait ...\nPreparing structures to be displayed ..."

    PrepareViewer
    set viewer [set Defauts(Viewer)]
    if {$viewer eq "O macro file"} {set viewer "Omac"}

    DownloadStructures

    AfficheDans$viewer

    FaireLaSuite

    return
}


proc CalculeSpheres {chn mol} {
    global ListeDesSpheres
    global ListeDesObjetsDansO
    global SphDef

    global PDB_[set mol]_NomAtm
    global PDB_[set mol]_NomRes
    global PDB_[set mol]_NmrRes
    global PDB_[set mol]_ChnIdn
    global PDB_[set mol]_AtmXYZ

    catch {unset ListeDesObjetsDansO}
    if {! [info exists ListeDesSpheres($mol)]} {return 0}

    set ListeAtm [set PDB_[set mol]_AtmXYZ($chn)]
    set ListeNom [set PDB_[set mol]_NmrRes($chn)]

    foreach sp [set ListeDesSpheres($mol)] {
	lassign $sp NoRes Coul
	set idn [lsearch $ListeNom $NoRes]
	set NAtm [llength [lindex $ListeAtm $idn]]

	set xm 0.
	set ym 0.
	set zm 0.

	foreach a [lindex $ListeAtm $idn] {
	    scan $a "%f %f %f" x y z

	    set xm [expr {$xm + $x}]
	    set ym [expr {$ym + $y}]
	    set zm [expr {$zm + $z}]
	}

	set xm [expr {$xm / $NAtm}]
	set ym [expr {$ym / $NAtm}]
	set zm [expr {$zm / $NAtm}]

	set dmax -9999
	foreach a [lindex $ListeAtm $idn] {
	    lassign $a x y z

	    set xd [expr {$x - $xm}]
	    set yd [expr {$y - $ym}]
	    set zd [expr {$z - $zm}]

	    set dist2 [expr {$xd * $xd + $yd * $yd + $zd * $zd}]
	    set dist [expr {sqrt($dist2)}]
	    if {$dist > $dmax} {set dmax $dist}
	}


	if {$SphDef == "Mean"} {
	    set Rayon $dmax
	} else {
	    set Hbond 3.4
	    set Rayon [expr {$dmax + $Hbond}]
	}

	set IdxPt [string last "PTS" $Coul]

	if {$IdxPt != -1} {
	    set CPts "PTS"
	    set Coul [string range $Coul 0 [expr {$IdxPt - 1}]]
	    lappend ListeDesObjetsDansO($CPts) "sphere_xyz [format "%6.2f %6.2f %6.2f %6.2f" $xm $ym $zm $Rayon]"
	}

	lappend ListeDesObjetsDansO($Coul) "sphere_xyz [format "%6.2f %6.2f %6.2f %6.2f" $xm $ym $zm $Rayon]"
    }

    #    EcritSpheres $mol
    #    puts " "
    return 1
}


proc CouleurOrdali2O {Cord} {
    #    set Cord [string tolower $Cord]
    if {[regexp "_" $Cord]} {return $Cord}
    if {[regexp {^[A-Za-z0-9#]+$} $Cord]} {return $Cord}

    regsub -all {([A-Z])} $Cord {_\1} Ctemp
    set Ctmp [string trim $Ctemp "_"]

    return [string tolower $Ctmp]
}


proc LaTkColDe {c} {
    if {! [info exists ::ListeTkCol]} {InitTkCol}
    if {[regexp {_} $c]} {
	set c [string map {_ ""} $c]
    }

    set n [lsearch -inline -nocase $::ListeTkCol $c]
    if {$n ne ""} {
	return $n
    } else {
	return blue
    }
}


proc CouleurDuStock {i} {

    #rR 20170531 pour Misynpat !!!!!!!!!!!!!!!!!!!!!!!!!
    if { ! [info exists ::Couleurs(Stock)]} {
	set ::Couleurs(Stock) {red blue yellow green1 magenta orange cyan brown forest_green pink goldenrod sea_green coral violet khaki navy_blue salmon sienna turquoise lime_green maroon spring_green medium_blue indian_red dim_gray light_gray gray}
    }

    set n [llength [set ::Couleurs(Stock)]]
    set c [lindex [set ::Couleurs(Stock)] [expr {$i%$n}]]

    return [LaTkColDe $c]
}


proc CouleurO2Ordali {Co} {
    if {[regexp {[A-Z]} [string index $Co 0]]} {
	return $Co
    }
    if {[string index $Co 0] eq "#"} {return $Co}

    set Co [string tolower $Co]
    set li [regexp -all -indices -inline {\_} $Co]
    if {$li != ""} {
	set li [lsort -decreasing -integer -index 0 $li]
	foreach e $li {
	    set i [lindex $e 0]
	    set im [expr {$i - 1}]
	    set ip [expr {$i + 1}]

	    set Co "[string toupper $Co 0 0]"
	    set Co "[string toupper $Co ${ip} ${ip}]"
	    set Co "[string range $Co 0 ${im}][string range $Co $ip end]"
	}
    }

    return [string trim $Co]
}


proc FinColorieSSParams {quoi} {
    global PSS

    if {$PSS(MeanRef) eq "ref" && $PSS(PDBRef) eq ""} {
	return
    }
    set w $PSS(Top)
    destroy $w

    if {$quoi ne "ok"} {
	unset PSS
    }

    update

    return
}


proc ColorieSSParamsGUI {} {
    global PSS ListePDB

    toplevel .pss
    wm title .pss "Select parameters ..."
    wm protocol .pss WM_DELETE_WINDOW KillParLaCroix
    wm resizable .pss 0 0
    set PSS(Top) .pss
    
    set fp .pss.f
    set ListChx [ExtraitListeDeListe $ListePDB 0]

    frame $fp
    grid $fp -row 0 -column 0 -sticky news
    grid columnconfig $fp 0 -weight 1

    label $fp.lbl \
	-text "Select Parameters ..." \
	-font "Helvetica 14 bold" \
	-anchor w -justify left
    grid $fp.lbl -row 0 -column 0 -sticky w  -pady 5 -padx 5
    
    set PSS(MeanRef) "mean"
    frame $fp.fpdb
    grid $fp.fpdb  -row 1 -column 0 -sticky ew -pady 5 -padx 5
    label $fp.fpdb.lbl \
	-text "Compute similarities on mean sec. str., or use a reference :" \
	-wraplength 250 \
	-fg blue \
	-anchor w -justify left
    radiobutton $fp.fpdb.rmean -text "Mean" \
	-relief flat -anchor w \
	-variable PSS(MeanRef) \
	-value "mean"
    radiobutton $fp.fpdb.rref \
	-text "Use reference" \
	-relief flat -anchor w\
	-variable PSS(MeanRef) \
	-value "ref"
    tk_optionMenu $fp.fpdb.mpdb PSS(PDBRef) {*}$ListChx
    grid $fp.fpdb.lbl -row 0 -column 0 -columnspan 2 -sticky ew
    grid $fp.fpdb.rmean -row 1 -column 0 -columnspan 2 -sticky w -padx {30 1}
    grid $fp.fpdb.rref  -row 2 -column 0 -sticky w -padx {30 1}
    grid $fp.fpdb.mpdb  -row 2 -column 1 -sticky w
    
    set PSS(Ramp) "color"
    frame $fp.framp
    grid $fp.framp -row 2 -column 0 -sticky ew -pady 5 -padx 5
    label $fp.framp.lbl \
	-text "Select the type of color gradient :" \
	-fg blue \
	-anchor w -justify left
    radiobutton $fp.framp.col \
	-text "Color" \
	-relief flat \
	-variable PSS(Ramp) \
	-value "color"
    radiobutton $fp.framp.gre \
	-text "Grey" \
	-relief flat \
	-variable PSS(Ramp) \
	-value "grey"
    grid $fp.framp.lbl -row 0 -column 0 -sticky w
    grid $fp.framp.col -row 1 -column 0 -sticky w -padx {30 1}
    grid $fp.framp.gre -row 2 -column 0 -sticky w -padx {30 1}
    
    set PSS(RExtend) "minmax"
    frame $fp.fborn
    grid $fp.fborn -row 3 -column 0 -sticky ew -pady 5 -padx 5
    label $fp.fborn.lbl \
	-text "Select limits of gradient :" \
	-fg blue \
	-anchor w -justify left
    radiobutton $fp.fborn.rvmm \
	-text "min to max" \
	-relief flat \
	-variable PSS(RExtend) \
	-value "minmax"    
    radiobutton $fp.fborn.rvmx \
	-text "0 to 100" \
	-relief flat \
	-variable PSS(RExtend) \
	-value "zerocent"
    grid $fp.fborn.lbl -row 0 -column 0 -sticky w
    grid $fp.fborn.rvmm -row 1 -column 0 -sticky w -padx {30 1}
    grid $fp.fborn.rvmx -row 2 -column 0 -sticky w -padx {30 1}

    set PSS(BFactor) 0
    checkbutton $fp.chkb \
	-text "assign similarites to B factors" \
	-relief flat -anchor w -justify left \
	-variable PSS(BFactor) \
	-onvalue 1 -offvalue 0
    grid $fp.chkb  -row 4 -column 0 -sticky ew -pady 5 -padx 5
    
    frame $fp.fbut
    grid $fp.fbut  -row 5 -column 0 -sticky ew -pady {30 10} -padx 5
    button $fp.fbut.bok \
	-text " OK " \
	-bg green1 \
	-command [list FinColorieSSParams ok]
    button $fp.fbut.bdis \
	-text "Dismiss" \
	-bg red \
	-command [list FinColorieSSParams dismiss]
    grid $fp.fbut.bdis -row 0 -column 0 -sticky w -padx {20 1}
    grid $fp.fbut.bok  -row 0 -column 1 -sticky e -padx {1 20}
    grid columnconfig $fp.fbut 0 -weight 1
    
    set oldGrab [grab current]
    grab .pss
    FenetreAuCentre .pss

    tkwait window .pss

    if {$oldGrab ne ""} {
	grab $oldGrab
    }

    return
}


proc ColorieSSSelonConservation {} {
    global Sequences ZoneSelect ListePCISS ListePDB LNOrdali TabSF ListeTypesDeFeatures StrucAVoir Defauts PSS

    if {[TypeAli] eq "pasdali"} {return}

    # pas de pdb
    if {! [info exists ListePDB] || $ListePDB == {}} {
	FaireLire "No structures in this alignment !"
	return
    }

    # interface graphique pour parametres
    set toto [ColorieSSParamsGUI]
    if {! [info exists PSS]} {return}

    FaireAttendre "Please wait ...\nComputing sequence similarities\naccording to secondary structures ...."

    # ATTENTION ! 
    # Tout est fait en position de l'alignement !
    # Calcule ListePCISS
    if {[set PSS(MeanRef)] eq "mean"} {
	CalculeConservationParSS ""
    } else {
	CalculeConservationParSS $PSS(PDBRef)
    }
    set Lfeat [list]
    set min  99999999.
    set max -99999999.
    foreach df $ZoneSelect {
	lassign $df deb fin
	puts "\nd= $deb f= $fin"
	if {abs($fin - $deb) < 2} {
	    continue
	}

	set lp [set ListePCISS($deb,$fin)]
	if {$lp == {} } {
	    continue
	}

	set m 0.0
	set i 0
	foreach elt $lp {
	    lassign $elt n1 n2 pci d e f
	    
	    if {$n1 eq $n2} {
		continue
	    }
	    if {[info exists Vu($n1,$n2)] || [info exists Vu($n2,$n1)]} {
		continue
	    }
	    set Vu($n1,$n2) 1
	    set Vu($n2,$n1) 1
	    
	    #puts "pci $pci"
	    set m [expr {$m + $pci}]
	    incr i
	}
	unset -nocomplain Vu

	#puts "i= $i"
	if {$i != 0} {
	    set m [expr {100.*$m/$i}]
	    set ListePCISS($deb,$fin,mean) $m
	    if {$m <= $min} {set min $m}
	    if {$m >= $max} {set max $m}
	} else {
	    array unset ListePCISS "$deb,$fin"
	    array unset ListePCISS "$deb,$fin,*"
	}
	update
    }

    if {! [info exists StrucAVoir]} {
	set StrucAVoir [ExtraitListeDeListe $ListePDB 0]
    }

    if {$PSS(RExtend) eq "minmax"} {
	set step [expr {($max-$min)/10.}]
	set floor $min
    } else {
	set step 10.
	set min 0.
	set max 100.
	set floor 0.
    }
    
    for {set i 1} {$i <= 10} {incr i} {
	set seuilB [expr {$floor+$step*($i-1)}]
	set seuilH [expr {$floor+$step*$i}]
	set ic [expr {$i-1}]
	foreach df $ZoneSelect {
	    lassign $df deb fin
	    if {abs($fin - $deb) < 2 || ! [info exists ListePCISS($deb,$fin,mean)]} {
		continue
	    }
	    
	    set m [set ListePCISS($deb,$fin,mean)]
	    if {$m >= $seuilB && $m <= $seuilH} {
		if {$PSS(Ramp) eq "color"} {
		    set c [set Defauts(GammeCoul$ic)]
		} else {
		    set c [set Defauts(GammeGris$ic)]
		}
		#puts [format "    %s %6.2f" $c $m]
		# the colour of the ramp, as for the other features
		lappend Lfeat [list "fstart" $deb "fstop" $fin "fcolor" $c "fscore" $m "fnote" [format "%.1f %% identity" $m]]
	    }
	}
    }

    set idn "SS-Cons"
    if {$idn ni $ListeTypesDeFeatures} {
	lappend ListeTypesDeFeatures $idn
    } else {
	array unset TabSF "*,SS-Cons"
    }
    foreach n $StrucAVoir {
	set TabSF([BonAccess $n],$idn) $Lfeat
    }

    if {$PSS(BFactor)} {
	foreach n $StrucAVoir {
	    set mol [DonneIdDeAccessPDB $n]
	    set chn [DonneChainDeAccessPDB $n]
	    $mol _SetB all all 0.0 $chn
	    
	    foreach ft $Lfeat {
		DecortiqueUneFeature $ft d f c s note
		set deb [DonnePosGS $n $d]
		set fin [DonnePosGS $n $f]

		$mol _SetB $deb $fin $s $chn
	    }
	}
    }

    # Log les resultats
    AuLog @separator

    AuLog @begin table
    AuLog @title Mean %Identity per secondary structure
    if {$PSS(MeanRef) ne "mean"} {
	set pdb $PSS(PDBRef)
	set nom [DonneIdDeAccessPDB $pdb]
	set meth "Method : using $PSS(PDBRef) as reference for sec. str."
	set head [list "Abs  Range" "Rel Range" "%Identity" "Color"]
	set type [list T T R T ]
    } else {
	set meth "Method : using mean sec. str.\n"
	set head [list "Ranges" "%Identity" "Color"]
	set type [list T R T]
    }
    AuLog @text "$meth"
    AuLog @begin tabular
    AuLog @titlecols {*}$head
    AuLog @typecols {*}$type
    foreach elt $Lfeat {
	DecortiqueUneFeature $elt d f c s n
	set col [CouleurPlusProcheDeTkCol $c]

	if {$PSS(MeanRef) eq "ref"} {
	    set dr [DonnePosGS $pdb $d]
	    set fr [DonnePosGS $pdb $f]
	}
	if {$PSS(MeanRef) ne "mean"} {
	    AuLog @row "$d $f" "$dr $fr" $s $col
	} else {
	    AuLog @row "$d $f" $s $col
	}
    }
    AuLog @end
    AuLog @end

    # Lance la visualisation
    ColorieMol3dSelonFeatures "SS-Cons"

    FaireLaSuite
    unset PSS
    unset ListePCISS

    return
}


proc AretesDuCube {a1 b1 c1 d1 a2 b2 c2 d2} {

    # Face haut
    glBegin GL_LINES
    glVertex3fv $a1
    glVertex3fv $b1
    glEnd

    glBegin GL_LINES
    glVertex3fv $b1
    glVertex3fv $c1
    glEnd

    glBegin GL_LINES
    glVertex3fv $c1
    glVertex3fv $d1
    glEnd

    glBegin GL_LINES
    glVertex3fv $d1
    glVertex3fv $a1
    glEnd

    # face bas
    glBegin GL_LINES
    glVertex3fv $a2
    glVertex3fv $b2
    glEnd

    glBegin GL_LINES
    glVertex3fv $b2
    glVertex3fv $c2
    glEnd

    glBegin GL_LINES
    glVertex3fv $c2
    glVertex3fv $d2
    glEnd

    glBegin GL_LINES
    glVertex3fv $d2
    glVertex3fv $a2
    glEnd

    # Poteaux
    glBegin GL_LINES
    glVertex3fv $a1
    glVertex3fv $a2
    glEnd

    glBegin GL_LINES
    glVertex3fv $b1
    glVertex3fv $b2
    glEnd

    glBegin GL_LINES
    glVertex3fv $c1
    glVertex3fv $c2
    glEnd

    glBegin GL_LINES
    glVertex3fv $d1
    glVertex3fv $d2
    glEnd

    return
}


proc FacesDuCube {c a1 b1 c1 d1 a2 b2 c2 d2} {

    # Face haut
    glBegin GL_QUADS

    glColor4f {*}$c
    set n [NormaleDe $a1 $b1 $c1]
    glNormal3fv $n
    glVertex3fv $a1
    glVertex3fv $b1
    glVertex3fv $c1
    glVertex3fv $d1

    # Face bas
    glColor4f {*}$c
    set n [NormaleDe $a1 $c2 $b2]
    glNormal3fv $n
    glVertex3fv $a2
    glVertex3fv $b2
    glVertex3fv $c2
    glVertex3fv $d2

    glColor4f {*}$c
    set n [NormaleDe $a1 $b1 $c1]
    glNormal3fv $n
    glVertex3fv $a1
    glVertex3fv $b1
    glVertex3fv $b2
    glVertex3fv $a2

    glColor4f {*}$c
    set n [NormaleDe $b1 $c1 $b2]
    glNormal3fv $n
    glVertex3fv $b1
    glVertex3fv $c1
    glVertex3fv $c2
    glVertex3fv $b2

    glColor4f {*}$c
    set n [NormaleDe $c1 $d1 $d2]
    glNormal3fv $n
    glVertex3fv $c1
    glVertex3fv $d1
    glVertex3fv $d2
    glVertex3fv $c2

    glColor4f {*}$c
    set n [NormaleDe $d1 $a1 $a2]
    glNormal3fv $n
    glVertex3fv $d1
    glVertex3fv $a1
    glVertex3fv $a2
    glVertex3fv $d2

    glEnd
    
    return
}


proc NormaleDe {a b c} {
    
    set v1 [V_VV $b - $a]
    set v2 [V_VV $c - $a]
    set N [Vectoriel $v1 $v2]
    set N [V_nV $N]

    return $N
}


proc TestCoupeMainChain {type Lca {Lcol {}} {Lc {}} {Lo {}}} {

    if {$type eq "Protein"} {
	# CA - CA : en gros 4.3 A -> Thr 6.
	set dst 36.
    } else {
	# P - P : en gros 5.5 A -> Thr 8
	set dst 64.
    }

    set Li 0
    set i 0
    set p0 [lindex $Lca 0]
    foreach p [lrange $Lca 1 end] {
	lassign $p0 a b c d
	lassign $p  x y z w
	if {($a-$x)**2 + ($b-$y)**2 + ($c-$z)**2 > $dst} {
	    lappend li $i
	}
	set p0 $p
	incr i
    }
    lappend Li [expr {[llength $Lca]-1}]
    set i0 0
    set Lres [list]
    foreach i [lrange $Li 1 end] {
	set rca  [lrange $Lca $i0 $i]
	if {$Lcol != {}} {
	    set rcol [lrange $Lcol $i0 $i]
	} else {
	    lappend Lres $rca
	    continue
	}
	if {$Lc != {}} {
	    set rc [lrange $Lc $i0 $i]
	    set ro [lrange $Lo $i0 $i]
	    
	    lappend Lres [list $rca $rcol $rc $ro]
	} else {
	    lappend Lres [list $rca $rcol]
	}
	set i0 [expr {$i+1}]
    }

    return $Lres
    if {[llength $Li] == 2} {
	return [list $Lres]
    } else {
	return $Lres
    }
}


