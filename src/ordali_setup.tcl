

#
# ordali_setup.tcl
#

proc TempFolder {} {
    # first existing and writable directory ; ORDALITMP first, as before
    set Ld {}
    foreach v {ORDALITMP TMPDIR TEMP TMP} {
        if {[info exists ::env($v)]} {
            lappend Ld $::env($v)
        }
    }
    lappend Ld /tmp /var/tmp C:/Temp C:/Windows/Temp
    foreach d $Ld {
        if {$d ne "" && [file isdirectory $d] && [file writable $d]} {
            # normalize : forward slashes on Windows, read by the bash of MAFFT
            return [file normalize $d]
        }
    }
    return [pwd]
}


proc InitLesDefauts {} {
    global env OrdaliDir OrdTmpDir OrdEtcDir OrdHlpDir OrdLibDir OrdBinDir OuiOuNonToujoursParDefaut GenomeOuCollection

    if {[info exists env(ORDALIEONWEB)]} {
	set ::EspionneNon 1
    }
    
    set OrdTmpDir [TempFolder]

    set OrdHlpDir [file join $OrdaliDir help]
    set OrdEtcDir [file join $OrdaliDir etc]
    set OrdBinDir [file join $OrdaliDir bin]

    set OuiOuNonToujoursParDefaut 0
    set GenomeOuCollection "Collection"

    LesDefauts

    return
}


proc LesDefauts {args} {
    global env OrdEtcDir Defauts VersionDeOrdali

    set VersionDeOrdali 3.5

    if {[llength $args] == 2} {
	lassign $args Type Valeur
	set Defauts($Type) $Valeur
	if {$Type eq "Mode" && [string equal -nocase $Valeur "batch"]} {
	    global FaireLireNon
	    set FaireLireNon 1
	}

	return
    }

    set ::VueEditee 0
    set ::FichierModifie 0
    ValsDesDefauts

    if {[UtiliseCCode]} {
	set Defauts(UseSpeedCode) "C"
    } else {
	set Defauts(UseSpeedCode) "tcl"
    }
    set Defauts(RSeed) 101112

    if {$args ne "OldDef"} {
	package require platform
	set plat [::platform::generic]
	if {[regexp -nocase {^window} $plat]} {
	    set fdef [file join $env(APPDATA) ordalierc.def]
	} else {
	    if {[info exists env(HOME)]} {
		set fdef [file join $env(HOME) .ordalierc]
	    } else {
		# env(HOME) does not exits...
		# Ordalie is launched from a httpd server
		set fdef "DontSaveIt"
	    }
	}

	if {[file exists $fdef]} {
	    LitOrdalieDefauts $fdef
	} elseif {$fdef ne "DontSaveIt"} {
	    SauveOrdalieDefauts
	}
    }

    if {"Structure" ni [info commands]} {
	SetupPDBObject
    }

    ToggleAuLog $Defauts(LogAtStartup)

    return
}


proc ValsDesDefauts {} {
    global Defauts

    set Defauts(ShowOrdalieHeader) 0
    set Defauts(Email)               luc.moulinier@unistra.fr
    set Defauts(WithPackages)        1
    set Defauts(Mode)                Interactive
    set Defauts(MarcheForcee)        0
    set Defauts(InProject)           0
    set Defauts(Project)             ""
    set Defauts(dispmode)            "ordali"
    set Defauts(Devlpt)              0
    set Defauts(FirstPass)           1
    set Defauts(MacsimDone)          0
    set Defauts(IxMacCourant) -1
    set Defauts(NmMacCourant) ""
    
    set Defauts(ToggleAllSeqs)       1
    set Defauts(ToggleToolBar)       1
    set Defauts(ToggleFeature)       1
    set Defauts(ToggleScores)        0
    set Defauts(ToggleColRes)        0
    set Defauts(ToggleMapRes)        0
    set Defauts(ToggleAuLog)         0
    set Defauts(RemovePropagated)    0

    set Defauts(NmMacCourant)        ""
    set Defauts(LogAtStartup)        0
    set Defauts(OnlyTLog)            0
    set Defauts(ShowFrame)           0
    set Defauts(FullScreen)          0
    set Defauts(TypeAli)             "pasdali"
    set Defauts(LongNom)             16
    set Defauts(NomsAffiches)        "seqname"
    set Defauts(PreCompute)          0
    set Defauts(PrecomputeSrf)       0
    set Defauts(CheckSeq)            0
    set Defauts(Poids)               0
    set Defauts(Poids2)              0
    set Defauts(Poids3)              0
    set Defauts(SelectionNom)        0
    set Defauts(SelectionLong)       0
    set Defauts(CutLong)             2
    set Defauts(TypeDeGroupesACreer) "User"
    set Defauts(FichierClu)          ""
    set Defauts(Run)                 0
    set Defauts(PDB)                 0
    # PDB sequences in conservation columns : only when the user
    # checks "include PDB" in the Conservation tool
    set Defauts(PDBDansPilier)       0
    set Defauts(SeqAssocie)          0
    set Defauts(FichierMSF)          ""
    set Defauts(FichierRSF)          ""
    set Defauts(FichierTFA)          ""
    set Defauts(FichierXML)          ""
    set Defauts(FichierORD)          ""
    set Defauts(FichierOBK)          ""
    set Defauts(FichierALN)          ""
    set Defauts(FichierPDB)          ""
    set Defauts(FichierOMAC)         ""
    set Defauts(Visualize)           0
    set Defauts(ConsNGrp)            1
    set Defauts(AffSS)               1
    set Defauts(AffPhy)              0
    set Defauts(AffGrp)              0
    set Defauts(SphPts)              1
    set Defauts(RunScript)           0

    set Defauts(FgEukaryota)         black
    set Defauts(BgEukaryota)         PaleVioletRed1
    set Defauts(FgArchaea)           black
    set Defauts(BgArchaea)           LightBlue
    set Defauts(FgBacteria)          black
    set Defauts(BgBacteria)          LightYellow
    set Defauts(FgViruses)           white
    set Defauts(BgViruses)           black
    set Defauts(LifeDomains)         [list Eukaryota Archaea Bacteria Viruses]

    set Defauts(PrefixesBank)        [list SPT SW PDB VARSPLIC UniRef90 UniRef100 PQS ENS sp unp tr ref gb dbj ENA]
    set Defauts(RemoveBankPrefix)    1

    set Defauts(seqWidth)            60
    set Defauts(seqHeight)           20
    set Defauts(Background)          "white"
    set Defauts(BackAppli)           "\#FFFFD0"
    set Defauts(BackAppliOri)        ""
    set Defauts(ForeAppli)           "\#00000000ffff"
    set Defauts(ForeAppliOri)        ""
    #set Defauts(bgFrmBtnCtrl) "\#FDF5E6"
    set Defauts(bgFrmBtnCtrl) "\#FFFFD0"
    set Defauts(SeqlabBg)            DimGray
    set Defauts(SeqlabFg)            black
    set Defauts(DeltaYScroll)        1

    set Defauts(PCThrGap)            0.3
    set Defauts(MinThrGap)           3
    # SDPpred (ordali_sdp.tcl)
    set Defauts(SDPNShuffle)         1000
    set Defauts(SDPSmooth)           0.5
    set Defauts(SDPMaxGap)           0.3
    set Defauts(SDPMinGroupSize)     2
    set Defauts(SDPSeed)             12345
    # GroupSim + ConsWin (ordali_groupsim.tcl) : defaults of the
    # reference code, except GroupSimTop (fraction of the scored
    # columns marked as SDP)
    set Defauts(GroupSimWindow)      3
    set Defauts(GroupSimLambda)      0.7
    set Defauts(GroupSimColGap)      0.1
    set Defauts(GroupSimGrpGap)      0.3
    set Defauts(GroupSimMinGroupSize) 2
    set Defauts(GroupSimTop)         0.05
    #set fontFml "Courier New"
    #set fontFml "FreeMono"
    set fontFml "courier"
    set Defauts(SeqFontFaml)         $fontFml
    set Defauts(SeqFontSize)         16
    set Defauts(SeqFontWght)         "normal"
    set Defauts(DeltaXScroll)        10
    set Defauts(Mapping)             [EditorMappingData]

    set Defauts(UrlPdbHoan)         "http://d1.crihan.fr:8080/bird/bsearch?db=pdb&accession=XXXX"
    set Defauts(UrlPdbHome)         "http://bird:8080/bird/bsearch?db=pdb&accession=XXXX"
    set Defauts(UrlPdbWorld)          "http://www.rcsb.org/pdb/cgi/export.cgi/XXXX.pdb?format=PDB&pdbId=XXXX&compression=None"

    set Defauts(Threshold)           80
    set Defauts(ThresholdIden)       100
    set Defauts(MethodeConservation) "Threshold"
    set Defauts(SimiGris)            1

    set Defauts(LockSeqs)            1

    set Defauts(CanvasHTree)         2000
    set Defauts(CanvasWTree)         2000
    set Defauts(FWidthTree)          400
    set Defauts(FHeightTree)         400
    set Defauts(TreeBoot)            0
    set Defauts(TreeNBoot)           100
    set Defauts(ThresBootPC)         80
    set Defauts(TypeGapTree)         "pairwise"
    set Defauts(TypeTree)            "dendrogram"
    set Defauts(PDBTree)             0
    set Defauts(CollapseTree)        0
    set Defauts(FontSizeTree)        14
    set Defauts(FontSizeTreeBoot)    8
    set Defauts(FontWghtTree)        normal

    set Defauts(CanvasHSFeat)        2000
    set Defauts(CanvasWSFeat)        2000
    set Defauts(FWidthSFeat)         600
    set Defauts(FHeightSFeat)        400

    set i 0
    foreach c [GammeDeCouleursRVB 10] g [GammeDeCouleursDeGris 10] {
	set Defauts(GammeCoul$i) $c
	set Defauts(GammeGris$i) $g
	incr i
    }

    set Defauts(Sampling)            3
    set Defauts(CoulVariable)        "LightSlateGray"
    set Defauts(Viewer)              "Viandox"
    set Defauts(Label3DColor)        [list 0.0 1.0 0.0]

    set Defauts(MethodeSuper)        "ordali"
    set Defauts(Super)               "CA"
    # peut etre 'dont' pour ne pas downloader
    set Defauts(DownloadPDB)         "internet"

    set Defauts(juju)                0
    set Defauts(SaveLog)             0
    set Defauts(clusdeb)             0
    set Defauts(Balibase)            0
    set Defauts(RemoveQuery)         0
    set Defauts(Dump)                0
    set Defauts(Exit)                0
    set Defauts(IsGenome)            0
    set Defauts(Debug)               0
    #set Defauts(UrlPdbHoan)         "http://star4:8080/bird/getproduct?db=pdb&id=XXXX"

    set Defauts(UserDef) [list \
			      Background \
			      BackAppli \
			      BackAppliOri \
			      ForeAppli \
			      ForeAppliOri \
			      SeqFontFaml \
			      SeqFontSize \
			      SeqFontWght \
			      DeltaXScroll \
			      DeltaYScroll \
			      UrlPdbHoan \
			      UrlPdbWorld \
			      UrlPdbHome \
			      Threshold \
			      MethodeConservation \
			      TreeBoot \
			      TreeNBoot \
			      ThresBootPC \
			      TypeGapTree \
			      TypeTree \
			      PDBTree \
			      FontSizeTree \
			      FontWghtTree \
			      CoulVariable \
			      Label3DColor
			 ]

    set Defauts(TablesDB) "
- ordalie : parametres generaux d'ordalie {
    . key T (nom du parametre)
    . val T (valeur du parametre)
}
- seqinfo : les infos des sequences {
    . pk_seqinfo P
    . seqname T (nickname de sequence)
    . access T
    . bid T
    . description T
    . organism T
    . taxid I
    . fragment I
    . cgroup I
    . ec T
    . complex I
    . phylum T
    . go T
    . lineage T
    . hydrophobicity R
    . isoelectric R
    . seqori T
}
- seqfeat : les features des sequences {
    . pk_seqfeat P
    . ftype T (de feature (PFAM, secstr, ...))
    . fstart I
    . fstop I
    . fcolor T
    . fscore R
    . fnote T
    . fcsys T (systeme coords, local ou global)
}
- ln_seqinfo_seqfeat : {
    . pk_seqinfo I
    . pk_seqfeat I
}
- seqali : une instance d'un seqinfo dans le contexte d'un alignement, et possede : {
    . pk_seqali P (pk pour chaque sequence)
    . pk_seqinfo I (de l'info de la sequence)
    . seqname T (nom affiche)
    . seq T (aminoacid + gap)
}
- mac : est un macsim  {
    . pk_mac P
    . name T
    . description T
}
- ln_mac_seqali {
    . pk_mac I
    . pk_seqali I
    . pos I
}
- featali : les features des sequences DANS LE CONTEXT DE L ALIGNEMENT {
    . pk_featali P
    . ftype T (de feature (PFAM, secstr, ...))
    . fstart I
    . fstop I
    . fcolor T
    . fscore R
    . fnote T
    . fcsys T (systeme coords, local ou global)
}
- ln_seqali_featali : {
    . pk_seqali I
    . pk_featali I
}
- clustering : definition generale du clustering {
    . pk_clustering P
    . pk_mac I
    . name T
    . methode T
    . zone T
}
- cluster : sont les paquets de sequences d'un clustering donne. {
    . pk_cluster P
    . pk_clustering I
    . name T
}
- ln_seqali_cluster : {
    . pk_seqali I
    . pk_cluster I
    . pos
}
- ln_mac_clustering : {
    . pk_mac I
    . pk_clustering I
    . pos I
}
- colmeasure : un calcul par colonne {
    . pk_colmeasure P
    . name T
}
- ln_mac_colmeasure {
    . pk_mac I
    . pk_colmeasure I
}
- colscore : conservation {
    . pk_colscore P
    . pk_colmeasure I
    . name V16
    . owner V16
    . type V16
    . data T
}
- ln_cluster_colscore {
    . pk_cluster I
    . pk_colscore I
}
- ln_seqali_colscore {
    . pk_seqali I
    - pk_colscore I
}
- anno : anotations d'un mac donne {
    . pk_anno P
    . annotation T
    . zone T
}
- ln_mac_anno {
    . pk_mac I
    . pk_anno I
}
- pdb : stockage des PDB {
    . pk_pdb P
    . nom T
    . source T
    . header T
}
- chaines : contient info sur chaines {
    . pk_chaines P
    . pk_pdb I
    . nom T
    . type T
}
- residues : residues de chaine {
    . pk_residues P
    . pk_pdb I
    . pk_chaines I
    . rnom1l T
    . rnom3l T
    . rnmr T
    . type T
}
- atomes : info sur atome. na = numero atomique {
    . pk_atomes P
    . pk_pdb I
    . pk_chaines I
    . pk_residues I
    . anom T
    . x R
    . y R
    . z R
    . b R
    . q R
    . na I
}
- objetinit : template objet {
    . pk_obj P
    . pk_pdb I
    . pk_chaines I
    . pk_residues I
    . currsel I
    . surface I
    . ribbon I
    . ribcol T
    . catrace I
    . cacol T
    . atomes I
    . atmcol T
    . cpk I
    . pearl I
    . picked I
    . label T
}
"

set Defauts(TablesDB1.1) "
- ordalie : tableaux generaux d'ordalie {
    . var V64 (nom du tableau)
    . key V64 (nom du parametre)
    . val T (valeur du parametre)
}
- seqinfo : les infos des sequences {
    . pk_seqinfo P
    . seqname V64 (nickname de sequence)
    . access V64
    . bid V64
    . description T
    . organism V128
    . taxid I
    . fragment I
    . cgroup I
    . ec V16
    . complex I
    . phylum V16
    . go T
    . lineage T
    . hydrophobicity R
    . isoelectric R
    . molweight R
    . seqori T
}
- seqfeat : les features des sequences {
    . pk_seqfeat P
    . pk_seqinfo I
    . ftype V32 (de feature (PFAM, secstr, ...))
    . fstart I
    . fstop I
    . fcolor V32
    . fscore R
    . fnote T
    . fcsys V8 systeme coords, local / global
}
- snapshot : est un alignement  {
    . pk_snap P
    . name V128
    . description T
}
- seqali : une instance d'un seqinfo dans le contexte d'un alignement, et possede : {
    . pk_seqali P (pk pour chaque sequence)
    . pk_seqinfo I (de l'info de la sequence)
    . seqname V64 (nom affiche)
    . seq T (aminoacid + gap)
}
- ln_snapshot_seqali {
    . pk_snap I
    . pk_seqali I
    . pos I
}
- featali : les features des sequences DANS LE CONTEXT DE L ALIGNEMENT {
    . pk_featali P
    . ftype V32 (de feature (PFAM, secstr, ...))
    . fstart I
    . fstop I
    . fcolor V32
    . fscore R
    . fnote V256
    . fcsys V8 (systeme coords, local ou global)
}
- ln_seqali_featali : les features des sequences DANS UN snapshot {
    . pk_seqali I
    . pk_featali I
    . pk_snap I (les seqali sont partagees entre snapshots)
}
- clustering : definition generale du clustering {
    . pk_clustering P
    . pk_snap I
    . name V64
    . method V64
    . zone T
}
- cluster : sont les paquets de sequences d'un clustering donne. {
    . pk_cluster P
    . pk_clustering I
    . name V64
    . label V64
}
- ln_seqali_cluster : {
    . pk_seqali I
    . pk_cluster I
    . pos I
}
- colmeasure : un calcul par colonne {
    . pk_colmeasure P
    . pk_snap I
    . name V64
    . method V64
}
- colscore : conservation, relatif a un cluster {
    . pk_colscore P
    . pk_colmeasure I
    . name V32
    . owner V32
    . type V8
    . cgroup V32
    . data T
}
- ln_cluster_colscore {
    . pk_cluster I
    . pk_colscore I
}
- annotation : anotations d'un snap donne {
    . pk_annotation P
    . pk_snap I
    . annotation T
    . color V32
    . zone T
}
"

set Defauts(TablesPDB) "
- pdb : stockage des PDB {
    . pk_pdb P
    . name V32
    . source V16
    . header T
}
- chains : contient info sur chaines {
    . pk_chains P
    . pk_pdb I
    . name V1
    . type V16
}
- residues : residues de chaine {
    . pk_residues P
    . pk_pdb I
    . pk_chains I
    . rname1l V1
    . rname3l V3
    . rnbr V8
    . type V16
}
- atoms : info sur atome. na = numero atomique {
    . pk_atoms P
    . pk_pdb I
    . pk_chains I
    . pk_residues I
    . aname V4
    . x R
    . y R
    . z R
    . b R
    . q R
    . na I
}
- objetinit : template objet {
    . pk_obj P
    . pk_pdb I
    . pk_chains I
    . pk_residues I
    . currsel I
    . surface I
    . ribbon I
    . ribcol V32
    . catrace I
    . cacol V32
    . atoms I
    . atmcol V32
    . cpk I
    . pearl I
    . picked I
    . label V32
    }
    "
    
	if {0 && [info exists ::env(USER)] && $::env(USER) eq "moumou"} {
       set Defauts(Background) "black"
       set Defauts(Foreground) "white"
   } else {
       #rR 2023/02/27
       set Defauts(Background) "white"
       set Defauts(Foreground) "black"
   }      

    return
}


proc InitialiseCouleurs {} {
    global OrdEtcDir Lookup_Couleurs

    set frgb [file join $OrdEtcDir "color_rgb.dat"]
    set fnms [file join $OrdEtcDir "color_names.dat"]

    set LesRGB [LesLignesDuFichier $frgb]
    set LesRGB [lrange $LesRGB 1 end]
    set LesRGB [string trim [join $LesRGB ""]]
    set LesRGB [split $LesRGB]

    set LesNms [LesLignesDuFichier $fnms]
    set LesNms [lrange $LesNms 1 end]
    set NbV    [expr {3*[llength $LesNms]}]

    foreach {r g b} $LesRGB lacol $LesNms {
	set lacol  [string trim $lacol]
	set lacolo [CouleurO2Ordali $lacol]

	set r [expr {int(floor($r * 255))}]
	set g [expr {int(floor($g * 255))}]
	set b [expr {int(floor($b * 255))}]

	set Lookup_Couleurs(${lacolo}) [list $r $g $b]
	set Lookup_Couleurs(${lacol})  [list $r $g $b]
    }

    return
}


proc DefinitionPreferences {} {
    global SeqChangeDansSeqlab Defauts SeqlabMode SphDef TypeCons TypeText Couleurs OrdEtcDir

    set SphDef "Mean"
    set SeqlabMode 0
    set SeqChangeDansSeqlab 0

    # define fonts if tk loaded
    if {[info exists ::tk_patchLevel]} {
	if {"SeqFont" ni [font names]} {
	    font create SeqFont -family [set Defauts(SeqFontFaml)] -size [set Defauts(SeqFontSize)] -weight [set Defauts(SeqFontWght)]
	}
	if {"EdtTitre" ni [font names]} {
	    font create EdtTitre {*}[font configure TkDefaultFont] -size 14 -weight bold
	}
	if {"EdtItem" ni [font names]} {
	    font create EdtItem {*}[font configure TkDefaultFont] -weight bold
	}
	if {"BtnFeatFont" ni [font names]} {
	    font create BtnFeatFont -family Helvetica -size 10 -weight normal
	}
	if {"TitleFont" ni [font names]} {
	    set size [font configure TkDefaultFont -size]
	    set family [font configure TkDefaultFont -family]
	    if {$size < 0} {
		incr size -2
	    } else {
		incr size 2
	    }
	    font create TitleFont -family $family -size $size -weight bold
	}
	}
    
    if {! [info exists TypeCons]} {
	set TypeCons {}
    }
    
    set TypeText(IdenGlob)     "Global identity"
    set TypeText(ConsGlob)     "Global conservation"
    set TypeText(SimiGlob)     "Global similarity"
    set TypeText(IdenGrp1)     "Identity Group 1"
    set TypeText(IdenGrp2)     "Identity Group 2"
    set TypeText(IdenGrp3)     "Identity Group 3"
    set TypeText(IdenGrp1Gris) "Group 1 similarity"
    set TypeText(IdenGrp2Gris) "Group 2 similarity"
    set TypeText(IdenGrp3Gris) "Group 3 similarity"
    set TypeText(InterG12)     "Inter-group 1-2"
    set TypeText(InterG13)     "Inter-group 1-3"
    set TypeText(InterG23)     "Inter-group 2-3"
    set TypeText(InterG12Gris) "Inter-group 1-2 sim."
    set TypeText(InterG13Gris) "Inter-group 1-3 sim."
    set TypeText(InterG23Gris) "Inter-group 2-3 sim."
    set TypeText(PoinGrp1)     "Points group 1"
    set TypeText(PoinGrp2)     "Points group 2"
    set TypeText(PoinGrp3)     "Points group 3"

    lappend TypeCons IdenGlob
    lappend TypeCons ConsGlob
    lappend TypeCons SimiGlob
    lappend TypeCons IdenGrp1
    lappend TypeCons IdenGrp2
    lappend TypeCons IdenGrp3
    lappend TypeCons IdenGrp1Gris
    lappend TypeCons IdenGrp2Gris
    lappend TypeCons IdenGrp3Gris
    lappend TypeCons InterG12
    lappend TypeCons InterG13
    lappend TypeCons InterG23
    lappend TypeCons InterG12Gris
    lappend TypeCons InterG13Gris
    lappend TypeCons InterG23Gris
    lappend TypeCons PoinGrp1
    lappend TypeCons PoinGrp2
    lappend TypeCons PoinGrp3

    ValsDeCouleurs
    # conservation colors chosen in the Preferences
    if {[info exists Defauts(CouleursCons)]} {
	foreach {k v} $Defauts(CouleursCons) {
	    set Couleurs($k) $v
	}
    }
    
    #  Following colors are Tk colors
    set Couleurs(Stock) {red blue yellow green1 magenta orange cyan brown ForestGreen pink goldenrod SeaGreen coral violet khaki NavyBlue salmon sienna turquoise LimeGreen maroon SpringGreen MediumBlue IndianRed DimGray LightGray gray}
    #set Couleurs(Stock) {red blue yellow green1 magenta orange cyan brown forest_green pink goldenrod sea_green coral violet khaki navy_blue salmon sienna turquoise lime_green maroon spring_green medium_blue indian_red dim_gray light_gray gray}

    return
}



proc ValsDeCouleurs {} {
    global Couleurs
    set Couleurs(IdenGlob) "white black"
    set Couleurs(ConsGlob) "white DimGray"
    set Couleurs(SimiGlob) "black LightGray"
    set Couleurs(IdenGrp1) "black red"
    set Couleurs(IdenGrp2) "black blue"
    set Couleurs(IdenGrp3) "black yellow"
    set Couleurs(IdenGrp1Gris) "red LightGray"
    set Couleurs(IdenGrp2Gris) "blue LightGray"
    set Couleurs(IdenGrp3Gris) "yellow LightGray"
    set Couleurs(InterG12) "black magenta"
    set Couleurs(InterG13) "black coral"
    set Couleurs(InterG23) "black green"
    set Couleurs(InterG12Gris) "magenta LightGray"
    set Couleurs(InterG13Gris) "coral LightGray"
    set Couleurs(InterG23Gris) "green LightGray"
    set Couleurs(PoinGrp1) "red white"
    set Couleurs(PoinGrp2) "blue white"
    set Couleurs(PoinGrp3) "yellow white"
}


#
# Routines for me !
if {[info exists env(USER)] && $env(USER) eq "moumou"} {
    proc tkerror {args} {
	puts ">>>>>>>>>>"
	puts "$args"
	puts "<<<<<<<<<<"
	
	return
    }
    
    proc ::bgerror {msg} {
	global errorInfo
	
	set old_errorInfo $errorInfo
	if {[info exists ::env(USER)]} {
	    set user $::env(USER)
	} else {
	    set user "unknown"
	}
	
	if  {[TypeAli] eq "pasdali"} {
	    set file ""
	} else {
	    set file $::Defauts(Fichier[TypeAli])
	}
	
	if {$user eq "moumou"} {
	    if {$::tcl_platform(platform) eq "windows"} {
		console show
	    }

	    puts "\n========================="
	    puts "Msg:\n$msg\n"
	    puts "\nEerrorInfo\n$::errorInfo"
	    puts "=========================\n"
	    bell
	} else {
	    set msg "[DonneDateEtHeure]
File : $file		 
       
$::erro	rInfo
"	
	    catch {send_simple_message luc.moulinier@unistra.fr localhost "\[Bug-Ordalie\] $user: $err" $msg}
	}
	
	#set errorInfo $old_errorInfo
	#Old_bgerror $err
	
	return
    }
}


proc logError {var tmp tmp} {
    global $var
    
    set old_errorInfo $errorInfo
    if {[info exists ::env(USER)]} {
	set user $::env(USER)
    } else {
	set user "unknown"
    }
    
    if  {[TypeAli] eq "pasdali"} {
	set file ""
    } else {
	set file 
    }

    if {$user eq "moumou"} {
	puts "\n========================="
	puts $::errorInfo
	puts "=========================\n"
    } else {
	set msg "[DonneDateEtHeure]
File : $file 

$::errorInfo
"
	catch {send_simple_message luc.moulinier@unistra.fr localhost "\[Bug-Ordalie\] $user: $err" $msg}
    }
    
    #set errorInfo $old_errorInfo
    #Old_bgerror $err

    return
}


proc ReportErrorMsg {args} {
    lassign $args var tmp tmp
    global $var

    if {[info exists ::env(USER)]} {
	set user $::env(USER)
    } else {
	set user "unknown"
    }
    
    if {$user eq "moumou"} {
	puts "\n=========================="
	puts "ERROR :"
	puts "[set $var]"
	puts "==========================\n"
    } else {
	set msg "[DonneDateEtHeure]
    File : $::Defauts(Fichier[TypeAli])

[set $var]
"
	catch {send_simple_message luc.moulinier@unistra.fr localhost "\[Bug-Ordalie\] $user: $err" $msg}
    }
    
    return
}

    
proc GiveFaireLire {a {b ""} {c ""} } {
    puts "\n== FaireLire =========="
    puts ">>$b<<"
    puts "======================"
    puts ""

    return
}


proc ChangeTkOptions {{back ""} {fore ""}} {
    global Defauts

    if {$back eq ""} {
	set ba [set Defauts(BackAppli)]
    } else {
	set ba $back
    }

    if {$fore eq ""} {
	set fo [set Defauts(ForeAppli)]
    } else {
	set fo $fore
    }

    set ac "#0083ffff0000"
    set bk "#000000000000"

    option add *tearOff                        0
    option add *Toplevel.background            $ba

    option add *Button.background            $ba
    option add *Button.foreground            $fo

    option add *Scale.background             $ba
    option add *Scale.foreground             $fo
    option add *Scale.Relief                 flat

    option add *Menubutton.background        $ba
    option add *Menubutton.foreground        $fo
    option add *Menubutton.activeBackground  $ac

    option add *Menu.background              $ba
    option add *Menu.foreground              $fo
    option add *Menu.activeBackground        $ac
    option add *Menu.activeForeground        $bk

    option add *Checkbutton.background       $ba
    option add *Checkbutton.foreground       $fo
    option add *Checkbutton.activeBackground $ac
    option add *Checkbutton.activeForeground $bk
    option add *Checkbutton.highlightThickness 0
    option add *Checkbutton.Relief flat

    option add *Radiobutton.background       $ba
    option add *Radiobutton.foreground       $fo
    option add *Radiobutton.activeBackground $ac
    option add *Radiobutton.activeForeground $bk
    option add *Radiobutton.highlightThickness 0
    option add *Radiobutton.Relief flat

    option add *Frame.background             $ba
    option add *Labelframe.background        $ba
    option add *Labelframe.foreground        $fo
    option add *Label.background             $ba
    option add *Label.foreground             $fo
    option add *Grid.background              $ba
    option add *Scrollbar.background         $ba

    option add *Dialog.msg.background        yellow

    option add *TCombobox.background         "#ffffffffffff"
    option add *TCombobox.disabledBackground "#ffffffffffff"
    option add *TCombobox.selectBackground   "#ffffffffffff"

    # define styles
    # Pour button
    ttk::style configure vdx.TButton \
	-background black
    ttk::style map vdx.TButton \
	-background [list disabled #d9d9d9  active #ececec] \
	-foreground [list disabled #a3a3a3] \
	-relief [list {pressed !disabled} sunken]

    # Pour combobox
    ttk::style configure vdx.TCombobox \
	-background black \
	-foreground white \
	-arrowcolor white \
	-fieldbackground black \
	-fieldforeground white
    ttk::style map vdx.TCombobox \
	-background [list [list readonly disabled] black] \
	-foreground [list [list readonly disabled] white] \
	-disabledbackground [list [list readonly disabled] black] \
	-disabledforeground [list [list readonly disabled] white] \
	-fieldbackground [list [list readonly disabled] black] \
	-fieldforeground [list [list readonly disabled] white]
    option add *vdx.TCombobox*Listbox.background black
    option add *vdx.TCombobox*Listbox.foreground white

    ttk::style configure vdx.TRadiobutton \
	-background black \
	-foreground white \
	-relief flat \
	-activebackground black \
	-anchor w -justify left

    option add *nwoj.f.fsel.ctyp*Listbox.foreground white
    option add *nwoj.f.fsel.ctyp*Listbox.background black
    option add *nwoj.f.fpai.ctyp*Listbox.foreground white
    option add *nwoj.f.fpai.ctyp*Listbox.background black
    option add *nwoj.f.fsel.cfea*Listbox.foreground white
    option add *nwoj.f.fsel.cfea*Listbox.background black
    option add *nwoj.f.fpai.cfea*Listbox.foreground white
    option add *nwoj.f.fpai.cfea*Listbox.background black
    option add *vdx.TCombobox.background "#ffffffffffff"
    option add *vdx.TCombobox.disabledBackground "#ffffffffffff"
    option add *vdx.TCombobox.selectBackground "#ffffffffffff"

    ttk::style configure FrmBtnCtrl.TFrame \
	-background $Defauts(bgFrmBtnCtrl) \
	-relief sunken

    return
}


proc FichierOrdalieDefauts {} {
    # user preferences file
    global env

    package require platform
    if {[regexp -nocase {^window} [::platform::generic]]} {
	return [file join $env(APPDATA) ordalierc.def]
    }
    if {! [info exists env(HOME)]} {
	return ""
    }

    return [file join $env(HOME) .ordalierc]
}


proc SauveOrdalieDefauts {{fout ""}} {
    # Save the preferences (see ClesPreferences) and the
    # conservation colors. The file starts with 'OrdaliePrefs 1'
    # to recognize it (files written by old versions contained
    # the whole Defauts array and are not read).
    global Defauts Couleurs

    if {$fout eq ""} {
	set fout [FichierOrdalieDefauts]
    }
    if {$fout eq ""} {
	return
    }

    set Lkv [list OrdaliePrefs 1]
    # Mapping depends on the alignment type : MappingProt and
    # MappingDNA are saved instead
    set Le [lsearch -all -inline -not -exact [ClesPreferences all] Mapping]
    lappend Le MappingProt MappingDNA
    foreach e $Le {
	if {[info exists Defauts($e)]} {
	    lappend Lkv $e $Defauts($e)
	}
    }
    if {[info exists Defauts(CouleursCons)]} {
	set Lcc $Defauts(CouleursCons)
    } else {
	set Lcc {}
    }
    if {[info exists ::TypeCons] && [info exists Couleurs(IdenGlob)]} {
	set Lcc {}
	foreach Type [lrange $::TypeCons 0 2] {
	    lappend Lcc $Type $Couleurs($Type)
	}
    }
    if {$Lcc ne {}} {
	set Defauts(CouleursCons) $Lcc
	lappend Lkv CouleursCons $Lcc
    }

    if {[catch {
	set foo [open $fout w]
	puts $foo $Lkv
	close $foo
    } Msg]} {
	puts "Can't save preferences in $fout : $Msg"
    }

    return
}


proc LitOrdalieDefauts {fin} {
    # Read the preferences saved by SauveOrdalieDefauts.
    # Only known keys are taken.
    global Defauts

    if {[catch {set fi [open $fin] ; set Lkv [string trim [read $fi]] ; close $fi}] || \
	    [catch {llength $Lkv} n] || $n % 2 || [lindex $Lkv 0] ne "OrdaliePrefs"} {
	# file of an old version : kept aside, replaced by the
	# current defaults
	catch {file rename -force -- $fin $fin.old}
	SauveOrdalieDefauts $fin
	return
    }

    set Lok [lsearch -all -inline -not -exact [ClesPreferences all] Mapping]
    lappend Lok CouleursCons MappingProt MappingDNA
    foreach {k v} [lrange $Lkv 2 end] {
	if {$k in $Lok} {
	    set Defauts($k) $v
	}
    }
    set Defauts(Mapping) [MappingDuType]

    return
}


proc tpxb {} {
    InitLesDefauts
    set k [array names ::Defauts *Bank]
    puts $::Defauts($k)
    puts ""
    set out [EnlevePrefixeBank "ENA|AAC74936|AAC74936.3"]
    puts $out
    exit
}


proc odef {} {
    puts [join [lsort [array names ::Defauts]] \n]
    exit
}


proc MyFaireLire {args} {
    ::old_FaireLire $args "" "yes"

    return
}








