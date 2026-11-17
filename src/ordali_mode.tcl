


#
#
#
# --- ordali_mode.tcl
#


proc ChangeMode {{mode ""}} {
    global NomFenetreOrdali NomTextSeq NomNomSeq ShowFt ListePDB CurrentMode

    if {! [ModeI]} {
	return
    }
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {$mode eq "superpose"} {
	# 0 structure : rien a faire ; 1 seule : on l'affiche,
	# sans changer de mode (pas de superposition possible)
	if {! [info exists ListePDB] || [llength $ListePDB] == 0} {
	    FaireLire "No 3D structures in this alignment !"
	    return
	}
	if {[llength $ListePDB] == 1} {
	    VisualiseStructure
	    return
	}
    }
    
    # CurrentMode is the mode to go back to. Keep the old value
    # if the change is refused or useless, otherwise the
    # 'Return' buttons of the current mode are broken.
    set OldCurrentMode ""
    if {[info exists CurrentMode]} {
	set OldCurrentMode $CurrentMode
    }
    if {[QuelMode] eq $mode} {
	return
    }
    # no argument : reload the current mode, keeping the mode to go
    # back to (setting it to the current mode broke the Return button)
    set Recharge [expr {$mode eq ""}]
    set Prev [QuelMode]
    if {$Recharge} {
	set mode $Prev
    } else {
	set CurrentMode $Prev
    }
    
    if {$mode eq "seqlab"} {
	#bind $NomTextSeq <Any-Motion> ""
    }
    update idletasks

    switch $mode {
	"ordali" {
	    QuelMode "ordali"
	    DetruitBoutonsOrdali
	    AfficheModeOrdali
	}
	"seqlab" {
	    bindtags $NomNomSeq {}
	    bindtags $NomTextSeq {}
	    bind $NomNomSeq ""
	    bind $NomTextSeq ""
	    BindMenuItems ubind
	    update idletasks
	    
	    GetActiveFeaturesInSeqlab
	    InSeqlabMode 1
	    QuelMode "seqlab"
	    DetruitBoutonsOrdali
	    AfficheModeSeqlab
	}
	"feature" {
	    DetruitBoutonsOrdali
	    QuelMode "feature"
	    AfficheModeFeatures
	}
	"annotation" {
	    # from the main view only : the other tools must be left
	    # with their own Return button
	    if {$CurrentMode ni {"ordali" "feature"}} {
		set pmod [string totitle $CurrentMode]
		FaireLire "Please leave $pmod mode first !"
		set CurrentMode $OldCurrentMode
		return
	    }
	    QuelMode "annotation"
	    DetruitBoutonsOrdali
	    AfficheModeAnnotation
	}
	"arbres" {
	    if {$CurrentMode eq "seqlab"} {
		FaireLire "Please leave the Editor before entering Tree mode !"
		set CurrentMode $OldCurrentMode
		return
	    }
	    QuelMode "arbres"
	    DetruitBoutonsOrdali
	    AfficheModeArbres
	}
	"cluster" {
	    if {$CurrentMode eq "seqlab"} {
		FaireLire "Not available in Editor mode !"
		set CurrentMode $OldCurrentMode
		return
	    }
	    QuelMode "cluster"
	    DetruitBoutonsOrdali
	    AfficheModeClusters
	}
	"conservation" {
	    if {$CurrentMode eq "seqlab"} {
		FaireLire "Not available in Editor mode !"
		set CurrentMode $OldCurrentMode
		return
	    }
	    QuelMode "conservation"
	    DetruitBoutonsOrdali
	    AfficheModeConservation
	}
	"donnepci" {
	    if {$CurrentMode ni {"ordali" "feature"}} {
		set pmod [string totitle $CurrentMode]
		FaireLire "Please leave $pmod mode first !"
		set CurrentMode $OldCurrentMode
		return
	    }
	    QuelMode "donnepci"
	    DetruitBoutonsOrdali
	    AfficheModePCI
	    #ChangeMode $CurrentMode
	}
	"search" {
	    if {$CurrentMode ni {"seqlab" "ordali" "feature"}} {
		set pmod [string totitle $CurrentMode]
		FaireLire "Please leave $pmod mode first !"
		set CurrentMode $OldCurrentMode
		return
	    }
	    QuelMode "search"
	    DetruitBoutonsOrdali
	    BindMenuItems ubind
	    AfficheModeCherche $CurrentMode
	}
	"superpose" {
	    QuelMode "superpose"
	    DetruitBoutonsOrdali
	    AfficheModeSuperposition
	}
	"feateditor" {
	    QuelMode "feateditor"
	    DetruitBoutonsOrdali
	    AfficheModeFeateditor
	}
    }

    if {! $Recharge} {
	MetAJourPileModes $Prev $mode
    }

    MesCouleurs $NomFenetreOrdali

    return
}


proc MetAJourPileModes {prev mode} {
    # PileModes : stack of the modes to go back to. A single
    # CurrentMode looped between two tools entered one from the
    # other (Superposition -> Conservation : Return went back to
    # Superposition, whose Return went back to Conservation...).
    # Going to a mode already in the stack is a return to it.
    global PileModes CurrentMode

    if {! [info exists PileModes]} {
	set PileModes {}
    }
    if {$mode in {"ordali" "feature"}} {
	# main view : nothing to go back to
	set PileModes {}
    } elseif {[set i [lsearch -exact $PileModes $mode]] >= 0} {
	set PileModes [lrange $PileModes 0 $i-1]
    } elseif {$prev ne "autre"} {
	# "autre" : temporary mode of ChoixNbCluster
	lappend PileModes $prev
    }
    if {$PileModes eq {}} {
	set CurrentMode $mode
    } else {
	set CurrentMode [lindex $PileModes end]
    }

    return
}


proc DepileMode {} {
    # back to the previous mode without going through ChangeMode
    # (FinCherche when the search was started from the Editor)
    global PileModes CurrentMode

    if {[info exists PileModes]} {
	set PileModes [lrange $PileModes 0 end-1]
    }
    if {[info exists PileModes] && $PileModes ne {}} {
	set CurrentMode [lindex $PileModes end]
    } else {
	set CurrentMode "ordali"
    }

    return
}


proc AfficheModeOrdali {} {
    AfficheBoutonsOrdali
    BindModeNormal

    return
}


proc AfficheModeSeqlab {} {
    global NomTextSeq Toggle NomNOmSeq
    
    # hides them and sets AffSS to 0 (setting AffSS to 0 first made
    # CacheStrSecDansAlignement do nothing)
    CacheStrSecDansAlignement
    if {$Toggle(Scores)} {
	set Toggle(Scores) 0
	ToggleScores
    }
    
    EmulationSeqLab
    BindModeSeqlab
    AfficheBoutonsSeqLab
    
    return
}


proc AfficheModeArbres {} {
    AfficheBoutonsArbres

    return
}


proc AfficheModeConservation {} {
    AfficheBoutonsConservation

    return
}


proc AfficheModeClusters {} {

    InitSeqsOut 0
    AfficheBoutonsClusters
    
    return
}


proc AfficheModePCI {} {
    # BindModeNormal first : AfficheBoutonsPCI adds the residue
    # range selection bindings (BindModeSelection)
    BindModeNormal
    AfficheBoutonsPCI

    return
}


proc AfficheModeCherche {{prevMode ""}} {
    AfficheBoutonsCherche $prevMode
	    BindMenuItems

    return
}


proc AfficheModeSuperposition {} {
    global ListePDB

    if {[TypeAli] eq "pasdali"} {return}

    # pas , ou 1 seul , pdb
    if {! [info exists ListePDB] || $ListePDB == {}} {
	FaireLire "No 3D structures in this alignment !"
	return
    }

    # BindModeNormal first : AfficheBoutonsSuperposition adds the
    # residue range selection bindings (BindModeSelection)
    BindModeNormal
    if {[llength $ListePDB] == 1} {
	set ::StrucAVoir $ListePDB
	VisualiseStructure
    } else {
	AfficheBoutonsSuperposition
    }

    return
}


proc AfficheModeFeateditor {} {
    AfficheBoutonsFeateditor

    return
}


proc AfficheModeFeatures {} {
    global LFeatCourantes
    
    if {! [info exists LFeatCourantes]} {
	set LFeatCourantes [list]
    }
    
    AfficheBoutonsFeatures
    
    return
}


proc AfficheModeAnnotation {} {
    # all the annotations of the snapshot are shown while editing
    EffaceAnnotations
    AfficheBoutonsAnnotation

    return
}


proc AfficheBoutonsOrdali {} {
    global boutordali boutreport FrmBouton menustatus

    if {! [ModeI]} {return}

    set wb "$FrmBouton.flab"
    frame $wb -relief sunken -bd 2
    grid $wb -row 0 -column 1 -sticky news -pady 5

    set boutordali $wb.label

    label $wb.label \
	-textvariable menustatus \
	-relief sunken \
	-bd 2 \
	-anchor w \
	-bg white \
	-justify left \
	-font "Helvetica 12"
    grid $wb.label -row 0 -column 0 -sticky ew -padx 2 -pady 1
    grid columnconfig $wb all -weight 1 -minsize 0
    
    set menustatus "Hummm ..... \nEverything seems OK ....\nLet's go !"

    MesCouleurs $FrmBouton

    return
}


proc AfficheBoutonsAnnotation {} {
    global FrmBouton Anno NomTextSeq WOrdali
    
    unset -nocomplain Anno
    LoadSnapAnnotations
    set Anno(ShowColor) "All"
    set Anno(Color) ""
    
    # gui	
    grid columnconfig $FrmBouton 1 -weight 1
    set wp "${FrmBouton}.fanno"
    frame $wp \
	-relief sunken  \
	-bd 2
    grid $wp -row 0 -column 1 -sticky ew
    
    frame $wp.fcols
    label $wp.fcols.label \
	-text "Show annotations colored in : " \
	-justify left
    set wdt [expr {max(10,[PlusLongEltDe $Anno(LColorsUsed)])}]
    set ::Anno(WComboCol) $wp.fcols.cbbcol
    ttk::combobox $wp.fcols.cbbcol \
	-state readonly \
	-values $Anno(LColorsUsed) \
	-width $wdt \
	-textvariable Anno(ShowColor)
    bind $wp.fcols.cbbcol <<ComboboxSelected>> [list ShowAnnotation]
    grid $wp.fcols.label  -row 0 -column 0 -sticky w
    grid $wp.fcols.cbbcol -row 0 -column 1 -sticky e

    frame $wp.fshhi
    button $wp.fshhi.bshow \
	-text " Show All " \
	-bg cyan \
	-command [list ShowAnnotation All]    
    button $wp.fshhi.bhide \
	-text " Hide All " \
	-bg red -fg white \
	-command [list ShowAnnotation None]
    grid $wp.fshhi.bshow  -row 0 -column 0 -sticky w -padx 2
    grid $wp.fshhi.bhide  -row 0 -column 1 -sticky e -padx 2
    
    button $wp.bret \
	-text " Return " \
	-bg green1 \
	-command [list QuitAnnotation ok]
    button $wp.bdis \
	-text " Dismiss " \
	-bg red -fg white \
	-command [list QuitAnnotation dismiss]

    grid $wp.fcols  -row 0 -column 0 -sticky w -padx 5
    grid $wp.fshhi  -row 0 -column 1 -padx 5
    grid $wp.bret   -row 0 -column 2 -sticky ew -padx 5
    grid $wp.bdis   -row 1 -column 2 -sticky ew -padx 5
    label $wp.aide \
	-text "<B1> drag : new annotation   <Shift-B1> : edit   <Ctrl-B1> : delete" \
	-justify left -anchor w
    grid $wp.aide   -row 1 -column 0 -columnspan 2 -sticky w -padx 5
    grid columnconfig $wp all -weight 1

    $NomTextSeq tag configure selZoneAnno -background lightblue -foreground black

    # bindings in the BAnno bindtag, removed by BindModeNormal
    # when leaving the mode
    bind BAnno <ButtonPress-1>   {PositionAnnotation %W %x %y "start" ; break}
    bind BAnno <B1-Motion>       {PositionAnnotation %W %x %y "move" ; break}
    bind BAnno <ButtonRelease-1> {PositionAnnotation %W %x %y "endsel" ; break}
    bind BAnno <Control-1> {PositionAnnotation %W %x %y "delete" ; break}
    bind BAnno <Shift-1>   {PositionAnnotation %W %x %y "edit" ; break}
    BindModeNormal
    bindtags $NomTextSeq [linsert [bindtags $NomTextSeq] 0 BAnno]

    ShowAnnotation All

    return
}


proc RetourModePCI {} {
    DetruitBoutonsOrdali
    BindModeNormal
    ChangeMode $::CurrentMode

    return
}


proc AfficheBoutonsPCI {} {
    global LNOrdali FrmBouton OrdEtcDir nsq1 nsq2 pciLbl pl1Lbl pl2Lbl TDesPCI TPCI ListeTypesDeFeatures ZoneSelect ZonePCI CurrentMode

    if {[TypeAli] eq "pasdali"} {return}
    
    set LNoms "Select"
    foreach n $LNOrdali {
	if {[string trim $n] ne ""} {
	    lappend LNoms $n
	}
    }
    set LMx [PlusLongEltDe $LNoms]
    
    set wp "$FrmBouton.fpci"
    frame $wp \
	-relief sunken \
	-bd 2
    grid $wp -row 0 -column 1 -sticky ew -pady 5
    grid columnconfig $wp {1 2 3} -weight 1
    
    frame $wp.falcl
    label $wp.falcl.lbf \
	-anchor w \
	-justify left \
	-text "Feature :"
    if {! [info exists ListeTypesDeFeatures]} {
	set ListeTypesDeFeatures {}
    }
    set EPCI(FTypes) [linsert $ListeTypesDeFeatures 0 "None"]
    set wdt [PlusLongEltDe $EPCI(FTypes)]
    set EPCI(FeatCombo) $wp.falcl.cft
    ttk::combobox $wp.falcl.cft \
	-state readonly \
	-width $wdt \
	-background white \
	-values $EPCI(FTypes) \
	-textvariable EPCI(Feat)
    $wp.falcl.cft current 0
    bind $wp.falcl.cft <<ComboboxSelected>> [list ChangeFeatureForEditing %W]
    button $wp.falcl.cle \
	-text "Clear" \
	-background white \
	-command "DeselectToutesLesColonnes "
    button $wp.falcl.sal \
	-text "Select All" \
	-background cyan \
	-command "SelectionneToutesColonnes"
    grid $wp.falcl.lbf -row 0 -column 0 -sticky ew
    grid $wp.falcl.cft -row 0 -column 1 -sticky ew
    grid $wp.falcl.cle -row 1 -column 0 -sticky ew
    grid $wp.falcl.sal -row 1 -column 1 -sticky ew
    grid $wp.falcl -row 0 -column 0 -sticky nw -padx 2
    grid columnconfig $wp.falcl 1 -weight 1
    
    button $wp.bdo \
	-text "Compute" \
	-background yellow \
	-command [list ComputeIdentity]
    button $wp.bsum \
	-text "Summary" \
	-background cyan \
	-command SummaryPCI
    grid $wp.bdo -row 0 -column 1 -sticky nsw -padx {20 2} -pady 5
    grid $wp.bsum -row 0 -column 2 -sticky nsw -padx {2 20} -pady 5
    
    set nsq1 [lindex $LNoms 0]
    set nsq2 [lindex $LNoms 0]
    set pciLbl "Identity :"
    set pl1Lbl "length seq 1 : "
    set pl2Lbl "length seq 2 : "
    
    frame $wp.fse
    label $wp.fse.ls1 \
	-text "Seq. 1" \
	-anchor w \
	-justify left
    ttk::combobox $wp.fse.sq1 \
	-background white \
	-width $LMx -height 10 \
	-state readonly \
	-values $LNoms \
	-textvariable nsq1
    $wp.fse.sq1 current 0
    bind $wp.fse.sq1 <<ComboboxSelected>> {CherchePCI %W}
    label $wp.fse.ls2 \
	-text "Seq. 2" \
	-anchor w \
	-justify left
    ttk::combobox $wp.fse.sq2 \
	-background white \
	-width $LMx -height 10 \
	-state readonly \
	-values $LNoms \
	-textvariable nsq2
    $wp.fse.sq2 current 0
    bind $wp.fse.sq2 <<ComboboxSelected>> {CherchePCI %W}
    label $wp.fse.lpci \
	-textvariable pciLbl \
	-justify left \
	-anchor w
    label $wp.fse.lpl1 \
	-textvariable pl1Lbl \
	-justify left \
	-anchor w
    label $wp.fse.lpl2 \
	-textvariable pl2Lbl \
	-justify left \
	-anchor w
    button $wp.fse.det \
	-text "Details" \
	-bg cyan \
	-command DetailsCherchePCI
    grid $wp.fse.ls1  -row 0 -column 0 -sticky e -padx 5
    grid $wp.fse.sq1  -row 0 -column 1 -sticky ew
    grid $wp.fse.ls2  -row 1 -column 0 -sticky e -padx 5
    grid $wp.fse.sq2  -row 1 -column 1 -sticky ew
    grid $wp.fse.lpci -row 0 -column 2 -padx 5 -sticky ew
    grid $wp.fse.lpl1 -row 1 -column 2 -padx 5 -sticky ew
    grid $wp.fse.lpl2 -row 2 -column 2 -padx 5 -sticky ew
    grid $wp.fse.det -row 3 -column 0
    grid $wp.fse -row 0 -column 3 -sticky nw -padx 5 -pady 5
    
    frame $wp.frbt
    grid rowconfig $wp.frbt 0 -weight 1
    button $wp.frbt.ret \
	-text "Return" \
	-background green1 \
	-command RetourModePCI
    grid $wp.frbt.ret -row 0 -column 0 -sticky nsew
    grid $wp.frbt -row 0 -column 4 -sticky nse -padx 5 -pady 5
    
    BindModeSelection
    if {! [info exists ZonePCI]} {
	set ZonePCI {}
    }
    # AfficheZonesSelectionnees rebuilds ZoneSelect
    set ZoneSelect {}
    AfficheZonesSelectionnees $ZonePCI
    StockPosition
    if {$ZonePCI == {}} {
	array set TPCI [array get TDesPCI]
    } else {
	# TPCI may have been overwritten (tree, clustering ...)
	ComputeIdentity
    }
    
    return
}


proc AfficheBoutonsCherche {{prevMode ""}} {
    global FrmBouton Chrc NomTextSeq

    # setup window pour AfficheModeCherche
    set Chrc(NbrOccus)  "0 found"
    set Chrc(Motif)    ""
    set Chrc(LOccus)   {}
    set Chrc(IdxMotif) {}
    set Chrc(prevMode) $prevMode
    
    set ws "$FrmBouton.fsearch"
    frame $ws -relief sunken -bd 2
    grid $ws -row 0 -column 1 -sticky news -pady 5
    
    frame $ws.fse
    label $ws.fse.lbl1 \
	-text "Search a sequence motif" \
	-justify left -anchor w
    label $ws.fse.lbl2 \
	-text "Motif :" \
	-anchor w -justify left
    entry $ws.fse.ent \
	-background white \
	-width 20 \
	-textvariable Chrc(Motif)
    button $ws.fse.sea \
	-text " Search " \
	-background yellow \
	-command "ChercheMotif"
    label $ws.fse.lbnb \
	-anchor w -justify right \
	-textvariable Chrc(NbrOccus)
    grid $ws.fse.lbl1 -row 0 -column 0 -columnspan 2 -sticky nw
    grid $ws.fse.lbl2 -row 1 -column 0 -sticky nw
    grid $ws.fse.ent  -row 1 -column 1 -sticky nw 
    grid $ws.fse.sea  -row 0 -rowspan 2 -column 2 -sticky nsw
    grid $ws.fse.lbnb -row 0 -rowspan 2 -column 3 -sticky nsw -ipadx 5
    grid $ws.fse -row 0 -column 0 -sticky nw -pady 2 -padx 2 -ipadx 5
    grid columnconfig $ws.fse 1 -weight 1
    
    frame $ws.frbt
    button $ws.frbt.next \
	-text "Find Next" \
	-background cyan \
	-command ChercheMotifSuivant
    button $ws.frbt.dismiss \
	-text "Return" \
	-background orange \
	-command "FinCherche"
    grid $ws.frbt.next    -row 0 -column 0 -sticky nsw
    grid $ws.frbt.dismiss -row 0 -column 1 -sticky nse
    grid $ws.frbt -row 0 -column 1 -sticky news -padx {20 2}
    grid columnconfig $ws.frbt 1   -weight 1
    grid rowconfig    $ws.frbt all -weight 1
    grid columnconfig $ws 1 -weight 1 

    $NomTextSeq tag configure Cherche -foreground white -background red
    
    # Hit Return in motif entry launch search
    bind $ws.fse.ent <Return> {$FrmBouton.fsearch.fse.sea invoke}
    
    MesCouleurs $FrmBouton
    focus $ws.fse.ent
    
    return
}


proc AfficheBoutonsFeateditor {} {
    global FrmBouton ListeTypesDeFeatures EFeat TabSF TSFori LTFori NomTextSeq
    
    if {! [ModeI]} {
	return
    }
    
    if {[info exists TabSF]} {
	# TSFori est une sauvegarde !!
	array set TSFori [array get TabSF]
	set LTFori $ListeTypesDeFeatures
    } else {
	array set TSFori {}
	set LTFori [list]
    }
    
    set wb $FrmBouton
    set ws "$wb.select"
    frame $ws -relief sunken -bd 2
    grid $ws -row 0 -column 1 -sticky news -pady 5 -padx 5

    # Utilise features presentes
    label $ws.lbf \
	    -anchor w \
	    -justify left \
	    -text "Feature :"
    if {! [info exists ListeTypesDeFeatures]} {
	set ListeTypesDeFeatures {}
    }
    set EFeat(FTypes) [linsert $ListeTypesDeFeatures 0 "None"]
    set wdt [PlusLongEltDe $ListeTypesDeFeatures]
    set EFeat(FeatCombo) $ws.cft
    ttk::combobox $ws.cft \
	    -state readonly \
	    -width $wdt \
	    -background white \
	    -values $EFeat(FTypes) \
	    -textvariable EFeat(Feat)
    $ws.cft current 0
    bind $ws.cft <<ComboboxSelected>> [list ChangeFeatureForEditing %W]
    button $ws.bnw \
	    -text "Clear selection" \
	    -bg cyan -anchor w \
	    -command [list CmdsMenuFeatures "clearsel"]
    button $ws.bdf \
	    -text "Delete Feature" \
	    -bg yellow \
	    -command {DeleteFeature all ""}

    grid $ws.lbf -row 0 -column 0 -sticky ew
    grid $ws.cft -row 0 -column 1 -sticky ew
    grid $ws.bnw -row 1 -column 0 -sticky ew -columnspan 2
    grid $ws.bdf -row 0 -column 2 -sticky ew -padx 3

    # frame boutons fichier feat/fet summary
    frame $wb.fffs
    set wff $wb.fffs
    grid $wff -row 0 -column 2 -rowspan 2 -sticky nws -padx 10 -pady 5
    button $wff.ff \
	    -text "Load feat. file" \
	    -background white \
	    -command [list ReadRawFeatureFile]
    button $wff.sm \
	    -text "Feature summary" \
	    -background cyan \
	    -command [list FeatureSummary]

    grid $wff.ff -row 0 -column 0 -sticky nsw -padx 5
    grid $wff.sm -row 0 -column 1 -sticky nse -padx 5

    # frame boutons OK / dismiss
    frame $wb.fokdm
    set wok $wb.fokdm
    grid $wok -row 0 -column 3 -sticky ne -padx 5 -pady 5
    button $wok.ok \
	    -text " Save " \
	    -background green1 \
	    -command [list RetourEditFeatures save]
    button $wok.dismiss \
	    -text "Cancel" \
	    -background red -foreground white \
	-command [list RetourEditFeatures dismiss]

    grid $wok.ok      -row 0 -column 0 -sticky ew
    grid $wok.dismiss -row 1 -column 0 -sticky ew
    grid columnconfig $wok all -weight 0
    grid rowconfig    $wok all -weight 1

    # bindings pour edit features
    # menu contextuel
    BindingsFeatEditor
    set EFeat(LItemSel) [list]
    set EFeat(ContextMenu) $NomTextSeq.ctxm
    CreateContextMenuFeature 
    bind $NomTextSeq <Button-3> [list ShowContextMenuFeat]

    # Selection de zones 
    $NomTextSeq configure -state normal
    $NomTextSeq tag configure slct -background LightGrey -foreground black
    $NomTextSeq configure -state disabled

    # some inits
    set EFeat(BindInit) [bindtags $NomTextSeq]
    set EFeat(Score) ""
    set EFeat(Note) ""
    set EFeat(Color) ""
    set EFeat(Name) ""
    set EFeat(Lx1x2) ""
    set EFeat(ZoneX1) ""
    set EFeat(ZoneX2) ""
    set EFeat(LItemSel) ""

    return
}


proc AfficheBoutonsFeatures {} {
    global FrmBouton FrmBtnFea ListeTypesDeFeatures Defauts OrdEtcDir NomNomSeq NomTextSeq EtatBtnFeat
    
    if {! [ModeI]} {
	return
    }
    
    set law $FrmBouton
    set wb "$FrmBouton.lesbt"
    set FrmBtnFea $wb
    frame $wb \
	-relief sunken \
	-bd 2
    grid $wb -row 0 -column 1 -sticky news -pady 5

    set LFeature [lsort -unique $ListeTypesDeFeatures]
    if {"Clear" ni $LFeature} {
	lappend LFeature "Clear"
    }
    
    set NFeat [llength $LFeature]
    set wdt [winfo reqwidth $NomTextSeq]
    set lg 0
    foreach f $LFeature {
	incr lg [expr {[string length $f] + 2}]
    }
    
    set Fs [font measure BtnFeatFont "Z"]
    set Npl [expr {floor($wdt/(($lg/$NFeat)*$Fs))}]
    
    set i 0 ; set j 0
    foreach f $LFeature {
	set flo [string tolower $f]
	regsub -all " " $flo "" fnsp
	if {[regexp {^Score\-} $f]} {
	    set bg yellow
	} else {
	    set bg green1
	}
	
	button ${wb}.$fnsp \
	    -background $bg \
	    -foreground black \
	    -font BtnFeatFont \
	    -text "$f" \
	    -activeforeground yellow \
	    -activebackground $bg \
	    -command [list ColorieSelonFeature $f $wb.$fnsp]
	grid $wb.$fnsp \
	    -padx 2 -pady 1 \
	    -row $i -column $j \
	    -sticky ew
	
	incr j
	if {$j >= $Npl} {
	    set j 0
	    incr i
	}
	if {! [info exists EtatBtnFeat($wb.$fnsp)]} {
	    set EtatBtnFeat($wb.$fnsp) 0
	} elseif {[EtatDuBouton "$wb.$fnsp"]} {
	    EnfonceBtnFeature $wb.$fnsp
	}
    }
    grid rowconfig    $wb all -weight 0 -minsize 0
    grid columnconfig $wb all -weight 1 -minsize 0
    update

    lassign [grid bbox $wb] t a x y 
    lassign [grid size $wb] c r 
    if {$c == 1} {set c 2}
    set wdt [winfo width $FrmBtnFea]
    set px [expr {floor(($wdt-$x)/($c-1)/2)}]
    foreach e [grid slaves $wb] {
	#grid configure $e -ipadx $px
	if {[$e cget -text] eq "Clear"} {
	    $e configure -background white
	}
    }
    update idletasks
    
    MesCouleurs $FrmBouton
    
    return
}


proc AfficheBoutonsSuperposition {} {
    global FrmBouton NomTextSeq ListeTypesDeFeatures

    set w $FrmBouton
    set ws "$w.select"
    frame $ws -relief sunken -bd 2
    grid $ws -row 0 -column 1 -sticky news -pady 5

    frame $ws.falcl
    grid $ws.falcl -row 0 -column 0 -sticky w -padx 2

    label $ws.falcl.lbf \
	-anchor w \
	-justify left \
	-text "Feature :"
    if {! [info exists ListeTypesDeFeatures]} {
	set ListeTypesDeFeatures {}
    }
    set wdt [PlusLongEltDe $ListeTypesDeFeatures]
    set LesTypes [linsert $ListeTypesDeFeatures 0 "None"]
    ttk::combobox $ws.falcl.cft \
	-state readonly \
	-width $wdt \
	-background white \
	-values $LesTypes \
	-textvariable SupFeat
    $ws.falcl.cft current 0
    bind $ws.falcl.cft <<ComboboxSelected>> [list ChangeFeature %W]
    button $ws.falcl.cle \
	-text "Clear" \
	-background white \
	-command "DeselectToutesLesColonnes "
    
    button $ws.falcl.sal \
	-text "Select All" \
	-background cyan \
	-command "SelectionneToutesColonnes"
    grid $ws.falcl.lbf -row 0 -column 0 -sticky ew
    grid $ws.falcl.cft -row 0 -column 1 -sticky ew
    grid $ws.falcl.cle -row 1 -column 0 -sticky ew
    grid $ws.falcl.sal -row 1 -column 1 -sticky ew
    grid columnconfig $ws.falcl 1 -weight 1
    
    frame $ws.frmsst
    grid $ws.frmsst -row 0 -column 1 -sticky nw -padx 2 -pady 2
    # buttons for helix and sheet
    set ::bhelix $ws.frmsst.hel
    button $ws.frmsst.hel \
	-text "All Helices" \
	-background red \
	-width 10 \
	-command [list SelectSSDeType helix]
    button $ws.frmsst.she \
	-text "All Strands" \
	-background green1 \
	-width 10 \
	-command [list SelectSSDeType sheet]
    button $ws.frmsst.fin \
	-text "Superpose" \
	-background yellow \
	-width 9 -height 2 \
	-command "FaitSuperposition 1"
    button $ws.frmsst.dpl \
	-text "Display" \
	-background green1 \
	-width 7 -height 2 \
	-command "VisualiseStructure"
    grid $ws.frmsst.hel -row 0 -column 0 -sticky new
    grid $ws.frmsst.she -row 1 -column 0 -sticky new -ipadx 5
    grid $ws.frmsst.fin -row 0 -rowspan 2 -column 1 -sticky news -ipady 5
    grid $ws.frmsst.dpl -row 0 -rowspan 2 -column 2 -sticky news -ipady 5
    grid $ws.frmsst -row 0 -column 1 -sticky news -padx 2 -pady 2 

    button $ws.dis \
	-text "Return" \
	-background green1 \
	-command "RetourModeSuperposition"
    grid $ws.dis -row 0 -column 2 -rowspan 2 -sticky news -padx 2 -pady 2 
    
    grid rowconfig $ws 0 -weight 0
    grid columnconfig $ws all -weight 1

    # bindings
    BindModeSelection

    AfficheZonesSelectionneesSuper
    StockPosition

    return
}


proc RetourModeSuperposition {} {
    global FrmBouton NomTextSeq CurrentMode

    set w $FrmBouton
    set ws $w.select
    destroy $ws

    $NomTextSeq tag remove slct
    $NomTextSeq tag remove Marque

    BindModeNormal
    ChangeMode $CurrentMode
    
    return
}


proc RetourDesArbres {} {
    global NomTextSeq FrmBouton CurrentMode

    set w $FrmBouton
    set ws $w.treesel
    destroy $ws

    $NomTextSeq tag remove slct

    BindModeNormal
    ChangeMode $CurrentMode

    return
}


proc AfficheBoutonsArbres {} {
    global Defauts FrmBouton NomTextSeq ZoneTree ZoneSelect ListeTypesDeFeatures WOrdali
    
    # pre-definit variables
    set lg [LongueurAlignement]
    set lgd [expr {double($lg)}]
    # define number of bootstrap. 1.15 * alignment length to be 99% sure all columns are seen once 
    # Change to 1000 standard for publication
    #set nbBoot [expr {int($lgd*1.15)}]
    #set nbBoot [expr {$nbBoot - ($nbBoot % 10)}]
    set Defauts(TreeNBoot) 1000
    
    # mise en place boutons
    set w $FrmBouton
    set ws $w.treesel
    frame $ws \
	-relief sunken \
	-bd 2
    grid $ws -row 0 -column 1 -sticky news -pady 5
    
    frame $ws.falcl
    grid $ws.falcl -row 0 -column 0 -sticky nw -padx 5 -pady 5
    
    label $ws.falcl.lbf \
	-anchor w \
	-justify left \
	-text "Feature :"
    if {! [info exists ListeTypesDeFeatures]} {
	set ListeTypesDeFeatures {}
    }
    set LesTypes [linsert $ListeTypesDeFeatures 0 "None"]
    set wdt [PlusLongEltDe $LesTypes]
    set Tree(Combo) $ws.falcl.cft
    ttk::combobox $ws.falcl.cft \
	-state readonly \
	-width $wdt \
	-background white \
	-values $LesTypes \
	-textvariable TreeFeat
    set WOrdali(Tree,SelectAll) $ws.falcl.sal 
    $ws.falcl.cft current 0
    bind $ws.falcl.cft <<ComboboxSelected>> [list ChangeFeature %W]
    button $ws.falcl.cle \
	-text "Clear" \
	-background white \
	-command "DeselectToutesLesColonnes "
    button $ws.falcl.sal \
	-text "Select All" \
	-background cyan \
	-command "SelectionneToutesColonnes"
    
    grid $ws.falcl.lbf -row 0 -column 0 -sticky ew
    grid $ws.falcl.cft -row 0 -column 1 -sticky ew
    grid $ws.falcl.cle -row 1 -column 0 -sticky ew
    grid $ws.falcl.sal -row 1 -column 1 -sticky ew
    grid columnconfig $ws.falcl 1 -weight 1
    
    frame $ws.frmsst
    grid $ws.frmsst -row 0 -column 1 -sticky nw -padx 5 -pady 5
    checkbutton $ws.frmsst.pdb \
	-text "with PDB seq" \
	-anchor w -justify left \
	-variable Defauts(PDBTree) \
	-onvalue 1 \
	-offvalue 0
    checkbutton $ws.frmsst.gap \
	-text "Pairwise / Global" \
	-anchor w -justify left \
	-variable Defauts(TypeGapTree) \
	-onvalue "pairwise" \
	-offvalue "global"
    button $ws.frmsst.loe \
	-text "Load Tree file" \
	-background white \
	-command [list LoadUnArbre "" 1]
    grid $ws.frmsst.pdb -row 0 -column 0 -sticky ew
    grid $ws.frmsst.gap -row 1 -column 0 -sticky ew
    grid $ws.frmsst.loe -row 0 -column 1 -sticky ew -padx 20
    grid columnconfig $ws.frmsst 0 -weight 1
    
    frame $ws.fbtp
    grid $ws.fbtp -row 0 -column 2 -sticky nw -padx 5 -pady 5
    set WOrdali(Tree,Bootstrap) $ws.fbtp.ynbtp 
    checkbutton $ws.fbtp.ynbtp \
	-text "Bootstrap tree" \
	-anchor w -justify left \
	-variable Defauts(TreeBoot) \
	-onvalue 1 \
	-offvalue 0
    entry $ws.fbtp.nbbtp \
	-justify right \
	-width 7 \
	-bg white \
	-textvariable Defauts(TreeNBoot)
    grid $ws.fbtp.ynbtp -row 0 -column 0 -sticky ew
    grid $ws.fbtp.nbbtp -row 1 -column 0 -sticky ew
    grid columnconfig $ws.fbtp 0 -weight 1
    
    set wc "$ws.control"
    frame $wc
    grid $wc -row 0 -column 3 -sticky ne -padx 5 -pady 5
    set WOrdali(Tree,Draw) $wc.fin
    button $wc.fin \
	-text "Draw" \
	-background yellow \
	-command "CalculeUnArbre"
    button $wc.dis \
	-text "Return" \
	-background green1 \
	-command "RetourDesArbres"
    grid $wc.fin -row 0 -column 0 -sticky news -padx 20
    grid $wc.dis -row 0 -column 1 -sticky news
    grid columnconfig $wc 0 -weight 1

    grid columnconfig $ws all -weight 1
    
    # bindings
    BindModeSelection
    if {! [info exists ZoneTree]} {
	set ZoneTree {}
    } else {
	set ZoneSelect $ZoneTree
    }
    AfficheZonesSelectionnees $ZoneTree
    StockPosition

    MesCouleurs $FrmBouton

    return
}


#
# method chosen in the Conservation tool : the separator line can
# not be chosen (back to the previous method)
#
proc ChoixMethodeConservation {} {
    global Cons

    if {$Cons(Method) eq $Cons(Separateur)} {
	set Cons(Method) $Cons(MethodPrec)
	return
    }
    set Cons(MethodPrec) $Cons(Method)
    set Cons(Title) ""

    return
}


proc AfficheBoutonsConservation {} {
    global FrmBouton Cons Defauts
    
    set ws $FrmBouton.cons
    frame $ws -relief sunken -bd 2
    grid $ws -row 0 -column 1 -sticky news -pady 5
    grid columnconfig $ws 1 -weight 1
    
    set wx "$ws.chx"
    frame $wx
    grid $wx -row 0 -column 0 -sticky nw -padx 2 -pady {2 5}
    grid columnconfig $wx 1 -weight 1
    
    label $wx.lmth \
	-text "Method : " \
	-anchor w -justify left
    # conservation methods, then (after a separator line, that can
    # not be chosen) specificity-determining positions
    set Cons(Separateur) [string repeat \u2500 10]
    set ListeMethCons [list "Threshold" "BILD" "Liu" "Mean Distances" "JSD" "Shannon" "Vector Norm" "Multi" $Cons(Separateur) "GroupSim"]
    set wdt [PlusLongEltDe $ListeMethCons]
    ttk::combobox $wx.smth \
	-width $wdt \
	-background white \
	-state readonly \
	-textvariable Cons(Method) \
	-values $ListeMethCons
    $wx.smth current 0
    set Cons(MethodPrec) $Cons(Method)
    bind $wx.smth <<ComboboxSelected>> [list ChoixMethodeConservation]
    label $wx.ltt \
	-text "Title : " \
	-anchor w -justify left 
    set Cons(Entry) $wx.tit
    entry $wx.tit \
	-bg white \
	-textvariable Cons(Title) \
	-width 20
    
    set Cons(OnlyGlobal) 0
    checkbutton $wx.glo \
	-text "only global" \
	-anchor w -justify left \
	-relief flat \
	-onvalue 1 \
	-offvalue 0 \
	-variable Cons(OnlyGlobal)
    
    # PDB sequences always excluded unless "include PDB" is checked
    set Cons(PDB) 0
    set Defauts(PDBDansPilier) 0
    checkbutton $wx.pdb \
	-text "include PDB" \
	-anchor w -justify left \
	-relief flat \
	-onvalue 1 \
	-offvalue 0 \
	-variable Cons(PDB)
    
    grid $wx.lmth -row 0 -column 0 -sticky new
    grid $wx.smth -row 0 -column 1 -sticky new
    grid $wx.ltt  -row 1 -column 0 -sticky new
    grid $wx.tit  -row 1 -column 1 -sticky new
    grid $wx.pdb  -row 0 -column 2 -sticky new
    grid $wx.glo  -row 1 -column 2 -sticky new
    
    set wc "$ws.control"
    frame $wc
    grid $wc -row 0 -column 1 -sticky nsw -padx 2 -pady 2
    grid columnconfig $wc 2   -weight 1
    button $wc.run \
	-text "Compute" \
	-bg yellow \
	-command [list LanceCalculConservation]
    set Cons(Show) [set ::Toggle(Scores)]
    checkbutton $wc.shh \
	-text "Show scores " \
	-anchor w -justify left \
	-relief flat \
	-onvalue 1 \
	-offvalue 0 \
	-variable Cons(Show)
    label $wc.lal \
	-text "Show : " \
	-anchor w -justify left
    set Cons(ConsCou) "None"
    set Cons(ListeCons) [list "None"]
    set wdt [PlusLongEltDe $Cons(ListeCons)]
    set Cons(ComboSel) $wc.call
    ttk::combobox $wc.call \
	-width $wdt \
	-background white \
	-state readonly \
	-textvariable Cons(ConsCou) \
	-values $Cons(ListeCons)
    $wc.call current 0
    bind $wc.call <<ComboboxSelected>> [list ChangeConservation]
    button $wc.save \
	-text " Save " \
	-bg green1 \
	-command [list SauveConservation]
    button $wc.expo \
	-text " Export " \
	-bg yellow \
	-command [list ExporteScoreConservation]
    
    grid $wc.run  -row 0 -rowspan 2 -column 0 -sticky nsw -ipadx 5
    grid $wc.lal  -row 0 -column 1 -sticky nw 
    grid $wc.call -row 0 -column 2 -sticky new 
    grid $wc.shh  -row 1 -column 1 -columnspan 2 -sticky new -ipadx 5
    grid $wc.save -row 0 -column 3 -sticky ew -padx 10
    grid $wc.expo -row 1 -column 3 -sticky ew -padx 10
    grid rowconfig    $wc all -weight 1

    # frame save/return
    set wb "$ws.sds"
    frame $wb
    grid $wb -row 0 -column 2 -sticky nse -padx 2 -pady 2
    button $wb.dis \
	-text "Return" \
	-background green1 \
	-command [list QuitteModeConservation $ws]
    #grid $wb.save -row 0 -column 0 -sticky new
    grid $wb.dis  -row 0 -column 0 -sticky new

    update idletasks

    trace add variable Cons(PDB) write PrendPDBDansPilier
    trace add variable Cons(Show) write ToggleScores
    trace add variable Cons(ConsCou) write ToggleScores

    return
}


proc AfficheBoutonsClusters {} {
    global FrmBouton NomTextSeq ZoneClusterisation ListeTypesDeFeatures Clus

    set ws $FrmBouton.clusel
    frame $ws \
	-relief sunken \
	-bd 2
    grid $ws -row 0 -column 1 -sticky news -pady 5
    grid columnconfig $FrmBouton 1 -weight 1

    set Clus(Title) "Give a Title to your clustering"
    set Clus(ShowSeqOut) 1
    set Clus(NewEntry) 1

    # Features/Clear/Select All
    frame $ws.fs
    grid $ws.fs -row 0 -column 0 -sticky w -padx 5 -pady 5
    label $ws.fs.lbf \
	-anchor w -justify left \
	-text "Feature :"
    if {! [info exists ListeTypesDeFeatures]} {
	set ListeTypesDeFeatures {}
    }
    set LesTypes [linsert $ListeTypesDeFeatures 0 "None"]
    set wdt [PlusLongEltDe $LesTypes]
    set Clus(Combo) $ws.fs.cft
    ttk::combobox $ws.fs.cft \
	-state readonly \
	-width $wdt \
	-background white \
	-values $LesTypes \
	-textvariable ClusFeat
    button $ws.fs.sal \
	-text "Select All" \
	-background cyan \
	-command [list SelectionneToutesColonnes]
    button $ws.fs.cle \
	-text "Clear" \
	-background white \
	-command [list DeselectToutesLesColonnes]
    grid $ws.fs.lbf -row 0 -column 0 -sticky we
    grid $ws.fs.cft -row 0 -column 1 -sticky we
    grid $ws.fs.cle -row 1 -column 0 -sticky we
    grid $ws.fs.sal -row 1 -column 1 -sticky we
    grid columnconfig $ws.fs 0 -weight 1
    
    # Criterion
    frame $ws.fv
    grid $ws.fv -row 0 -column 1 -sticky e -padx 5 -pady 5
    label $ws.fv.lctr \
	-text "Criterions : " \
	-relief flat \
	-anchor w -justify right
    menubutton $ws.fv.mctr \
	-relief raised \
	-text "Choose ..." \
	-direction above \
	-menu $ws.fv.mctr.criteres
    menu $ws.fv.mctr.criteres -tearoff 0
    foreach f {"% identity" "length" "hydrophobicity" "pI" "aa composition"} {
	$ws.fv.mctr.criteres add checkbutton -label "$f" -variable Clus(LCrit,$f) -onvalue 1 -offvalue 0 
    }
    set lfdm "Life Domain"
    set Clus(LCrit,$lfdm) 0
    $ws.fv.mctr.criteres add separator
    $ws.fv.mctr.criteres add checkbutton -label "Life Domain" -variable Clus(LCrit,$lfdm) -onvalue 1 -offvalue 0
    # clustering methods
    label $ws.fv.lmet \
	-text "Method : " \
	-relief flat \
	-anchor w -justify right
    set Lmeth [list "kmeans / DPC" "hierarchic / secator" "mixture model / AIC" "mixture model / BIC"]
    ttk::combobox $ws.fv.cmet \
	-state readonly \
	-values $Lmeth \
	-textvariable Clus(Method)
    #bind $ws.fv.cmet <<ComboboxSelected>> NouveauClustering

    grid $ws.fv.lctr -row 0 -column 0 -sticky e
    grid $ws.fv.mctr -row 0 -column 1 -sticky ew
    grid $ws.fv.lmet -row 1 -column 0 -sticky e
    grid $ws.fv.cmet -row 1 -column 1 -sticky ew
    
    # Run
    button $ws.run \
	-text "Compute" \
	-background yellow \
	-command NouveauClustering
    grid $ws.run -row 0 -column 2 -rowspan 2 -sticky ns -padx 5 -pady 5

    # controls
    frame $ws.fc 
    grid $ws.fc -row 0 -column 3 -sticky e -padx 5 -pady 5
    grid columnconfig $ws.fc 0 -weight 1
    button $ws.fc.ori \
	-text "Reset" \
	-background white \
	-command [list DefinitionGroupes integral]
    button $ws.fc.noc \
	-text "No Clusters" \
	-background yellow \
	-command [list NouveauClustering nogroups]

    if {[TypeAli] in {XML ORD}} {
	grid $ws.fc.ori -row 0 -column 0 -sticky we -padx 5
    }
    grid $ws.fc.noc -row 1 -column 0 -sticky ns -padx 5

    # Dismiss/New/Overwrite
    frame $ws.fb    
    grid $ws.fb -row 0 -column 4 -sticky e -padx 5 -pady 5
    grid columnconfig $ws.fb 0 -weight 1
    button $ws.fb.cnm \
	-text "Clusters\nNames" \
	-bg cyan \
	-command {NamesOfClusters}
    button $ws.fb.fin \
	-text " Save " \
	-background green1 \
	-command GardeClustering
    button $ws.fb.dis \
	-text "Return" \
	-background green1 \
	-command [list QuitteModeClusters $ws]
    grid $ws.fb.cnm -row 0 -column 0 -rowspan 2 -sticky ns -padx 5
    grid $ws.fb.fin -row 0 -column 1 -sticky ew -padx 5
    grid $ws.fb.dis -row 1 -column 1 -sticky ew -padx 5

    grid columnconfig $ws all -weight 1
    grid rowconfig    $ws all -weight 0

    $ws.fs.cft current 0
    bind $ws.fs.cft <<ComboboxSelected>> [list ChangeFeature %W]

    # bindings
    BindModeSelection
    if {! [info exists ZoneClusterisation]} {
	set ZoneClusterisation ""
    }
    AfficheZonesSelectionneesCluster
    StockPosition
    
    # Tags Specifiques
    $::NomNomSeq tag configure SLock -foreground black -background grey
    
    MesCouleurs $FrmBouton
    
    return
}


proc AfficheBoutonsSeqLab {{GardeShowFt 0}} {
    global FrmBouton ListeTypesDeFeatures ShowFt
    
    if {! [ModeI]} {
	return
    }
    
    set wb $FrmBouton.sl
    frame $wb \
	-relief sunken \
	-bd 2
    grid $wb -row 0 -column 1 -sticky news -pady 5
    
    frame $wb.frmgp
    grid $wb.frmgp -row 0 -column 0 -sticky w -padx 2
    
    button $wb.frmgp.clear \
	-text "Clear\nselections" \
	-foreground black \
	-background white \
	-width 10 \
	-command "ClearSelections"
    button $wb.frmgp.ungroup \
	-text "Ungroup" \
	-foreground black \
	-background cyan \
	-width 10 \
	-command "DegroupeLesSequences"
    button $wb.frmgp.group \
	-text "Group" \
	-foreground black \
	-background cyan \
	-width 10 \
	-command "GroupeLesSequences"
    grid $wb.frmgp.clear   -row 0 -column 0 -rowspan 2 -sticky news -padx {2 5} 
    grid $wb.frmgp.group   -row 0 -column 1 -sticky ew
    grid $wb.frmgp.ungroup -row 1 -column 1 -sticky ew
    grid columnconfig $wb.frmgp 0   -weight 1
    grid rowconfig    $wb.frmgp all -weight 0

    frame $wb.frmnet
    grid $wb.frmnet -row 0 -column 1 -sticky w -padx 2
    button $wb.frmnet.col \
	-text "Remove columns of gaps" \
	-foreground black \
	-background pink \
	-width 22 \
	-command RemoveColumnsOfGaps
    checkbutton $wb.frmnet.ulock \
	-text "Lock/Unlock Sequences" \
	-anchor w -justify left \
	-variable ::LockSeqs\
	-onvalue 1 \
	-offvalue 0 \
	-command "EtatLockSeqs"
    set ::Toggle(MapRes) 1
    checkbutton $wb.frmnet.umap \
	-text "Map / Unmap residues" \
	-anchor w -justify left \
	-variable ::Toggle(MapRes) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list ToggleMapResidues 1]
    grid $wb.frmnet.ulock  -row 0 -column 0 -sticky ew
    grid $wb.frmnet.umap   -row 1 -column 0 -sticky ew
    grid $wb.frmnet.col    -row 2 -column 0 -sticky ew
    grid columnconfig $wb.frmnet 0 -weight 1

    # frame features
    frame $wb.frmft
    grid $wb.frmft -row 0 -column 2 -sticky e -padx 2
    label $wb.frmft.label \
	-text "Show feature : " \
	-relief flat \
	-anchor w -justify right
    menubutton $wb.frmft.menu \
	-relief raised \
	-text "Click to select Features ..." \
	-direction above \
	-menu $wb.frmft.menu.features
    menu $wb.frmft.menu.features -tearoff 0
    # initialisation show/hide feature.
    # The trace of a previous call is still there when coming back
    # from the motif search (FinCherche) : setting ShowFt with it
    # toggled every feature (AppliqueFeature) and drew all of them,
    # and the trace was added twice. Remove it first, and keep the
    # show/hide state of the Editor when coming back from the search.
    trace remove variable ShowFt write ShowHideFeatureInSeqlab
    if {! $GardeShowFt || ! [array exists ShowFt]} {
	lmap ft $ListeTypesDeFeatures {set ShowFt($ft) 0}
	lmap ft [ListeDesFeaturesUtilisees] {set ShowFt($ft) 1}
    }
    trace add variable ShowFt write ShowHideFeatureInSeqlab
    foreach ft $ListeTypesDeFeatures {
	$wb.frmft.menu.features add checkbutton -label " $ft" -variable ShowFt($ft) -onvalue 1 -offvalue 0 
    }
    
    button $wb.frmft.hide \
	-text "Hide features" \
	-foreground black \
	-background white \
	-command [list ClearingFeatureInSeqlab]
    grid $wb.frmft.label -column 0 -row 0 -sticky w
    grid $wb.frmft.menu  -column 0 -row 1 -sticky we
    grid $wb.frmft.hide  -column 0 -row 2 -sticky e
    grid columnconfig $wb.frmft 0 -weight 1
    
    # save, cancel, ...
    frame $wb.frmsv
    grid $wb.frmsv -row 0 -column 3 -sticky e -padx 2
    button $wb.frmsv.search \
	-text "Search Motif" \
	-background yellow \
	-command [list ChangeMode "search"]
    button $wb.frmsv.save \
	-text "temp. save" \
	-background cyan \
	-command SauveTempSeqlab
    set bdismiss $wb.frmsv.dismiss
    set breturn  $wb.frmsv.return
    button $wb.frmsv.return \
	-text "Save & Return" \
	-background green1 \
	-command [list RetourFenetreOrdali $wb save $breturn]
    button $wb.frmsv.dismiss \
	-text "Cancel" \
	-background red -foreground white \
	-command "RetourFenetreOrdali $wb dismiss $bdismiss"
    grid $wb.frmsv.save    -row 0 -column 0 -sticky ew -padx {2 20}
    grid $wb.frmsv.search  -row 1 -column 0 -sticky ew -padx {2 20}
    grid $wb.frmsv.return  -row 0 -column 1 -sticky ew
    grid $wb.frmsv.dismiss -row 1 -column 1 -sticky ew
    grid columnconfig $wb.frmsv all -weight 1
    grid rowconfig    $wb.frmsv all -weight 0
    
    grid columnconfig $wb all -weight 1
    grid rowconfig    $wb all -weight 1 
    
    MesCouleurs $FrmBouton
    
    update idletasks
    
    return
}

proc mttree {} {
    global Defauts Tree WOrdali Abr

    set Defauts(TreeBoot) 1
    ChangeMode arbres
    SelectionneToutesColonnes

    $WOrdali(Tree,Draw) invoke
    update idletasks

    set AId 1
    puts $Abr(TypeAff)
    set i [lsearch $Abr(TypeAff) "Accession"]
    $Abr(toto) current $i
    ChangeLabelTree $AId
    update idletasks

    set Ln [$Abr($AId,CbLTag) cget -values]
    set i [lsearch $Ln "Imito_Arab_thal"]
    $Abr($AId,CbLTag) index $i
    update idletasks

    exit
}


proc tcx {} {
    global Cons FrmBouton
    
    set wp "$FrmBouton.fpci"
    ChangeMode "donnepci"
    update idletasks
    $wp.fse.sq1 current 3
    $wp.fse.sq2 current 68
    update idletasks
    
    DetailsCherchePCI

    return
}
