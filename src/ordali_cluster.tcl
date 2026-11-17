

#
# --- ordali_cluster.tcl
#



proc DefinitionGroupes {Type {NbGr -1}} {
    global Defauts LNDG SDG

    if {[QuelMode] eq "seqlab"} {
	FaireLire "Not available in Editor !"
	return
    }

    # (secondary structures are on the sequences, the group colors on
    # the names : AffSS is not changed, resetting it left them
    # displayed with the menu item unchecked)
    ColorieNomsSelonPhylum hide

    switch $Type {
	"fichierclu" {
	    set txt "Please wait ...\nComputing Cluspack groups from cluster file"
	    set GrMeth "cluster file"
	}
	"integral" {
	    if {[TypeAli] ni {XML ORD}} {
		FaireLire "This is not a Macsims file !"

		return
	    }
	    set txt "Please wait ...\nRestoring Macsims groups"
	    set GrMeth "taken from Macsims file"
	}
	"ordsecator" {
	    set txt "Please wait ...\nComputing Ordalie groups from secator"
	    set GrMeth "3 ordalie groups with secator"
	}
	"orddpc" {
	    set txt "Please wait ...\nComputing Ordalie groups from DPC"
	    set GrMeth "3 ordalie groups with dpc"
	}
	"secator" {
	    set txt "Please wait ...\nComputing Secator groups"
	    set GrMeth "secator"
	}
	"dpc" {
	    set txt "Please wait ...\nComputing DPC groups"
	    set GrMeth "dpc"
	}
	"zonesecator" {
	    set txt "Please wait ...\nComputing Secator groups using defined zones"
	    set GrMeth "zones with secator"
	}
	"zonedpc" {
	    set txt "Please wait ...\nComputing DPC groups using defined zones"
	    set GrMeth "zones with dpc"
	}
	"fixed" {
	    set txt "Please wait ...\nComputing $NbGr groups using DPC"
	    set GrMeth "fixed number of groups (k-means)"
	}
	"nogroups" {
	    set txt "Clearing clusters"
	}
    }

    FaireAttendre "$txt"

    set rep [CalculeGroupes $Type $NbGr]
    if {$rep ne "1"} {
	FaireLaSuite
	FaireLire "$rep"

	return
    }

    if {! [ModeI]} {
	return
    }

    ClearSelections
    InitConsensus
    InitPoints

    if {[QuelMode] eq "feature"} {
	ColorieSelonFeature "Clear"
    }
    EnleveConservation
    EffaceWNomsWSeqs
    RafraichitAffichage

    if {[QuelMode] eq "cluster"} {
	AfficheZonesSelectionneesCluster
    }

    FaireLaSuite

    puts ""
    puts "LNDG out [llength $LNDG]"
    foreach g [array names SDG] {
	puts "$g [llength $SDG($g)]"
    }

    return
}


proc LogClustering {} {
    global SDG LNDG

    AuLog @begin blob
    AuLog @title New Clustering
    AuLog @text Alignment : [MacCourant name]
    set GrMeth [ClusteringDuMac method]
    AuLog @text Grouping method .........: $GrMeth
    AuLog @text Number of groups ........: [expr {[llength $LNDG] -1}]
    foreach g [lrange $LNDG 1 end] {
	AuLog @text $g : [llength [set SDG($g)]] sequences
	AuLog @text {*}[set SDG($g)]
    }
    AuLog @end

    return
}


proc CalculeGroupes {Type {NbGr -1}} {
    global Defauts Sequences LNOrdali LNDG SDG NomSeqSel

    if {[llength [array names Sequences]] < 3} {
	return "Not enough sequences to apply clustering !"
    }

    if {$Type eq "fixed"} {
	set NbGr [ChoixNbCluster]
	if {$NbGr < 2} {
	    return "Not enough clusters"
	}
    }
    LesDefauts TypeDeGroupesACreer $Type

    unset -nocomplain SDG
    set LNDG {}

    switch $Type {
	"fichierclu" {
	    set FichierClu [set Defauts(FichierClu)]
	    LectureClusters $FichierClu SDG LNDG dpc
	    for {set y 1} {$y <= [llength $LNOrdali]} {incr y} {
		lappend NomSeqSel "$y.0"
	    }
	}
	"integral" {
	    global NomsGrpIntegral LesNomsSeqGrpIntegral

	    InitClustersDuMac
	    if {0} {
		AssigneGroupesIntegral
		set LNDG $NomsGrpIntegral
		array set SDG [array get LesNomsSeqGrpIntegral]
	    }
	    set LReste [set SDG(GroupeToutLeMonde)]
	}
	"ordsecator" {
	    GroupesSecator LNDG SDG ordali
	}
	"orddpc" {
	    GroupesDpc LNDG SDG ordali
	    set GrMeth "3 ordalie groups with dpc"
	}
	"secator" {
	    GroupesSecator LNDG SDG secator
	    set GrMeth "secator"
	}
	"dpc" {
	    GroupesDpc LNDG SDG dpc
	    set GrMeth "dpc"
	}
	"zonesecator" {
	    set LReste [GroupesZones LNDG SDG secator]
	}
	"zonedpc" {
	    set LReste [GroupesZones LNDG SDG dpc]
	    set GrMeth "zones with dpc"
	}
	"fixed" {
	    GroupesDpc LNDG SDG dpc $NbGr
	    set GrMeth "fixed number of groups (k-means)"
	}
	"nogroups" {
	    global TableauCouleurEtGroupe
	    unset -nocomplain TableauCouleurEtGroupe
	    set LNDG {}
	}
    }

    AjouteGroupeToutLeMonde
    if {! [llength $LNDG]} {
	unset -nocomplain SDG
	foreach n $LNOrdali {
	    if {[string trim $n] ne ""} {
		lappend SDG(GroupeToutLeMonde) $n
	    }
	}
	set LNDG "GroupeToutLeMonde"
    }

    if {! [info exists LReste]} {
	set LReste {}
    }
    if {$Type ne "integral"} {
	GroupeRestant SDG LNDG $LReste
    }

    AssignSeqToGroup

    return 1
}


proc AjouteGroupeToutLeMonde {} {
    global SDG LNDG

    # already here
    if {"GroupeToutLeMonde" in $LNDG} {
	return
    }

    set LNDG [linsert $LNDG 0 "GroupeToutLeMonde"]
    set Lt {}
    foreach e [array names SDG] {
	# SDG(Equiv,g) : name of group g, not sequences
	if {[string match "Equiv,*" $e]} {
	    continue
	}
	lappend Lt {*}[set SDG($e)]
    }
    set SDG(GroupeToutLeMonde) $Lt

    return
}


proc FinChoixNbCluster {quoi} {
    if {$quoi eq "dismiss"} {set ::NbGr -1}
    DetruitBoutonsOrdali

    return
}



proc ChoixNbCluster {} {
    global FrmBouton NbGr Defauts

    set mode [set Defauts(dispmode)]
    LesDefauts dispmode "autre"
    DetruitBoutonsOrdali
    set wb $FrmBouton
    set wp "$wb.fchx"
    frame $wp -relief sunken  -bd 2
    pack $wp -side left -expand 1 -fill x -padx 10 -pady 10

    frame $wp.le
    label $wp.le.label \
	-text " Number of Clusters :"
    entry $wp.le.ent \
	-background white \
	-width 5 \
	-textvariable NbGr
    pack $wp.le.label $wp.le.ent -side left
    button $wp.bok \
	-text " OK " \
	-bg green1 \
	-command "FinChoixNbCluster ok"
    button $wp.bds \
	-text "Dismiss" \
	-bg red \
	-command "FinChoixNbCluster dismiss"
    pack $wp.le $wp.bok $wp.bds -side left -expand 1 -pady 20

    MesCouleurs $FrmBouton

    bind $wp.le.ent <Return> {$FrmBouton.fchx.bok invoke}
    tkwait window $wp.bok

    ChangeMode $mode

    return $NbGr
}


proc NettoieLesGroupes {} {
    global LNOrdali LNDG SDG

    foreach g $LNDG {
	set avirer 1
	foreach s [set SDG($g)] {
	    if {$s in $LNOrdali} {
		set avirer 0
		break
	    }
	}
	if {! $avirer} {lappend Lg $g}
    }

    set LNDG $Lg

    return
}


proc AssigneGroupesIntegral {} {
    global TDuGroupeDesSeqs NomsGrpIntegral LesNomsSeqGrpIntegral LNOrdali TabRSF

    unset -nocomplain NomsGrpIntegral LesNomsSeqGrpIntegral

    if {[info exists TabRSF]} {
	AssigneGroupesDuRSF

	return
    }

    set NomsGrpIntegral [list]
    unset -nocomplain LesNomsSeqGrpIntegral
    foreach nom $LNOrdali {
	if {[string trim $nom] eq ""} {continue}
	set grp [set TDuGroupeDesSeqs($nom)]
	lappend NomsGrpIntegral $grp
	lappend LesNomsSeqGrpIntegral($grp) $nom
    }
    set NomsGrpIntegral [lsort -unique $NomsGrpIntegral]

    return
}


proc AssigneGroupesDuRSF {} {

    global NomsGrpIntegral
    global LesNomsSeqGrpIntegral
    global LNOrdali
    global TabRSF

    set NomsGrpIntegral {}
    foreach nom $LNOrdali {
	if {! [info exists TabRSF($nom,group)]} {continue}
	set grp [set TabRSF($nom,group)]
	if {[lsearch $NomsGrpIntegral "Group$grp"]==-1} {
	    lappend NomsGrpIntegral "Group$grp"
	}
	lappend LesNomsSeqGrpIntegral(Group$grp) $nom
    }

    return
}


proc CreeLeTfaDesZones {{FilOut ""} {nmgrp ""}} {
    global ZoneClusterisation

    set LVide [AlignementDesSelections $ZoneClusterisation SAli]

    foreach {n s} $SAli {
	lappend LesNoms $n
	lappend LesSequences $s
    }

    if {! [llength $LesNoms]} {
	set ok 0
    } else {
	EcritLeTfa $FilOut $LesNoms $LesSequences
	set ok 1
    }

    return [list $ok $LVide]
}


proc GroupeRestant {as al LR} {
    upvar $as SG
    upvar $al LG
    global LNOrdali

    # Donne toutes les sequences qui ne sont dans aucun groupe :
    # - n'ont pas ete selectionnees pour clustering
    # - ont ete mises dans le groupe poubelle (LR : pas de
    #   residu dans la zone clusterisee)
    # Toutes les sequences affichees doivent se retrouver
    # dans un groupe, sinon elles disparaissent de l'affichage.

    foreach g $LG {
	if {! [info exists SG($g)]} {continue}
	foreach n [set SG($g)] {
	    set TDansGrp($n) 1
	}
    }

    # take the rest
    set Laisse [list]
    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n ne "" && ! [info exists TDansGrp($n)]} {
	    lappend Laisse $n
	}
    }
    if {[llength $Laisse]} {
	lappend LG "GroupSeqOut"
	set SG(GroupSeqOut) $Laisse
	#puts "===> GroupeRestant \n[join $Laisse \n]"
    }

    return
}


proc GroupesZones {aL aT quoi {NbGr -1}} {
    upvar  $aL NomsGrp
    upvar  $aT LesNomsSeqGrp
    global ZoneSelect ZoneClusterisation

    catch {unset NomsGrp}
    catch {unset LesNomsSeqGrp}
    set ZoneClusterisation $ZoneSelect

    set LReste [AlignementDesSelections $ZoneClusterisation SAli]

    if {! [llength $SAli]} {
	puts "GroupesZones : Pb creation ali selections"
	return
    }

    if {$LReste != {}} {
	puts "GroupesZones : [llength [lindex $LReste 1]] seqs virees, pas de seq"
    }

    if {$quoi eq "dpc"} {
	set nbc secator
	set cm hierar
    } else {
	set nbc dpc
	set cm kmeans
    }
    set Lres [Tclcluspack $SAli -dt alignment -cm $cm -nbc $nbc -fd 0.001]
    ClusterSeqsDeCluspackTcl $Lres LesNomsSeqGrp NomsGrp

    return $LReste
}



proc GroupesDpc {aL aT how {NbGr -1}} {
    upvar $aL NomsGrpDpc
    upvar $aT LesNomsSeqGrpDpc

    unset -nocomplain NomsGrpDpc LesNomsSeqGrpDpc
    if {$how eq "ordali"} {
	set NmG "dpcordali"
	set nbc 3
    } else {
	set NmG "dpc"
	if {$NbGr != -1} {
	    set nbc dpc
	} else {
	    set nbc $NbGr
	}
    }
    set cm kmeans

    set LReste [AlignementDesSelections "" SAli]
    if {! [llength $SAli]} {
	puts "GroupesZones : Pb creation ali selections"
	return
    }

    if {$LReste != {}} {
	puts "GroupesZones : [llength [lindex $LReste 1]] seqs virees, pas de seq"
    }

    set Lres [Tclcluspack $SAli -dt alignment -cm $cm -nbc $nbc -fd 0.001]
    ClusterSeqsDeCluspackTcl $Lres LesNomsSeqGrpDpc NomsGrpDpc

    return $LReste
}


proc GroupesSecator {aL aT how} {
    upvar  $aL NomsGrpSecator
    upvar  $aT LesNomsSeqGrpSecator

    unset -nocomplain NomsGrpSecator LesNomsSeqGrpSecator

    set LReste [AlignementDesSelections "" SAli]

    if {! [llength $SAli]} {
	puts "GroupesZones : Pb creation ali selections"
	return
    }

    if {$LReste != {}} {
	puts "GroupesZones : [llength [lindex $LReste 1]] seqs virees, pas de seq"
    }

    set cm hierar
    if {$how eq "ordali"} {
	set NmG "secord"
	set nbc 3
    } else {
	set NmG "secator"
	set nbc secator
    }

    set Lres [Tclcluspack $SAli -dt alignment -cm $cm -nbc $nbc -fd 0.001]
    ClusterSeqsDeCluspackTcl $Lres LesNomsSeqGrpSecator NomsGrpSecator

    return $LReste
}


proc ClusterSeqsDeCluspackTcl {Lres aTDeGrp aLGrp} {
    upvar $aTDeGrp tab $aLGrp Lgrp

    unset -nocomplain tab
    set Lgrp {}

    set i 1
    foreach c $Lres {
	set ngr "Group$i"
	lappend Lgrp $ngr
	set tab($ngr) $c
	incr i
    }

    return 1
}


proc LectureClusters {File atab aNG {NmG "Group"}} {
    upvar $atab tab
    upvar $aNG NomsGroupe

    set NmG "Group"

    # Lit les fichiers issus de CLUSPACK mais
    # SANS LES COORDONNEES !!!

    set LLignes [LesLignesDuFichier $File]
    #    set Ln [split [lindex $LLignes 0] ":"]
    #    set NbrGrp [string trim [lindex $Ln 1]]

    set LLignes [lrange $LLignes 2 end]
    set i 1
    foreach l $LLignes {
	if {[regexp {^Cluster|^Unclustered} $l]} {
	    set NmGrp "$NmG$i"
	    lappend NomsGroupe $NmGrp
	} elseif {$l != ""} {
	    lappend tab($NmGrp) [string trim $l]
	} else {
	    incr i
	}
    }

    return 1
}


proc PhylumClustering {aL aT {Lnoms ""}} {
    global TDesPhylum LNOrdali
    upvar $aL LGP $aT TGP

    # Lnoms : sequences a grouper (par defaut toutes)
    if {$Lnoms eq ""} {
	foreach n $LNOrdali {
	    if {[string trim $n] ne ""} {
		lappend Lnoms [string trim $n]
	    }
	}
    }

    # domaine de vie -> sequences, dans l'ordre de Lnoms
    set Ldom {}
    foreach n $Lnoms {
	if {[info exists TDesPhylum($n)] && [string trim $TDesPhylum($n)] ne ""} {
	    set d [string totitle [string trim $TDesPhylum($n)]]
	} else {
	    set d "Undefined"
	}
	if {$d ni $Ldom} {lappend Ldom $d}
	lappend Tdom($d) $n
    }
    if {[llength $Ldom] < 2} {
	FaireLire "Life Domain information not available !"

	return 0
    }

    # Les groupes doivent s'appeler GroupN (affichage, couleurs,
    # noms de clusters) ; le domaine est garde comme nom du cluster
    unset -nocomplain TGP
    set LGP [list "GroupeToutLeMonde"]
    set TGP(GroupeToutLeMonde) $Lnoms
    set ig 1
    foreach d [lsort -dictionary $Ldom] {
	set g "Group$ig"
	lappend LGP $g
	set TGP($g) $Tdom($d)
	set TGP(Equiv,$g) $d
	incr ig
    }

    return 1
}


proc InitCouleursGroupes {} {
    global LNDG TypeCons TypeText Couleurs

    set NombreDeGroupes [llength $LNDG]
    if {$NombreDeGroupes > 1} {
	set ListeCol [Nuancier $NombreDeGroupes]
	set i 1
	foreach col $ListeCol {
	    lappend TypeCons "CoulG$i"
	    set TypeText(CoulG$i) "Identity Group $i"
	    set Couleurs(CoulG$i) "$col black"

	    incr i
	}
    }

    return
}


proc CouleurDuGroupe {n} {
    global Lookup_Couleurs Couleurs

    set col "cyan"
    if {$n <= [llength [set Couleurs(Stock)]]} {
	set col [lindex [set Couleurs(Stock)] [expr {$n-1}]]
    } else {
	foreach c [array names Lookup_Couleurs] {
	    if {[lsearch [set Couleurs(Stock)] $c] == -1} {
		set col $c
		lappend Couleurs(Stock) $c
		break
	    }
	}
    }

    return $col
}


proc ColorieGroupe {x Grp LeTag} {
    global LNDG TableauCouleurEtGroupe

    set TableauCouleurEtGroupe($x,$Grp) $LeTag

    if {$Grp == "0"} {
	set DernierGrp [expr {[llength $LNDG]-2}]
	for {set g 1} {$g <= $DernierGrp} {incr g} {
	    set TableauCouleurEtGroupe($x,$g) $LeTag
	}
    }

    return
}


proc ColorieAlignementSecator {} {
    global TableauCouleurEtGroupe Couleurs LongueurTotale Defauts LNDG ListeDesConsensusDuGroupe NombreDeGroupes NomTextSeq

    if {[lindex $LNDG end] ne "grise"} {
	return
    }
    set NombreDeGroupes [llength $LNDG]
    if {$NombreDeGroupes == 2} {
	set NbrGrp [expr {$NombreDeGroupes - 1}]
    } else {
	set NbrGrp [expr {$NombreDeGroupes - 1}]
    }

    if {[ModeI]} {
	foreach type [array names Couleurs] {
	    if {$type eq "Stock"} {
		continue
	    }

	    lassign [set Couleurs($type)] fori bori
	    #puts "\ncoul $type\nfori $fori bori $bori"
	    if {[string first "\#" $fori] == 0} {
		set f [CouleurPlusProcheDeTkCol $fori]
	    } else {
		set f [CouleurO2Ordali $fori]
	    }
	    if {[string first "\#" $bori] == 0} {
		set b [CouleurPlusProcheDeTkCol $bori]
	    } else {
		set b [CouleurO2Ordali $bori]
	    }
	    #puts "f $f b $b " ; flush stdout ; update idletasks
	    if {[regexp "CoulG" $type]} {
		set tmp $f
		set f "black"
		set b $tmp
	    }

	    $NomTextSeq tag configure $type -foreground $f -background $b
	}
    }

    if {[ModeI]} {
	set EntreAvecStrSec 0
	if {$Defauts(AffSS)} {
	    CacheStrSecDansAlignement
	    set EntreAvecStrSec 1
	}
    }

    unset -nocomplain TableauCouleurEtGroupe
    set GrTM "GroupeToutLeMonde"
    set ConsensusGlobal [set ListeDesConsensusDuGroupe($GrTM)]

    if {[ModeI]} {
	AfficheLesPoints
    }

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set CGlob [string index $ConsensusGlobal $i]
	if {"#" ne $CGlob} {
	    if {[regexp {[A-Y]} $CGlob]} {
		ColorieGroupe $i $GrTM "IdenGlob"
	    }
	    if {[regexp {[a-y]} $CGlob]} {
		ColorieGroupe $i $GrTM "ConsGlob"
	    }
	    if {[regexp {[1-5]} $CGlob]} {
		ColorieGroupe $i $GrTM "SimiGlob"
	    }
	} else {
	    set j 1
	    foreach g [lrange $LNDG 1 end-1] {
		if {$g eq "bidon"} {continue}
		#		if {$g eq "grise"} {continue}
		set ConsensusGrp [set ListeDesConsensusDuGroupe($g)]
		set CGrp [string index $ConsensusGrp $i]

		if {[regexp {[A-Y]} $CGrp]} {
		    ColorieGroupe $i $g "CoulG$j"
		}
		incr j
	    }
	}
    }

    return
}


proc LanceurMacsim {Fichier} {

    set pab [file rootname $Fichier]
    set Fichier2 "$pab.blocks"
    set Fichier3 "tmp_macsim"

    set Commande "/home/julie/macsim_clustering/macsim_new.tcsh $Fichier $Fichier2 > $Fichier3"

    eval exec $Commande

    if {[file exists $Fichier3]} {
	set LLignes [LesLignesDuFichier $Fichier3]
	foreach l $LLignes {
	    if {! [regexp "GCG" $l]} {continue}
	    set nb [string range [lindex $l 3] 1 7]
	    foreach file [glob -nocomplain $nb*] {
		file delete -force $file
	    }

	    file delete -force $Fichier.tfa
	    file delete -force $Fichier3
	}
    }
    return 1
}


proc CluspackExe {} {
    global tcl_platform OrdBinDir env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./cluspack"
    }
    if {$tcl_platform(platform) ne "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "cluspack"]
	} else {
	    return "/biolo/cluspack/bin/cluspack"
	}
    } else {
	set lexe [file join $OrdBinDir "cluspack.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}


proc LanceurCluspack {File {Type "coordinates"} {Model "dpc"} {Method "kmeans"} {Dist "0.001"} {NbGr -1} args} {

    # OBLIGATOIRE :
    # -------------
    # -dt=coordinates|alignment|distances|similarities
    # -nbc=secator|dpc|aic|bic|number  number=3 pour ordali
    # -cm=ward|kmeans|bionj|mm
    # OPTIONS :
    # ---------
    # -fd=x : filtering_distance
    # -wc : write coordinates"
    # -dt1 ou dt2 : density1 ou -density2
    # NOTE : mixturemodel+aic -> pas de dist !

    if {$Dist ne ""} {set filter "-fd=$Dist"} {set filter ""}
    if {$Model eq "secator" && $Method eq "kmeans"} {set Method "ward"}
    if {$Model eq "dpc" && $NbGr > -1} {set Model $NbGr}

    set Commande "[CluspackExe] $File -dt=$Type -nbc=$Model -cm=$Method $filter $args"

    catch {eval exec $Commande}

    return
}


proc LogInfosClusters {} {
    global LNDG SDG

    # log clustering
    if {[llength $LNDG] > 1} {
	AuLog @begin blob
	AuLog @title Alignment Clustering
	AuLog @begin teletype
	foreach g $LNDG {
	    if {$g eq "GroupeToutLeMonde" || $g eq "all" || $g eq "All"} {continue}
	    AuLog @tele $g : [llength [set SDG($g)]] sequences
	    AuLog @tele {*}[set SDG($g)]
	    AuLog @tele ""
	}
	AuLog @end
	AuLog @end
    }

    return
}


proc MetAJourGroupes {} {
    global SDG LNDG LNOrdali LNSeqlab GroupeDeLaSequence

    if {[InSeqlabMode]} {
	set LNoms $LNSeqlab
    } else {
	set LNoms $LNOrdali
    }
    
    set ig 1
    set Lscou {}
    foreach n $LNoms {
	if {[string trim $n] eq ""} {
	    if {[llength $Lscou]} {
		set gcou "Group${ig}"
		lappend LGrp $gcou
		set LSG($gcou) $Lscou
		set Lscou {}
		incr ig
	    }
	} else {
	    lappend Lscou [string trim $n]
	}
    }
    if {[llength $Lscou]} {
	set gcou "Group${ig}"
	lappend LGrp $gcou
	set LSG($gcou) $Lscou
    }
    
    # Verif qu'on a pas juste change l'ordre dans
    # un groupe
    set ok 1
    foreach g $LGrp {
	if {! [info exists SDG($g)]} {
	    set ok 0
	    break
	}
	if {[llength [lor [set SDG($g)] [set LSG($g)]]]} {
	    set ok 0
	}
    }
    
    # garde les noms de groupe
    set Lnme [list]
    if {$ok && $ig > 2} {
	foreach e [array names SDG "Equiv,*"] {
	    lappend Lnme $e [set SDG($e)]
	}
    }
    
    unset -nocomplain SDG LNDG GroupeDeLaSequence

    set LNDG {}
    if {$ig > 2} {
	set LNDG $LGrp
	array set SDG [array get LSG]

	# Add names if necessary
	if {$Lnme != {} } {
	    foreach {k v} $Lnme {
		set SDG($k) $v
	    }
	} else {
	    foreach g $LNDG {
		set SDG(Equiv,$g) $g
	    }
	}
    }

    set LNDG [linsert $LNDG 0 "GroupeToutLeMonde"]
    set Lt {}
    foreach n $LNoms {
	if {[string trim $n] ne ""} {
	    lappend Lt [string trim $n]
	}
    }
    set SDG(GroupeToutLeMonde) $Lt

    AssignSeqToGroup

    return
}


proc AssignSeqToGroup {} {
    global LNDG SDG GroupeDeLaSequence TDuGroupeDesSeqs

    set Lg [lsearch -all -inline -regexp $LNDG {Group[0-9]+}]
    if {[llength $Lg] > 0} {
	set Lg [lrange $LNDG 1 end]
    } else {
	set Lg "GroupeToutLeMonde"
    }
    foreach g $Lg {
	if {$g eq "GroupeToutLeMonde"} {
	    set ng "Group0"
	} else {
	    set ng $g
	}
	foreach n [set SDG($g)] {
	    set GroupeDeLaSequence($n) $ng
	    set TDuGroupeDesSeqs($n) $ng
	}
    }

    if {! [info exists GroupeDeLaSequence]} {
	foreach n [set SDG(GroupeToutLeMonde)] {
	    set GroupeDeLaSequence($n) "Group0"
	}
    }

    return
}


#trace add variable ListeTypesDeFeatures write Tracelavar
#trace add variable LFeatCourantes write Tracelavar
#trace add execution AfficheNomsEtSeqs leave Tracelaproc
proc Tracelaproc {args} {
    puts "info var [info level -1]"
    catch {puts "info var [info level -2]"}
    catch {puts "info var [info level -3]"}
    return
}
proc Tracelavar {n1 n2 o} {
    puts "\n ############"
    catch {puts "info var -3 : [info level -3]"}
    catch {puts "info var -2 : [info level -2]"}
    puts "info var -1 : [info level -1]"
    puts "$n1 [set $n1]" ; flush stdout
    puts " ############\n"

    return

    set i 0
    while {$i <= [llength $::LNOrdali]} {
	puts "\t[join [lrange $::LNOrdali $i [expr {$i+4}]]]"
	incr i 5
    }
    puts ""
    return
}


proc ExtraitNoDuGroupe {a} {
    if {$a == ""} {return -1}
    set i -1
    set isnb 0
    while {! $isnb && $i < [string length $a]} {
	incr i
	set isnb [string is integer [string index $a $i]]
    }
    if {$isnb} {
	return [string range $a $i end]
    } else {
	return -1
    }
}


proc TrieNomGroupe {a b} {

    set ea [ExtraitNoDuGroupe $a]
    set eb [ExtraitNoDuGroupe $b]

    if {$ea > $eb}  {return 1}
    if {$ea == $eb} {return 0}
    if {$ea < $eb}  {return -1}
}


proc ReordonneGroupes {lg} {
    set lg [lsort -command TrieNomGroupe $lg]
    #set lg [lsort -dictionary $lg]
    foreach g [list GroupeToutLeMonde all] {
	set i [lsearch $lg $g]
	if {$i != -1 && ! $i} {
	    set lg [lreplace $lg $i $i]
	    set lg [linsert $lg 0 $g]
	}
    }

    return $lg
}


proc NouveauGroupe {} {
    global LNDG

    set nmax 0
    foreach g $LNDG {
	if {$g eq "all" || $g eq "GroupeToutLeMonde"} {continue}
	if {[regexp {^Group} $g]} {
	    set n [string range $g 5 end]
	    if {$n > $nmax} {set nmax $n}
	}
    }
    incr nmax
    set ng "Group$nmax"

    return $ng
}


proc ClusterIsoform {} {
    global LNOrdali LSOrdali SDG LNDG

    set SAli [list]
    set Lnom [list]
    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] eq ""} {continue}
	lappend SAli $n $s
	lappend Lnom $n
    }

    CalculeLesPCIGenerique $SAli TPCI
    set Lv [list]
    foreach n1 $Lnom {
	set tmp [list $n1]
	foreach n2 $Lnom {
	    lassign [set TPCI($n1,$n2)] pc l1 l2 lsl
	    lappend tmp [expr {1.-$pc}]
	}
	lappend Lv $tmp
    }

    if {[catch {set Lgr [Tclcluspack $Lv -dt coordinates -cm kmeans -nbc dpc]} Msg]} {
	puts "error"
	exit
    }
    unset -nocomplain SDG LNDG
    #puts [llength $Lgr]
    ClusterSeqsDeCluspackTcl $Lgr SDG LNDG
    #puts [array names SDG]
    AssignSeqToGroup

    LesDefauts Mode Batch
    LesDefauts Exit 1
    LesDefauts DownloadPDB none

    set fout "[file rootname [set ::Defauts(FichierTFA)]].xml"
    #SauveLAlignement XML $fout

    SauveLAlignement XML JLeSauveAs

    exit
}


proc InitPremierGroupe {} {
    global NombreDeGroupes LNDG SDG LNOrdali

    # already here, do nothing
    if {[info exists LNDG] && "GroupeToutLeMonde" in $LNDG} {
	return
    }

    set LNDG {}
    unset -nocomplain SDG

    set LNDG "GroupeToutLeMonde"
    foreach Nom $LNOrdali {
	set Nom [string trim $Nom]
	if {$Nom ne ""} {
	    lappend tmp $Nom
	}
    }
    set SDG(GroupeToutLeMonde) $tmp
    
    set NombreDeGroupes 1
    set NumeroDeGroupe 1

    return
}


proc ReadCluspackOutputFile {file aLgrp aTgrp} {
    upvar $aLgrp Lgrp $aTgrp Tgrp

    set Lf [LesLignesDuFichier $file]
    lappend Lf ""

    set i 0
    foreach l [lrange $Lf 2 end] {
	regsub -all { +} [string trim $l] " " l
	if {[regexp -nocase {^Cluster|^Unclustered} $l]} {
	    incr i
	    set startGrp 1
	    lassign [split $l] tmp num tmp tmp tmp size
	    if {[string is integer -strict $num]} {
		set ngr "gr$num"
	    } else {
		set ngr "gr$i"
	    }

	} elseif {$l ne ""} {
	    set listev [split $l "\t"]
	    set v [lindex $listev 0]
	    lappend Lv $v
	} else {
	    if {$startGrp} {
		set startGrp 0
		set Tgrp($ngr) $Lv
		lappend Lgrp $ngr
	    }
	}
    }

    return
}

proc kir {{method ""}} {
    global Cons ScoreMeth LNDG SDG Defauts

    ReadCluspackOutputFile kir.clu LNDG SDG

    puts "LNDG $LNDG"

    set i -1
    foreach g $LNDG {
	incr i
	if {[string first "Gr" $g] > -1} {
	    continue
	}
	set Lg [split $g ""]
	set i 0
	set c [lindex $Lg $i]
	while {! [string is integer -strict $c]} {
	    incr i
	    set c [lindex $Lg $i]
	}
	set no [string range $g $i end]

	set newG "Group$no"
	set i [lsearch -exact $LNDG $g]
	lset LNDG $i $newG
	set SDG($newG) $SDG($g)
	unset SDG($g)
    }
    puts "LNDG $LNDG"

    MetAJourNomsEtSeqs

    set Cons(OnlyGlobal) 0
    set Cons(PDB) 0
    set Cons(Title) ""
    if {$method eq ""} {
	set method BILD
    }
    set Cons(Method) $method
    set Cons(Entry) ""
    set Cons(ComboSel) ""

    set ft [LanceCalculConservation]
    set Cons(ConsCou) $ft
    SauveConservation

    set file "[file rootname [set Defauts(Fichier[TypeAli])]].scores"
    set o [CheckOpen $file]
    if {$o eq ""} {
	return
    }
    foreach g $LNDG {
	set Lv [array names ScoreMeth "Cons-BILD,$g,*"]
	puts "\ng= $g [llength $Lv]"
	set Lv [lsort -dictionary $Lv]
	set Lout {}
	foreach k $Lv {
	    lassign [split $k ,] tmp tmp i
	    if {[string is integer -strict $i]} {
		lappend Lout $i $ScoreMeth($k)
	    }
	}
	puts "Lout [llength $Lout]"

	set Lres {}
	set k 0
	foreach {i v} $Lout {
	    #puts "$k $i"
	    while {$i > $k} {
		lappend Lres -999.
		incr k
	    }
	    lappend Lres $v
	    incr k
	}
	puts $o "$g;[join $Lres "\;"]"
    }
    close $o

    exit
}


proc kirsley_ShowMethod {root {grp "all"}} {
    set Lf [lsort [glob ${root}_*.csv]]
    if {$Lf == {} } {
	return
    }

    set Lres {}
    set first 0
    foreach f $Lf {
	# methode name
	set idx [string first "_" $f]
	set meth [string range [file rootname $f] $idx+1 end]

	# get scores
	set Ll [LesLignesDuFichier $f]
	if {! $first} {
	    lappend Lres [split [lindex $Ll 0] ,]
	    set first 1
	}
	set iline [lsearch -regexp $Ll "^$grp"]
	if {$iline == -1} {
	    puts "no group named >$grp<"
	    exit
	}
	set Lv [split [lindex $Ll $iline] ,]
	lset Lv 0 $meth
	lappend Lres $Lv
    }

    kirsley_PrintScores $Lres

    return
}


proc kirsley_ShowGroups {file} {
    set Ll [LesLignesDuFichier $file]
    set Lv {}
    foreach l $Ll {
	lappend Lv [split $l ,]
    }

    kirsley_PrintScores $Lv

    return
}


proc kirsley_PrintScores {Lv} {
    set step 10
    set stepm1 [expr {$step - 1}]
    set fmt "%10s | [string repeat "%3d " $step]"
    for {set i 1} {$i < [llength [lindex $Lv 0]]} {incr i $step} {
	foreach l $Lv {
	    set Lval [lrange $l $i $i+${stepm1}]
	    set reste [expr {$step - [llength $Lval]}]
	    lappend Lval {*}[lrepeat $reste 0]
	    puts [format $fmt [lindex $l 0] {*}$Lval]
	}
	puts ""
    }

    exit
}


proc DumpGroupes {} {
    global SDG

    set Lg [array names SDG]
    set Lg [ReordonneGroupes $Lg]
    foreach g $Lg {
	puts "\ngroupe : $g"
	lmap n $SDG($g) {puts ">$n<"}
    }

    return
}



























