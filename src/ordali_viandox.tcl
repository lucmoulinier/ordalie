

#
# ordali_viandox.tcl   (anciennement v2)
#

proc QuitteViandox {} {
    global Mol3dCou pgl StrucAVoir Obj3dCou Feat3dCou Feat3dCou2

    trace remove variable Mol3dCou write UpdateMol3dObjets
    trace remove variable ::ListeTypesDeFeatures write MetAJourFeaturesViandox
    trace remove variable ::AtomePique write ProcessMeasureDistance

    # We only delete display lists
    foreach mold [StrucDuViewer] {
	set nom [DonneIdDeAccessPDB $mold]
	foreach o [$nom _ListeObjets] {
	    $nom _dellist $o
	}
    }

    if {$pgl(SelectionList) ne ""} {
	glDeleteLists $pgl(SelectionList) 1
    }

    destroy [winfo toplevel $pgl(wogl)]

    unset pgl 
    unset -nocomplain NwOj NwOjR
    unset -nocomplain Obj3dCou Feat3dCou Feat3dCou2

    return
}


# The 3D viewer is bound to the instance it was opened for (pgl(Mac)),
# like the trees (Abr($AId,Mac)) and the overviews (Ovw(O$Id,Mac)) :
# what needs the data of the alignment (features, columns, objects
# made from them, superposition) is refused in another instance.
# Viewing (rotation, zoom, objects on/off, distances ...) stays allowed.

proc ViewerOuvert {} {
    return [expr {[info exists ::pgl(wogl)] && [winfo exists $::pgl(wogl)]}]
}


proc StrucDuViewer {} {
    # structures shown by the 3D viewer : StrucAVoir when it was
    # opened (the global is changed by the tools of other instances)
    if {[info exists ::pgl(StrucAVoir)]} {
	return $::pgl(StrucAVoir)
    }
    if {[info exists ::StrucAVoir]} {
	return $::StrucAVoir
    }
    return {}
}


proc NomInstanceViewer {} {
    set nm ""
    catch {set nm [lindex [NomDeMac $::pgl(Mac)] 0]}
    return $nm
}


proc NomInstanceCourante {} {
    set nm ""
    catch {set nm [MacCourant name]}
    return $nm
}


proc ViewerDansSonInstance {{quoi "use this function"}} {
    # 1 if the 3D viewer shows the current instance, else warns and 0
    if {! [info exists ::pgl(Mac)] || $::pgl(Mac) == [MacCourant]} {
	return 1
    }
    set nm [NomInstanceViewer]
    FaireLire "Warning !\nThis 3D viewer was opened for another instance of the alignment ($nm),\nnot for the current one ([NomInstanceCourante]).\nDisplay instance $nm to $quoi."

    return 0
}


proc ViewerPourInstanceCourante {{quoi "display the structures"}} {
    # before working on the structures of the current instance : a 3D
    # viewer opened for another instance is closed if the user agrees
    # (its objects are kept). 0 if the user cancels.
    if {! [ViewerOuvert] || ! [info exists ::pgl(Mac)] || $::pgl(Mac) == [MacCourant]} {
	return 1
    }
    set chx [tk_dialog .chxviewer "Warning" "The 3D viewer shows instance [NomInstanceViewer].\nClose it to $quoi for instance [NomInstanceCourante] ?\n(the objects are kept)" warning 0 "Close it" "Cancel"]
    if {$chx != 0} {
	return 0
    }
    QuitteViandox

    return 1
}


proc AfficheDansViandox {} {
    global pgl Rad OrdaliDir StrucAVoir Liste3dMol

    # Deja passe par la
    # (viewer of another instance : closed if the user agrees)
    if {[info exists pgl(wogl)]} {
	if {! [ViewerPourInstanceCourante]} {
	    raise [winfo toplevel $pgl(wogl)]
	    return 0
	}
    }
    if {[info exists pgl(wogl)]} {
	raise [winfo toplevel $pgl(wogl)]
	update idletasks

	return 1
    }

    InitialisationViandox
    # the viewer is bound to the current instance
    set pgl(Mac) [MacCourant]
    set pgl(StrucAVoir) $StrucAVoir

    # default objects are then created only for the chains without them
    LoadObjFromDB
    set ObjDone 0
    
    # Liste des structures pour la combobox
    set Liste3dMol {}
    foreach e $StrucAVoir {
	lappend Liste3dMol [DonneIdDeAccessPDB $e]
    }
    set Liste3dMol [lsort -unique $Liste3dMol]

    set cx 0. ; set cy 0. ; set cz 0.
    set zmin 999999. ; set zmax -999999.
    set ymin 999999. ; set ymax -999999.
    set xmin 999999. ; set xmax -999999.
    set cmp 0 ; set ZeRad 1.
    set ListeObjPDB {}

    foreach mold $StrucAVoir {
	set nom [DonneIdDeAccessPDB $mold]
	set chn [DonneChainDeAccessPDB $mold]
	lappend ListeObjPDB $nom

	# bbox returns (xmin xmax ymin ymax zmin zmax) -- fix: the previous
	# lassign assumed (xmin ymin zmin xmax ymax zmax), which mixed up
	# the axes (see analysis). Fixed here.
	lassign [$nom bbox] xm xx ym yx zm zx
	if {$xm < $xmin} {set xmin $xm}
	if {$xx > $xmax} {set xmax $xx}
	if {$ym < $ymin} {set ymin $ym}
	if {$yx > $ymax} {set ymax $yx}
	if {$zm < $zmin} {set zmin $zm}
	if {$zx > $zmax} {set zmax $zx}
	# Keep each structure's own bbox (once per name) for the
	# superposed/non-superposed coherence test done further below.
	if {![info exists BBoxNom($nom)]} {
	    set BBoxNom($nom) [list $xm $xx $ym $yx $zm $zx]
	}
	#if {$zeRad < [$nom radius]} {set ZeRad [$nom radius]}

	# Viewer opened again : the objects still exist, only their
	# display lists were deleted by QuitteViandox -> draw them again,
	# and do not create the default objects again
	set LObjEx [$nom _ListeObjets]
	if {! [info exists DejaRendu($nom)]} {
	    set DejaRendu($nom) 1
	    foreach o $LObjEx {
		$nom render $o
	    }
	}
	if {"obj_CT${nom}$chn" in $LObjEx} {
	    continue
	}

	if {! $ObjDone} {
	    if {$::Defauts(PrecomputeSrf)} {
		$nom newObj "SF${nom}$chn"
		$nom select chain $chn
		$nom ribbons "SF${nom}$chn"
		$nom surface "SF${nom}$chn"
		$nom render "SF${nom}$chn"
	    }

	    #$nom newObj "CP${nom}$chn"
	    #$nom select chain $chn
	    #$nom CPK "CP${nom}$chn"
	    #$nom render "CP${nom}$chn"
	}

	if {1} {
	    $nom newObj "CT${nom}$chn"
	    $nom select chain $chn
	    $nom catrace "CT${nom}$chn"
	    $nom render "CT${nom}$chn"
	}

	if {1} {
	    if {! $ObjDone} {
		$nom newObj "AL${nom}$chn"
		$nom select chain $chn
		$nom atomes "AL${nom}$chn"
		$nom render "AL${nom}$chn"
		update

		$nom newObj "CA${nom}$chn"
		$nom select chain $chn
		$nom ribbons "CA${nom}$chn"
		#$nom setboite "CA${nom}$chn" $chn
		$nom render "CA${nom}$chn"
	    }
	}

	if {0} {
	    $nom newObj "CP${nom}$chn"
	    $nom select chain $chn
	    $nom CPK "CP${nom}$chn"
	    $nom render "CP${nom}$chn"
	}
    }

    # --- PROVISIONAL center/radius, just so the OpenGL window can be
    # created (AfficheFenetreOpengl -> Togl -> reshape needs valid
    # values). Recomputed below around the real camera center (the
    # centroid), once it is known.
    set pgl(xCen) [expr {($xmax+$xmin)/2.}]
    set pgl(yCen) [expr {($ymax+$ymin)/2.}]
    set pgl(zCen) [expr {($zmax+$zmin)/2.}]

    set Rad [expr {sqrt( \
			     ($xmax-$xmin)**2 + \
			     ($ymax-$ymin)**2 + \
			     ($zmax-$zmin)**2) \
		       / 2.}]
    set pgl(Rad)       $Rad

    # backclip = z near (z neg)
    set pgl(backclip)  [expr {-0.1 * $Rad}]
    # frontclip = z far 
    set pgl(frontclip) [expr { 2.1 * $Rad}]

    set pgl(eyeX)      0.0
    set pgl(eyeY)      0.0
    set pgl(eyeZ)      $pgl(frontclip)

    set pgl(fogStart)  [expr {0.3*$Rad}]
    set pgl(fogEnd)    [expr {0.6*$Rad}]
    
    AfficheFenetreOpengl
    set nm [NomInstanceCourante]
    if {$nm ne ""} {
	wm title [winfo toplevel $pgl(wogl)] "$pgl(appName) - instance $nm"
    }
    
    set LFPDB {}
    foreach mold $StrucAVoir {
	set nom [DonneIdDeAccessPDB $mold]
	set chn [DonneChainDeAccessPDB $mold]

	if {$nom ni $LFPDB} {
	    AddFObj $nom
	    lappend LFPDB $nom
	}

	lassign [$nom center] x y z
	set cx [expr {$cx + $x}]
	set cy [expr {$cy + $y}]
	set cz [expr {$cz + $z}]

	incr cmp
    }
    if {$cmp != 0} {
	set cx [expr {$cx/$cmp}]
	set cy [expr {$cy/$cmp}]
	set cz [expr {$cz/$cmp}]
    }

    # at start, only the CA traces are shown (light and readable for
    # superposed structures) : the other objects are switched on with
    # their buttons
    TousObjetsOff
    foreach mold $StrucAVoir {
	set nom [DonneIdDeAccessPDB $mold]
	set chn [DonneChainDeAccessPDB $mold]
	set o "CT${nom}$chn"
	if {[winfo exists $pgl(frObjc).f${nom}.bto$o]} {
	    $pgl(frObjc).f${nom}.bto$o invoke
	}
    }
    update

    # --- Are the structures superposed or not? ---
    # If the structures in StrucAVoir are NOT superposed (no shared
    # RotTrans, coordinates in independent crystallographic frames), the
    # GLOBAL bounding center/radius (over the union of all structures)
    # makes no physical sense: it can be huge, with each structure tiny
    # and lost in the middle of empty space. So we compute each
    # structure's own center/radius, and only switch to a global framing
    # if the structures are "close to each other" relative to their own
    # size -- a sign that they have been superposed (or are naturally
    # close). Otherwise, we frame on a reference structure (the first one
    # loaded) and warn the user (strategy A+C).
    set LNomUniq {}
    foreach n $ListeObjPDB {
	if {$n ni $LNomUniq} {lappend LNomUniq $n}
    }

    foreach n $LNomUniq {
	lassign [set BBoxNom($n)] xmN xxN ymN yxN zmN zxN
	lassign [$n center] cxN cyN czN
	set rN 0.
	foreach xe [list $xmN $xxN] {
	    foreach ye [list $ymN $yxN] {
		foreach ze [list $zmN $zxN] {
		    set d [expr {sqrt(($xe-$cxN)**2 + ($ye-$cyN)**2 + ($ze-$czN)**2)}]
		    if {$d > $rN} {set rN $d}
		}
	    }
	}
	set CentreStruct($n) [list $cxN $cyN $czN]
	set RayonStruct($n)  $rN
    }

    # Coherence threshold: two structures are considered to be "in the
    # same scene" if the distance between their centers does not exceed
    # kCoherence times the sum of their own radii. Adjust if needed (2.0
    # is already fairly tolerant: it leaves room even if structures do
    # not overlap exactly after superposition).
    set kCoherence 2.0
    set Coherent 1
    set nN [llength $LNomUniq]
    for {set i 0} {$i < $nN} {incr i} {
	set ni [lindex $LNomUniq $i]
	lassign $CentreStruct($ni) cix ciy ciz
	set ri $RayonStruct($ni)
	for {set j [expr {$i+1}]} {$j < $nN} {incr j} {
	    set nj [lindex $LNomUniq $j]
	    lassign $CentreStruct($nj) cjx cjy cjz
	    set rj $RayonStruct($nj)
	    set dij [expr {sqrt(($cix-$cjx)**2 + ($ciy-$cjy)**2 + ($ciz-$cjz)**2)}]
	    if {$dij > $kCoherence*($ri+$rj)} {
		set Coherent 0
	    }
	}
    }

    if {$Coherent || $nN <= 1} {
	# --- Coherent case (superposed structures, or a single structure) ---
	# Rad recomputed around the REAL camera center (the centroid), as
	# the max distance from the centroid to the 8 corners of the global
	# bbox (correct and cheap bound, already established above).
	set RadCentroid 0.
	foreach xe [list $xmin $xmax] {
	    foreach ye [list $ymin $ymax] {
		foreach ze [list $zmin $zmax] {
		    set d [expr {sqrt(($xe-$cx)**2 + ($ye-$cy)**2 + ($ze-$cz)**2)}]
		    if {$d > $RadCentroid} {set RadCentroid $d}
		}
	    }
	}
    } else {
	# --- Non-coherent case: frame on the reference structure (the
	# first one in StrucAVoir) and warn the user. ---
	set NomRef [lindex $LNomUniq 0]
	lassign $CentreStruct($NomRef) cx cy cz
	set RadCentroid $RayonStruct($NomRef)

	tk_messageBox -icon warning -type ok \
	    -title "Structures non superposees" \
	    -message "Les structures affichees semblent trop eloignees les\
                       unes des autres pour former une seule scene coherente\
                       (pas de superposition detectee). La vue est cadree sur\
                       $NomRef ; utilisez le zoom/pan, ou le menu \"Center\"\
                       de chaque objet, pour naviguer vers les autres\
                       structures."
    }

    set pgl(xCen) $cx
    set pgl(yCen) $cy
    set pgl(zCen) $cz

    # Fixed additive margin (in Angstrom), on top of the proportional
    # margin (x1.1) already applied via backclip/frontclip below. The
    # min/max above only cover atom positions (points), not what is
    # actually drawn around them: van der Waals radius of CPK/pearl
    # spheres (RayonDeAtome, ~1.5-2 A), ribbon half-width (d1/d2 in
    # CheminRibbon, 0.7 A). Without this margin, a purely proportional
    # margin on Rad can be insufficient for a small structure (isolated
    # peptide, small Rad).
    set MargeRad 4.0
    set Rad [expr {$RadCentroid + $MargeRad}]
    set pgl(Rad) $Rad

    # backclip = z near (z neg)
    set pgl(backclip)  [expr {-0.1 * $Rad}]
    # frontclip = z far
    set pgl(frontclip) [expr { 2.1 * $Rad}]
    set pgl(eyeZ)      $pgl(frontclip)

    set pgl(fogStart) [expr {abs($cz)}]
    set pgl(fogEnd)   [expr {0.9*($Rad-abs($cz))}]
    
    Update3DMatrices
    $pgl(wogl) postredisplay

    return 1
}


proc InitialisationViandox {} {
    global frontclip backclip cx cy Rad pgl Defauts BUFSIZE selectBuffer AtmPick AtomePique TypeRep Transform TransformList 

    #package require tclsurface
    set ::cQuat [trackball 0.0 0.0 0.0 0.0]
    set ::qCount 0

    set TypeRep ""

    # Pour texte
    set Transform [tcl3dVector GLfloat 16]
    tcl3dMatfIdentity $Transform
    set TransformList [tcl3dVectorToList $Transform 16]

    set BUFSIZE 512
    set selectBuffer [tcl3dVector GLuint $BUFSIZE]
    set AtmPick {}
    set AtomePique ""
    set Rad 0.
    set cx 0
    set cy 0

    set pgl(showframe)  1
    set pgl(appName)    "Ordalie 3D Viewer"
    set pgl(width)      500
    set pgl(height)     400
    set pgl(ratioX)     1.0
    set pgl(ratioY)     1.0
    set pgl(Zoom)       1.0
    set pgl(frontclip)  1.0
    set pgl(backclip)  -1.0
    set pgl(Created)    0
    set pgl(fscreen)    0
    set pgl(Label3DColor) [set Defauts(Label3DColor)]
    set pgl(GLMode)  "render"
    set pgl(SelectionList) ""

    set pgl(no_mat)            { 0.0 0.0 0.0 1.0 }

    set pgl(mat_ambient)       { 0.5 0.5 0.5 1.0 }
    set pgl(mat_diffuse)       { 0.5 0.5 0.5 1.0 }
    set pgl(mat_specular)      { 1.0 1.0 1.0 1.0 }
    set pgl(mat_emission)      { 0.3 0.5 0.5 1.0 }

    set pgl(light_ambient)     { 0.0 0.0 0.0 1.0 }
    # set pgl(light_ambient)     { 0.4 0.4 0.4 1.0 }
    set pgl(light_amb_lin)     { 0.7 0.7 0.7 1.0 }
    set pgl(light_diffuse)     { 1.0 1.0 1.0 1.0 }
    #    set pgl(light_diffuse)     { 0.4 0.4 0.4 1.0 }
    set pgl(light_specular)    { 1.0 1.0 1.0 1.0 }
    set pgl(light_position)    { 0.0 5.0 100. 0}

    set pgl(no_shininess)        0.0
    set pgl(low_shininess)      15.0
    set pgl(high_shininess)    128.0
    set pgl(shadeModel)        $::GL_SMOOTH
    set pgl(lineMode)            0

    set pgl(coeff_ambient)       0.4
    set pgl(coeff_diffuse)       0.4
    set pgl(coeff_specular)      0.4

    set pgl(DistColor)           [list 0.0 1.0 0.0]
    set pgl(Dist2Show)           {}
    set pgl(TextColor)           [list 0.0 1.0 0.0]
    set pgl(Text2Show)           {}
    set pgl(TextDeDist)          {}

    set pgl(xCen) 0.0
    set pgl(yCen) 0.0
    set pgl(zCen) 0.0
    set pgl(xTra) 0.0
    set pgl(yTra) 0.0
    set pgl(zTra) 0.0
    set pgl(xRot) 0.0
    set pgl(yRot) 0.0
    set pgl(eyeX) 0.0
    set pgl(eyeY) 0.0
    set pgl(eyeZ) 0.0

    set pgl(fogStart) 0.0
    set pgl(fogEnd)   1.0

    set pgl(TextInfo) ""

    return
}


proc printString { str } {
    # no bitmap font (see Togl_CreateFonct) : labels are not drawn
    if {! [info exists ::pgl(FontBase)] || $::pgl(FontBase) eq ""} {
	return
    }
    
    glDisable GL_DEPTH_TEST
    glListBase $::pgl(FontBase)
    set len [string length $str]
    set sa [tcl3dVectorFromString GLubyte $str]
    glCallLists $len GL_UNSIGNED_BYTE $sa
    $sa delete
    glEnable GL_DEPTH_TEST

    return
}


proc ClearDistances {} {
    set ::pgl(Dist2Show) {}
    set ::pgl(TextDeDist) {}
    $::pgl(wogl) postredisplay

    return
}


proc ResetFonctions {} {

    if {[$::pgl(BoutonCenter) cget -fg] eq "yellow"} {
	FinCentreAtome
    }
    if {[$::pgl(BoutonDistance) cget -fg] eq "yellow"} {
	ProcessMeasureDistance reset
    }
    
    return
}


proc AfficheDistances {} {
    global pgl

    # texts are computed again at each redraw
    set pgl(TextDeDist) {}
    if {$pgl(Dist2Show) == {} } {return}

    # green whatever the state left by the objects : with lighting,
    # texture or blending on, glColor is ignored (dark lines)
    glPushAttrib [expr {$::GL_ENABLE_BIT | $::GL_CURRENT_BIT}]
    glDisable GL_LIGHTING
    glDisable GL_TEXTURE_2D
    glDisable GL_BLEND
    glColor3fv $pgl(DistColor)
    glLineStipple 3 0xAAAA
    glEnable GL_LINE_STIPPLE
    foreach e $pgl(Dist2Show) {
	lassign $e v1 v2 dst
	glBegin GL_LINES
	glVertex3fv $v1
	glVertex3fv $v2
	glEnd
	
	lappend pgl(TextDeDist) {*}[V_VV $v1 + [V_SV 0.5 * [V_VV $v2 - $v1]]] [format " %4.1f A" $dst]
    }
    glDisable GL_LINE_STIPPLE
    glPopAttrib
    
    return

    # recup de la matrice de modelisation
    set mvmatrix [tcl3dVector GLdouble 16]
    glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
    set modmat [tcl3dVectorToList $mvmatrix 16]

    # recup de la matrice de projection
    set pjmatrix [tcl3dVector GLdouble 16]
    glGetDoublev GL_PROJECTION_MATRIX $pjmatrix
    set projmat [tcl3dVectorToList $pjmatrix 16]

    # Recup du viewport
    set viewmat [tcl3dVector GLint 4]
    glGetIntegerv GL_VIEWPORT $viewmat
    set viewport [tcl3dVectorToList $viewmat 4]

    # print the string
    glMatrixMode GL_MODELVIEW
    glPushMatrix
    glLoadIdentity

    foreach v $Lx text $Lt {
	lassign $v x y z

	set xa [expr {[lindex $modmat 0]*$x + [lindex $modmat 4]*$y + [lindex $modmat 8]*$z + [lindex $modmat 12]}]
	set ya [expr {[lindex $modmat 1]*$x + [lindex $modmat 5]*$y + [lindex $modmat 9]*$z + [lindex $modmat 13]}]
	set za [expr {[lindex $modmat 2]*$x + [lindex $modmat 6]*$y + [lindex $modmat 10]*$z + [lindex $modmat 14]}]

	glRasterPos3f $xa $ya $za

	printString $text
    }

    glPopMatrix
    glFlush

    return
}


proc ProcessMeasureDistance {args} {
    global AtomePique PtMD1 PtMD2

    if {$args eq "reset"} {
	set PtMD1 ""
	set PtMD2 ""
	trace remove variable AtomePique write ProcessMeasureDistance
	$::pgl(BoutonDistance) configure -fg cyan
	bind $::pgl(wogl) <ButtonPress-1> {set ::BQx %x ; set ::BQy %y}

	return
    }

    if {$AtomePique eq ""} {return}
    if {$PtMD1 eq ""} {
	set PtMD1 $AtomePique
	return
    }
    if {$PtMD2 eq ""} {
	set PtMD2 $AtomePique
    }

    lassign [Tag2MolObjAtm $PtMD1] mol1 obj1 atm1
    lassign [Tag2MolObjAtm $PtMD2] mol2 obj2 atm2
    set Lx1 [$mol1 AtomXYZ $atm1]
    set Lx2 [$mol2 AtomXYZ $atm2]
    set dst [Dist $Lx1 $Lx2]
    
    lappend ::pgl(Dist2Show) [list $Lx1 $Lx2 $dst]

    trace remove variable AtomePique write ProcessMeasureDistance

    $::pgl(BoutonDistance) configure -fg cyan

    bind $::pgl(wogl) <ButtonPress-1> {set ::BQx %x ; set ::BQy %y}

    $::pgl(wogl) postredisplay

    return
}


proc MeasureDistance {} {

    set ::PtMD1 "" ; set ::PtMD2 ""
    set ::pgl(SelectionList) ""
    # add the trace only once (button clicked twice)
    if {[lsearch -exact [trace info variable ::AtomePique] {write ProcessMeasureDistance}] == -1} {
	trace add variable ::AtomePique write ProcessMeasureDistance
    }
    bind $::pgl(wogl) <ButtonPress-1> [list PickAtom %x %y %W]

    $::pgl(BoutonDistance) configure -fg yellow

    return
}


proc ClearIDs {} {
    foreach mold [StrucDuViewer] {
	set nom [DonneIdDeAccessPDB $mold]

	$nom ClearPicked
    }
    DefineLabels2Show

    $::pgl(wogl) postredisplay

    return
}


proc AfficheLabels {} {
    # atom labels and distances (distances are shown even if no
    # atom is labelled)
    set Lxt [concat $::pgl(Text2Show) $::pgl(TextDeDist)]
    if {$Lxt == {} } {
	return
    }

    # recup de la matrice de modelisation
    set mvmatrix [tcl3dVector GLdouble 16]
    glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
    set modmat [tcl3dVectorToList $mvmatrix 16]

    # recup de la matrice de projection
    set pjmatrix [tcl3dVector GLdouble 16]
    glGetDoublev GL_PROJECTION_MATRIX $pjmatrix
    set pgl(projmat) [tcl3dVectorToList $pjmatrix 16]
    set projmat $pgl(projmat)

    # Recup du viewport
    set viewmat [tcl3dVector GLint 4]
    glGetIntegerv GL_VIEWPORT $viewmat
    set pgl(viewport) [tcl3dVectorToList $viewmat 4]
    set viewport $pgl(viewport)

    # print the string
    glMatrixMode GL_MODELVIEW
    glPushMatrix
    glLoadIdentity

    # labels in green (as the distances) : the color of a text is
    # the one of glRasterPos, i.e. the color left by the last object
    # drawn (or the lit color : black), unless it is set here
    glPushAttrib [expr {$::GL_ENABLE_BIT | $::GL_CURRENT_BIT}]
    glDisable GL_LIGHTING
    glDisable GL_TEXTURE_2D
    glDisable GL_BLEND
    foreach {x y z text} $Lxt {
	set xa [expr {[lindex $modmat 0]*$x + [lindex $modmat 4]*$y + [lindex $modmat 8]*$z + [lindex $modmat 12]}]
	set ya [expr {[lindex $modmat 1]*$x + [lindex $modmat 5]*$y + [lindex $modmat 9]*$z + [lindex $modmat 13]}]
	set za [expr {[lindex $modmat 2]*$x + [lindex $modmat 6]*$y + [lindex $modmat 10]*$z + [lindex $modmat 14]}]

	glColor3fv $::pgl(DistColor)
	glRasterPos3f $xa $ya $za

	printString $text
    }
    glPopAttrib

    glPopMatrix

    return
}


proc disp_string {} {
    global mol AtmPick AtomePique TypeRep Pck Cor

    #    dont_use_light

    foreach a $AtmPick {
	if {$TypeRep eq "fildefer"} {
	    lassign [set PDB_[set mol]_Labels($a)] text Lx 
	}
	if {$TypeRep eq "benjilamalice"} {
	    lassign [set Cor($a)] text Lx 
	}

	lassign $Lx x y z

	# recup de la matrice de modelisation
	set mvmatrix [tcl3dVector GLdouble 16]
	glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
	set modmat [tcl3dVectorToList $mvmatrix 16]

	# recup de la matrice de projection
	set pjmatrix [tcl3dVector GLdouble 16]
	glGetDoublev GL_PROJECTION_MATRIX $pjmatrix
	set projmat [tcl3dVectorToList $pjmatrix 16]

	# Recup du viewport
	set viewmat [tcl3dVector GLint 4]
	glGetIntegerv GL_VIEWPORT $viewmat
	set viewport [tcl3dVectorToList $viewmat 4]

	# print the string
	glMatrixMode GL_MODELVIEW
	glPushMatrix
	glLoadIdentity

	set xa [expr {[lindex $modmat 0]*$x + [lindex $modmat 4]*$y + [lindex $modmat 8]*$z + [lindex $modmat 12]}]
	set ya [expr {[lindex $modmat 1]*$x + [lindex $modmat 5]*$y + [lindex $modmat 9]*$z + [lindex $modmat 13]}]
	set za [expr {[lindex $modmat 2]*$x + [lindex $modmat 6]*$y + [lindex $modmat 10]*$z + [lindex $modmat 14]}]

	glColor3f 0.0 1.0 0.0
	glRasterPos3f $xa $ya $za

	printString $text

	glPopMatrix

	glFlush
    }

    return
}


proc processHits { hits } {
    set AtmPick {}
    set count 0
    for {set i 0} {$i < $hits} {incr i} {
	# 1st rec : nbr of Nnames in this hit
	set NbrNames [$::selectBuffer get $count]
	incr count
	# 2nd rec : min z-depth div par
 	# set minz [$::selectBuffer get $count]
	incr count
	# 3rd rec : max z
	incr count
	# 4th rec : noms
	set MOA {}
	for {set j 0} {$j < $NbrNames} { incr j } {
	    set unom [$::selectBuffer get $count]
	    lappend MOA $unom
	    incr count
	}
	lappend AtmPick $MOA
    }

    # return si le unom n'est pas > a 6 char
    if {[llength [lindex $AtmPick end]] < 3} {
	return
    }

    lassign [lindex $AtmPick end] mol obj atm
    # conversion mol as number to command
    set ZePicked [format "%d%02d%02d" $atm $obj $mol]
    lassign [Tag2MolObjAtm $ZePicked] mol obj atm

    # atoms and residues are in the structure's own database
    set rnra [$mol _dbEval "select r.rnbr,r.rname3l, a.aname from atoms as a , residues as r where a.pk_atoms=[expr {int($atm)}] and r.pk_residues=a.pk_residues"]

    lassign $rnra rnmr rnom natm
    set rnmr [string trimleft $rnmr 0]
    set ::pgl(TextInfo) "Mol [string trimleft $mol :] Res $rnmr $rnom $natm"

    $mol AddPicked $obj $atm
    DefineLabels2Show

    set ::AtomePique $ZePicked

    return
}


proc XYZCenterAtom {} {
    global pgl TypeRep AtomePique Rad

    if {$AtomePique eq ""} {return 0}

    lassign [Tag2MolObjAtm $AtomePique] mol obj atm

    lassign [$mol AtomXYZ $atm] x y z

    set pgl(xCen) $x
    set pgl(yCen) $y
    set pgl(zCen) $z

    set pgl(xTra) 0.0
    set pgl(yTra) 0.0
    set pgl(zTra) 0.0

    # Fix: the old formula (Rad+zCen / zCen-Rad) injected the RAW Z
    # coordinate of the picked atom (in the PDB file's own frame, unrelated
    # to Rad) into the clipping computation. But the render pipeline
    # (Togl_DisplayFonct: translate -Rad, rotate, translate -center)
    # ALWAYS places the current center at z=-Rad in camera space,
    # whatever point is chosen as the center. backclip/frontclip must
    # therefore be computed exactly as in AfficheDansViandox, independently
    # of zCen -- otherwise the clipping window gets shifted and the
    # molecule may disappear entirely (see discussion).
    set pgl(backclip)  [expr {-0.1 * $Rad}]
    set pgl(frontclip) [expr { 2.1 * $Rad}]
    set pgl(eyeZ)      $pgl(frontclip)

    update

    return 1
}


proc FinCentreAtome {args} {
    set ::AtomePique ""

    $::pgl(BoutonCenter) configure -fg cyan

    bind $::pgl(wogl) <ButtonPress-1> {set ::BQx %x ; set ::BQy %y}

    return
}


proc CentreOnAtome {w} {
    global AtomePique pgl

    set pgl(SelectionList) ""

    bind $pgl(wogl) <1> [list CenterAtom %x %y %W]

    $w configure -fg yellow

    return
}


proc CenterAtom {x y win} {
    global cx cy AtomePique pgl Rad

    set hits [DonneAtomePique $x $y]
    if {$hits <= 0} {return}

    processHits $hits
    XYZCenterAtom

    Update3DMatrices
    set cx 0 ; set cy 0
    FinCentreAtome

    return
}


proc DonneAtomePique {x y} {
    global pgl Rad

    glSelectBuffer $::BUFSIZE $::selectBuffer
    glRenderMode GL_SELECT
    set pgl(GLMode) "select"

    set viewport  [tcl3dVector GLint 4]
    glGetIntegerv GL_VIEWPORT $viewport
    set w [$viewport get 2]
    set h [$viewport get 3]

    glMatrixMode GL_PROJECTION
    glPushMatrix
    glLoadIdentity
    # create 5x5 pixel picking region 
    # near cursor location
    gluPickMatrix $x [expr {$h-$y}] 5.0 5.0 $viewport

    set ratX      $pgl(ratioX)
    set ratY      $pgl(ratioY)
    set zoom      $pgl(Zoom)
    set frontclip $pgl(frontclip)
    set backclip  $pgl(backclip)

    glOrtho \
	[expr {-$ratX*$zoom*($Rad+$pgl(xTra))}]\
	[expr { $ratX*$zoom*($Rad-$pgl(xTra))}]\
	[expr {-$ratY*$zoom*($Rad+$pgl(yTra))}]\
	[expr { $ratY*$zoom*($Rad-$pgl(yTra))}]\
	[expr {$backclip+$pgl(zTra)}] \
	[expr {$frontclip+$pgl(zTra)}]

    # MODELVIEW
    glMatrixMode GL_MODELVIEW
    glLoadIdentity
    glPushMatrix

    glTranslatef 0.0 0.0 [expr {-1. * $::Rad}]

    set mat [build_rotmatrix $::cQuat]
    glMultMatrixf $mat

    glTranslatef [expr {-1.0*$::pgl(xCen)}] [expr {-1.0*$::pgl(yCen)}] [expr {-1.0*$::pgl(zCen)}]

    EnvoieLesObjets

    glMatrixMode GL_PROJECTION
    glPopMatrix

    set hits [glRenderMode GL_RENDER]
    set pgl(GLMode) "render"

    return $hits
}


proc PickAtom {x y win} {

    set hits [DonneAtomePique $x $y]

    set ::BQx $x
    set ::BQy $y

    if {! $hits} {return}

    processHits $hits

    set ::cx $x
    set ::cy $y

    $win postredisplay

    return
}


proc dont_use_light {} {
    global pgl

    #    glDisable GL_COLOR_MATERIAL
    return
    glMaterialfv GL_FRONT_AND_BACK GL_SPECULAR [list 0.0 0.0 0.0 1.0]
    glMaterialfv GL_FRONT_AND_BACK GL_DIFFUSE  [list 0.0 0.0 0.0 1.0]
    #    glMaterialfv GL_FRONT_AND_BACK GL_SPECULAR [list 0.0 0.0 0.0 1.0]
    #    glMaterialfv GL_FRONT_AND_BACK GL_AMBIENT  [list 0.0 0.0 0.0 1.0]

    # next calls to glColor will affect GL_AMBIENT composante
    #glColorMaterial GL_FRONT_AND_BACK GL_AMBIENT
    glColorMaterial GL_FRONT GL_AMBIENT
    glColorMaterial GL_FRONT GL_SPECULAR

    return
}


proc use_light {} {
    #    global pgl
    #    return
    #    glEnable      GL_LIGHTING
    #glEnable      GL_COLOR_MATERIAL

    # glLightfv GL_LIGHT0 GL_AMBIENT $pgl(light_ambient)

    glMaterialfv GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE {0.2 0.2 0.2 1.0}
    glMaterialfv GL_FRONT_AND_BACK GL_SPECULAR {1.0 1.0 1.0 1.0}
    glMaterialf  GL_FRONT_AND_BACK GL_SHININESS 80.

    return
}


proc light_color3f {a b c} {
    set le [list $a $b $c 1.0]

    glMaterialfv GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE $le
    glMaterialfv GL_FRONT_AND_BACK GL_SPECULAR [list 1.0 1.0 1.0 1.0]
    glMaterialfv GL_FRONT_AND_BACK GL_EMISSION [list 0.0 0.0 0.0 1.0]
    glMaterialfv GL_FRONT_AND_BACK GL_SHININESS 100.

    return
}


proc light_color3fv {a} {
    lappend a 1.0
    glMaterialfv GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE $a
    glMaterialfv GL_FRONT GL_SPECULAR [list 1.0 1.0 1.0 1.0]
    #glMaterialfv GL_FRONT GL_EMISSION [list 0.0 0.0 0.0 1.0]
    glMaterialfv GL_FRONT GL_SHININESS 100.

    return
}


proc nolight_color3f {r g b} {
    global pgl

    set c $pgl(coeff_ambient)

    glColor3f [expr {$r/$c}] [expr {$g/$c}] [expr {$b/$c}]

    return
}



proc nolight_color3fv {col} {
    global pgl

    lassign $col r g b a
    set c $pgl(coeff_ambient)

    glColor3f [expr {$r/$c}] [expr {$g/$c}] [expr {$b/$c}]

    return
}



proc SetWindowMode {} {
    global pgl

    set win [winfo toplevel $pgl(wogl)]
    set h           $pgl(Oldh)
    set w           $pgl(Oldw)
    set sh          [winfo screenheight $win]
    set sw          [winfo screenwidth  $win]

    wm minsize $win 10 10
    # the window can be resized again
    wm maxsize $win $sw $sh

    # leave the full screen mode BEFORE setting the size, otherwise
    # the window manager ignores the geometry
    wm attributes $win -fullscreen 0
    wm overrideredirect $win 0
    update idletasks
    set fmtStr [format "%dx%d+0+25" $w $h]
    wm geometry $win $fmtStr
    update idletasks
    focus $win

    return
}


proc SetFullScreenMode {} {
    global pgl

    set win [winfo toplevel $pgl(wogl)]
    if {1} {
	set pgl(Oldw) [winfo width  $win]
	set pgl(Oldh) [winfo height $win]
	set sh        [winfo screenheight $win]
	set sw        [winfo screenwidth  $win]
	
	wm minsize $win $sw $sh
	wm maxsize $win $sw $sh
	wm overrideredirect $win 1
    }

    wm attributes $win -fullscreen 1

    update idletasks

    focus $win

    return
}


proc ToggleShowFrame {} {
    global pgl

    if {$pgl(showframe)} {
	grid forget $pgl(frInfo)
	grid forget $pgl(frCtrl)
	grid forget $pgl(frObjc)
	grid forget $pgl(frFonc)
	
	set pgl(showframe) 0
    } else {
	grid $pgl(frInfo) -row 0 -column 0 -columnspan 3 -sticky ew
	grid $pgl(frCtrl) -row 1 -column 0 -columnspan 3 -sticky ew
	grid $pgl(frObjc) -row 2 -column 0 -sticky ns   -pady 15
	grid $pgl(frFonc) -row 2 -column 2 -sticky ns -pady 15
	set pgl(showframe) 1
    }

    FenetreAuCentre [winfo toplevel $pgl(wogl)]
    raise $pgl(wogl)

    update idletasks

    return
}


proc ToggleWindowMode {{from ""}} {
    global pgl

    # <Escape> only leaves the full screen mode
    if {$from eq "escape" && ! $pgl(fscreen)} {
	return
    }

    if {! $pgl(fscreen) } {
	SetFullScreenMode
	set pgl(fscreen) 1
    } else {
	SetWindowMode
	set pgl(fscreen) 0
    }

    FenetreAuCentre [winfo toplevel $pgl(wogl)]

    return
}


proc MakeOpenglSelection {} {
    if {$::pgl(SelectionList) ne ""} {
	glCallList $::pgl(SelectionList)
	return
    }
    
    set list [glGenLists 1]
    set ::pgl(SelectionList) $list
    glNewList $list GL_COMPILE_AND_EXECUTE

    dont_use_light
    glInitNames

    set imol -1
    foreach mol [StrucDuViewer] {
	incr imol
	set nom [DonneIdDeAccessPDB $mol]
	
	set LObj [$nom _ListeObjets]
	set MolOn 0
	foreach obj $LObj {
	    if {! [$nom _EtatDeObjet $obj]} {continue}
	    set MolOn 1
	}
	if {! $MolOn} {continue}

	glPushName $imol
	set iobj -1
	foreach obj $LObj {
	    incr iobj
	    if {! [$nom _EtatDeObjet $obj]} {continue}

	    glPushName $iobj
	    set La [$nom _SetupPicking $obj]
	    foreach {x y z i} $La {
		glPushName $i
		glBegin GL_POINTS
		glVertex3f $x $y $z
		glEnd
		glPopName
	    }

	    glPopName
	}
	glPopName
    }
    glEndList
    
    return
}


proc EnvoieLesObjetsTmp {} {
    return
}


proc EnvoieLesObjets {} {
    if {$::pgl(GLMode) eq "select"} {
	MakeOpenglSelection
    } else {
	foreach i [StrucDuViewer] {
	    set nom [DonneIdDeAccessPDB $i]
	    $nom display
	}
    }

    return
}


proc Togl_CreateFonct {w} {
    global BUFSIZE selectBuffer pgl Rad

    glClearColor 0.0 0.0 0.0 0.0
    glDepthFunc  GL_LEQUAL
    glEnable     GL_DEPTH_TEST

    set BUFSIZE 512
    set selectBuffer [tcl3dVector GLuint $BUFSIZE]
    # bitmap font used to draw atom labels and distances
    if {[catch {set pgl(FontBase) [$w loadbitmapfont]}]} {
	set pgl(FontBase) ""
    }
    
    set ambient        { 0.4 0.4 0.4 1.0 }
    set diffuse        { 0.8 0.8 0.8 1.0 }
    set specular       { 1.0 1.0 1.0 1.0 }
    # x,y,z,w if w=0 lumier a l'infini , 1 
    set position       { 0.0 50.0 100.0 0.0 }
    set lmodel_ambient { 0.2 0.2 0.2 1.0 }
    set local_view     { 0.0 }

    glLightfv GL_LIGHT0 GL_AMBIENT  $ambient
    glLightfv GL_LIGHT0 GL_DIFFUSE  $diffuse
    glLightfv GL_LIGHT0 GL_SPECULAR $specular
    glLightf  GL_LIGHT0 GL_SHININESS 85.
    glLightfv GL_LIGHT0 GL_POSITION $position
    glLightModelfv GL_LIGHT_MODEL_AMBIENT $lmodel_ambient
    glLightModelfv GL_LIGHT_MODEL_TWO_SIDE 1.0
    glLightModeli  GL_LIGHT_MODEL_COLOR_CONTROL $::GL_SEPARATE_SPECULAR_COLOR
    #glLightModelfv GL_LIGHT_MODEL_LOCAL_VIEWER $local_view

    glEnable GL_LIGHTING
    glEnable GL_LIGHT0

    glColorMaterial GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE
    glEnable GL_COLOR_MATERIAL

    glMaterialfv GL_FRONT_AND_BACK GL_SPECULAR {1.0 1.0 1.0 1.0}
    glMaterialf  GL_FRONT_AND_BACK GL_SHININESS 100.

    # Fog section
    #glEnable GL_FOG
    set fogColor {0.0 0.0 0.0 0.0}
    glFogfv GL_FOG_COLOR $fogColor
    glFogi GL_FOG_MODE $::GL_EXP2
    glFogf GL_FOG_DENSITY 0.02
    glFogf GL_FOG_START 0.0
    glFogf GL_FOG_END 10.0
    glFogi GL_FOG_COORD_SRC $::GL_FOG_COORD
    glHint GL_FOG_HINT  $::GL_NICEST

    glEnable GL_LINE_SMOOTH
    glHint GL_LINE_SMOOTH_HINT $::GL_NICEST

    glEnable GL_POLYGON_SMOOTH
    glHint GL_POLYGON_SMOOTH_HINT $::GL_NICEST

    glShadeModel $pgl(shadeModel)

    glEnable GL_RESCALE_NORMAL

    return
}


proc WriteFogPrm {} {
    puts "\n-- FOG ----------"
    puts "| fog enabled $::fogon"
    puts "| system      $::fogsys"
    puts "| coords      $::fogcoords"
    puts ""

    return
}


proc FogOnOff {} {
    if {$::fogon} {
	set ::fogon 0
	glDisable GL_FOG
    } else {
	set ::fogon 1
	glEnable GL_FOG
    }
    WriteFogPrm

    $::pgl(wogl) postredisplay

    return
}

proc ChangeFogSys {} {
    set Lfog [list "::GL_LINEAR" "::GL_EXP" "::GL_EXP2"]
    set i [lsearch $Lfog $::fogsys]
    incr i
    if {$i == 3} {set i 0}
    set fs [lindex $Lfog $i]
    glFogi GL_FOG_MODE "[set $fs]"
    set ::fogsys $fs

    WriteFogPrm
    $::pgl(wogl) postredisplay

    return
}


proc FogCoords {} {
    if {$::fogcoords eq "fog"} {
	glFogi GL_FOG_COORD_SRC $::GL_FRAGMENT_DEPTH
	set ::fogcoords "frag"
    } else {
	glFogi GL_FOG_COORD_SRC $::GL_FOG_COORD
	set ::fogcoords "fog"
    }
    WriteFogPrm

    $::pgl(wogl) postredisplay

    return
}

proc EyePos {} {
    global pgl

    if {$::eyepos eq "zero"} {
	set pgl(eyeZ) $::Rad
	set ::eyepos "rad"
    } else {
	set pgl(eyeZ) 0.
	set ::eyepos "zero"
    }
    update
    Update3DMatrices

    $::pgl(wogl) postredisplay

    return
}

proc AdjustFog {what} {
    puts "what $what"
    flush stdout
    update idletasks

    if {$what eq "up"} {
	set dadd  0.01
    } else {
	set dadd -0.01
    }
    if {$::fogsys ne "::GL_LINEAR"} {
	set den [tcl3dOglGetFloatState GL_FOG_DENSITY]
	set den [expr {$den + $dadd}]
	if {$den < 0.001} {set den 0.001}
	glFogf GL_FOG_DENSITY $den
	puts "   density $den"
    } else {
	set ::fact [expr {$::fact + $dadd}]
	if {$::fact < 0.005} {set ::fact 0.005}
	#if {$::fact > 2.} {set ::fact 2.}
	set end [expr {$::fact*2.*$::Rad}]
	glFogf GL_FOG_START 0.
	glFogf GL_FOG_END   $end
	puts "   end $end"
    }

    $::pgl(wogl) postredisplay

    return
}


proc Togl_ReshapeFonct {toglwin {w -1} {h -1}} {
    global pgl Rad

    # for tcl3d 0.5.0
    set h [$toglwin height]
    set w [$toglwin width]
    if { $h == 0 }  {set h 1}
    if { $w == 0 }  {set w 1}

    set pgl(width)  $w
    set pgl(height) $h
    if {$w > $h} {
	set pgl(ratioX) [expr {double($w)/$h}]
	set pgl(ratioY) 1.0
    } else {
	set pgl(ratioY) 1.0
	set pgl(ratioY) [expr {double($h)/$w}]
    }
    glViewport 0 0 $w $h

    set ratX      $pgl(ratioX)
    set ratY      $pgl(ratioY)
    set zoom      $pgl(Zoom)
    set frontclip $pgl(frontclip)
    set backclip  $pgl(backclip)

    glMatrixMode GL_PROJECTION
    glLoadIdentity
    glOrtho \
	[expr {-$ratX*$zoom*($Rad+$pgl(xTra))}]\
	[expr { $ratX*$zoom*($Rad-$pgl(xTra))}]\
	[expr {-$ratY*$zoom*($Rad+$pgl(yTra))}]\
	[expr { $ratY*$zoom*($Rad-$pgl(yTra))}]\
	[expr {$pgl(backclip) +$pgl(zTra)}]  \
	[expr {$pgl(frontclip)+$pgl(zTra)}] 
    
    glMatrixMode GL_MODELVIEW
    glLoadIdentity

    $toglwin swapbuffers

    return
}


proc Togl_DisplayFonct {w} {

    glViewport 0 0 [$w width] [$w height]

    glClear [expr $::GL_COLOR_BUFFER_BIT | $::GL_DEPTH_BUFFER_BIT]

    glMatrixMode GL_MODELVIEW
    glLoadIdentity

    glTranslatef 0.0 0.0 [expr {-1. * $::Rad}]

    set mat [build_rotmatrix $::cQuat]
    glMultMatrixf $mat

    glTranslatef [expr {-1.0*$::pgl(xCen)}] [expr {-1.0*$::pgl(yCen)}] [expr {-1.0*$::pgl(zCen)}]
    EnvoieLesObjets
    AfficheDistances
    AfficheLabels
    
    glFlush
    # PrintOgl reads the back buffer : no swap
    if {! [info exists ::pgl(NoSwap)] || ! $::pgl(NoSwap)} {
	$w swapbuffers
    }

    return
}


proc Update3DMatrices {} {
    global pgl Rad

    set ratX      $pgl(ratioX)
    set ratY      $pgl(ratioY)
    set zoom      $pgl(Zoom)
    set frontclip $pgl(frontclip)
    set backclip  $pgl(backclip)

    glMatrixMode GL_PROJECTION
    glLoadIdentity
    glOrtho \
	[expr {-$ratX*$zoom*($Rad+$pgl(xTra))}]\
	[expr { $ratX*$zoom*($Rad-$pgl(xTra))}]\
	[expr {-$ratY*$zoom*($Rad+$pgl(yTra))}]\
	[expr { $ratY*$zoom*($Rad-$pgl(yTra))}]\
	[expr {$pgl(backclip) }]  \
	[expr {$pgl(frontclip)}] 

    glMatrixMode GL_MODELVIEW
    glLoadIdentity
    
    $pgl(wogl) postredisplay
    
    return
}


proc ResetRotationsEST_AUSSI-DANS_ordali_arc2 {} {
    global pgl

    tcl3dMatfIdentity $::TransformAB
    tcl3dMatfIdentity $::ThisRot
    tcl3dMatfIdentity $::LastRot
    set ::TransformListAB [tcl3dVectorToList $::TransformAB 16]
    $pgl(wogl) postredisplay

    return
}


proc Mouse {quoi x y win} {
    global pgl cx cy Rad

    switch $quoi {
	"RotXY" {
	    # rotation X et Y
	    if { abs($cx-$x) < 5 && abs($cy-$y) < 5 } {return}

	    glMatrixMode GL_MODELVIEW

	    set mvm      [tcl3dVector GLdouble 16]
	    glGetDoublev GL_MODELVIEW_MATRIX $mvm
	    #set mvList   [tcl3dVectorToList $mvmatrix 16]
	    
	    #glRotatef [expr {$cy-$y}] [lindex $mvList 0] [lindex $mvList 4] [lindex $mvList 8]
	    glRotatef [expr {$cy-$y}] [$mvm get 0] [$mvm get 4] [$mvm get 8]

	    glGetDoublev GL_MODELVIEW_MATRIX $mvm
	    #set mvList   [tcl3dVectorToList $mvmatrix 16]
	    #glRotatef [expr {$cx-$x}] [lindex $mvList 1] [lindex $mvList 5] [lindex $mvList 9]
	    glRotatef [expr {$cx-$x}] [$mvm get 1] [$mvm get 5] [$mvm get 9]
	}
	"TraXY" {
	    if { $cx == $x && $cy == $y } {return}

	    # empiric constant 1.5
	    set rx [expr {1.5*$Rad*($x-$cx)/$pgl(width)}]
	    set ry [expr {1.5*$Rad*($y-$cy)/$pgl(height)}]

	    set pgl(yTra) [expr {$pgl(yTra) - $ry}]
	    set pgl(xTra) [expr {$pgl(xTra) + $rx}]

	    update
	    Update3DMatrices
	}
    }

    set cx $x ; set cy $y

    $win postredisplay

    return
}


proc HandleZoom {n win} {
    global pgl

    if {$pgl(Zoom) > 1.} {
	set pgl(Zoom) [expr {$pgl(Zoom) + $n/$pgl(Zoom)}]
    } else {
	set pgl(Zoom) [expr {$pgl(Zoom) + $n*$pgl(Zoom)}]
    }
    if {$pgl(Zoom) < 0.0001} {set pgl(Zoom) 0.0001}

    Update3DMatrices
    $pgl(wogl) postredisplay

    return
}


proc RotTrans {} {
    global pgl

    glMatrixMode GL_MODELVIEW
    #    glLoadIdentity

    glTranslatef [expr {-1.*$pgl(xdist)}] [expr {-1.0*$pgl(ydist)}] 0.0
    #    glTranslatef $pgl(xdist) $pgl(ydist) 0.0

    set mvmatrix [tcl3dVector GLdouble 16]
    glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
    set mvList   [tcl3dVectorToList $mvmatrix 16]

    glRotatef $pgl(yRot) [lindex $mvList 0] [lindex $mvList 4] [lindex $mvList 8]

    glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
    set mvList   [tcl3dVectorToList $mvmatrix 16]
    glRotatef $pgl(yRot) [lindex $mvList 1] [lindex $mvList 5] [lindex $mvList 9]

    glTranslatef $pgl(xdist) $pgl(ydist) 0.0

    return
}


proc RotTrans1 {} {
    global pgl

    glMatrixMode GL_MODELVIEW
    #    glLoadIdentity

    #    glTranslatef $pgl(xdist) $pgl(ydist) 0.0

    set mvmatrix [tcl3dVector GLdouble 16]
    glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
    set mvList   [tcl3dVectorToList $mvmatrix 16]

    glRotatef $pgl(yRot) [lindex $mvList 0] [lindex $mvList 4] [lindex $mvList 8]

    glGetDoublev GL_MODELVIEW_MATRIX $mvmatrix
    set mvList   [tcl3dVectorToList $mvmatrix 16]
    glRotatef $pgl(yRot) [lindex $mvList 1] [lindex $mvList 5] [lindex $mvList 9]

    glTranslatef [expr {-1.*$pgl(xdist)}] [expr {-1.0*$pgl(ydist)}] 0.0
    return
}


proc RotTrans2 {} {
    global pgl

    glTranslatef $pgl(xdist) $pgl(ydist) 0.0

    return
}


proc RotX { w angle } {
    global pgl

    set pgl(xRotate) [expr {$pgl(xRotate) + $angle}]
    $w postredisplay

    return
}


proc RotY { w angle } {
    global pgl

    set pgl(yRotate) [expr {$pgl(yRotate) + $angle}]
    $w postredisplay

    return
}


proc RotZ { w angle } {
    set ::pgl(zRotate) [expr {$::pgl(zRotate) + $angle}]
    $w postredisplay

    return
}


proc ToggleTabBouton {w} {
    set Lw [split $w .]
    set mol [string range [lindex $Lw end-1] 1 end]
    set sea [join [lrange $Lw 0 end-1] .]
    set Lwo [lsearch -regexp -all -inline [winfo children $sea] "\.bto"]
    set Lwc [lsearch -regexp -all -inline [winfo children $sea] "\.cac"]

    if {[string index [$w cget -text] 0] eq "-"} {
	$w configure -text "+ $mol" -foreground green1
	if {$Lwo != {} } {
	    grid forget {*}$Lwo
	    grid forget {*}$Lwc
	}
    } else {
	$w configure -text "- $mol" -foreground yellow
	set c 1
	foreach o $Lwo cac $Lwc {
	    # re-grid obj name button
	    grid $o \
		-row $c -column 0 -sticky w \
		-pady 0 -ipady 0 -padx {10 0}
	    # re-grid the action combobox (replaces the old Edit/Del buttons)
	    grid $cac \
		-row $c -column 1 -columnspan 2 -sticky we \
		-pady 0 -ipady 0 -padx {5 0}
	    incr c
	}
    }

    update idletasks
    $::pgl(wogl) postredisplay

    return
}


proc DefineLabels2Show {{mol ""}} {
    
    if {$mol eq ""} {
	set Lmol [StrucDuViewer]
    } else {
	set Lmol $mol
    }

    set txt {}
    foreach n $Lmol {
	set pdb [DonneIdDeAccessPDB $n]
	set l [::$pdb AllLabels]
	if {$l != {}} {
	    lappend txt {*}$l
	}
    }

    set ::pgl(Text2Show) $txt

    return
}


proc DeleteObjet {nom obj} {
    # cas fichier ORD, 
    if {[TypeAli] eq "ORD"} {
	VueEditee 1
    }

    if {[$nom _EtatDeObjet $obj]} {
	$nom ObjetOff $obj
    }

    # delete in database
    $nom deleteObjects $obj

    # delete buttons
    set frObjc $::pgl(frObjc)
    # object button and its action combobox (the old Edit/Del
    # buttons bte/btd do not exist anymore)
    set obj [string range $obj 4 end]
    foreach wd [list $frObjc.f${nom}.bto$obj $frObjc.f${nom}.cac$obj] {
	if {[winfo exists $wd]} {
	    grid forget $wd
	    destroy $wd
	}
    }
    update idletasks

    $::pgl(wogl) postredisplay

    return
}


proc AfficheObjet {w nom obj} {
    global pgl

    if {[$w cget -foreground] eq "green1"} {
	$nom ObjetOff $obj
	$w configure -foreground red
    } else {
	$nom ObjetOn $obj
	$w configure -foreground green1
    }

    DefineLabels2Show
    set pgl(SelectionList) ""

    $pgl(wogl) postredisplay

    return
}


proc TousObjetsOn {} {
    global pgl StrucAVoir

    set fobj $pgl(frObjc)
    set Lf [winfo children $fobj]
    foreach w $Lf {
	set c [lindex [split $w .] end]
	if {[string index $c 0] ne "f"} {continue}
	set nom [string range $c 1 end]
	foreach e [winfo children $w] {
	    set b [lindex [split $e .] end]
	    if {[string range $b 0 2] ne "bto"} {continue}
	    set o [string trim [$e cget -text]]
	    if {[$nom _EtatDeObjet $o]} {continue}
	    $nom ObjetOn $o
	    $e configure -foreground green1
	}
    }

    update idletasks
    $pgl(wogl) postredisplay

    return
}


proc TousObjetsOff {} {
    global pgl StrucAVoir

    set fobj $pgl(frObjc)
    set Lf [winfo children $fobj]
    foreach w $Lf {
	set c [lindex [split $w .] end]
	if {[string index $c 0] ne "f"} {continue}
	set nom [string range $c 1 end]
	foreach e [winfo children $w] {
	    set b [lindex [split $e .] end]
	    if {[string range $b 0 2] ne "bto"} {continue}
	    set o [string trim [$e cget -text]]
	    if {! [$nom _EtatDeObjet $o]} {
		continue
	    }

	    $nom ObjetOff $o
	    $e configure -foreground red
	}
    }

    update idletasks
    $pgl(wogl) postredisplay

    return
}


proc ToggleAllOff {} {
    global StrucAVoir pgl

    set fobj $pgl(frObjc)
    foreach e [StrucDuViewer] {
	lassign $e nc f
	set nom [DonneIdDeAccessPDB $nc]
	set t [$fobj.f${nom}.b0 cget -text]
	if {[string index $t 0] eq "-"} {
	    $fobj.f${nom}.b0 invoke
	}
    }

    return
}


proc AddObjToFObj {nom obj} {
    global pgl

    set frO "$pgl(frObjc).f${nom}"
    # open the "menu" corresponding to the pdb
    if {[llength [grid slaves $frO]] == 2} {
	$frO.b0 invoke
    }
    set c [lindex [grid size $frO] 1]
    button $frO.bto$obj \
	-text "$obj" -font FontOg \
	-bg black -fg green1 \
	-activeforeground red \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 \
	-padx 0 -pady 0 \
	-anchor w -justify left \
	-command [list AfficheObjet $frO.bto$obj $nom $obj]
    grid $frO.bto$obj \
	-row $c -column 0 -sticky "" \
	-columnspan 2 \
	-pady 0 -ipady 0 -padx 0
    
    return
}


proc ExecuteActionObjet {nom obj args} {
    # "args" absorbs the extra parameters that combobox::CallCommand
    # appends automatically to -command (the widget path and the newly
    # selected value) -- we don't need them, ::ActionObj($nom,$obj) is
    # already up to date via -textvariable by the time -command fires.
    global ActionObj

    set action $ActionObj($nom,$obj)

    switch -- $action {
	Edit    { DefineNewObj $nom $obj }
	Delete  { DeleteObjet  $nom $obj }
	Center  { CenterOnObjet $nom $obj }
	default {
	    # "..." (placeholder) or any other unexpected value -> no-op
	}
    }

    return
}


proc CenterOnObjet {nom obj} {
    global pgl Rad

    set res [$nom objCenterRad $obj]
    if {$res eq ""} {
	FaireLire "The object contains no atoms !\nIt is then impossible to center on it"
	return
    }

    lassign $res cx cy cz r

    set pgl(xCen) $cx
    set pgl(yCen) $cy
    set pgl(zCen) $cz

    set pgl(xTra) 0.0
    set pgl(yTra) 0.0
    set pgl(zTra) 0.0

    # "Center" frames the object : when centering, the object is what
    # matters. The visible half-width is Rad x ratio x Zoom
    # (Update3DMatrices) : Rad becomes the object's radius + a margin
    # (reduced or increased), and the mouse-wheel zoom is reset, so
    # that the object fills the window. The rest of the scene may go
    # out of the frame or be clipped (clips computed from Rad below).
    # The margin covers the thickness of the drawn spheres/cylinders.
    set MargeRad [expr {max(4.0, 0.1*$r)}]
    set Rad [expr {$r + $MargeRad}]
    set pgl(Rad) $Rad
    set pgl(Zoom) 1.0

    set pgl(backclip)  [expr {-0.1 * $Rad}]
    set pgl(frontclip) [expr { 2.1 * $Rad}]
    set pgl(eyeZ)      $pgl(frontclip)

    Update3DMatrices
    $pgl(wogl) postredisplay

    return
}


proc AddFObj {nom} {
    global pgl ActionObj ListeActionsObj

    # Items for the per-object action combobox (replaces the Edit/Del
    # buttons). "..." is a neutral placeholder shown by default, which
    # triggers no action (see ExecuteActionObjet) -- this avoids having to
    # "reset" the combobox right after running Edit or Center.
    set ListeActionsObj {... Edit Delete Center}

    # proc is called to create the frame or 
    # to update the objects buttons
    set frObjc $pgl(frObjc)
    set c 0
    if {! [winfo exists $frObjc.f${nom}]} {
	set i [lindex [grid size $frObjc] 1]
	frame $frObjc.f${nom} -bg black -relief flat -bd 0 -highlightthickness 0
	
	button $frObjc.f${nom}.b$c \
	    -text "- $nom" -font FontOgTitle \
	    -bg black -fg white \
	    -activeforeground yellow \
	    -activebackground black \
	    -bd 0 -relief flat \
	    -pady 0 -padx 0 \
	    -highlightthickness 0 \
	    -anchor w -justify left \
	    -command [list ToggleTabBouton $frObjc.f${nom}.b$c]
	button $frObjc.f${nom}.n$c \
	    -text "New" -font FontOg \
	    -bg DarkSlateGrey -fg cyan \
	    -activeforeground yellow \
	    -activebackground black \
	    -bd 0 -relief flat \
	    -pady 0 -padx 0 \
	    -highlightthickness 0 \
	    -anchor w -justify left \
	    -command [list DefineNewObj $nom]

	grid $frObjc.f${nom}.b$c \
	    -row $c -column 0 -sticky w \
	    -ipady 0 -pady 0 -padx {0 5}
	grid $frObjc.f${nom}.n$c \
	    -row $c -column 2 -sticky e \
	    -ipady 0 -pady 0 -padx {5 0}

	grid columnconfig $frObjc.f${nom} all -weight 1
	# grid the whole frame
	grid $frObjc.f${nom} \
	    -row $i -column 0 -sticky nwe \
	    -pady 0 -ipady 0 -padx {20 1}
    } else {
	# if the frame exists , expand it if necessary
	if {[llength [grid slaves $frObjc.f${nom}]] == 2} {
	    $frObjc.f${nom}.b0 invoke
	}
    }

    # objects buttons
    set Lb [winfo children $frObjc.f${nom}]
    set Li [lsearch -all -regexp $Lb {\.b0|\.n0}]
    foreach i [lreverse $Li] {
	set Lb [lreplace $Lb $i $i]
    }
    destroy {*}$Lb
    foreach objI [$nom _ListeObjets] {
	if {$objI eq "Index"} {continue}
	incr c

	if {[$nom _EtatDeObjet $objI]} {
	    set col green1
	} else {
	    set col red
	}
	set obj [string range $objI 4 end]
	button $frObjc.f${nom}.bto$obj \
	    -text "$obj" -font FontOg \
	    -bg black -fg $col \
	    -activeforeground $col \
	    -activebackground black \
	    -bd 0 -relief flat \
	    -highlightthickness 0 \
	    -padx 0 -pady 0 \
	    -anchor w -justify left \
	    -command [list AfficheObjet $frObjc.f${nom}.bto$obj $nom $obj]

	# A single combobox (black background, same style as the feature
	# picker) replaces the two Edit/Del buttons. "Center" frames the
	# camera on the atoms currently displayed for THIS object
	# (Structure::objCenterRad).
	set ActionObj($nom,$objI) "..."
	combobox::combobox $frObjc.f${nom}.cac$obj \
	    -background black -foreground white \
	    -width 7 \
	    -editable false \
	    -textvariable ::ActionObj($nom,$objI) \
	    -command [list ExecuteActionObjet $nom $objI] \
	    -listvar ::ListeActionsObj

	grid $frObjc.f${nom}.bto$obj \
	    -row $c -column 0 -sticky w \
	    -pady 0 -ipady 0 -padx {5 0}
	grid $frObjc.f${nom}.cac$obj \
	    -row $c -column 1 -columnspan 2 -sticky we \
	    -pady 0 -ipady 0 -padx {5 0}
    }

    return
}


proc UpdateMolObjFeat {args} {
    global pgl Mol3dCou Obj3dCou Feat3dCou Feat3dCou2

    update
    if {$Obj3dCou eq ""}  {return}
    if {$Feat3dCou eq ""} {return}
    # features of another instance : the comboboxes go back to the
    # features mapped until now
    if {! [ViewerDansSonInstance "map its features"]} {
	lassign [expr {[info exists pgl(FeatsMappees)] ? $pgl(FeatsMappees) : {None None}}] Feat3dCou Feat3dCou2
	return
    }
    set pgl(FeatsMappees) [list $Feat3dCou $Feat3dCou2]

    # back to the default colour first : the residues coloured
    # by the previous features must not stay coloured
    $Mol3dCou _mapfeat $Obj3dCou None 0
    $Mol3dCou _mapfeat $Obj3dCou $Feat3dCou  0
    $Mol3dCou _mapfeat $Obj3dCou $Feat3dCou2 1
    $Mol3dCou _dellist $Obj3dCou
    $Mol3dCou render   $Obj3dCou

    $pgl(wogl) postredisplay

    return
}


proc MetAJourFeaturesViandox {{n1 ""} {n2 ""} {op ""}} {
    global ListeTypesDeFeatures ListeFeat43d pgl

    # the lists show the features of the instance of the viewer
    if {[info exists pgl(Mac)] && $pgl(Mac) != [MacCourant] && [info exists ListeFeat43d]} {
	return $ListeFeat43d
    }
    set ListeFeat43d "None"
    if {[info exists ListeTypesDeFeatures]} {
	set ListeFeat43d [concat $ListeFeat43d [lsort $ListeTypesDeFeatures]]
    }

    return $ListeFeat43d
}


proc UpdateMol3dObjets {n1 n2 op} {
    global ListeMol3dObjets Obj3dCou Mol3dCou Feat3dCou
    set lob [[set $n1] _ListeObjets]
    set ListeMol3dObjets {}
    foreach o $lob {
	lappend ListeMol3dObjets [string range $o 4 end]
    }
    set Obj3dCou ""
    set Feat3dCou "None"

    return
}


proc CentreSurObj3dCou {w obj} {
    # -command of the "Object" combobox : center the view on the
    # object chosen by the user (not called when Obj3dCou is set by
    # the program, eg reset to "" when the molecule changes)
    global Mol3dCou

    if {$obj eq "" || $Mol3dCou eq ""} {return}

    # switch the object on (its button in the left panel goes green)
    set b $::pgl(frObjc).f${Mol3dCou}.bto$obj
    if {[winfo exists $b] && [$b cget -foreground] ne "green1"} {
	$b invoke
    }

    CenterOnObjet $Mol3dCou $obj

    return
}


proc ChoixQuickMapping {Liste val} {
    # element of Liste matching val : same name whatever the
    # case, else the first one starting with val ("pfam" -> PFAM-A)
    set e [lsearch -inline -exact -nocase $Liste $val]
    if {$e eq ""} {
	set e [lsearch -inline -glob -nocase $Liste "${val}*"]
    }

    return $e
}


proc QuickMappingAuto {{mol 1c0a} {obj CA1c0a} {f1 pfam} {f2 cons-t80}} {
    # opens the 3D viewer and does what the user would do with the
    # Quick Mapping bar : molecule, object (view centered on it),
    # Feature 1 and Feature 2. Eg, after loading D_maj.xml :
    #   ordali D_maj.xml -exe QuickMappingAuto
    global Liste3dMol ListeMol3dObjets ListeFeat43d
    global Mol3dCou Obj3dCou Feat3dCou Feat3dCou2

    VisualiseStructure
    update
    # viewer of another instance kept (Cancel) : nothing to map
    if {! [ViewerOuvert] || $::pgl(Mac) != [MacCourant]} {
	return
    }

    set m [ChoixQuickMapping $Liste3dMol $mol]
    if {$m eq ""} {
	FaireLire "Quick Mapping : no molecule $mol !"
	return
    }
    # the trace on Mol3dCou fills the objects list
    set Mol3dCou $m

    set o [ChoixQuickMapping $ListeMol3dObjets $obj]
    if {$o eq ""} {
	FaireLire "Quick Mapping : no object $obj in $m !"
	return
    }
    set Obj3dCou $o
    CentreSurObj3dCou "" $o

    set Lf {}
    foreach f [list $f1 $f2] {
	set e [ChoixQuickMapping $ListeFeat43d $f]
	if {$e eq ""} {
	    FaireLire "Quick Mapping : no feature $f !"
	    set e "None"
	}
	lappend Lf $e
    }
    lassign $Lf Feat3dCou Feat3dCou2
    UpdateMolObjFeat

    return [list $m $o $Feat3dCou $Feat3dCou2]
}


proc DefineOutputBackgroundOgl {} {
    # Asks the background colour of the image written by PrintOgl.
    # Returns {r g b} (0 to 1), or "" if cancelled.
    global NwOj

    set tpl .bgchx
    catch {destroy $tpl}
    if {! [info exists NwOj(BgOgl)] || $NwOj(BgOgl) ni {black white other}} {
	set NwOj(BgOgl) black
    }
    if {! [info exists NwOj(BgOglCol)]} {
	set NwOj(BgOglCol) ""
    }
    set NwOj(BgOglOk) 0

    toplevel $tpl \
	-bg black
    wm title $tpl "Image background"
    wm iconname $tpl "Background"
    wm protocol $tpl WM_DELETE_WINDOW [list destroy $tpl]

    set top $tpl.f
    frame $top -bg black
    grid $top -row 0 -column 0 -sticky news -padx 10 -pady 10
    grid columnconfig $tpl 0 -weight 1
    grid rowconfig    $tpl 0 -weight 1

    label $top.label \
	-bg black \
	-fg cyan \
	-font TitleFont \
	-justify left -anchor w \
	-text "Select background color:"
    foreach c {black white other} {
	radiobutton $top.r$c \
	    -value $c \
	    -fg white \
	    -bg black \
	    -selectcolor black \
	    -activebackground DimGrey \
	    -text $c \
	    -variable NwOj(BgOgl)
    }
    # sample of the colour chosen with "choose..."
    label $top.lcol \
	-bg [expr {$NwOj(BgOglCol) eq "" ? "black" : $NwOj(BgOglCol)}] \
	-width 3 \
	-relief sunken
    button $top.rbtn \
	-bg DimGrey \
	-fg white \
	-text "choose..." \
	-justify left -anchor w \
	-command [list ChoisitCouleurFondOgl $top]
    button $top.bok \
	-bg green1 \
	-fg black \
	-text " OK " \
	-command "set ::NwOj(BgOglOk) 1 ; destroy $tpl"
    button $top.bcan \
	-bg red \
	-fg white \
	-text "Cancel" \
	-command [list destroy $tpl]

    grid $top.label -row 0 -column 0 -columnspan 3 -sticky w -padx 5
    grid $top.rblack -row 1 -column 0 -columnspan 3 -sticky w -padx {20 5}
    grid $top.rwhite -row 2 -column 0 -columnspan 3 -sticky w -padx {20 5}
    grid $top.rother -row 3 -column 0 -sticky w -padx {20 5}
    grid $top.rbtn -row 3 -column 1 -sticky w -padx {1 5}
    grid $top.lcol -row 3 -column 2 -sticky w -padx {1 5}
    grid $top.bcan -row 4 -column 0 -sticky w -padx 5 -pady 20
    grid $top.bok -row 4 -column 1 -columnspan 2 -sticky e -padx 5 -pady 20

    update idletasks
    FenetreAuCentre $tpl

    # modal : PrintOgl waits for the answer
    catch {grab $tpl}
    tkwait window $tpl

    if {! $NwOj(BgOglOk)} {
	return ""
    }
    switch $NwOj(BgOgl) {
	black {return {0.0 0.0 0.0}}
	white {return {1.0 1.0 1.0}}
    }
    # other : the colour chosen, black if none was
    if {$NwOj(BgOglCol) eq ""} {
	return {0.0 0.0 0.0}
    }
    lassign [winfo rgb . $NwOj(BgOglCol)] r g b
    return [list [expr {$r/65535.}] [expr {$g/65535.}] [expr {$b/65535.}]]
}


proc ChoisitCouleurFondOgl {top} {
    global NwOj

    set ini [expr {$NwOj(BgOglCol) eq "" ? "black" : $NwOj(BgOglCol)}]
    set col [tk_chooseColor -initialcolor $ini -parent [winfo toplevel $top] \
		 -title "Background color"]
    if {$col ne ""} {
	set NwOj(BgOglCol) $col
	set NwOj(BgOgl) other
	$top.lcol configure -bg $col
    }

    return
}


proc PrintOgl {{file ""}} {
    if {$file eq ""} {
	set file [DemandeEtSauveFichier jpg]
	if {$file eq ""} {
	    return
	}
    }

    set rgb [DefineOutputBackgroundOgl]
    if {$rgb eq ""} {
	return
    }
    lassign $rgb r g b

    # The scene is drawn in the back buffer, which is read before
    # swapping (reading the front buffer depends on what covers the
    # window). Real size of the window (it may have been resized).
    set wg $::pgl(wogl)
    $wg makecurrent
    # background of the image only : the viewer stays black
    glClearColor $r $g $b 1.0
    set ::pgl(NoSwap) 1
    Togl_DisplayFonct $wg
    set ::pgl(NoSwap) 0
    set h [$wg height]
    set w [$wg width]
    set numChans 4

    set vec [tcl3dVector GLubyte [expr {$w * $h * $numChans}]]

    # alpha forced to 1 : otherwise the image is darker than the screen
    glReadBuffer GL_BACK
    glPixelTransferf GL_ALPHA_SCALE 0.0
    glPixelTransferf GL_ALPHA_BIAS 1.0
    glReadPixels 0 0 $w $h GL_RGBA GL_UNSIGNED_BYTE $vec
    glPixelTransferf GL_ALPHA_SCALE 1.0
    glPixelTransferf GL_ALPHA_BIAS 0.0

    # back to the background of the viewer (Togl_CreateFonct), and
    # drawn again on the screen
    glClearColor 0.0 0.0 0.0 0.0
    Togl_DisplayFonct $wg

    set ph [image create photo -width $w -height $h]
    tcl3dVectorToPhoto $vec $ph $w $h $numChans
    $vec delete

    set fmt "png"
    if {[file extension $file] eq ""} {
	set file "${file}.png"
    }
    # alpha is 1 everywhere : no -background needed
    $ph write $file -format png
    image delete $ph 

    return
}


proc RetourAlignement {} {
    global NomFenetreOrdali

    focus $NomFenetreOrdali
    #    raise [winfo toplevel $NomFenetreOrdali]
    raise .

    update idletasks

    return
}


proc AfficheFenetreOpengl {} {
    global OrdEtcDir pgl

    InitTestGL

    # define fonts
    if {"FontOg" ni [font names]} {
	font create FontOg -family Helvetica -size 10 -weight normal
    }
    if {"FontOgTitle" ni [font names]} {
	font create FontOgTitle -family Helvetica -size 12 -weight bold
    }

    #rename EnvoieLesObjets EnvoieLesObjets_wait
    #rename EnvoieLesObjetsTmp EnvoieLesObjets

    # define window
    set wgl .ordogl
    if {[winfo exists $wgl]} {
	raise $wgl
	return
    }
    toplevel $wgl
    wm title $wgl $pgl(appName)
    wm protocol $wgl WM_DELETE_WINDOW KillParLaCroix
    wm withdraw $wgl

    $wgl configure -background black

    if {[winfo exists .fattendre]} {
	focus -force .fattendre
	raise .fattendre
	wm attributes .fattendre -topmost 1
	update idletasks
    }

    set frInfo [frame $wgl.f1 -bg black -bd 0 -relief flat -highlightthickness 0]
    grid $frInfo -row 0 -column 0 -columnspan 3 -sticky ew
    set frCtrl [frame $wgl.f2 -bg black -bd 0 -relief flat -highlightthickness 0]
    grid $frCtrl -row 1 -column 0 -columnspan 3 -sticky we
    set frObjc [frame $wgl.f3 -bg black -bd 0 -relief flat -highlightthickness 0]
    grid $frObjc -row 2 -column 0 -sticky news -pady 15
    set frTogl [frame $wgl.f4 -bg black -bd 0 -relief flat -highlightthickness 0]
    grid $frTogl -row 2 -column 1 -sticky news -pady 15
    set frFonc [frame $wgl.f5 -bg black -bd 0 -relief flat -highlightthickness 0]
    grid $frFonc -row 2 -column 2 -sticky news -pady 15
    
    set pgl(frInfo) $frInfo
    set pgl(frCtrl) $frCtrl
    set pgl(frTogl) $frTogl
    set pgl(frObjc) $frObjc
    set pgl(frFonc) $frFonc

    # frame Banniere
    set fmacsim [file join $OrdEtcDir "MACSIM_30px_cut_transparent.gif"]
    image create photo macsim
    macsim read $fmacsim
    set pgl(TextInfo) "Ordalie Structure Viewer"
    label $frInfo.imgm \
	-image macsim -anchor w \
	-bd 0 -bg black -padx 30 -pady 10
    label $frInfo.linf \
	-bg black -fg magenta \
	-anchor w -justify left \
	-bd 0 \
	-textvariable pgl(TextInfo)
    grid $frInfo.imgm -row 0 -column 0 -padx {20 10}
    grid $frInfo.linf -row 0 -column 1 -padx {1 20} -sticky ew
    grid columnconfig $frInfo 1 -weight 1
    
    # frame Control (map onto obj)
    global Mol3dCou Obj3dCou Feat3dCou
    global ListeTypesDeFeatures ListeFeat43d
    global Liste3dMol

    if {! [info exists Liste3dMol]} {
	set Liste3dMol {}
    }
    set Mol3dCou ""
    set Obj3dCou ""
    set Feat3dCou "None"
    set ListeFeat43d [MetAJourFeaturesViandox]
    # the feature lists follow the features of the alignment
    if {[lsearch -exact [trace info variable ::ListeTypesDeFeatures] {write MetAJourFeaturesViandox}] == -1} {
	trace add variable ::ListeTypesDeFeatures write MetAJourFeaturesViandox
    }
    
    label $frCtrl.label \
	-text "Quick Mapping :" \
	-fg white -bg black
    frame $frCtrl.f1 -bd 0 -highlightthickness 0 -relief flat -bg black
    label $frCtrl.f1.txt1 \
	-relief flat -bd 0 \
	-bg black -fg white \
	-text "Molecule : " \
	-anchor w -justify left \
	-highlightthickness 0
    combobox::combobox $frCtrl.f1.co1 \
	-background black \
	-foreground white \
	-width 6 \
	-editable false \
	-textvariable Mol3dCou \
	-listvar Liste3dMol
    grid $frCtrl.f1.txt1 -row 0 -column 0 -sticky w
    grid $frCtrl.f1.co1  -row 0 -column 1 -sticky we
    trace add variable Mol3dCou write UpdateMol3dObjets
    
    frame $frCtrl.f2 \
	-bd 0 -highlightthickness 0 \
	-relief flat -bg black
    label $frCtrl.f2.txt2 \
	-anchor e -bg black -fg white \
	-text "Object : " \
	-relief flat -bd 0 \
	-anchor w -justify left \
	-highlightthickness 0
    global ListeMol3dObjets
    combobox::combobox $frCtrl.f2.co2 \
	-background black -foreground white \
	-width 6 \
	-editable false \
	-textvariable Obj3dCou \
	-command [list CentreSurObj3dCou] \
	-listvar ListeMol3dObjets
    grid $frCtrl.f2.txt2 -row 0 -column 0 -sticky w
    grid $frCtrl.f2.co2  -row 0 -column 1 -sticky we

    frame $frCtrl.f3 -bd 0 -highlightthickness 0 -relief flat -bg black
    label $frCtrl.f3.txt3 \
	-bg black -fg white \
	-text "Feature 1 : " \
	-anchor w -justify left \
	-highlightthickness 0
    combobox::combobox $frCtrl.f3.co3 \
	-background black -foreground white \
	-width 10 \
	-editable false \
	-textvariable Feat3dCou \
	-command [list UpdateMolObjFeat] \
	-listvar ListeFeat43d
    grid $frCtrl.f3.txt3 -row 0 -column 0 -sticky w
    grid $frCtrl.f3.co3  -row 0 -column 1 -sticky we

    frame $frCtrl.f4 -bd 0 -highlightthickness 0 -relief flat -bg black
    label $frCtrl.f4.txt4 \
	-bg black -fg white \
	-anchor w -justify left \
	-highlightthickness 0 \
	-text "Feature 2 : "
    combobox::combobox $frCtrl.f4.co4 \
	-background black -foreground white \
	-width 10 \
	-editable false \
	-textvariable Feat3dCou2 \
	-command [list UpdateMolObjFeat] \
	-listvar ListeFeat43d
    grid $frCtrl.f4.txt4 -row 0 -column 0 -sticky w
    grid $frCtrl.f4.co4  -row 0 -column 1 -sticky we

    # gridify control frame
    grid $frCtrl.label -row 0 -column 0 \
	-sticky w -padx 10
    grid $frCtrl.f1    -row 0 -column 1 \
	-sticky w -padx 20
    grid $frCtrl.f2    -row 0 -column 2 \
	-sticky w -padx 20
    grid $frCtrl.f3    -row 0 -column 3 \
	-sticky w -padx 20
    grid $frCtrl.f4  -row 0 -column 4 \
	-sticky w -padx 20
    #grid columnconfig $frCtrl {1 2 3 4} -weight 1
    
    # frame OpenGL
    # Fenetre Togl
    set pgl(wogl) $frTogl.c 
    togl $frTogl.c \
	-width $pgl(width) \
	-height $pgl(height) \
	-double true \
	-depth true \
	-createproc  Togl_CreateFonct \
	-reshapeproc Togl_ReshapeFonct \
	-displayproc Togl_DisplayFonct
    grid $frTogl.c -row 0 -column 0 -sticky news
    grid columnconfig $frTogl 0 -weight 1
    grid rowconfig    $frTogl 0 -weight 1
    
    # Frame Fonctions
    button $frFonc.ca -text "\u2022Reset" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command {ResetFonctions}
    button $frFonc.ci -text "\u2022Clear Ids" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command [list ClearIDs]
    button $frFonc.cd \
	-text "\u2022Clear Distances" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command [list ClearDistances]
    set pgl(BoutonDistance) "$frFonc.ds"
    button $frFonc.ds \
	-text "\u2022Distance" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command [list MeasureDistance]
    
    set pgl(BoutonCenter) "$frFonc.ct"
    button $frFonc.ct \
	-text "\u2022Center On Atom" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command [list CentreOnAtome $frFonc.ct]
    button $frFonc.pr \
	-text "\u2022Print" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command {PrintOgl}
    button $frFonc.fs \
	-text "\u2022Full Screen" \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-bd 0 -relief flat \
	-highlightthickness 0 -anchor w \
	-command {ToggleWindowMode}
    button $frFonc.cl \
	-text "Close" \
	-bg forestgreen -fg white \
	-activeforeground red \
	-activebackground forestgreen \
	-highlightthickness 0 -anchor w \
	-command [list QuitteViandox]
    
    grid $frFonc.ca -row 0 -column 0 -pady 0 -sticky nwe
    grid $frFonc.ci -row 1 -column 0 -pady 0 -sticky nwe
    grid $frFonc.cd -row 2 -column 0 -pady 0 -sticky nwe
    grid $frFonc.ds -row 3 -column 0 -pady 0 -sticky nwe
    grid $frFonc.ct -row 4 -column 0 -pady 0 -sticky nwe
    grid $frFonc.pr -row 5 -column 0 -pady 0 -sticky nwe
    grid $frFonc.fs -row 6 -column 0 -pady 0 -sticky nwe
    grid $frFonc.cl -row 7 -column 0 -pady 20 -sticky swe
    grid rowconfig $frFonc 7 -weight 1

    # Frame Objects
    frame $frObjc.onoff \
	-bg black \
	-relief flat \
	-bd 0 \
	-highlightthickness 0

    button $frObjc.onoff.allon \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-text "All On" \
	-font FontOg \
	-bd 0 -highlightthickness 0 \
	-anchor w -justify left \
	-padx 0 -relief flat \
	-command [list TousObjetsOn]
    
    button $frObjc.onoff.alloff \
	-bg black -fg cyan \
	-activeforeground yellow \
	-activebackground black \
	-font FontOg \
	-text "All Off" \
	-anchor e -justify right \
	-padx 0 -relief flat \
	-bd 0 -highlightthickness 0 \
	-command [list TousObjetsOff]
    
    grid $frObjc.onoff.allon  -row 0 -column 0 -sticky w -ipadx 10
    grid $frObjc.onoff.alloff -row 0 -column 1 -sticky e -ipadx 10
    grid columnconfig $frObjc.onoff all -weight 1
    grid $frObjc.onoff -row 0 -column 0 -sticky we -pady 0 -ipady 0 -padx {20 1}
    
    grid columnconfig $frObjc all -weight 1

    # Grille Generale

    grid rowconfigure $wgl 2 -weight 1
    grid columnconfig $wgl 1 -weight 1

    # Bindings 
    bind $frTogl.c <Control-ButtonPress-1> {PickAtom %x %y %W}
    #    bind $frFonc.c.c <Shift-1>   {CenterAtom %x %y %W}

    set ::BQx [expr {$pgl(width)/2}]
    set ::BQy [expr {$pgl(height)/2}]
    bind $frTogl.c <ButtonPress-1> {set ::BQx %x ; set ::BQy %y}
    #bind $frTogl.c <1>         "LClick %x %y"
    #bind $frTogl.c <B1-Motion> "LDrag %x %y %W"
    bind $frTogl.c <B1-Motion> {QDrag %x %y}

    bind $frTogl.c <2> {set cx %x; set cy %y}
    bind $frTogl.c <3> {set cx %x; set cy %y}

    bind $frTogl.c <B3-Motion> {Mouse TraXY %x %y %W}

    bind $frTogl.c <4> {HandleZoom  0.03 %W}
    bind $frTogl.c <5> {HandleZoom -0.03 %W}
    # Fix: <4>/<5> only cover the wheel under "classic" X11 (Tk <= 8.6).
    # On Windows/macOS (and on X11 with Tk >= 8.7, TIP 474), the wheel is
    # reported via the <MouseWheel> virtual event and %D. The two forms
    # never fire at the same time for a given OS/Tk combination: they can
    # coexist without any platform test, each staying inert while the
    # other is active.
    bind $frTogl.c <MouseWheel> {HandleZoom [expr {%D > 0 ? 0.03 : -0.03}] %W}

    #bind $wgl <Escape> {AdieuOrdali}
    bind $wgl <Key-F1> [list ToggleWindowMode]
    bind $wgl <Key-F2> [list ToggleShowFrame]
    bind $wgl <Control-Key-p> {PrintOgl}
    bind $wgl <Escape> {ToggleWindowMode escape}

    set ::fact 0.1
    bind $wgl <Control-Key-f> {AdjustFog up}
    bind $wgl <Control-Key-g> {AdjustFog down}
    set ::fogon 1
    bind $wgl <Control-Key-F1> {FogOnOff}
    set ::fogsys "::GL_EXP2"
    bind $wgl <Control-Key-F2> {ChangeFogSys}
    set ::fogcoords "fog"
    bind $wgl <Control-Key-F3> {FogCoords}
    set ::eyepos "zero"
    #bind $wgl <Control-Key-F4> {EyePos}
    
    wm deiconify $wgl
    update idletasks
    
    FenetreAuCentre $wgl

    if {[winfo exists .fattendre]} {
	focus -force .fattendre
	raise .fattendre
	wm attributes .fattendre -topmost 1
	update idletasks
    }

    update idletasks

    Update3DMatrices
    EnvoieLesObjets

    #glFlush
    #$pgl(Wogl) postredisplay

    return
}


proc SProut {} {
    global ListePDB mol Rad pgl LesVecs ListeTypesDeFeatures StrucAVoir

    set StrucAVoir {}
    set ListeTypesDeFeatures {}
    set ListePDB {}
    set LesVecs {}

    #set mol "1c0a"
    #set mol "1ile"
    #set chn A
    #Structure create $mol
    #$mol new "1ile.pdb" $chn

    Initialisation

    set Rad 10.0
    set pgl(Rad) $Rad
    set pgl(backclip) -10.
    set pgl(frontclip) 20.
    set pgl(xc) 0.
    set pgl(yc) 0.
    set pgl(zc) 0.
    set pgl(xCen) $pgl(xc)
    set pgl(yCen) $pgl(yc)
    set pgl(zCen) $pgl(zc)
    set pgl(eyeX)  0.0
    set pgl(eyeY)  0.0
    set pgl(eyeZ) 15.0

    AfficheFenetreOpengl

    $pgl(wogl) postredisplay

    return
}


proc FaitTracage {what} {
    global TypeRep DListCou pgl TSList Rad RadMol Rc LesVecs mol

    set TypeRep $what
    set w $pgl(wogl)

    if {[info exists TSList($what)]} {
	set DListCou [set TSList($what)]
	set Rad [set Rc($what)]
    } else {
	switch $what {
	    "ribbon" {
		if {$LesVecs == {} } {return}
		set TSList($what) [glGenLists 1]
		set DListCou [set TSList($what)]
		glNewList [set TSList($what)] GL_COMPILE

		use_light

		glBegin GL_TRIANGLES

		set k 0
		foreach {v1 v2 v3} $LesVecs {
		    glNormal3fv $v1
		    light_color3f {*}$v2
		    glVertex3fv $v3
		    if {$k < 3} {
			puts [format "v1 %8.3f %8.3f %8.3f" {*}$v1]
			puts [format "v3 %8.3f %8.3f %8.3f" {*}$v3]
			puts ""
			incr k
		    }
		}
		glEnd
		set Rad $RadMol
		set Rc($what) $RadMol
	    }
	    "stick" {
		set TSList($what) [glGenLists 1]
		set DListCou [set TSList($what)]
		glNewList [set TSList($what)] GL_COMPILE

		CalculeStick [set TSList($what)] $mol
		set Rad $RadMol
		set Rc($what) $RadMol
	    }
	    "fildefer" {
		set TSList($what) [glGenLists 1]
		set DListCou [set TSList($what)]
		glNewList [set TSList($what)] GL_COMPILE

		CalculeFilDeFer [set TSList($what)] $mol
		set Rad $RadMol
		set Rc($what) $RadMol
	    }
	    "benjilamalice" {
		use_light

		set pgl(xCen) 0.0
		set pgl(yCen) 0.0
		set pgl(zCen) 0.0

		set Rc($what) 2.
		set Rad 2.
		set TSList($what) [glGenLists 1]
		set DListCou [set TSList($what)]
		glNewList [set TSList($what)] GL_COMPILE_AND_EXECUTE

		BenjiLaMalice trace
		puts "j'ai fait la benji experience !"
	    }
	}

	glEndList
    }

    Update3DMatrices
    $pgl(wogl) postredisplay

    return
}


proc ColorieMol3dSelonFeatures {f} {
    global StrucAVoir TabSF ListePDB
    global pgl Mol3dCou Obj3dCou Feat3dCou Feat3dCou2

    if {! [AfficheDansViandox]} {
	return
    }

    foreach mold [StrucDuViewer] {
	set nom [DonneIdDeAccessPDB $mold]
	set chn [DonneChainDeAccessPDB $mold]

	set Mol3dCou $nom
	set Obj3dCou "CA${nom}${chn}"	
	set Feat3dCou $f

	UpdateMolObjFeat
    }

    return
}


proc ObjDeTest {} {
    global Tlist

    if {[info exists Tlist]} {
	glCallList $Tlist
    } else {
	set QObj [gluNewQuadric]
	gluQuadricDrawStyle $QObj GLU_FILL
	gluQuadricOrientation $QObj GLU_OUTSIDE
	gluQuadricNormals   $QObj GLU_SMOOTH
	
	set mat_spe { 1.0 1.0 1.0 1.0 }
	set Lball [list \
		       [list 0.0 0.0 0.0 0.5] \
		       [list 5.0 0.0 0.0 1.0] \
		       [list 0.0 5.0 0.0 2.0] \
		       [list 0.0 0.0 5.0 3.0]]
	set Lcol [list \
		      [list 1.0 1.0 1.0] \
		      [list 1.0 0.0 0.0] \
		      [list 0.0 1.0 0.0] \
		      [list 0.0 0.0 1.0] ]
	set Lcyl [list 0.1 0.4 5.0 12 1]
	set Laxe [list 0 \
		      [list  90. 0.0 1.0 0.0] \
		      [list -90. 1.0 0.0 0.0] \
		      [list   0. 0.0 0.0 1.0]]
	
	set Tlist [glGenLists 1]
	puts "Display List $Tlist"
	glNewList $Tlist GL_COMPILE_AND_EXECUTE
	foreach v $Lball c $Lcol a $Laxe {
	    lassign $v x y z r
	    lappend c 1.0
	    glMaterialfv GL_FRONT GL_SPECULAR $mat_spe
	    glMaterialfv GL_FRONT GL_SHININESS 100.
	    glMaterialfv GL_FRONT GL_EMISSION {0. 0. 0. 1.}
	    glMaterialfv GL_FRONT GL_AMBIENT   $c
	    glMaterialfv GL_FRONT GL_DIFFUSE   $c

	    glPushMatrix
	    glTranslatef $x $y $z
	    glColor4fv $c
	    gluSphere $QObj $r 16 16
	    glPopMatrix
	    
	    if {$a != 0} {
		glPushMatrix
		glRotatef {*}$a
		glColor4f 1.0 1.0 1.0 1.0
		gluCylinder $QObj {*}$Lcyl
		glPopMatrix
	    }
	}
	gluDeleteQuadric $QObj
	
	glEndList
    }

    return 
}


proc DefineNewObj {lamol {obj ""}} {
    global NwOj NwOjR ListeFeat43d

    if {! [ViewerDansSonInstance "create or edit objects"]} {
	return
    }
    set NwOj(Mol) $lamol
    set mol "::$lamol"
    set NwOj(Toplevel) .nwoj
    if {[winfo exists $NwOj(Toplevel)]} {
	raise $NwOj(Toplevel)
	return
    }

    set OldGrab [grab current]
    set tpl $NwOj(Toplevel)
    toplevel $tpl \
	-bg black
    wm title $tpl "New Object ..."
    wm iconname $tpl "New Obj"
    wm protocol $tpl WM_DELETE_WINDOW KillParLaCroix

    set top $tpl.f
    frame $top -bg black
    grid $top -row 0 -column 0 -sticky news -padx 10 -pady 10
    grid columnconfig $tpl 0 -weight 1
    grid rowconfig    $tpl 0 -weight 1

    # frame for obj name
    frame $top.fnames -bg black
    if {$obj ne ""} {
	set text1 "Object : "
    } else {
	set text1 "New Object : "
    }
    label $top.fnames.lobj \
	-text $text1 \
	-anchor w -justify left \
	-relief flat -highlightthickness 0 \
	-bg black -fg white
    set NwOj(Obj) "objname"
    set NwOj(ObjEntry) $top.fnames.eobj
    entry $top.fnames.eobj \
	-textvariable NwOj(Obj) \
	-bg black -fg white
    label $top.fnames.lmol \
	-text "in Molecule $mol" \
	-anchor w -justify left \
	-relief flat -highlightthickness 0 \
	-bg black -fg white
    grid $top.fnames.lobj -row 0 -column 0 -sticky w -padx 2
    grid $top.fnames.eobj -row 0 -column 1 -sticky ew
    grid $top.fnames.lmol -row 0 -column 2 -sticky w
    
    # frame for chain selection
    frame $top.fchains \
	-bg black -relief groove -bd 2
    frame $top.fchains.fsel \
	-relief flat -bd 0 \
	-bg black
    label $top.fchains.fsel.lchn \
	-text "Chain :" \
	-anchor w -justify left \
	-relief flat -highlightthickness 0 \
	-bg black -fg white
    grid $top.fchains.fsel.lchn -row 0 -column 0 -sticky w -padx 2
    set col 1
    set Lchn [lsort [$mol _chains]]
    foreach chn $Lchn {
	ttk::radiobutton $top.fchains.fsel.r$chn \
	    -style vdx.TRadiobutton \
	    -text "$chn" \
	    -value "$chn" \
	    -variable NwOj(Chain) \
	    -command CanvasDeChaine
	grid $top.fchains.fsel.r$chn -row 0 -column $col -ipadx 2
	incr col
    }
    set NwOj(ChainCou) ""

    frame $top.fchains.ftype \
	-relief flat -bd 0 \
	-bg black
    set NwOj(ChType) "polymer"
    label $top.fchains.ftype.ltyp \
	-text "Type of chain : " \
	-anchor w -justify left \
	-relief flat -highlightthickness 0 \
	-bg black -fg white
    ttk::radiobutton $top.fchains.ftype.typo \
	-style vdx.TRadiobutton \
	-text "Polymer" \
	-value "polymer" \
	-variable NwOj(ChType)
    ttk::radiobutton $top.fchains.ftype.tyli \
	-style vdx.TRadiobutton \
	-text "ligand" \
	-value "ligand" \
	-variable NwOj(ChType)
    grid $top.fchains.ftype.ltyp -row 0 -column 0 -sticky w -padx 2
    grid $top.fchains.ftype.typo -row 0 -column 1 -sticky w -padx {2 5}
    grid $top.fchains.ftype.tyli -row 0 -column 2 -sticky w -padx 5
    # Stack the two frames for chains
    grid $top.fchains.ftype -row 0 -column 0
    grid $top.fchains.fsel -row 1 -column 0

    # Inits
    set NwOj(Colors) [list None "Feature Color" red blue green yellow magenta cyan orange pink brown "more ..."]
    set NwOj(ColorSel) [lindex $NwOj(Colors) 0]
    set wdtC [PlusLongEltDe $NwOj(Colors)]
    set NwOj(Types) [list "None" "Atoms" "Ca/P Trace" "Ribbon" "Ribbon + Atoms" "Ribbon + CPK" "Pearls" "CPK"]
    set NwOj(TypeSel) [lindex $NwOj(Types) 0]
    set wdtT [PlusLongEltDe $NwOj(Types)]
    set wdt [expr {max($wdtT,$wdtC)+1}]
    set NwOj(ListeFeat) [list "None" {*}$ListeFeat43d]
    set wdtF [PlusLongEltDe $NwOj(ListeFeat)]
    set NwOj(FeatSel) [lindex $NwOj(ListeFeat) 0]
    set NwOj(FeatCol) [lindex $NwOj(ListeFeat) 0]

    # frame selection
    labelframe $top.fsel \
	-bg black -relief groove -bd 2 \
	-text "Define representation scheme for a given residue zone" \
	-fg cyan \
	-font TitleFont
    frame $top.fsel.ftypes \
	-relief flat -bd 0 \
	-bg black
    label $top.fsel.ftypes.ltyp \
	-text "Draw as " \
	-relief flat \
	-width 10 \
	-anchor w -justify left \
	-bg black -fg white 
    set NwOj(CbType) $top.fsel.ftypes.ctyp
    ttk::combobox $top.fsel.ftypes.ctyp \
	-style vdx.TCombobox \
	-state readonly \
	-width $wdt \
	-values $NwOj(Types) \
	-textvariable NwOj(TypeSel)
    label $top.fsel.ftypes.lsel \
	-text " and apply to :" \
	-bg black -fg white \
	-anchor w -justify left \
	-relief flat
    grid $top.fsel.ftypes.ltyp -row 0 -column 0 -sticky w -padx 2
    grid $top.fsel.ftypes.ctyp -row 0 -column 1 -sticky ew -padx 2
    grid $top.fsel.ftypes.lsel -row 0 -column 2 -sticky w
    frame $top.fsel.fas \
	-relief flat -bd 0\
	-bg black
    button $top.fsel.fas.ball \
	-text " All " \
	-bg cyan -fg black \
	-command [list SelectChainNwOj all]
    label $top.fsel.fas.lor \
	-text "or " \
	-anchor w -justify left \
	-relief flat \
	-fg white -bg black
    button $top.fsel.fas.bslt \
	-text " Selected " \
	-bg cyan -fg black \
	-command [list SelectChainNwOj selected]
    label $top.fsel.fas.lres \
	-text " residues" \
	-anchor w -justify left \
        -relief flat \
	-fg white -bg black
    grid $top.fsel.fas.ball -row 0 -column 0 -sticky w -padx 2
    grid $top.fsel.fas.lor -row 0 -column 1 -sticky w -padx 2
    grid $top.fsel.fas.bslt -row 0 -column 2 -sticky w -padx 2
    grid $top.fsel.fas.lres -row 0 -column 3 -sticky w -padx 2
    
    frame $top.fsel.ffea \
	-relief flat -bd 0 \
	-bg black
    label $top.fsel.ffea.lfea \
	-text " Or in feature " \
	-width 18 \
	-bg black -fg white \
	-anchor w -justify left \
	-relief flat
    set NwOj(CbFeat) $top.fsel.ffea.cfea
    ttk::combobox $top.fsel.ffea.cfea \
	-style vdx.TCombobox \
	-state readonly \
	-width $wdtF \
	-values $NwOj(ListeFeat) \
	-textvariable NwOj(FeatSel)
    bind $top.fsel.ffea.cfea <<ComboboxSelected>> [list SelectChainNwOj feature]
    grid $top.fsel.ffea.lfea -row 0 -column 0 -sticky w -padx 2
    grid $top.fsel.ffea.cfea -row 0 -column 1 -sticky w -padx 2

    # Stack the 3 sub-frames
    grid $top.fsel.ftypes -row 0 -column 0
    grid $top.fsel.fas -row 1 -column 0 -padx {30 0}
    grid $top.fsel.ffea -row 2 -column 0 -padx {30 0}

    # frame painting
    labelframe $top.fpai \
	-bg black -relief groove -bd 2 \
	-text "Define a painting scheme for a given residue zone" \
	-font TitleFont -fg cyan
    frame $top.fpai.fcol \
	-bd 0 -relief flat \
	-bg black
    label $top.fpai.fcol.ltyp \
	-text "Paint in " \
	-relief flat \
	-width 10 \
	-anchor w -justify left \
	-bg black -fg white 
    set NwOj(CbCol) $top.fpai.fcol.ctyp
    ttk::combobox $top.fpai.fcol.ctyp \
	-style vdx.TCombobox \
	-state readonly \
	-width $wdt \
	-values $NwOj(Colors) \
	-textvariable NwOj(ColorSel)
    label $top.fpai.fcol.lsel \
	-text " residues " \
	-bg black -fg white \
	-anchor w -justify left \
	-relief flat
    grid $top.fpai.fcol.ltyp -row 0 -column 0 -sticky w -padx 2
    grid $top.fpai.fcol.ctyp -row 0 -column 1 -sticky w -padx 2
    grid $top.fpai.fcol.lsel -row 0 -column 2 -sticky w -padx 2
    frame $top.fpai.fas \
	-bd 0 -relief flat \
	-bg black
    button $top.fpai.fas.ball \
	-text " All " \
	-bg cyan -fg black \
	-command [list ColorChainNwOj all]
    label $top.fpai.fas.lor \
	-text " or " \
	-bd 0 -relief flat \
	-anchor w -justify left \
	-bg black -fg white
    button $top.fpai.fas.bslt \
	-text "Selected" \
	-relief flat \
	-bg cyan -fg black \
	-command [list ColorChainNwOj selected]
    label $top.fpai.fas.lres \
	-text " residues" \
	-anchor w -justify left \
        -relief flat \
	-fg white -bg black
    grid $top.fpai.fas.ball -row 0 -column 0 -sticky w -padx 2
    grid $top.fpai.fas.lor -row 0 -column 1 -sticky w -padx 2
    grid $top.fpai.fas.bslt -row 0 -column 2 -sticky w -padx 2
    grid $top.fpai.fas.lres -row 0 -column 3 -sticky w -padx 2

    frame $top.fpai.ffea \
	-bd 0 -relief flat \
	-bg black
    label $top.fpai.ffea.lfea \
	-text " using feature " \
	-width 15 \
	-bg black -fg white \
	-anchor w -justify left \
	-relief flat
    set NwOj(CbFeatCol) $top.fpai.ffea.cfea
    ttk::combobox $top.fpai.ffea.cfea \
	-style vdx.TCombobox \
	-state readonly \
	-width $wdtF \
	-values $NwOj(ListeFeat) \
	-textvariable NwOj(FeatCol)
    bind $top.fpai.ffea.cfea <<ComboboxSelected>> [list ColorChainNwOj feature]
    grid $top.fpai.ffea.lfea -row 0 -column 0 -sticky w -padx 2
    grid $top.fpai.ffea.cfea -row 0 -column 1 -sticky w -padx 2
    # Stack the 3 frames
    grid $top.fpai.fcol -row 0 -column 0 -sticky w
    grid $top.fpai.fas -row 1 -column 0 -sticky w -padx {30 0}
    grid $top.fpai.ffea -row 2 -column 0 -sticky w -padx {30 0}

    # frame canvas
    set NwOj(Can) $top.fcan.can
    frame $top.fcan -bg black
    canvas $top.fcan.can \
	-width 300 -height 200 \
	-highlightthickness 0 \
	-scrollregion [list 0 0 300 200] \
	-bg black
    
    grid $top.fcan.can -row 0 -column 0 -sticky news
    grid columnconfig $top.fcan 0 -weight 1
    grid rowconfig $top.fcan 0 -weight 1

    # frame surface
    frame $top.fsrf -bg black -relief groove -bd 2
    set NwOj(Surface) 0
    label $top.fsrf.lsrf \
	-text "Add surface : " \
	-bg black -fg white \
	-anchor w -justify left
    ttk::radiobutton $top.fsrf.ryes \
	-style vdx.TRadiobutton \
	-text "Yes" \
	-value 1 \
	-variable NwOj(Surface)
    ttk::radiobutton $top.fsrf.rno \
	-style vdx.TRadiobutton \
	-text "No" \
	-value 0 \
	-variable NwOj(Surface)
    grid $top.fsrf.lsrf -row 0 -column 0 -sticky w -padx 2
    grid $top.fsrf.ryes -row 0 -column 1 -sticky w
    grid $top.fsrf.rno  -row 0 -column 2 -sticky w

    # frame controls 
    frame $top.fbutton -bg black
    button $top.fbutton.ok \
	-text " OK " \
	-bg green1 \
	-highlightthickness 0 \
	-command [list FinNewObj ok]
    button $top.fbutton.dis \
	-text "Dismiss" \
	-highlightthickness 0 \
	-bg red -fg white \
	-command [list FinNewObj dismiss]
    grid $top.fbutton.dis -row 0 -column 0 -sticky w -padx 20
    grid $top.fbutton.ok -row 0 -column 1 -sticky e -padx 20
    grid columnconfig $top.fbutton all -weight 1

    # grid les frames
    grid $top.fnames  -row 0 -column 0 -sticky ew -pady 5 -padx 5
    grid $top.fchains -row 1 -column 0 -sticky ew -padx 5 -pady 3
    grid $top.fsel    -row 2 -column 0 -sticky ew -padx 5 -pady 3
    grid $top.fpai    -row 3 -column 0 -sticky ew -padx 5 -pady 3
    grid $top.fcan    -row 4 -column 0 -sticky news -pady 3
    grid $top.fsrf    -row 5 -column 0 -sticky ew -padx 5 -pady 3
    grid $top.fbutton -row 6 -column 0 -sticky ew -pady {15 10}

    grid rowconfig    $top 4 -weight 1
    grid columnconfig $top all -weight 1

    # initialise object
    # Carefull !! only for polymer at present
    foreach chn $Lchn {
	set Lr [$mol _resnumber -chain $chn -polymer]
	foreach n $Lr {
	    set NwOjR($chn,$n) [list $n 0 couldefond]
	}
    }
    set NwOj(Edit) 0

    # Now update if editing
    if {$obj ne ""} {
	set NwOj(Obj) [string range $obj 4 end]
	set NwOj(Edit) 1
	$NwOj(ObjEntry) configure -state disabled
	array set NwOjR [$mol editObject $obj]
	# "Add surface" shows if the object has a surface
	set NwOj(Surface) [$mol hasSurface $obj]
	$mol _dellist $obj
    }

    if {"Fcan" ni [font names]} {
	font create Fcan -size 10 
    }

    $top.fchains.fsel.r[lindex $Lchn 0] invoke

    FenetreAuCentre $top

    #tkwait window $NwOj(Toplevel)

    if {$OldGrab ne ""} {
	#grab $OldGrab
    }

    return
}


proc ColorChainNwOj {what} {
    global NwOj NwOjR TabSF

    set can $NwOj(Can)
    if {$NwOj(ColorSel) eq "None"} {
	set col couldefond
    } elseif {$NwOj(ColorSel) eq "more ..."} {
	set col [tk_chooseColor]
	if {$col eq ""} {
	    return
	}
	set NwOj(ColorSel) $col
    } elseif {$NwOj(ColorSel) eq "Feature Color" && $what ne "feature"} {
	return
    } else {
	set col $NwOj(ColorSel)
	if {$col eq "green"} {set col green1}
    }

    set chn $NwOj(Chain)
    switch $what {
	"all" {
	    foreach e [array names NwOjR "${chn},*"] {
		lset NwOjR($e) 2 $col
	    }
	}
	"selected" {
	    set Li [$can find withtag Selected]
	    foreach i $Li {
		set Lt [$can gettags $i]
		set nb [lsearch -inline -regexp $Lt {^Nbr}]
		set n [string range $nb 3 end]
		lset NwOjR($chn,$n) 2 $col
	    }
	    ClearSelectionNwOj
	}
	"feature" {
	    if {$NwOj(FeatCol) eq "None"} {return}
	    if {! [ViewerDansSonInstance "use its features"]} {return}
	    set feat $NwOj(FeatCol)
	    set mol $NwOj(Mol)
	    set chn $NwOj(Chain)
	    set nom [BonNomPDB "${mol}_$chn"]
	    set ft [info exists TabSF($nom,$feat)]
	    if {! $ft} {return}
	    foreach e [set TabSF($nom,$feat)] {
		DecortiqueUneFeature $e d f fcol sc note
		if {$NwOj(ColorSel) eq "Feature Color"} {
		    set col $fcol
		}
		# Special case for Discri
		# don't take if indel present
		if {[regexp -nocase {^indel} $note]} {
		    continue
		}
		for {set i $d} {$i <= $f} {incr i} {
		    set n [DonnePosGS $nom $i]
		    # column before the first residue of the chain
		    if {! [info exists NwOjR($chn,$n)]} {continue}
		    lset NwOjR($chn,$n) 2 $col
		}
	    }
	}
    }

    CanvasDeChaine

    return
}


proc SelectChainNwOj {what} {
    global NwOj NwOjR TabSF

    set Strtype $NwOj(TypeSel)
    set can $NwOj(Can)
    switch $Strtype {
	"None"           {set type 0}
	"Atoms"          {set type 1}
	"Ca/P Trace"     {set type 2}
	"Ribbon"         {set type 3}
	"Ribbon + Atoms" {set type 4}
	"Ribbon + CPK"   {set type 5}
	"Pearls"         {set type 6}
	"CPK"            {set type 7}
    }

    set chn $NwOj(Chain)
    switch $what {
	"all" {
	    foreach e [array names NwOjR "${chn},*"] {
		lset NwOjR($e) 1 $type
	    }
	}
	"selected" {
	    set Li [$can find withtag Selected]
	    foreach i $Li {
		set Lt [$can gettags $i]
		set nb [lsearch -inline -regexp $Lt {^Nbr}]
		set n [string range $nb 3 end]
		lset NwOjR($chn,$n) 1 $type
	    }
	    ClearSelectionNwOj
	}
	"feature" {
	    if {$NwOj(FeatSel) eq "None"} {return}
	    if {! [ViewerDansSonInstance "use its features"]} {return}
	    set feat $NwOj(FeatSel)
	    set mol $NwOj(Mol)
	    set chn $NwOj(Chain)
	    set nom [BonNomPDB "${mol}_$chn"]
	    if {! [info exists TabSF($nom,$feat)]} {
		return
	    }
	    foreach e [set TabSF($nom,$feat)] {
		DecortiqueUneFeature $e d f col sc note
		# Special case for Discri :
		# don't take if indel present
		if {[regexp -nocase {^indel} $note]} {
		    continue
		}
		for {set i $d} {$i <= $f} {incr i} {
		    set n [DonnePosGS $nom $i]
		    if {$n eq ""} {
			DonnePosGS $nom $i 1
		    }
		    # column before the first residue of the chain
		    if {! [info exists NwOjR($chn,$n)]} {continue}
		    lset NwOjR($chn,$n) 1 $type
		}
	    }
	}
    }

    CanvasDeChaine

    return
}


proc CanvasDeChaine {args} {
    global NwOj NwOjR TabSF

    set mol $NwOj(Mol)
    set chn $NwOj(Chain)

    # setup widgets depending on chain
    set NwOj(ListeFeat) "None"
    set nom [BonNomPDB "${mol}_$chn"]
    if {[info exists TabSF]} {
	set Lf [array names TabSF "$nom,*"]
	set Lt {} ; set wdt 10
	if {$Lf != {} } {
	    foreach e $Lf {
		lassign [split $e ,] tmp type
		lappend Lt $type
	    }
	    set wdt [PlusLongEltDe $Lt]
	}
	lappend NwOj(ListeFeat) {*}$Lt

	$NwOj(CbFeat) configure -values $NwOj(ListeFeat) -width $wdt
	$NwOj(CbFeat) current 0
	$NwOj(CbFeatCol) configure -values $NwOj(ListeFeat) -width $wdt
	$NwOj(CbFeatCol) current 0
    }
    $NwOj(CbType) current 0
    $NwOj(CbCol)  current 0

    set NwOj(ResPerLine) 100
    set c $NwOj(Can)
    $c delete all
    set Lr [$mol _resnumber -chain $chn -polymer]
    set NwOj(LResNb) $Lr
    set NwOj(LResNm) [$mol _resname -chain $chn -code3l]

    if {$NwOj(ChainCou) ne ""} {
	SauveNwOjCourant
    }
    set NwOj(ChainCou) $NwOj(Chain)
    set NwOj(ListeIdSel) {}

    set Lg [llength $Lr]
    set nl [expr {int(double($Lg)/$NwOj(ResPerLine))+1}]

    set YPerLine 30 ; set NwOj(YPerLine) $YPerLine
    set YOffset  10 ; set NwOj(YOffset) $YOffset
    set XOffset [font measure Fcan "9999"] ; set NwOj(XOffset) $XOffset
    set idx -1
    for {set i 0} {$i < $nl} {incr i} {
	incr idx
	set y [expr {($i+1)*$YPerLine + $YOffset}]
	set x $XOffset
	$c create text $x $y \
	    -text "[lindex $Lr $idx]" \
	    -anchor se -justify right \
	    -fill white
	incr x 3
	for {set j 0} {$j < $NwOj(ResPerLine)} {incr j} {
	    set n [lindex $Lr $idx]
	    lassign [set NwOjR($chn,$n)] nr type col
	    InitResBox $x $y $n
	    TraceResBox $x $y $n $type
	    TraceColBox $x $y $n $col
	    incr x 7

	    incr idx
	    if {$idx == $Lg} {
		break
	    }
	}
	incr idx -1
	incr x 3
	$c create text $x $y \
	    -text "[lindex $Lr $idx]" \
	    -anchor sw -justify left \
	    -fill white
    }
    
    set NwOj(isSelecting) 0
    $c bind {BgRes || NBox} <ButtonRelease-3> [list ChangeResBoxType %W %x %y]
    #$c bind NBox  <1> [list ChangeResBoxType %W %x %y]
    set NwOj(CurrentNbr) ""
    bind $c <ButtonPress-1>   {StartSelectionForObj %W %x %y}
    bind $c <B1-Motion>       {SelectionZoneForObj %W %x %y}
    bind $c <ButtonRelease-1> {StopSelectionForObj %W %x %y}
    bind $c <Motion>    [list MontreCacheResNumber %W %x %y]
    bind $c <B1-Motion> [list +MontreCacheResNumber %W %x %y]
    #$c bind BgRes <Enter> [list MontreResNumber %W %x %y]
    #$c bind NBox <Enter> [list MontreResNumber %W %x %y]
    #$c bind BgRes <Leave> [list CacheResNumber %W]
    #$c bind NBox <Leave> [list CacheResNumber %W]

    #$c lower BgRes
    lassign [$c bbox all] z e w h
    #incr w 20 ; incr h 20
    $c configure -width $w
    #$c configure -width $w -height $h -scrollregion [list $z $e $w $h]
    #$c move all 10 10

    update idletasks

    return
}


proc InitResBox {x y n} {
    set c $::NwOj(Can)
    
    set x1 [expr {$x+7}]
    set y1 [expr {$y-20}]
    $c create rectangle $x $y1 $x1 $y \
	-fill black \
	-outline black \
	-tags [list BgRes Nbr$n]

    return
}


proc TraceColBox {x y n col} {	    

    set c $::NwOj(Can)
    set x1 [expr {$x+7}]
    set y1 [expr {$y-3}]
    if {$col eq "couldefond"} {set col black}
    $c create rectangle $x $y1 $x1 $y \
	-fill $col \
	-outline $col \
	-tags [list ColRes Nbr$n]

    return
}


proc TraceResBox {x y n type} {

    set c $::NwOj(Can)
    set ::NwOj(TypeMax) 7
    if {$type > $::NwOj(TypeMax)} {set type 0}

    incr y -5
    switch $type {
	0 {
	    # "None" - nothing
	    set x1 [expr {$x+3}]
	    set y2 [expr {$y-4}]
	    $c create line $x1 $y $x1 $y2 \
		-fill cyan \
		-tags [list NBox Type0 Nbr$n NBox$n]
	}
	1 {
	    # "Atoms" - wireframe or stick
	    set y1 $y
	    set x1 [expr {$x+3}]
	    set y2 [expr {$y-3}]
	    $c create line $x1 $y1 $x1 $y2 \
		-fill cyan \
		-tags [list NBox Type1 Nbr$n NBox$n]
	    set x2 $x
	    set y3 [expr {$y2-3}]
	    $c create line $x1 $y2 $x2 $y3 \
		-fill cyan \
		-tags [list NBox Type1 Nbr$n]
	    set x3 [expr {$x1+3}]
	    $c create line $x1 $y2 $x3 $y3 \
		-fill cyan \
		-tags [list NBox Type1 Nbr$n]
	    set y4 [expr {$y3-2}]
	    $c create line $x3 $y3 $x3 $y4 \
		-fill cyan \
		-tags [list NBox Type1 Nbr$n]
	}
	2 {
	    # "Ca/P Trace" - simple ca/p trace
	    set x1 $x ; set x2 [expr {$x+7}]
	    set y1 [expr {$y-2}]
	    $c create line $x1 $y1 $x2 $y1 \
		-fill cyan \
		-tags [list NBox Type2 Nbr$n]
	}
	3 {
	    # "Ribbon" - lit Ribbon on CA or P trace
	    set x1 [expr {$x+7}]
	    set y1 [expr {$y-3}]
	    $c create rectangle $x $y $x1 $y1 \
		-fill black \
		-outline cyan \
		-tags [list NBox Type3 Nbr$n]
	}
	4 {
	    # "Ribbon + Atoms" - Ribbon + sticks
	    set x1 [expr {$x+7}]
	    set y1 [expr {$y-3}]
	    $c create rectangle $x $y $x1 $y1 \
		-fill black \
		-outline cyan \
		-tags [list NBox Type4 Nbr$n]
	    set x2 [expr {$x+3}]
	    set y2 [expr {$y1-3}]
	    $c create line $x2 $y1 $x2 $y2 \
		-fill cyan \
		-tags [list NBox Type4 Nbr$n]
	    set y3 [expr {$y2-3}]
	    $c create line $x2 $y2 $x $y3 \
		-fill cyan \
		-tags [list NBox Type4 Nbr$n]
	    $c create line $x2 $y2 $x1 $y3 \
		-fill cyan \
		-tags [list NBox Type4 Nbr$n]
	}
	5 {
	    # "Ribbon + CPK" - ribbon + CPK sidechains
	    set x1 [expr {$x+7}]
	    set y1 [expr {$y-3}]
	    $c create rectangle $x $y $x1 $y1 \
		-fill black \
		-outline cyan \
		-tags [list NBox Type5 Nbr$n]
	    # 2eme ball , just on top
	    set y2 [expr {$y1-3}]
	    set x1 [expr {$x+3}] ; set x2 [expr {$x+5}] 
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type5 Nbr$n]
	    set x1 $x ; set x2 [expr {$x+3}]
	    set y1 $y2 ; set y2 [expr {$y1-3}]
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type5 Nbr$n]
	    set x1 [expr {$x+4}] ; set x2 [expr {$x+7}]
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type5 Nbr$n]

	}
	6 {
	    # "Pearls" - Big ball at residue position
	    set x1 [expr {$x+7}]
	    set y1 [expr {$y-7}]
	    $c create oval $x $y $x1 $y1 \
		-fill black \
		-outline cyan \
		-tags [list NBox Type6 Nbr$n]
	}
	7 {
	    # "CPK" - whole residue as CPK
	    # premiere boule
	    set x1 [expr {$x+2}] ; set x2 [expr {$x+5}]
	    set y1 $y ; set y2 [expr {$y-3}]
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type7 Nbr$n NBox$n]
	    # 2eme ball , just on top
	    set y1 $y2 ; set y2 [expr {$y1-3}]
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type7 Nbr$n]
	    set x1 $x ; set x2 [expr {$x+3}]
	    set y1 $y2 ; set y2 [expr {$y1-3}]
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type7 Nbr$n]
	    set x1 [expr {$x+4}] ; set x2 [expr {$x+7}]
	    $c create oval $x1 $y1 $x2 $y2 \
		-fill black -outline cyan \
		-tags [list NBox Type7 Nbr$n]
	}
    }

    $c raise NBox

    return
}


proc ChangeResBoxType {c x y} {
    if {$::NwOj(isSelecting)} {return}

    set Lt [$c gettags current]
    set nb [lsearch -inline -regexp $Lt {^Nbr}]
    if {$nb eq ""} {return}
    set n [string range $nb 3 end]
    set chn $::NwOj(Chain)

    # if I change it , then it is selected
    set e [$c find withtag "BgRes && $nb"]
    lappend NwOj(ListeIdSel) $e
    $c addtag Selected withtag $e
    $c itemconfig Selected -fill DarkSlateGrey

    # take background item for corrdinates
    set bid [$c find withtag "BgRes && $nb"]
    lassign [$c coords $bid] x tmp tmp y
    set x [expr {int($x)}]
    set y [expr {int($y)}]

    # delete all "cyan" items of current residue
    set Ldel [$c find withtag "NBox && $nb"]
    # but keep the current type
    set Lt [$c gettags [lindex $Ldel 0]]
    set ty [lsearch -inline -regexp $Lt {^Type}]
    set NType [string range $ty 4 end]
    incr NType
    # after the last type comes 0 (None), as drawn by TraceResBox
    if {$NType > 7} {
	set NType 0
    }

    $c delete {*}$Ldel

    TraceResBox $x $y $n $NType
    lset ::NwOjR($chn,$n) 1 $NType

    return
}


proc MontreCacheResNumber {w x y} {
    set Lid [$w find overlapping $x $y [incr x] [incr y]]
    set Lt {}
    foreach id $Lid {
	lappend Lt {*}[$w gettags $id]
    }

    set tag [lsearch -inline -regexp $Lt {^Nbr}]
    if {$tag eq ""} {
	set ::NwOj(CurrentNbr) ""
	CacheResNumber $w
	
	return
    }

    set Nbr [string range $tag 3 end]
    if {$Nbr ne $::NwOj(CurrentNbr)} {
	CacheResNumber $w
	set ::NwOj(CurrentNbr) $Nbr
	MontreResNumber $w $tag
    }

    return
}


proc MontreResNumber {w tag} {
    foreach i [$w find withtag "NBox && $tag"] {
	$w itemconfig $i -fill orange
	if {[$w type $i] ne "line"} {
	    $w itemconfig $i -outline orange
	}
    }

    set id [$w find withtag "BgRes && $tag"]
    lassign [$w bbox $id] xd yd tmp tmp
    incr xd 3 
    incr yd 6
    set Nbr [string range $tag 3 end]
    set irs [lsearch -exact $::NwOj(LResNb) $Nbr]
    set res [lindex $::NwOj(LResNm) $irs] 
    $w create text $xd $yd \
	-anchor s -justify center \
	-text "$res $Nbr" \
	-fill orange \
	-tags [list LabelNbr A$Nbr]

    return
}


proc CacheResNumber {w} {
    set i [$w find withtag LabelNbr]
    if {$i eq ""} {return}

    set t [lsearch -inline -regexp [$w gettags $i] {^A}]
    set Nbr [string range $t 1 end]
    $w delete LabelNbr

    set Li [$w find withtag "NBox && Nbr$Nbr"]
    foreach i $Li {
	if {[$w type $i] ne "line"} {
	    $w itemconfig $i -fill black
	    $w itemconfig $i -outline cyan
	} else {
	    $w itemconfig $i -fill cyan
	}
    }

    return
}


proc SauveNwOjCourant {} {
    global NwOj NwOjR

    set c $NwOj(Can)
    set Lit [$c find withtag NBox]
    foreach i $Lit {
	set Lt [$c gettags $i]
	foreach t $Lt {
	    switch -regexp $t {
		{^Nbr} {
		    set n [string range $t 3 end]
		}
		{^Type} {
		    set type [string range $t 4 end]
		}
		{^NBox} {
		    set co [$c itemcget $i -background]
		}
	    }
	}
	if {$co eq "black"} {set co $::Defauts(CoulVariable)}
	set NwOjR($chn,$n) [list $n $type $co]
    }

    return
}


proc FinNewObj {quoi} {
    global NwOj NwOjR pgl
    
    if {$quoi eq "ok"} {
	# object made in the instance of the viewer
	if {! [ViewerDansSonInstance "save this object"]} {
	    return
	}
	# check if we have a new name
	set NwOj(Obj) [string trim $NwOj(Obj)]
	if {$NwOj(Obj) eq "objname" || $NwOj(Obj) eq ""} {
	    FaireLire "Please give a name to the new object !"
	    return
	}
	# the name is a SQL table name : letters, digits and _ only
	# (a space or a quote broke the SQL and left the structure
	# db in an open transaction)
	regsub -all -- {[^A-Za-z0-9_]} $NwOj(Obj) "_" NwOj(Obj)
	
	set mol $NwOj(Mol)
	set pdb "::$mol"
	if {! $NwOj(Edit)} {
	    if {[ObjectAlreadyExists $NwOj(Obj)]} {
		FaireLire "This object already exists !\nPlease give an other name !"

		return
	    }
	    
	    # define the object 
	    $pdb newObj $NwOj(Obj)
	}

	# a redraw while editing has rebuilt the display list with the old data
	if {$NwOj(Edit)} {
	    $pdb _dellist $NwOj(Obj)
	}
	$pdb assignSelection $NwOj(Obj) [array get NwOjR]
	if {$NwOj(Surface)} {
	    $pdb surface $NwOj(Obj)
	} else {
	    $pdb nosurface $NwOj(Obj)
	}
	$pdb render $NwOj(Obj)
	
	if {! $NwOj(Edit)} {
	    AddFObj $mol 
	}
	VueEditee 1
    }
    
    update idletasks
    destroy $NwOj(Toplevel)
    unset -nocomplain NwOjR NwOj
    $::pgl(wogl) postredisplay
    
    return
}


proc SelectObjItemsOnLine {l x1 x2} {
    global NwOj
    
    set y1 [expr {($l-1)*$NwOj(YPerLine)+$NwOj(YOffset)+15}]
    set y2 [expr {$l*$NwOj(YPerLine)+$NwOj(YOffset)-1}]
    
    set w $NwOj(Can)
    set Lsel {}
    foreach id [lrange [lsort -integer [$w find overlapping $x1 $y1 $x2 $y2]] 1 end-1] {
	set Lt [$w gettags $id]
	set nb [lsearch -regexp -inline $Lt {^Nbr}]
	if {$nb ne ""} {
	    set e [$w find withtag "BgRes && $nb"]
	    lappend Lsel $e
	}
    }

    return [lsort -unique -integer $Lsel]
}


proc NewObjRangeSelected {w x y} {
    global NwOj

    set Lsel {}
    if {! [info exists NwOj(Start)]} {return $Lsel}

    lassign $NwOj(Start) xs ys
    # we are not in a residue line
    if {$y <= $NwOj(YOffset)} {
	return $Lsel
    }
    if {$ys <= $NwOj(YOffset)} {
	set ys $NwOj(YOffset)
    }
    if {$xs < $NwOj(XOffset)+3} {
	set xs [expr {$NwOj(XOffset)+3}]
    }
    if {$x < $NwOj(XOffset)+3} {
	set x [expr {$NwOj(XOffset)+3}]
    }
    set x [expr {$x + (7-($x-$NwOj(XOffset)-3)%7)}]

    # determine which lines
    set l1 [expr {int(0.5+(double($ys)-$NwOj(YOffset))/$NwOj(YPerLine))}]
    set l2 [expr {int(0.5+(double($y)-$NwOj(YOffset))/$NwOj(YPerLine))}]
    set l1 [expr {$l1<=0?1:$l1}]
    set l2 [expr {$l2<=0?1:$l2}]

    if {$y < ($l1*$NwOj(YPerLine))+$NwOj(YOffset)+10} {
	set l2 $l1
    }

    # do the selection
    if {($l2-$l1) == 0} {
	# we are on the same line
	set Lsel [SelectObjItemsOnLine $l1 $xs $x]
    } else {
	# we are on distinct lines
	set x0 0
	set xf [$NwOj(Can) cget -width]
	# first line up to the end
	set Lsel [SelectObjItemsOnLine $l1 $xs $xf]
	# select lines between start and end
	for {set i [expr {$l1+1}]} {$i < $l2} {incr i} {
	    lappend Lsel {*}[SelectObjItemsOnLine $i $x0 $xf]
	}
	# last line from start to x
	lappend Lsel {*}[SelectObjItemsOnLine $l2 $x0 $x]
    }
    
    return $Lsel
}


proc StopSelectionForObj {w x y} {

    return
    return -code break
}


proc StartSelectionForObj {w x y} {
    set ::NwOj(isSelecting) 0
    ClearSelectionNwOj

    set x [expr {$x - ($x-$::NwOj(XOffset)-3)%7}]
    set ::NwOj(Start) [list $x $y]

    return
}


proc SelectionZoneForObj {w x y} {
    set ::NwOj(isSelecting) 1
    set Lsel [NewObjRangeSelected $w $x $y]
    if {$Lsel == {}} {return}

    set LToSel [lor $Lsel $::NwOj(ListeIdSel) from1]
    foreach e $LToSel {
	$w addtag Selected withtag $e
    }

    set LToUnsel [lor $Lsel $::NwOj(ListeIdSel) from2]
    if {$LToUnsel != {}} {
	ClearSelectionNwOj $LToUnsel
    }

    $w itemconfig Selected -fill DarkSlateGrey
    set ::NwOj(ListeIdSel) $Lsel
    update idletasks

    return
}


proc ClearSelectionNwOj {{Ls {}}} {
    set w $::NwOj(Can)
    if {$Ls == {}} { 
	$w itemconfig Selected -fill black
	$w dtag all Selected
	set ::NwOj(ListeIdSel) {}
    } else {
	foreach e $Ls {
	    $w itemconfig $e -fill black
	    $w dtag $e Selected
	}
    }

    return
}


proc TOT {} {
    global StrucAVoir

    LoadTkAndPackages

    rename EnvoieLesObjets Envoie_wait
    rename Cubes EnvoieLesObjets

    catch {glDeleteLists 513 1}
    glFlush
    glFinish

    set StrucAVoir {}
    InitialisationViandox
    AfficheFenetreOpengl

    #Update3DMatrices
    $::pgl(wogl) postredisplay

    return
}


proc Cubes {{type "one"}} {
    global TList Rad pgl

    # 
    # type = one : une boule a chaque
    # coin du cube
    # type = multi : un cube a chaque coin
    # du cube

    if {0 && [info exists TList]} {
	glCallList $TList

	return
    }

    set cube [list \
		  0 0 1 \
		  1 0 1 \
		  0 1 1 \
		  1 1 1 \
		  0 0 0 \
		  1 0 0 \
		  0 1 0 \
		  1 1 0]
    if {$type eq "multi"} {
	set voff 15.
	set rad 2.
	set fct 5.
    } else {
	set voff 15.
	set rad 5.
    }

    set TList [glGenLists 1]
    glNewList $TList GL_COMPILE_AND_EXECUTE
    
    use_light
    set QObj [gluNewQuadric]
    gluQuadricDrawStyle $QObj GLU_FILL
    gluQuadricOrientation $QObj GLU_OUTSIDE
    gluQuadricNormals   $QObj GLU_SMOOTH

    foreach {xo yo zo} $cube {
	set xo [expr {$xo*$voff}]
	set yo [expr {$yo*$voff}]
	set zo [expr {$zo*$voff}]
	
	set r [expr {0.7*$xo}]
	set g [expr {0.7*$yo}]
	set b [expr {0.7*$zo}]
	if {$r == 0.0 && $g == 0.0 && $b == 0.0} {
	    set r 0.5 ; set g 0.5 ; set b 0.5
	}
	set col [list $r $g $b 1.0]

	# gris pour les Z = voff, bleu Z = 0.0
	set col [list 0.5 0.5 0.8 1.0] 
	if {$zo > 0} {
	    set col [list 0.5 0.5 0.5 1.0] 
	}

	if {$type eq "multi"} {
	    foreach {x y z} $cube {
		set x [expr {$fct*$x + $xo}]
		set y [expr {$fct*$y + $yo}]
		set z [expr {$fct*$z + $zo}]
		
		lappend Lx $x
		lappend Ly $y
		lappend Lz $z
		
		glPushMatrix
		glTranslatef $x $y $z
		glColor4fv $col
		gluSphere $QObj $rad 16 16
		glPopMatrix
	    }
	} else {
	    lappend Lx $xo
	    lappend Ly $yo
	    lappend Lz $zo
	    
	    glPushMatrix
	    glTranslatef $xo $yo $zo
	    glColor4fv $col
	    gluSphere $QObj $rad 16 16
	    glPopMatrix
	}
    }
    gluDeleteQuadric $QObj	
    glEndList
    
    set xm [lindex [lsort -real $Lx] 0]
    set xx [lindex [lsort -real $Lx] end]
    set ym [lindex [lsort -real $Ly] 0]
    set yx [lindex [lsort -real $Ly] end]
    set zm [lindex [lsort -real $Lz] 0]
    set zx [lindex [lsort -real $Lz] end]

    # Calcul exact de Rad
    # Rad = dist entre points extremes/2 + 
    # 2 * rayon boules
    set Rad [expr {sqrt(($xx-$xm)**2 + ($yx-$ym)**2 + ($zx-$zm)**2)/2. + 2.*$rad}]

    set pgl(xCen) [expr {($xx+$xm)/2.}]
    set pgl(yCen) [expr {($yx+$ym)/2.}]
    set pgl(zCen) [expr {($zx+$zm)/2.}]

    #set pgl(xCen) 0.0
    #set pgl(yCen) 0.0
    #set pgl(zCen) 0.0

    # backclip = z near (z neg)
    set pgl(backclip)  [expr {$pgl(zCen)-1.1*$Rad
			  }]
    # frontclip = z far
    set pgl(frontclip) [expr {$pgl(zCen)+1.1*$Rad}]

    # backclip = z near (z neg)
    #set pgl(backclip)  [expr { -1.1 * $Rad}]
    # frontclip = zfar 
    #set pgl(frontclip) [expr {  1.1 * $Rad}]

    # backclip = z near (z neg)
    set pgl(backclip)  [expr { -2.1 * $Rad}]
    # frontclip = zfar 
    set pgl(frontclip) 0.0

    # backclip = z near (z neg)
    set pgl(backclip)  [expr { -0.1 * $Rad}]
    # frontclip = zfar 
    set pgl(frontclip) [expr {  2.1 * $Rad}]

    set pgl(eyeX)      0.0
    set pgl(eyeY)      0.0
    set pgl(eyeZ)      [expr {$pgl(frontclip)-1.}]
    
    puts ""
    puts [format "max    %6.2f %6.2f %6.2f" $xx $yx $zx]
    puts [format "min    %6.2f %6.2f %6.2f" $xm $ym $zm]
    puts ""
    puts [format "centre %6.2f %6.2f %6.2f" $pgl(xCen) $pgl(yCen) $pgl(zCen)]
    puts [format "tranla %6.2f %6.2f %6.2f" $pgl(xTra) $pgl(yTra) $pgl(zTra)]
    puts [format "eye    %6.2f %6.2f %6.2f" $pgl(eyeX) $pgl(eyeY) $pgl(eyeZ)]
    puts ""
    puts "Rad       $Rad"
    puts "frontclip $pgl(frontclip)"
    puts "backclip  $pgl(backclip)"
    puts ""

    update
    
    return
}

proc SurfBall {} { 
    global doneSurfBall pgl listSurfBall Rad

    if {! $doneSurfBall} {
	set listSurfBall [glGenLists 1]
	glNewList $listSurfBall GL_COMPILE_AND_EXECUTE

	glEnable GL_BLEND
	glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
	glEnable GL_CULL_FACE
	glCullFace GL_BACK
	
	glPolygonMode GL_FRONT_AND_BACK GL_FILL
	glHint GL_PERSPECTIVE_CORRECTION_HINT $::GL_NICEST
	glEnable GL_TEXTURE_2D
	
	#set FileTex "gold.jpg"
	#set FileTex "glass.jpg"
	set FileTex [file join $::OrdEtcDir fond.png]
	#lassign [Bidon_LoadImage $FileTex] imgData imgW imgH type
	puts "\nFileTex $FileTex"
	catch {image create photo phImg -file $FileTex} Msg
	if {$Msg ne "phImg"} {
	    puts "\n==== Failed :\n$Msg"
	    set FileTex [file join $::OrdEtcDir fond.gif]
	    catch {image create photo phImg -file $FileTex} Msg
	    if {$Msg ne "phImg"} {
		puts "\n==== Failed :\n$Msg"
	    }
	}
	set imgH  [image height phImg]
	set imgW  [image width  phImg]
	set imgData [tcl3dVectorFromPhoto phImg 1]
	image delete phImg
	set latex [tcl3dVector GLuint 1]
	
	glGenTextures 1 $latex
	glBindTexture GL_TEXTURE_2D [$latex get 0]
	gluBuild2DMipmaps GL_TEXTURE_2D $::GL_ALPHA $imgW $imgH $::GL_ALPHA GL_UNSIGNED_BYTE $imgData
	$imgData delete
	
	glEnable GL_TEXTURE_GEN_S
	glEnable GL_TEXTURE_GEN_T
	
	glTexEnvi GL_TEXTURE_ENV GL_TEXTURE_ENV_MODE $::GL_REPLACE
	glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER $::GL_LINEAR
	glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER $::GL_LINEAR
	glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S $::GL_REPEAT
	glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T $::GL_REPEAT
	
	glTexGeni  GL_S GL_TEXTURE_GEN_MODE $::GL_SPHERE_MAP
	glTexGeni  GL_T GL_TEXTURE_GEN_MODE $::GL_SPHERE_MAP
	
	#glMaterialfv GL_BACK GL_AMBIENT_AND_DIFFUSE {0.0 0.0 0.0 1.0}
	
	set Lv [LesLignesDuFichier Lv.xyz]
	foreach {x y z} $Lv {
	    lappend Lx $x
	    lappend Ly $y
	    lappend Lz $z
	}
	set Ln [LesLignesDuFichier Ln.xyz]
	set Lco  {}
	for {set i 0} {$i<[llength $Lv]/3} {incr i} {
	    lappend Lco 0.5 0.5 0.5 0.95
	}
	
	set Vec [tcl3dVectorFromList GLfloat $Lv]
	set Nml [tcl3dVectorFromList GLfloat $Ln]
	set Col [tcl3dVectorFromList GLfloat $Lco]
	
	glEnableClientState GL_VERTEX_ARRAY
	glEnableClientState GL_COLOR_ARRAY
	glEnableClientState GL_NORMAL_ARRAY
	
	glVertexPointer 3 GL_FLOAT 0 $Vec
	glColorPointer  4 GL_FLOAT 0 $Col
	glNormalPointer   GL_FLOAT 0 $Nml
	
	glDrawArrays GL_TRIANGLES 0 [expr {[llength $Lv]/3}]
	
	glDisableClientState GL_VERTEX_ARRAY
	glDisableClientState GL_COLOR_ARRAY
	glDisableClientState GL_NORMAL_ARRAY
	
	glLightModeli GL_LIGHT_MODEL_COLOR_CONTROL $::GL_SINGLE_COLOR
	
	glDisable GL_TEXTURE_GEN_S
	glDisable GL_TEXTURE_GEN_T
	glDisable GL_TEXTURE_2D
	glDisable GL_BLEND
	glDisable GL_CULL_FACE
	glLightModelfv GL_LIGHT_MODEL_TWO_SIDE 1.0
	
	set doneSurfBall [expr {[llength $Lv]/3}]
	
	set xm [lindex [lsort -real $Lx] 0]
	set xx [lindex [lsort -real $Lx] end]
	set ym [lindex [lsort -real $Ly] 0]
	set yx [lindex [lsort -real $Ly] end]
	set zm [lindex [lsort -real $Lz] 0]
	set zx [lindex [lsort -real $Lz] end]
	
	# Calcul exact de Rad
	# Rad = dist entre points extremes/2 + 
	# 2 * rayon boules
	set rad 10.
	set Rad [expr {sqrt(($xx-$xm)**2 + ($yx-$ym)**2 + ($zx-$zm)**2)/2. + 2.*$rad}]
	
	set pgl(xCen) [expr {($xx+$xm)/2.}]
	set pgl(yCen) [expr {($yx+$ym)/2.}]
	set pgl(zCen) [expr {($zx+$zm)/2.}]
	
	#set pgl(xCen) 0.0
	#set pgl(yCen) 0.0
	#set pgl(zCen) 0.0
	
	# backclip = z near (z neg)
	set pgl(backclip)  [expr {$pgl(zCen)-1.1*$Rad
			      }]
	# frontclip = z far
	set pgl(frontclip) [expr {$pgl(zCen)+1.1*$Rad}]
	
	# backclip = z near (z neg)
	#set pgl(backclip)  [expr { -1.1 * $Rad}]
	# frontclip = zfar 
	#set pgl(frontclip) [expr {  1.1 * $Rad}]
	
	# backclip = z near (z neg)
	set pgl(backclip)  [expr { -2.1 * $Rad}]
	# frontclip = zfar 
	set pgl(frontclip) 0.0
	
	# backclip = z near (z neg)
	set pgl(backclip)  [expr { -0.1 * $Rad}]
	# frontclip = zfar 
	set pgl(frontclip) [expr {  2.1 * $Rad}]
	
	set pgl(eyeX)      0.0
	set pgl(eyeY)      0.0
	set pgl(eyeZ)      [expr {$pgl(frontclip)-1.}]
	
	puts ""
	puts [format "max    %6.2f %6.2f %6.2f" $xx $yx $zx]
	puts [format "min    %6.2f %6.2f %6.2f" $xm $ym $zm]
	puts ""
	puts [format "centre %6.2f %6.2f %6.2f" $pgl(xCen) $pgl(yCen) $pgl(zCen)]
	puts [format "tranla %6.2f %6.2f %6.2f" $pgl(xTra) $pgl(yTra) $pgl(zTra)]
	puts [format "eye    %6.2f %6.2f %6.2f" $pgl(eyeX) $pgl(eyeY) $pgl(eyeZ)]
	puts ""
	puts "Rad       $Rad"
	puts "frontclip $pgl(frontclip)"
	puts "backclip  $pgl(backclip)"
	puts ""
	
	glEndList
	
	update
    } else {
	glCallList $listSurfBall
	#glDrawArrays GL_TRIANGLES 0 $doneSurfBall
    }

    return
}


proc tstsurf {} {
    global StrucAVoir doneSurfBall

    set doneSurfBall 0
    LoadTkAndPackages

    rename EnvoieLesObjets Envoie_wait
    rename SurfBall EnvoieLesObjets
    #rename Cubes EnvoieLesObjets

    catch {glDeleteLists 513 1}
    glFlush
    glFinish

    set StrucAVoir {}
    Initialisation
    AfficheFenetreOpengl

    #Update3DMatrices
    $::pgl(wogl) postredisplay

    return
}


proc ViewPDB {args} {
    # viewpdb <PDB ID | UniProt accession (AlphaFold) | PDB or mmCIF file> ...
    # Structures loaded as by "Add structure" (LoadNewStructure), then
    # shown in the 3D viewer. LoadNouveauPDB, used before, failed on its
    # first line when called with one argument.
    global Defauts StrucAVoir db ListePDB

    package require http
    package require tls
    package require tcl3d
    package require sqlite3
    package require combobox

    if {! [info exists db] || $db eq ""} {
	set db [FabriqueDeTables [set Defauts(TablesDB1.1)] "" memory]
    }

    set StrucAVoir {}
    set ListePDB {}
    foreach arg $args {
	if {[file exists $arg]} {
	    set ret [LoadNewStructure $arg]
	} else {
	    set ret [LoadNewStructure [string toupper $arg] [string toupper $arg]]
	}
	lassign $ret what pdbid
	if {$what ne "StrucID"} {
	    puts "Error ! Structure >$arg< could not be loaded : $pdbid"
	    continue
	}
	foreach c [$pdbid _chains] {
	    # the same structure given twice is shown once
	    if {"PDB_${pdbid}_$c" ni $StrucAVoir} {
		lappend StrucAVoir PDB_${pdbid}_$c
		lappend ListePDB   PDB_${pdbid}_$c
	    }
	}
	puts "$arg : structure $pdbid, chains [$pdbid _chains]"
    }
    if {$StrucAVoir == {}} {
	puts "\nError ! No structure to show !\n"
	exit 1
    }

    InfosDesPDB
    AfficheDansViandox

    # no alignment : the empty main window is hidden, and closing the
    # viewer ends the program
    if {[info exists ::pgl(wogl)]} {
	wm withdraw .
	set top [winfo toplevel $::pgl(wogl)]
	bind $top <Destroy> [list apply {{w top} {
	    if {$w eq $top} {
		exit
	    }
	}} %W $top]
    }

    return
}


proc InitTestGL {} {
    global pgl

    package require Tk
    package require tcl3d
    package require combobox

    set pgl(appName) "3D Viewer"
    set pgl(width) 500
    set pgl(height) 400

    return
}

proc tgl {} {
    package require Tk
    package require tcl3d

    InitialisationViandox

    togl .tgl \
	-width 500 \
	-height 400 \
	-double true \
	-depth true \
	-createproc  Togl_createTmp \
	-reshapeproc Togl_reshapeTmp \
	-displayproc Togl_displayTmp
    grid .tgl -row 0 -column 0

    return
}

proc Togl_createTmp {w} {
    global BUFSIZE selectBuffer pgl Rad

    glClearColor 0.0 0.0 0.0 0.0
    glDepthFunc  GL_LEQUAL
    glEnable     GL_DEPTH_TEST

    puts "createTmp done" ; flush stdout ; update idletasks

    #return

    set BUFSIZE 512
    set selectBuffer [tcl3dVector GLuint $BUFSIZE]
    #set pgl(FontBase) [$w loadbitmapfont]

    #return
    
    set ambient        { 0.4 0.4 0.4 1.0 }
    set diffuse        { 0.8 0.8 0.8 1.0 }
    set specular       { 1.0 1.0 1.0 1.0 }
    # x,y,z,w if w=0 lumier a l'infini , 1 
    set position       { 0.0 50.0 100.0 0.0 }
    set lmodel_ambient { 0.2 0.2 0.2 1.0 }
    set local_view     { 0.0 }

    glLightfv GL_LIGHT0 GL_AMBIENT  $ambient
    glLightfv GL_LIGHT0 GL_DIFFUSE  $diffuse
    glLightfv GL_LIGHT0 GL_SPECULAR $specular
    glLightf  GL_LIGHT0 GL_SHININESS 85.
    glLightfv GL_LIGHT0 GL_POSITION $position
    glLightModelfv GL_LIGHT_MODEL_AMBIENT $lmodel_ambient
    glLightModelfv GL_LIGHT_MODEL_TWO_SIDE 1.0
    glLightModeli  GL_LIGHT_MODEL_COLOR_CONTROL $::GL_SEPARATE_SPECULAR_COLOR
    #glLightModelfv GL_LIGHT_MODEL_LOCAL_VIEWER $local_view

    glEnable GL_LIGHTING
    glEnable GL_LIGHT0

    glColorMaterial GL_FRONT_AND_BACK GL_AMBIENT_AND_DIFFUSE
    glEnable GL_COLOR_MATERIAL

    glMaterialfv GL_FRONT_AND_BACK GL_SPECULAR {1.0 1.0 1.0 1.0}
    glMaterialf  GL_FRONT_AND_BACK GL_SHININESS 100.

    # Fog section
    glEnable GL_FOG
    set fogColor {0.0 0.0 0.0 0.0}
    glFogfv GL_FOG_COLOR $fogColor
    glFogi GL_FOG_MODE $::GL_EXP2
    glFogf GL_FOG_DENSITY 0.02
    glFogf GL_FOG_START 0.0
    glFogf GL_FOG_END 10.0
    glFogi GL_FOG_COORD_SRC $::GL_FOG_COORD
    glHint GL_FOG_HINT  $::GL_NICEST

    glEnable GL_LINE_SMOOTH
    glHint GL_LINE_SMOOTH_HINT $::GL_NICEST
    glEnable GL_POLYGON_SMOOTH
    glHint GL_POLYGON_SMOOTH_HINT $::GL_NICEST

    glShadeModel $pgl(shadeModel)

    glEnable GL_RESCALE_NORMAL

    return
}

proc Togl_reshapeTmp {toglwin {w -1} {h -1}} {
    global pgl Rad

    # for tcl3d 0.5.0
    set h [$toglwin height]
    set w [$toglwin width]
    if { $h == 0 }  {set h 1}
    if { $w == 0 }  {set w 1}

    set pgl(width)  $w
    set pgl(height) $h
    if {$w > $h} {
	set pgl(ratioX) [expr {double($w)/$h}]
	set pgl(ratioY) 1.0
    } else {
	set pgl(ratioY) 1.0
	set pgl(ratioY) [expr {double($h)/$w}]
    }
    glViewport 0 0 $w $h

    set ratX      $pgl(ratioX)
    set ratY      $pgl(ratioY)
    set zoom      $pgl(Zoom)
    set frontclip $pgl(frontclip)
    set backclip  $pgl(backclip)

    glMatrixMode GL_PROJECTION
    glLoadIdentity
    glOrtho \
	[expr {-$ratX*$zoom*($Rad+$pgl(xTra))}]\
	[expr { $ratX*$zoom*($Rad-$pgl(xTra))}]\
	[expr {-$ratY*$zoom*($Rad+$pgl(yTra))}]\
	[expr { $ratY*$zoom*($Rad-$pgl(yTra))}]\
	[expr {$pgl(backclip) +$pgl(zTra)}]  \
	[expr {$pgl(frontclip)+$pgl(zTra)}] 
    
    glMatrixMode GL_MODELVIEW
    glLoadIdentity

    $toglwin swapbuffers
    
    puts "reshape done ..." ; flush stdout ; update idletasks

    return
}

proc Togl_displayTmp {w} {
    glViewport 0 0 [$w width] [$w height]

    glClear [expr $::GL_COLOR_BUFFER_BIT | $::GL_DEPTH_BUFFER_BIT]

    glMatrixMode GL_MODELVIEW
    glLoadIdentity

    glTranslatef 0.0 0.0 [expr {-1. * $::Rad}]

    set mat [build_rotmatrix $::cQuat]
    glMultMatrixf $mat

    glTranslatef [expr {-1.0*$::pgl(xCen)}] [expr {-1.0*$::pgl(yCen)}] [expr {-1.0*$::pgl(zCen)}]

    Cubes
    
    #EnvoieLesObjets
    #AfficheDistances
    #AfficheLabels
    
    glFlush
    $w swapbuffers

    return
}

