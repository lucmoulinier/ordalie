
#
#
# --- ordali_overview.tcl
#
#
# Routines to manage the 'overview' window
#

proc PrintOverview {w {format png}} {
    raise [winfo toplevel $w]
    raise $w
    update idletasks

    package require Img
    set img [image create photo -format window -data $w]
    update idletasks

    set outfile [DemandeEtSauveFichier $format]
    if {$outfile eq ""} {return}

    $img write $outfile -format $format

    image delete $img
    update

    return
}


proc InitCentreOverview {Id} {
    global Ovw
    # At overview creation,
    # creates the mark on the overview of the center of the 
    # center of the visible zone of the alignment,
    # and the square of the visible region

    set wc [set Ovw(O$Id,w)]
    set Wdt [$wc cget -width]
    set Hgt [$wc cget -height]

    # draw the visible zone of the alignment on the overview
    lassign [VisiblePartOfAlignment] xm ym xx yx
    # back to canvas coords
    set xcm [expr {round(1.0*$xm/[set Ovw(O$Id,Width)] *$Wdt)}]
    set ycm [expr {round(1.0*$ym/[set Ovw(O$Id,Height)]*$Hgt)}]
    set xcx [expr {round(1.0*$xx/[set Ovw(O$Id,Width)] *$Wdt)}]
    set ycx [expr {round(1.0*$yx/[set Ovw(O$Id,Height)]*$Hgt)}]
    if {[info exists Ovw(O$Id,TagRegion)]} {
	$wc delete [set Ovw(O$Id,TagRegion)]
    }
    set Ovw(O$Id,TagRegion) [$wc create rectangle \
				 $xcm $ycm $xcx $ycx \
				 -dash {3 3} \
				 -outline black \
				 -width 2 \
				 -tag algtRegion]

    # center of the region (already in canvas coords)
    set x [expr {round(($xcm + $xcx)/2.)}]
    set y [expr {round(($ycm + $ycx)/2.)}]
    # create a mark for the new centre on the overview
    if {[info exists Ovw(O$Id,TagCentre)]} {
	$wc delete [set Ovw(O$Id,TagCentre)]
    }
    set Ovw(O$Id,TagCentre) [$wc create oval \
				 [expr {$x-2}] [expr {$y-2}] [expr {$x+2}] [expr {$y+2}] \
				 -fill white \
				 -outline black \
				 -tags algtCentre]

    # keep the Show/Hide choice
    ShowHideOverviewRegion $Id

    return
}


proc ShowHideOverviewRegion {Id} {
    global Ovw
    
    set wc [set Ovw(O$Id,w)]
    if {! [info exists Ovw(O$Id,TagCentre)]} {
	return
    }

    if {$Ovw(O$Id,ShowRegion)} {
	$wc itemconfigure $Ovw(O$Id,TagCentre) -state normal
	$wc itemconfigure $Ovw(O$Id,TagRegion) -state normal
    } else {
	$wc itemconfigure $Ovw(O$Id,TagCentre) -state hidden
	$wc itemconfigure $Ovw(O$Id,TagRegion) -state hidden
    }

    return
}


proc CentreOverview {Id x y} {
    global NomTextSeq NomNomSeq WTexteRegle Ovw

    if {[InSeqlabMode]} {
	return
    }
    if {[set Ovw(O$Id,Mac)] != [MacCourant]} {
	FaireLire "Warning !\nThis overview does not correspond to the actual Instance !\nIt was drawn for another instance of the alignment."
	return
    }
    
    set wc [set Ovw(O$Id,w)]
    set Wdt [$wc cget -width]
    set Hgt [$wc cget -height]

    # re-center alignment window
    set xt [expr {round(1.0*$x/$Wdt*[set Ovw(O$Id,Width)])}]
    set yt [expr {round(1.0*$y/$Hgt*[set Ovw(O$Id,Height)])}]
    # indices of the alignment start at line 1, column 0
    set xt [expr {max(0, min($xt, [set Ovw(O$Id,Width)]-1))}]
    set yt [expr {max(1, min($yt, [set Ovw(O$Id,Height)]))}]
    $NomTextSeq  see $yt.$xt
    $NomNomSeq   see $yt.1
    $WTexteRegle see 1.$xt
    update idletasks

    # draw the visible zone of the alignment and its centre
    InitCentreOverview $Id
    
    return
}


proc CheckImageOverview {img} {
    set wdt [$img cget -width]
    set hgt [$img cget -height]

    set Ld [$img data]
    set See1 0 ; set See2 0 
    set skip 0 ; set dupl 0
    set Lnew {}
    set iRow 0
    foreach rowOri $Ld {
	set row [lunique [split $rowOri]]
	if {[llength $row] == 1 && $row eq "#ffffff"} {
	    # this is a blank line
	    if {! $See1} {
		set See1 1
	    } elseif {! $See2} {
		set See2 1
	    } else {
		set skip 1
	    }
	} else {
	    # not a blank line
	    if {$See1 && ! $See2} {
		set dupl 1
	    }
	}
	if {$dupl} {
	    lappend Lnew [lindex $Ld $iRow-1]
	    set dupl 0
	}
	if {! $skip} {
	    lappend Lnew $rowOri
	} else {
	    set skip 0
	}

	incr iRow
    }
    image delete $img
    image create photo $img
    $img put $Lnew

    return
}


proc CalculeOverview {Id} {
    global NomTextSeq Ovw
    
    set wc [set Ovw(O$Id,w)]
    set Twdt [LongueurDeLAlignement]
    set Thgt [llength [$NomTextSeq output all]]
    #set Thgt [llength $LSOrdali]
    set Ovw(O$Id,Width)  $Twdt
    set Ovw(O$Id,Height) $Thgt
    # order of the sequences of the overview (annotations)
    set Ovw(O$Id,LNoms) $::LNOrdali
    
    set Ovw(O$Id,WidthOri)  600.
    set Ovw(O$Id,HeightOri) 400.

    set fx [expr {1.* $Ovw(O$Id,WidthOri)/$Twdt}]
    set fy [expr {1.* $Ovw(O$Id,HeightOri)/$Thgt}]
    if {$fx >= 1.} {
	set Ovw(O$Id,WidthOri) $Twdt
	set fx 1.0
    }
    if {$fy >= 1.} {
	set Ovw(O$Id,HeightOri) $Thgt
	set fy 1.0
    }
    set Ovw(O$Id,ScaOriX) [expr {int($fx * 100.)}]
    set Ovw(O$Id,ScaOriY) [expr {int($fy * 100.)}]

    $wc configure -height $Ovw(O$Id,HeightOri) -width $Ovw(O$Id,WidthOri)

    # create original image
    set f " #888"
    set b " #fff"
    # blank line
    set linew [string trim [string repeat $b $Twdt]]
    # get the whole alignment
    set s [join [$NomTextSeq output all] \n]
    #set tstm [string map [list . "" " " "" * "" ~ "" "?" "" A "" B "" C "" D "" E "" F "" G "" H "" I "" J "" K "" L "" M "" N "" O "" P "" Q "" R "" S "" T "" U "" V "" W "" X "" Y "" Z ""] $s]
    #puts "tstm >[string map {"\n" ""} $tstm]<\n"
    set smap [string map [list . $b " " $b * $b ~ $b "?" $b A $f B $f C $f D $f E $f F $f G $f H $f I $f J $f K $f L $f M $f N $f O $f P $f Q $f R $f S $f T $f U $f V $f W $f X $f Y $f Z $f] $s]
    set Ls [split $smap "\n"]
    set Data {}
    foreach l $Ls {
	set l [string trim $l]
	if {$l eq ""} {
	    lappend Data $linew
	} else {
	    lappend Data $l
	}
    }
    set img [image create photo]
    $img put $Data
    
    # subsample image if necessary
    LRI::imgtransform $img -scalex [expr {int($fx  * 100)}] -scaley [expr {int($fy * 100.)}]
    CheckImageOverview $img
    if {! [info exists Ovw(O$Id,ScaleTot)] || $Ovw(O$Id,ScaleTot) eq ""} {
	set Ovw(O$Id,ScaleTot) {}
    } else {
	set St [expr int(100*[join [set Ovw(O$Id,ScaleTot)] *])]
	LRI::imgtransform $img -scale $St
	# the canvas keeps the size given by the zoom (+/- buttons)
	set Sc [expr [join [set Ovw(O$Id,ScaleTot)] *]]
	$wc configure \
	    -width  [expr {int($Ovw(O$Id,WidthOri)*$Sc)}] \
	    -height [expr {int($Ovw(O$Id,HeightOri)*$Sc)}]
    }
    update
    
    set TOri [$wc create image 0 0 \
		  -image $img \
		  -anchor nw \
		  -tags algt]
    set Ovw(O$Id,Images) $img
    set Ovw(O$Id,FOri) $TOri
    set Ovw(O$Id,FeatAff) {}

    InitCentreOverview $Id
    bind $wc <Button-1> [list CentreOverview $Id %x %y]

    return
}


proc DessineFeatureSurOverview {Id w ft {Show 1} {DeBtn 0}} {
    global TabSF Ovw LNOrdali

    if {$DeBtn && ( [set Ovw(O$Id,Feat)] ne "automatic" ) } {
	return
    }
    
    set wc [set Ovw(O$Id,w)]
    set Ovft [set Ovw(O$Id,Feat)]

    if {$Ovft ne "automatic" || ( $ft eq "None" && $Ovft eq "automatic") } {
	set FOri [set Ovw(O$Id,FOri)]
	$wc raise $FOri
	MonteAnnotationsOverview $Id
	update
	if {$ft eq "None"} {
	    return
	}
    }
    if {! $DeBtn && $ft eq "automatic"} {
	return
    }

    # Feature deja calculee, monte ou descend
    if {[info exists Ovw(O$Id,$ft)]} {
	if {! $Show} {
	    $wc lower [set Ovw(O$Id,$ft)]
	    set lf [set Ovw(O$Id,FeatAff)]
	    set i [lsearch $lf $ft]
	    set lf [lreplace $lf $i $i]
	    set Ovw(O$Id,FeatAff) [linsert $lf 0 $ft]
	} else {
	    $wc raise [set Ovw(O$Id,$ft)]
	}
	MonteAnnotationsOverview $Id
	update idletasks

	return
    }

    # the image is computed from the data of the current instance :
    # never for an overview of another instance
    if {$Ovw(O$Id,Mac) != [MacCourant]} {
	return
    }

    # Calcul image de la feature
    set Wdt [set Ovw(O$Id,Width)]
    set Hgt [set Ovw(O$Id,Height)]
    set img [image create photo]
    $img blank

    # one 'put' per pixel is slow (~100 us each, 37000 for a
    # Cons- feature) : adjacent features of the same color are
    # merged into runs, and consecutive rows with the same runs
    # are drawn as one rectangle. Puts keep the features order.
    set LNoms $LNOrdali
    set y -1
    set Lprev {}
    set y0 0
    foreach n $LNoms {
	incr y
	set Lruns {}
	if {[string trim $n] ne "" && [info exists TabSF($n,$ft)]} {
	    set rd ""
	    foreach e [set TabSF($n,${ft})] {
		DecortiqueUneFeature $e d f col score note
		if {$col eq ""} {continue}
		if {$rd ne "" && $col eq $rc && $d == $rf + 1} {
		    set rf $f
		    continue
		}
		if {$rd ne ""} {
		    lappend Lruns $rc $rd $rf
		}
		lassign [list $col $d $f] rc rd rf
	    }
	    if {$rd ne ""} {
		lappend Lruns $rc $rd $rf
	    }
	}
	if {$Lruns ne $Lprev} {
	    # '-to' excludes x2 : the last column is f
	    foreach {c d f} $Lprev {
		$img put $c -to $d $y0 [expr {$f+1}] $y
	    }
	    set Lprev $Lruns
	    set y0 $y
	}
    }
    incr y
    foreach {c d f} $Lprev {
	$img put $c -to $d $y0 [expr {$f+1}] $y
    }
    LRI::imgtransform $img -scalex $Ovw(O$Id,ScaOriX) -scaley $Ovw(O$Id,ScaOriY)
    if {[set Ovw(O$Id,ScaleTot)] != {}} {
	set St [expr int(100*[join [set Ovw(O$Id,ScaleTot)] *])]
	LRI::imgtransform $img -scale $St
    }

    set tag [$wc create image 0 0 \
		 -image $img \
		 -anchor nw \
		 -tags [list FX_${ft} ImgFeature]]
    lappend Ovw(O$Id,Images) $img
    set Ovw(O$Id,$ft) $tag
    if {$ft ne "automatic"} {
	set Ovw(O$Id,FeatAff) {}
    }
    lappend Ovw(O$Id,FeatAff) $ft

    MonteAnnotationsOverview $Id
    update idletasks

    return
}


proc MonteAnnotationsOverview {Id} {
    # annotations above the features, region and centre on top
    global Ovw

    set wc $Ovw(O$Id,w)
    $wc raise AnnoOvw
    $wc raise $Ovw(O$Id,TagCentre)
    $wc raise $Ovw(O$Id,TagRegion)

    return
}


proc DessineAnnotationsSurOverview {Id} {
    # annotations of the instance of the overview, as rectangles
    # (one per sequence segment) with their text in a balloon
    global Ovw db

    set wc $Ovw(O$Id,w)
    $wc delete AnnoOvw
    if {! [info exists Ovw(O$Id,ShowAnno)] || ! $Ovw(O$Id,ShowAnno)} {
	return
    }

    # same scale as the region (InitCentreOverview)
    set sx [expr {1.0*[$wc cget -width] /$Ovw(O$Id,Width)}]
    set sy [expr {1.0*[$wc cget -height]/$Ovw(O$Id,Height)}]
    set pkmac $Ovw(O$Id,Mac)
    $db eval {select pk_annotation, annotation, color, zone from annotation where pk_snap = $pkmac order by pk_annotation} {
	set tag "AnnoOvw_$pk_annotation"
	foreach e $zone {
	    if {[regexp {^[0-9]+\.[0-9]+$} [lindex $zone 0]]} {
		# zone of older versions : "y.x1 y.x2" ...
		break
	    }
	    lassign $e nom x1 x2
	    set y [lsearch -exact $Ovw(O$Id,LNoms) $nom]
	    if {$y == -1} {
		continue
	    }
	    # at least 2 pixels : visible when the overview is small
	    set cx1 [expr {$x1*$sx}]
	    set cx2 [expr {max(($x2+1)*$sx, $cx1+2)}]
	    set cy1 [expr {$y*$sy}]
	    set cy2 [expr {max(($y+1)*$sy, $cy1+2)}]
	    $wc create rectangle $cx1 $cy1 $cx2 $cy2 \
		-fill $color -outline black -width 1 \
		-tags [list AnnoOvw $tag]
	}
	if {$annotation ne ""} {
	    $wc bind $tag <Enter> [list BulleAnnotationOverview $wc $annotation %x %y]
	    $wc bind $tag <Leave> [list after 1 $wc delete cballoon]
	}
    }
    MonteAnnotationsOverview $Id

    return
}


proc BulleAnnotationOverview {w text x y} {
    # balloon beside the pointer, and not pickable : under the
    # pointer, it would make the pointer leave the rectangle
    # (Leave deletes the balloon, Enter shows it again ... endlessly)
    ShowBalloonOnItem $w $text [expr {$x+12}] [expr {$y-6}]
    $w itemconfigure cballoon -state disabled

    return
}


proc RafraichitAnnotationsOverviews {} {
    # annotations of the current instance changed (annotation
    # mode left with Return) : redraw them on its overviews
    global Ovw

    if {! [info exists Ovw(Liste)]} {
	return
    }
    foreach Id $Ovw(Liste) {
	if {$Ovw(O$Id,Mac) == [MacCourant]} {
	    DessineAnnotationsSurOverview $Id
	}
    }

    return
}


proc ChangeEchelleOverview {Id quoi} {
    global Ovw

    set wc [set Ovw(O$Id,w)]
    if {$quoi eq "moins"} {
	# inverse of "plus" : + then - gives the size back
	set Scale [expr {1/1.2}]
    } else {
	set Scale 1.2
    }

    set Ch [expr {int([$wc cget -height]*$Scale)}]
    set Cw [expr {int([$wc cget -width] *$Scale)}]
    # taille minimale et maximale de la fenetre
    if {$Cw <= 300 || $Cw > 4000} {return}

    lappend Ovw(O$Id,ScaleTot) $Scale
    set Ovw(O$Id,Scale) $Scale

    $wc configure -width $Cw -height $Ch

    # Scale toute les images
    foreach i [$wc find all] {
	if {[$wc type $i] eq "image"} {
	    set img [$wc itemcget $i -image]
	    LRI::imgtransform $img -scale [expr {int($Scale*100)}]
	    $wc itemconfigure $i -image $img
	} else {
	    $wc delete $i
	}
    }
    
    # overview of another instance : its images are only scaled, the
    # visible region is the one of the current instance
    if {$Ovw(O$Id,Mac) == [MacCourant]} {
	DessineFeatureSurOverview $Id $wc [set Ovw(O$Id,Feat)]

	# region and centre have been deleted : draw them again
	InitCentreOverview $Id
    }
    # annotations too
    DessineAnnotationsSurOverview $Id
    
    return
}


proc DetruitOverview {{Id ""}} {
    global Ovw ListeTypesDeFeatures

    if {$Id eq ""} {
	set Lids [set Ovw(Liste)]
    } else {
	set Lids $Id
    }

    foreach id $Lids {
	set i [lsearch [set Ovw(Liste)] $id]
	set Ovw(Liste) [lreplace [set Ovw(Liste)] $i $i]
	
	if {[info exists Ovw(O$id,Images)]} {
	    foreach img $Ovw(O$id,Images) {
		catch {image delete $img}
	    }
	}
	array unset Ovw "O$id,*"
	if {[winfo exists ".overview$id"]} {
	    wm protocol ".overview$id" WM_DELETE_WINDOW ""
	    destroy ".overview$id"
	}
    }

    if {$Ovw(Liste) == {}} {
	unset -nocomplain Ovw
	
	trace remove variable ListeTypesDeFeatures write MetAJourFeaturesOverview
	trace remove execution MetAJourNomsEtSeqs leave MetAJourOverview
    }

    update idletasks

    return
}


proc MetAJourOverviewNo {i} {
    global Ovw

    if {[InSeqlabMode]} {
	return
    }

    if {[set Ovw(O$i,Mac)] != [MacCourant]} {
	return
    }

    # start again from scratch : delete drawings and images
    set lf [lreverse [set Ovw(O$i,FeatAff)]]
    [set Ovw(O$i,w)] delete all
    foreach img $Ovw(O$i,Images) {
	catch {image delete $img}
    }
    set Ovw(O$i,Images) {}
    foreach j $lf {
	unset -nocomplain Ovw(O$i,$j)
    }
    unset -nocomplain Ovw(O$i,TagCentre) Ovw(O$i,TagRegion)

    CalculeOverview $i
    set Ovw(O$i,FeatAff) {}
    foreach j $lf {
	DessineFeatureSurOverview $i "" $j 1
    }
    DessineAnnotationsSurOverview $i
    
    return
}


proc MetAJourOverview {n1 n2 n3 op} {
    global Ovw LNDG SDG

    if {! [info exists Ovw]} {
	return
    }

    if {$LNDG eq ""} {
	return
    }

    # Consider overviews of the current Mac
    set macCurrent [MacCourant]
    set Lids {}
    foreach id [set Ovw(Liste)] {
	if {[set Ovw(O$id,Mac)] == $macCurrent} {
	    lappend Lids $id
	}
	}

    FaireAttendre "Please Wait ...\nUpdating overviews ..."
    foreach id $Lids {
	# redraw only if groups have changed
	set diff 0
	if {! [lequal $LNDG $Ovw(O$id,LGroupes)]} {
	    set diff 1
	} else {
	    unset -nocomplain Og
	    array set Og [set Ovw(O$id,LSeqGroupes)]
	    foreach g $LNDG {
		if {! [info exists Og($g)] || ! [info exists SDG($g)] || [lor $SDG($g) $Og($g)] != {}} {
		    set diff 1
		    break
		}
	    }
	}
	if {$diff == 0} {
	    continue
	}

	MetAJourOverviewNo $id

	set Ovw(O$id,LGroupes) $LNDG
	set Ovw(O$id,LSeqGroupes) [array get SDG]
    }

    FaireLaSuite

    return
}


proc MetAJourDessinOverview {Id w {f None} {etat 1}} {
    global Ovw
    
    # No overview windows
    set Ltoplevels [winfo children .]
    if {[lsearch -regexp $Ltoplevels {\.overview}] == -1} {
	return
    }
    if {[InSeqlabMode]} {
	return
    }
    if {! [info exists Ovw]} {
	return
    }

    if {$Id == -1} {
	set DeBtn 1
	set Li [set Ovw(Liste)]
    } else {
	set DeBtn 0
	set Li $Id
	set f [set Ovw(O$Id,Feat)]
	# features of an overview of another instance can not be
	# computed : the list goes back to the feature displayed
	if {$Ovw(O$Id,Mac) != [MacCourant]} {
	    set Ovw(O$Id,Feat) $Ovw(O$Id,FeatPrec)
	    set nm [lindex [NomDeMac $Ovw(O$Id,Mac)] 0]
	    FaireLire "Warning !\nThis overview does not correspond to the actual Instance !\nIt was drawn for another instance of the alignment ($nm).\nDisplay this instance to show its features."
	    return
	}
	set Ovw(O$Id,FeatPrec) $f
    }

    # Determine Overview ACTIVE
    set ni {}
    foreach i $Li {
	if {[set Ovw(O$i,Mac)] == [MacCourant]} {
	    lappend ni $i
	}
    }
    if {$ni == {}} {
	return
    } else {
	set Li $ni
    }

    if {$f eq "automatic"} {
	# one overview at a time
	foreach i $Li {
	    DessineFeatureSurOverview $i "" "None" $etat $DeBtn
	}
	set Lf [LesBoutonsEnfonces]
    } else {
	set Lf $f
    }

    foreach Id $Li {
	foreach f $Lf {
	    DessineFeatureSurOverview $Id "" $f $etat $DeBtn
	}
    }

    return
}


proc MetAJourFeaturesOverview {{Id ""} {n2 ""} {op ""}} {
    global Ovw ListeTypesDeFeatures

    # if called from a 'trace' statement
    if {$Id eq "ListeTypesDeFeatures"} {
	set Id ""
    }
    
    set LFeat $ListeTypesDeFeatures
    set LFeat [linsert $LFeat 0 "None" "automatic"]
    set ic [lsearch $LFeat "Clear"]
    if {$ic != -1} {
	set LFeat [lreplace $LFeat $ic $ic]
    }
    set CmbWdt [PlusLongEltDe $LFeat]

    if {$Id ne ""} {
	set Lids $Id
    } elseif {[info exists Ovw(Liste)]} {
	set Lids {}
	foreach Id $Ovw(Liste) {
	    if {$Ovw(O$Id,Mac) == [MacCourant]} {
		lappend Lids $Id
	    }
	}
    } else {
	set Lids {}
    }
    foreach Id $Lids {
	set Ovw(O$Id,FeatWidth) $CmbWdt
	set Ovw(O$Id,LFeat) $LFeat
	# update the combobox of an existing overview window
	set cb ".overview$Id.btn.combo"
	if {[winfo exists $cb]} {
	    $cb configure -values $LFeat -width $CmbWdt
	}
    }

    return
}


proc VisiblePartOfAlignment {} {
    lassign [$::NomTextSeq xview] fxm fxx
    lassign [$::NomTextSeq yview] fym fyx
    set Lgt [LongueurDeLAlignement]
    set xm [expr {$Lgt*$fxm}]
    set xx [expr {$Lgt*$fxx}]
    set Nseq [llength $::LNOrdali]
    set ym [expr {$Nseq*$fym}]
    set yx [expr {$Nseq*$fyx}]

    return [list $xm $ym $xx $yx]
}

proc AfficheFenetreOverview {Id} {
    global Ovw

    set w ".overview$Id"
    toplevel $w
    set inst ""
    if {[info exists Ovw(O$Id,Mac)]} {set pkm $Ovw(O$Id,Mac)}
    if {[info exists pkm] && ! [catch {$::db onecolumn {select name from snapshot where pk_snap = :pkm}} nm] && $nm ne ""} {
	set inst " - Instance $nm"
    }
    wm title $w "Overview No $Id$inst"
    wm iconname $w "Overview $Id"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    wm resizable $w 0 0

    grid columnconfig $w 0 -weight 1
    grid rowconfig    $w 0 -weight 1
    
    set Ovw(O$Id,w) "$w.c"
    set wc "$w.c"
    canvas $w.c \
	-height 400 \
	-width  600 \
	-background white
    frame $w.btn
    grid $w.c   -row 0 -column 0 -sticky news
    grid $w.btn -row 1 -column 0 -sticky ew -pady 10

    grid columnconfig $w.btn all -weight 0
    ttk::combobox $w.btn.combo \
	-background white \
	-state readonly \
	-height 0 \
	-textvariable Ovw(O$Id,Feat) \
	-values $Ovw(O$Id,LFeat) \
	-width $Ovw(O$Id,FeatWidth)
    $w.btn.combo index 0
    bind $w.btn.combo <<ComboboxSelected>> "MetAJourDessinOverview $Id %W"
    frame $w.btn.fpm
    button $w.btn.fpm.btm \
	-text "-" \
	-background cyan \
	-command [list ChangeEchelleOverview $Id "moins"]
    button $w.btn.fpm.btp \
	-text "+" \
	-background cyan \
	-command [list ChangeEchelleOverview $Id "plus"]
    grid $w.btn.fpm.btm -row 0 -column 0
    grid $w.btn.fpm.btp -row 0 -column 1

    checkbutton $w.btn.cksh \
	-text "Show/Hide region" \
	-relief flat \
	-background white \
	-onvalue 1 \
	-offvalue 0 \
	-variable Ovw(O$Id,ShowRegion) \
	-command [list ShowHideOverviewRegion $Id]

    checkbutton $w.btn.ckann \
	-text "Annotations" \
	-relief flat \
	-background white \
	-onvalue 1 \
	-offvalue 0 \
	-variable Ovw(O$Id,ShowAnno) \
	-command [list DessineAnnotationsSurOverview $Id]

    button $w.btn.btprt \
	-text "Print" \
	-background yellow \
	-command "PrintOverview $wc png"

    button $w.btn.btclose \
	-text "Close" \
	-background green1 \
	-command [list DetruitOverview $Id]
    grid $w.btn.combo   -row 0 -column 0
    grid $w.btn.fpm     -row 0 -column 1
    grid $w.btn.cksh -row 0 -column 2
    grid $w.btn.ckann   -row 0 -column 3
    grid $w.btn.btprt   -row 0 -column 4
    grid $w.btn.btclose -row 0 -column 5
    grid columnconfig $w.btn all -weight 1

    return $w
}


proc AfficheOverview {{Restore {}}} {
    # Restore : settings of an overview saved in an ORD file
    # (RestaureFenetresORD) : Feat FeatAff ShowRegion ShowAnno ScaleTot
    global Ovw FrmBtnFea LNDG SDG ListeTypesDeFeatures

    # alignement vide
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {[InSeqlabMode]} {
	FaireLire "Not available in Editor mode !"
	return
    }
    
    FaireAttendre "Please wait ...\nDrawing alignment overview ..."

    # configure features
    if {! [info exists Ovw(Liste)]} {
	set Ovw(Liste) {}
	set Id 1
    } else {
	set Id [expr {[lindex [set Ovw(Liste)] end] + 1}]
    }
    lappend Ovw(Liste) $Id
    
    # define new overview
    set Ovw(O$Id,Feat) "automatic"
    set Ovw(O$Id,ShowRegion) 1
    # annotations shown if they are shown on the alignment
    # ("Annotations" button of the instance bar)
    set Ovw(O$Id,ShowAnno) 0
    if {[info exists ::WOrdali(BoutAnno)] && [winfo exists $::WOrdali(BoutAnno)]} {
	set Ovw(O$Id,ShowAnno) [EtatBouton $::WOrdali(BoutAnno)]
    }
    set Ovw(O$Id,Mac) [MacCourant]
    set Ovw(O$Id,LGroupes) $LNDG
    set Ovw(O$Id,LSeqGroupes) [array get SDG]
    foreach k {Feat ShowRegion ShowAnno ScaleTot} {
	if {[dict exists $Restore $k]} {
	    set Ovw(O$Id,$k) [dict get $Restore $k]
	}
    }
    if {$Ovw(O$Id,Feat) ni [concat None automatic $ListeTypesDeFeatures]} {
	set Ovw(O$Id,Feat) "automatic"
    }
    set Ovw(O$Id,FeatPrec) $Ovw(O$Id,Feat)

    MetAJourFeaturesOverview $Id

    # Create overview window
    set w [AfficheFenetreOverview $Id]

    CalculeOverview $Id
    DessineAnnotationsSurOverview $Id

    # Display the feautres currently displayed on the 
    # alignment (if any) on the overview, or the ones it showed
    # when it was saved
    if {[dict exists $Restore FeatAff]} {
	foreach f [dict get $Restore FeatAff] {
	    if {$f in $ListeTypesDeFeatures} {
		DessineFeatureSurOverview $Id "" $f 1
	    }
	}
	if {! $Ovw(O$Id,ShowRegion)} {
	    ShowHideOverviewRegion $Id
	}
    } elseif {[info exists FrmBtnFea] && [QuelMode] eq "feature"} {
	foreach c [winfo children $FrmBtnFea] {
	    if {[EtatDuBouton $c]} {
		set f [lindex [$c cget -command] 1]
		DessineFeatureSurOverview $Id "" $f 1
	    }
	}
    }

    FaireLaSuite .wover

    # traces are shared by all overviews : add them once
    if {[lsearch -exact [trace info execution MetAJourNomsEtSeqs] {leave MetAJourOverview}] == -1} {
	trace add execution MetAJourNomsEtSeqs leave MetAJourOverview
    }
    if {[lsearch -exact [trace info variable ListeTypesDeFeatures] {write MetAJourFeaturesOverview}] == -1} {
	trace add variable ListeTypesDeFeatures write MetAJourFeaturesOverview
    }

    # position new window
    set h 1
    foreach top [winfo children .] {
	if {[string first ".overview" $top] != 0} {
	    continue
	}
	if {$top eq $w} {
	    continue
	}
	incr h [winfo height $top]
    }
    wm geometry $w +0+$h

    update idletasks

    return $Id
}




