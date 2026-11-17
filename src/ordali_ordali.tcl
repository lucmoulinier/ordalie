

#
# --- ordali_ordali.tcl
#


proc lesso {} {
    set Ls [LesLignesDuFichier lso]
    foreach l $Ls {
	regsub -all { +} [string trim $l] " " l
	set o [lindex [split $l " "] 4]
	while {$o ne "" && [string index $o end] ne "l"} {
	    set o [string range $o 0 end-1]
	    update
	}
	lappend lo $o
    }
    puts [join [lsort $lo] " \\ \n"]

    exit
}


proc CreeLesRBJOVVSurFondGris {} {
    global SDG
    global LongueurTotale
    global ListeDesAcidesAmines
    global ListeDesPiliersDuGroupe
    global ListeDesConsensusDuGroupe
    global LNDG
    global Threshold

    set NbrGrp [expr {[llength $LNDG] - 1}]
    set ListeDesConsensusDuGroupe(grise) ""
    set PremierGroupe [lindex $LNDG 0]
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe($PremierGroupe)]
    lappend LNDG "grise"
    set DernierGrp [expr {[llength $LNDG] - 2}]

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set CGlob [string index [set ListeDesConsensusDuGroupe($PremierGroupe)] $i]

	set bon 0
	if { $CGlob eq "#" || ($CGlob > 5 && $CGlob < 10) } {
	    foreach NomDeGroupe [lrange $LNDG 1 $DernierGrp] {
		set CG [string index [set ListeDesConsensusDuGroupe($NomDeGroupe)] $i]
		set Pilier [lindex [set ListeDesPiliersDuGroupe($NomDeGroupe)] $i]
		set Seuil [CalculeLesSeuils $Pilier $NomDeGroupe]
		set ValEqui 1

		set CGTmp($NomDeGroupe) $CG
		foreach Equiv {[ILMV] [PAGST] [DEQN] [FYW] [KRH]} {
		    set YaCount [CalculePoidsDuPilier2 $Pilier $Equiv $NomDeGroupe $Seuil]
		    if {$YaCount} {
			set CGTmp($NomDeGroupe) $ValEqui
			break
		    } else {
			incr ValEqui
		    }
		}
	    }

	    if {$NbrGrp == 3} {
		set GroupeA [lindex $LNDG 1]
		set GroupeB [lindex $LNDG 2]
		set GroupeC [lindex $LNDG 3]

		set g1 [set CGTmp($GroupeA)]
		set g2 [set CGTmp($GroupeB)]
		set g3 [set CGTmp($GroupeC)]

		set bon [expr {$g1 == $g2} && {$g1 == $g3} && {$g1 > 0} && {$g1 < 6}]
	    }

	    if {$NbrGrp == "2"} {
		set GroupeA [lindex $LNDG 1]
		set GroupeB [lindex $LNDG 2]

		set g1 [set CGTmp($GroupeA)]
		set g2 [set CGTmp($GroupeB)]

		set bon [expr {$g1 == $g2} && {$g1 > 0} && {$g1 < 6}]
	    }

	    if {$NbrGrp == "1"} {
		set GroupeA [lindex $LNDG 1]
		set g1 [set CGTmp($GroupeA)]

		set bon [expr {$g1 > 0} && {$g1 < 6}]
	    }

	    if {$bon} {
		append ListeDesConsensusDuGroupe(grise) $g1
	    } else {
		append ListeDesConsensusDuGroupe(grise) "#"
	    }
	} else {
	    append ListeDesConsensusDuGroupe(grise) "#"
	}

    }

    return
}


# 1 =  I,L,M,V
# 2 =  P,A,G,S,T
# 3 =  D,E,Q,N
# 4 =  F,Y,W
# 5 =  K,R,H

# 6 =  ABC
# 7 =  Orange
# 8 =  Violet
# 9 =  Vert
proc CreeLesSimilaires {{OGlob 0}} {
    global SDG LongueurTotale ListeDesAcidesAmines
    global ListeDesPiliersDuGroupe ListeDesConsensusDuGroupe
    global LNDG Threshold NombreDeGroupes

    set PremierGroupe [lindex $LNDG 0]
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe($PremierGroupe)]
    if {! $OGlob && $NombreDeGroupes > 1} {
	set LesGrps [lrange $LNDG 1 end]
    } else {
	set LesGrps $PremierGroupe
    }

    foreach NomDeGroupe $LesGrps {
	set Consensus [set ListeDesConsensusDuGroupe($NomDeGroupe)]
	set LesPiliers [set ListeDesPiliersDuGroupe($NomDeGroupe)]
	set i -1
	foreach Pilier $LesPiliers {
	    incr i
	    set CG [string index $Consensus $i]
	    if {$CG ne "#"} {
		continue
	    }

	    set Seuil [CalculeLesSeuils $Pilier $NomDeGroupe]
	    set ValEqui 1
	    foreach Equiv {{I L M V} {P A G S T} {D E Q N} {F Y W} {K R H}} {
		set YaCount [CalculePoidsDuPilier2 $Pilier $Equiv $NomDeGroupe $Seuil]
		if {$YaCount} {
		    set CG $ValEqui
		    break
		}
		incr ValEqui
	    }
	    set Consensus [string replace $Consensus $i $i $CG]
	}

	set ListeDesConsensusDuGroupe($NomDeGroupe) $Consensus
    }

    return
}


# 1 =  I,L,M,V
# 2 =  P,A,G,S,T
# 3 =  D,E,Q,N
# 4 =  F,Y,W
# 5 =  K,R,H

proc CreeLesOranges {} {
    global LNOrdali
    global Sequences
    global LNDG
    global ListeDesConsensusDuGroupe
    global ListeDesPiliersDuGroupe
    global LongueurTotale
    global NombreDeGroupes

    set PremierGroupe [lindex $LNDG 0]
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe($PremierGroupe)]
    set Consensus $ConsensusGlobalTous

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set CG [string index $ConsensusGlobalTous $i]

	if {![string compare $CG "#"]} {

	    set GroupeA [lindex $LNDG 1]
	    set GroupeB [lindex $LNDG 2]
	    set GroupeC [lindex $LNDG 3]

	    set ConsA [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeA)] $i]]
	    set ConsB [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeB)] $i]]
	    set ConsC [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeC)] $i]]

	    set A1 [expr {![string compare $ConsA $ConsC]}]
	    set A2 [string compare $ConsA $ConsB]
	    set A3 [regexp {[A-Y]} $ConsA]

	    if {$A1 && $A2 && $A3} {

		set LePilierOppose [lrange [set ListeDesPiliersDuGroupe($GroupeB)] $i $i]

		set BonOrange [expr {![regexp $ConsA $LePilierOppose]}]

		if {$BonOrange} {
		    set CG 7
		} else {
		    set CG "#"
		}
	    }
	}
	set Consensus [string range $Consensus 0 [expr {$i - 1}]]$CG[string range $Consensus [expr {$i + 1}] end]
    }
    set ListeDesConsensusDuGroupe($PremierGroupe) $Consensus

    return
}

proc CreeLesViolets {} {
    global LNOrdali
    global Sequences
    global LNDG
    global ListeDesConsensusDuGroupe
    global ListeDesPiliersDuGroupe
    global LongueurTotale
    global NombreDeGroupes

    set PremierGroupe [lindex $LNDG 0]
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe($PremierGroupe)]
    set Consensus $ConsensusGlobalTous

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set CG [string index $ConsensusGlobalTous $i]

	if {![string compare $CG "#"]} {

	    set GroupeA [lindex $LNDG 1]
	    set GroupeB [lindex $LNDG 2]
	    set GroupeC [lindex $LNDG 3]

	    set ConsA [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeA)] $i]]
	    set ConsB [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeB)] $i]]
	    set ConsC [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeC)] $i]]

	    set A1 [expr {![string compare $ConsA $ConsB]}]
	    set A2 [string compare $ConsA $ConsC]
	    set A3 [regexp {[A-Y]} $ConsA]

	    if {$A1 && $A2 && $A3} {

		set LePilierOppose [lrange [set ListeDesPiliersDuGroupe($GroupeC)] $i $i]

		set BonViolet [expr {![regexp $ConsA $LePilierOppose]}]

		if {$BonViolet} {
		    set CG 8
		} else {
		    set CG "#"
		}
	    }
	}
	set Consensus [string range $Consensus 0 [expr {$i - 1}]]$CG[string range $Consensus [expr {$i + 1}] end]
    }
    set ListeDesConsensusDuGroupe($PremierGroupe) $Consensus

    return
}


proc CreeLesVerts {} {
    global LNOrdali
    global Sequences
    global LNDG
    global ListeDesConsensusDuGroupe
    global ListeDesPiliersDuGroupe
    global LongueurTotale
    global NombreDeGroupes

    set PremierGroupe [lindex $LNDG 0]
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe($PremierGroupe)]
    set Consensus $ConsensusGlobalTous

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set CG [string index $ConsensusGlobalTous $i]

	if {![string compare $CG "#"]} {

	    set GroupeA [lindex $LNDG 1]
	    set GroupeB [lindex $LNDG 2]
	    set GroupeC [lindex $LNDG 3]

	    set ConsA [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeA)] $i]]
	    set ConsB [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeB)] $i]]
	    set ConsC [string toupper [string index [set ListeDesConsensusDuGroupe($GroupeC)] $i]]

	    set A1 [expr {![string compare $ConsB $ConsC]}]
	    set A2 [string compare $ConsA $ConsB]
	    set A3 [regexp {[A-Y]} $ConsB]

	    if {$A1 && $A2 && $A3} {

		set LePilierOppose [lrange [set ListeDesPiliersDuGroupe($GroupeA)] $i $i]

		set BonVert [expr {![regexp $ConsC $LePilierOppose]}]

		if {$BonVert} {
		    set CG 9
		} else {
		    set CG "#"
		}
	    }
	}
	set Consensus [string range $Consensus 0 [expr {$i - 1}]]$CG[string range $Consensus [expr {$i + 1}] end]
    }
    set ListeDesConsensusDuGroupe($PremierGroupe) $Consensus

    return
}


proc CreeLesABC {} {
    global NombreDeGroupes LongueurTotale ListeDesConsensusDuGroupe LNDG

    set NombreDeGroupes [llength $LNDG]
    if {$NombreDeGroupes == 1} {return}

    set PremierGroupe [lindex $LNDG 0]
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe($PremierGroupe)]
    set Consensus $ConsensusGlobalTous

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set CG [string index $ConsensusGlobalTous $i]
	if {$CG eq "#"} {
	    foreach NomDeGroupe [lrange $LNDG 1 end] {
		set Consi [string toupper [string index [set ListeDesConsensusDuGroupe($NomDeGroupe)] $i]]
		if {[regexp {[A-Y]} $Consi]} {
		    set T($Consi) $Consi
		}
	    }

	    set CarEgaux [llength [array name T]]

	    if {$CarEgaux == [expr {$NombreDeGroupes - 1}]} {
		set CG 6
	    } else {
		set CG "#"
	    }

	    if {! [info exists T]} {set T(toto) A}
	    catch [unset T]
	}
	set Consensus [string range $Consensus 0 [expr {$i - 1}]]$CG[string range $Consensus [expr {$i + 1}] end]
    }

    set ListeDesConsensusDuGroupe($PremierGroupe) $Consensus

    return
}


proc CreeLesConservesGlobaux {} {
    global LongueurTotale LNDG ListeDesPiliersDuGroupe ListeDesConsensusDuGroupe

    if {[llength $LNDG] == 1} {
	return
	set PremierGroupe [lindex $LNDG 0]
	set ListeDesConsensusDuGroupe([lindex $LNDG 0]) [set ListeDesConsensusDuGroupe($PremierGroupe)]
	return
    }

    set NouveauConsensusDuGroupe ""
    set ConsensusGlobalTous [set ListeDesConsensusDuGroupe([lindex $LNDG 0])]
    set ConsensusGlobalPremierGroupe [set ListeDesConsensusDuGroupe([lindex $LNDG 1])]

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set ConsensusAvant [string tolower [string index $ConsensusGlobalPremierGroupe $i]]

	set ConsEgaux 0
	if {[string index $ConsensusGlobalTous $i] eq "#"} {
	    foreach NomDeGroupe [lrange $LNDG 2 end] {
		set ConsensusGlobalDuGroupe [set ListeDesConsensusDuGroupe($NomDeGroupe)]
		set Consensus [string tolower [string index $ConsensusGlobalDuGroupe $i]]
		set ConsEgaux [expr {![string compare $ConsensusAvant $Consensus]}]
		if {! $ConsEgaux} {break}
	    }
	}
	if {$ConsEgaux} {
	    append NouveauConsensusDuGroupe $Consensus
	} else {
	    append NouveauConsensusDuGroupe [string index $ConsensusGlobalTous $i]
	}
    }
    set ListeDesConsensusDuGroupe([lindex $LNDG 0]) $NouveauConsensusDuGroupe

    return
}


proc CreeLesConservesDuGroupe {NomDeGroupe} {
    global ListeDesConsensusDuGroupe ListeDesPiliersDuGroupe ListeDesAcidesAmines SDG

    set ConsensusGlobalDuGroupe [set ListeDesConsensusDuGroupe($NomDeGroupe)]
    set NouveauConsensusDuGroupe ""
    set LesPiliers [set ListeDesPiliersDuGroupe($NomDeGroupe)]
    set i 0
    foreach Pilier $LesPiliers {
	set Seuil [CalculeLesSeuils $Pilier $NomDeGroupe]

	foreach aa $ListeDesAcidesAmines {
	    set YaConsSeuil [CalculePoidsDuPilier2 $Pilier $aa $NomDeGroupe $Seuil]

	    if { $YaConsSeuil} {break}
	}

	set ConsensusAvant [string index $ConsensusGlobalDuGroupe $i]
	if {$YaConsSeuil && $ConsensusAvant eq "#"} {
	    set Consensus $aa
	    append NouveauConsensusDuGroupe [string tolower $Consensus]
	} else {
	    set ConsensusAvant [string index $ConsensusGlobalDuGroupe $i]
	    append NouveauConsensusDuGroupe $ConsensusAvant
	}
	incr i
    }

    set ListeDesConsensusDuGroupe($NomDeGroupe) $NouveauConsensusDuGroupe

    return
}


proc LePilierDeReference {aa Pilier} {
    return [string map [list . $aa] $Pilier]
}


proc DebugEcritConsensus {} {
    global ListeDesConsensusDuGroupe
    global LNDG
    global LongueurTotale

    set D 0
    while {$D < $LongueurTotale} {
	set F [expr {$D + 59}]
	foreach NomDeGroupe $LNDG {
	    set L [string range [set ListeDesConsensusDuGroupe($NomDeGroupe)] $D $F]
	    AuLog "[join $L ""] $NomDeGroupe"
	}
	incr D 60

	AuLog " "
    }

    return
}


proc DebugEcritPoints {} {
    global LesPointsDuGroupe
    global LNDG
    global LongueurTotale

    if {[lrange $LNDG end end] == "grise"} {
	set Ng [expr {[llength $LNDG] - 2}]
    } else {
	set Ng [expr {[llength $LNDG] - 1}]
    }

    set D 0
    while {$D < $LongueurTotale} {
	set F [expr {$D + 59}]
	foreach NomDeGroupe [lrange $LNDG 1 $Ng] {
	    set L [string range [set LesPointsDuGroupe($NomDeGroupe)] $D $F]
	    AuLog "[join $L ""] $NomDeGroupe"
	}
	incr D 60

	AuLog " "
    }

    return
}


proc InitComparaison {} {
    global ListeDesSimilarites ListeDesAcidesAmines

    # liste acides amines de Clustal
    set ListeDesAcidesAmines {A B C D E F G H I K L M N P Q R S T V W X Y Z}
    #set ListeDesAcidesAmines {A C D E F G H I K L M N P Q R S T V W Y Z}
    set ListeDesSimilarites {1 2 3 4 5 Z}

    # 1 =  A,I,L,M,V
    # 2 =  P,A,G,S,T
    # 3 =  D,E,Q,N
    # 4 =  F,Y,W
    # 5 =  K,R,H
    #   Z si sequence manquante

    return
}


proc MetDesZDansSequencesDeFragments {} {
    global ListeDesFragments LNOrdali Sequences

    set ider -1
    foreach s $ListeDesFragments {
	set seq [set Sequences($s)]
	regexp -indices {[A-Z]} $seq iprm
	regexp -indices {[A-Z]\.*$} $seq ider
	set iprm [lindex $iprm 0]
	set ider [lindex $ider 0]

	set seq1 [string range $seq 0 [expr {$iprm-1]}]
	set seq2 [string range $seq $iprm $ider]
	set seq3 [string range $seq [expr {$ider+1}] end]

	regsub -all {\.} $seq1 "Z" seq1
	regsub -all {\.} $seq3 "Z" seq3

	set Sequences($s) "$seq1$seq2$seq3"
    }

    return
}


proc InitConsensus {} {
    global ListeDesConsensusDuGroupe LNDG LongueurTotale

    set Cs [string repeat "#" $LongueurTotale]
    unset -nocomplain ListeDesConsensusDuGroupe
    foreach NomDeGroupe $LNDG {
	set ListeDesConsensusDuGroupe($NomDeGroupe) $Cs
    }

    return
}


proc InitPoints {} {
    global LesPointsDuGroupe LNDG LongueurTotale

    unset -nocomplain LesPointsDuGroupe
    set nb [string repeat " " $LongueurTotale]
    foreach NomDeGroupe $LNDG {
	set LesPointsDuGroupe($NomDeGroupe) $nb
    }

    return
}


proc CreeLesPiliers {} {
    global ListeDesPiliersDuGroupe LNDG LongueurTotale SDG Sequences Defauts ListePDB
    
    unset -nocomplain ListeDesPiliersDuGroupe
    if {! [info exists ListePDB]} {
	set ListePDB {}
    }
    set NombreDeGroupes [llength $LNDG]
    if {[lindex $LNDG end] eq "grise"} {
	set DernierGroupe [expr {$NombreDeGroupes-2}]
    } else {
	set DernierGroupe [expr {$NombreDeGroupes-1}]
    }
    set LGrp [lrange $LNDG 0 $DernierGroupe]
    
    foreach NomDeGroupe $LGrp {
	set Ls {}
	
	foreach NSeq [set SDG($NomDeGroupe)] {
	    if {$NSeq in $ListePDB && ! [set Defauts(PDBDansPilier)]} {
		continue
	    }
	    lappend Ls [split [set Sequences($NSeq)] ""]
	}
	
	for {set i 0} {$i < $LongueurTotale} {incr i} {
	    lappend ListeDesPiliersDuGroupe($NomDeGroupe) [list [join [ExtraitListeDeListe $Ls $i] ""]]
	}
    }
    unset Ls
    update

    return
}


proc CreeLesIdentitesDuGroupe {NomDeGroupe} {
    global Threshold LongueurTotale LNDG SDG ListeDesConsensusDuGroupe ListeDesPiliersDuGroupe ListeDesAcidesAmines Defauts

    if {$NomDeGroupe eq "grise" || $NomDeGroupe eq "bidon"} {
	return
    }

    set ConsensusGlobalDuGroupe [set ListeDesConsensusDuGroupe($NomDeGroupe)]
    set NouveauConsensusDuGroupe ""
    set LesPiliers [set ListeDesPiliersDuGroupe($NomDeGroupe)]

    set i 0
    foreach Pilier $LesPiliers {
	set Seuil [CalculeLesSeuils $Pilier $NomDeGroupe $Defauts(ThresholdIden)]
	if {$Seuil != -1.} {
	    foreach aa $ListeDesAcidesAmines {
		set YaCons [CalculePoidsDuPilier2 $Pilier $aa $NomDeGroupe $Seuil]
		if {$YaCons} {break}
	    }
	} else {
	    set YaCons 0
	}
	
	if {$YaCons} {
	    set Consensus $aa
	} else {
	    set Consensus [string index $ConsensusGlobalDuGroupe $i]
	}
	append NouveauConsensusDuGroupe $Consensus
	incr i
    }

    set ListeDesConsensusDuGroupe($NomDeGroupe) $NouveauConsensusDuGroupe

    return
}


proc NbrAcidesAminesAuSeuil {texte ref s} {
    set count [regsub -all "$ref" $texte "" bidon]

    if {$count >= $s} {
	return 1
    } else {
	return 0
    }
}


proc OteConsensusGlobal {} {
    global LNDG
    global ListeDesConsensusDuGroupe
    global SDG
    global NombreDeGroupes

    set DernierGroupe [lindex $LNDG end]
    if {$DernierGroupe != "grise"} {
	return
    }
    set LNDG [lreplace $LNDG end end]
    unset ListeDesConsensusDuGroupe($DernierGroupe)
    set NombreDeGroupes [llength $LNDG]

    return
}


proc StockScoreOrdali {f} {
    global TableauCouleurEtGroupe ScoreMeth LNDG Threshold Defauts

    set sIde "[set Defauts(ThresholdIden)]."
    set sThr "$Threshold."
    set sSim 60.
    set sGrp $sIde
    
    foreach g [ReordonneGroupes $LNDG] {
	set Lv [array names TableauCouleurEtGroupe "*,$g"]
	if {$Lv == {}} {
	    continue
	}
	
	set Lx {}
	foreach v $Lv {
	    lassign [split $v ,] i tmp
	    lappend Lx $i
	}

	#
	# Method Ordali is still running from 0 to n-1
	# columns. All methods runs form 1 to N
	set Lx [lsort -integer $Lx]
	set max -99999.
	set c 0
	foreach i $Lx {
	    while {$c != $i} {
		set ScoreMeth($f,$g,$c) 0
		incr c
	    }
	    switch -regexp -- $TableauCouleurEtGroupe($i,$g) {
		"IdenGlob" {set v $sIde}
		"ConsGlob" {set v $sThr}
		"SimiGlob" {set v $sSim}
		{^CoulG}   {set v $sIde}
	    }
	    set v [expr {int($v)}]
	    set ScoreMeth($f,$g,$i) $v
	    if {$v > $max} {
		set max $v
	    }
	    
	    incr c
	}
	while {$c < [LongueurDeLAlignement]} {
	    set ScoreMeth($f,$g,$c) 0
	    incr c
	}
	set ScoreMeth($f,${g}-min) 0
	set ScoreMeth($f,${g}-max) $max
    }
    
    return
}


proc CreeFeaturesOrdali {{OGlob 0}} {
    global ListeTypesDeFeatures NomTextSeq SDG TableauCouleurEtGroupe ScoreMeth Couleurs Threshold LNDG TabSF Defauts ListePDB

    if {! [info exists ListeTypesDeFeatures]} {
	set ListeTypesDeFeatures {}
    }
    
    # Nom de la feature temporaire (avant validation par
    # SauveConservation, qui retire "tmp" et le suffixe _n) :
    # tmpCons-T<seuil> au premier calcul, puis
    # tmpCons-T<seuil>_2, _3 ... si des features temporaires
    # pour ce seuil existent deja. On ne regarde que ce seuil
    # exactement (T8 ne doit pas compter T80) ; l'ancien code
    # comparait le nom entier a un nombre et donnait
    # "tmpCons-T80_tmpCons-T80".
    set base "tmpCons-T$Threshold"
    set nmax 0
    foreach f $ListeTypesDeFeatures {
	if {$f eq $base} {
	    if {$nmax < 1} {set nmax 1}
	} elseif {[string first "${base}_" $f] == 0} {
	    set n [string range $f [string length "${base}_"] end]
	    if {[string is integer -strict $n] && $n > $nmax} {
		set nmax $n
	    }
	}
    }
    if {$nmax == 0} {
	set ft $base
    } else {
	set ft "${base}_[expr {$nmax + 1}]"
    }
    lappend ListeTypesDeFeatures $ft

    set LesVals [array get TableauCouleurEtGroupe]
    set LesVals [lsort -dictionary -stride 2 -index 0 $LesVals]
    foreach {v b} $LesVals {
	lassign [split $v ,] r Grp 
	
	# if only global conservation is required
	if {$OGlob && $Grp ne "GroupeToutLeMonde"} {
	    continue
	}
	
	if {$Grp eq "grise" || $Grp eq "bidon"} {
	    continue
	}
	
	set start $r
	set stop $r
	set score 0.0
	set note $b
	if {[regexp {^CoulG} $b]} {
	    set n [string range $b 5 end]
	    set col [CouleurO2Ordali [CouleurDuGroupe $n]]
	} else {
	    lassign [set Couleurs($b)] f col 
	}
	set csys "global"
	
	set nl [list "fstart" $start "fstop" $stop "fcolor" $col "fscore" $score "fnote" $note "fcsys" $csys]
	
	foreach n [set SDG($Grp)] {
	    if {[string trim $n] in $ListePDB && ! [set Defauts(PDBDansPilier)]} {
		continue
	    }
	    lappend TabSF($n,$ft) $nl
	}
    }
    
    set ScoreMeth($ft,Edit) 0
    set ScoreMeth($ft,ListeGrps) $::LNDG
    
    return $ft
}


proc MetAJourFeatures {} {
    if {! [ModeI]} {
	return
    }

    set ft [CreeFeaturesOrdali]
    DetruitBoutonsOrdali
    AfficheBoutonsFeatures

    return
}


proc StockNomsSeqsOrdre {ft {q "nothing"}} {

    global OldNomsSeqsOrdre
    global LNOrdali

    switch $q {
	"clear"   {catch {unset OldNomsSeqsOrdre($ft)}}
	"get"     {return [set OldNomsSeqsOrdre($ft)]}
	"nothing" {set OldNomsSeqsOrdre($ft) $LNOrdali}
    }

    return
}


proc PrepareRunOrdali {} {
    global TypeText TypeCons Couleurs Cons LNDG NombreDeGroupes Defauts Threshold

    if {[TypeAli] eq "pasdali"} {
	FaireLire "Please load an alignment first !"
	return
    }
    if {[InSeqlabMode]} {
	FaireLire "Leave [string totitle [QuelMode]] mode first !"
	return
    }
    
    set method $Cons(Method)
    if {! [ModeI]} {
	set method [set Defauts(MethodeConservation)]
    }
    LesDefauts MethodeConservation $method

    set mode [QuelMode]
    if {$mode eq "feature"} {
	ColorieSelonFeature "Clear"
    }
    
    InitCouleursGroupes
    InitPoints
    CreeLesPiliers
    
    if {$Cons(OnlyGlobal)} {
	set OGlob "GroupeToutLeMonde"
    } else {
	set OGlob ""
    }
    
    switch $method {
	"Wang" -
	"Caffrey" -
	"Capra" -
	"Karlin" -
	"Peivar" -
	"Kabat" -
	"JSD" -
	"Liu" -
	"Liu2" -
	"Williamson" -
	"Ranganathan" -
	"BILD" -
	"Shannon" {
	    set cmd "RunMethode $method $OGlob"
	}
	"Threshold" {
	    set cmd "RunOrdali $OGlob"
	}
	"MeanDistances" -
	"Mean Distances" {
	    set cmd "RunMethode MeanDistance $OGlob"
	}
	"VectorNorm" -
	"Vector Norm" {
	    set cmd "RunMethode VectorNorm $OGlob"
	}
	"Multi" {
	    set cmd "RunMethode Cluster $OGlob"
	}
    }

    set ft [eval $cmd]

    EcritLeBilanConservation $ft

    return $ft
}


proc RunOrdali {{OGlob ""}} {
    global Threshold ListeDesConsensusDuGroupe SDG LNDG NombreDeSequences Defauts NombreDeGroupes

    FaireAttendre "Please wait ....\nComputing residue conservation with threshold method ...."

    set NomDuGroupeToutLeMonde "GroupeToutLeMonde"
    
    OteConsensusGlobal
    InitConsensus
    InitPoints
    set NombreDeGroupes [llength $LNDG]
    set LesGroupes [lrange $LNDG 1 end]

    if {$OGlob ne ""} {
	set OGlob 1
	CreeLesIdentitesDuGroupe GroupeToutLeMonde
	CreeLesConservesDuGroupe GroupeToutLeMonde
	CreeLesConservesGlobaux
	set OGlob 1
    } else {
	set OGlob 0
	CreeLesIdentitesDuGroupe $NomDuGroupeToutLeMonde
	foreach NomDeGroupe $LesGroupes {
	    set ListeDesConsensusDuGroupe($NomDeGroupe) \
		[set ListeDesConsensusDuGroupe($NomDuGroupeToutLeMonde)]
	}
	
	foreach NomDeGroupe $LesGroupes {
	    CreeLesIdentitesDuGroupe $NomDeGroupe
	}
	
	if {$NombreDeGroupes <= 4} {
	    CreeLesABC
	}
	
	if {$NombreDeGroupes == 1} {
	    CreeLesConservesDuGroupe $NomDuGroupeToutLeMonde
	} else {
	    foreach NomDeGroupe $LesGroupes {
		CreeLesConservesDuGroupe $NomDeGroupe
	    }
	}
	
	if {$NombreDeGroupes == 4} {
	    CreeLesOranges
	    CreeLesViolets
	    CreeLesVerts
	}	
    }

    CreeLesSimilaires $OGlob
    CreeLesConservesGlobaux
    CreeLesPoints
    CreeLesRBJOVVSurFondGris
    if {[regexp "ord" [set Defauts(TypeDeGroupesACreer)]]} {
	ColorieAlignement
    } else {
	ColorieAlignementSecator
    }
    set ft [CreeFeaturesOrdali $OGlob]
    StockScoreOrdali $ft
    AppliqueFeature $ft
    EcritLeBilanConservation $ft
    if {[set Defauts(AffSS)]} {
	MontreStrSecDansAlignement
    }

    FaireLaSuite

    return $ft
}


proc EcritLeBilanConservation {ft} {
    global Defauts TabSF Couleurs TypeCons TypeText LNDG

    set NbGrp [expr {[llength $LNDG]-2}]
    set LesVals {}
    set LesCpl [array get TabSF "*,$ft"]
    foreach {s e} $LesCpl {
	set LesVals [concat $LesVals $e]
    }
    set LesVals [lsort -unique $LesVals]

    AuLog ""
    AuLog "Ordali results summary : Residues between braces are Ordali points"
    AuLog "========================"
    AuLog "Method : $ft"

    set aecrire ""
    foreach t $TypeCons {
	set NP 0
	set NA 0

	set Lidx [lsearch -all -regexp $LesVals $t]
	foreach idx $Lidx {
	    set f [lindex $LesVals $idx]
	    DecortiqueUneFeature $f dg fg col score note

	    if {[EstCeUnPoint $dg $t]} {
		set lav "($dg)"
		incr NP
	    } else {
		set lav $dg
		incr NA
	    }
	    if {$aecrire eq ""} {
		set nsep [expr {19-[string length [set TypeText($t)]]}]
		set entete "[set TypeText($t)] [string repeat "." $nsep]:"
		set aecrire "$entete $lav"
	    } else {
		set lg [expr {[string length $aecrire]+[string length " ,$lav"]}]
		set nnl [regsub "\n" $aecrire "" tmp]
		if {$lg-$lg*$nnl > 80} {
		    append aecrire "\n ,$lav"
		} else {
		    append aecrire " ,$lav"
		}
	    }
	}
	if {$aecrire ne ""} {
	    AuLog $aecrire
	    set aecrire ""
	}
    }

    return
}


proc DefinitionLookups {ordre} {

    global TypeCons
    global lookupGrp
    global lookupCns
    global lookupInt
    global LNDG

    if {[info exist lookupGrp]} {
	unset lookupGrp
	unset lookupCns
	unset lookupInt
    }

    set Grp1 [lindex $LNDG [string index $ordre 0]]
    set Grp2 [lindex $LNDG [string index $ordre 1]]
    set Grp3 [lindex $LNDG [string index $ordre 2]]

    set lookupGrp(0) 0
    set lookupGrp(1) $Grp1
    set lookupGrp(2) $Grp2
    set lookupGrp(3) $Grp3

    set lookupOrd(1) [string index $ordre 0]
    set lookupOrd(2) [string index $ordre 1]
    set lookupOrd(3) [string index $ordre 2]

    set g1 [string index $ordre 0]
    set g2 [string index $ordre 1]
    set g3 [string index $ordre 2]

    if {$g1 > $g2} {
	set p1 "$g2$g1"
    } else {
	set p1 "$g1$g2"
    }
    if {$g2 > $g3} {
	set p2 "$g3$g2"
    } else {
	set p2 "$g2$g3"
    }
    if {$g1 > $g3} {
	set p3 "$g3$g1"
    } else {
	set p3 "$g1$g3"
    }

    if {[string index $p1 0] == 2} {
	set lookupInt(9) 8
    } else {
	if {[string index $p1 1] == 2} {
	    set lookupInt(8) 8
	} else {
	    set lookupInt(7) 8
	}
    }

    if {[string index $p2 0] == 2} {
	set lookupInt(9) 9
    } else {
	if {[string index $p2 1] == 2} {
	    set lookupInt(8) 9
	} else {
	    set lookupInt(7) 9
	}
    }

    if {[string index $p3 0] == 2} {
	set lookupInt(9) 7
    } else {
	if {[string index $p3 1] == 2} {
	    set lookupInt(8) 7
	} else {
	    set lookupInt(7) 7
	}
    }

    foreach tp $TypeCons {
	if {[string first "InterG" $tp] != 0} {
	    set lookupCns($tp) $tp
	} else {
	    set g1 [string index $tp 6]
	    set g2 [string index $tp 7]
	    set ng1 [set lookupOrd($g1)]
	    set ng2 [set lookupOrd($g2)]

	    if {$ng1 > $ng2} {
		set ngs "$ng2$ng1"
	    } else {
		set ngs "$ng1$ng2"
	    }

	    set newtp "InterG$ngs[string range $tp 8 end]"
	    set lookupCns($tp) $newtp
	}
    }

    return
}


proc AssigneLePoint {aa NmGrp pos} {
    global LNDG ListeDesPiliersDuGroupe

    set aa [string toupper $aa]
    set YaPoint 1

    foreach groupe [lrange $LNDG 1 end] {
	if {[string compare $groupe $NmGrp] && $YaPoint} {
	    set PilierCompare [lrange [set ListeDesPiliersDuGroupe($groupe)] $pos $pos]
	    set YaPoint [expr {![regexp $aa $PilierCompare]}]
	}
    }

    return $YaPoint
}


proc CreeLesPoints {} {
    global ListeDesConsensusDuGroupe LNDG LesPointsDuGroupe LongueurTotale ListeDesPiliersDuGroupe

    if {[lindex $LNDG end] == "grise"} {
	set DernierGroupe [expr {[llength $LNDG] - 2}]
	set NbrGrp [expr {[llength $LNDG] - 2}]
	if {$NbrGrp <= 1} {return}
    } else {
	set DernierGroupe [expr {[llength $LNDG] - 1}]
	set NbrGrp [expr {[llength $LNDG] - 1}]
    }

    if {$NbrGrp == 3} {
	set NmGrp1 [lindex $LNDG 1]
	set NmGrp2 [lindex $LNDG 2]
	set NmGrp3 [lindex $LNDG 3]
    }

    set ConsensusGlobal [set ListeDesConsensusDuGroupe([lindex $LNDG 0])]

    for {set i 0} {$i < $LongueurTotale} {incr i} {
	set ConsGlob [string index $ConsensusGlobal $i]
	if {$NbrGrp == 3} {
	    if {$ConsGlob == "7"} {
		set LesPointsDuGroupe($NmGrp1) [string replace [set LesPointsDuGroupe($NmGrp1)] $i $i "*"]
		set LesPointsDuGroupe($NmGrp3) [string replace [set LesPointsDuGroupe($NmGrp3)] $i $i "*"]
		set grp [lindex $LNDG 2]
		set CG [string index [set ListeDesConsensusDuGroupe($grp)] $i]
		if {[regexp {[A-Ya-y]} $CG]} {
		    set GroupeOppose $NmGrp1
		    set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
		    set BonPoint1 [expr {![regexp [string toupper $CG] $LePilierOppose]}]
		    set GroupeOppose $NmGrp3
		    set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
		    set BonPoint3 [expr {![regexp [string toupper $CG] $LePilierOppose]}]
		    if {$BonPoint1 && $BonPoint3} {set LesPointsDuGroupe($NmGrp2) [string replace [set LesPointsDuGroupe($NmGrp2)] $i $i "*"]}
		}
	    }

	    if {$ConsGlob == "8"} {
		set LesPointsDuGroupe($NmGrp1) [string replace [set LesPointsDuGroupe($NmGrp1)] $i $i "*"]
		set LesPointsDuGroupe($NmGrp2) [string replace [set LesPointsDuGroupe($NmGrp2)] $i $i "*"]
		set grp [lindex $LNDG 3]
		set CG [string index [set ListeDesConsensusDuGroupe($grp)] $i]
		if {[regexp {[A-Ya-y]} $CG]} {
		    set GroupeOppose $NmGrp1
		    set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
		    set BonPoint1 [expr {![regexp [string toupper $CG] $LePilierOppose]}]
		    set GroupeOppose $NmGrp2
		    set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
		    set BonPoint2 [expr {![regexp [string toupper $CG] $LePilierOppose]}]
		    if {$BonPoint1 && $BonPoint2} {set LesPointsDuGroupe($NmGrp3) [string replace [set LesPointsDuGroupe($NmGrp3)] $i $i "*"]}
		}
	    }

	    if {$ConsGlob == "9"} {
		set LesPointsDuGroupe($NmGrp2) [string replace [set LesPointsDuGroupe($NmGrp2)] $i $i "*"]
		set LesPointsDuGroupe($NmGrp3) [string replace [set LesPointsDuGroupe($NmGrp3)] $i $i "*"]
		set grp [lindex $LNDG 1]
		set CG [string index [set ListeDesConsensusDuGroupe($grp)] $i]

		if {[regexp {[A-Ya-y]} $CG]} {
		    set GroupeOppose $NmGrp2
		    set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
		    set BonPoint2 [expr {![regexp [string toupper $CG] $LePilierOppose]}]
		    set GroupeOppose $NmGrp3
		    set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
		    set BonPoint3 [expr {![regexp [string toupper $CG] $LePilierOppose]}]
		    if {$BonPoint2 && $BonPoint3} {set LesPointsDuGroupe($NmGrp1) [string replace [set LesPointsDuGroupe($NmGrp1)] $i $i "*"]}
		}
	    }
	}

	if {$ConsGlob != "7" && $ConsGlob != "8" && $ConsGlob != "9"} {
	    foreach grp [lrange $LNDG 1 $DernierGroupe] {
		set BonPoint 1
		set CG [string index [set ListeDesConsensusDuGroupe($grp)] $i]
		if {[regexp {[A-Z]} $CG] && [string index [set LesPointsDuGroupe($grp)] $i] != "*"} {
		    for {set j 1} {$j <= $NbrGrp} {incr j} {
			set grpcou [lindex $LNDG $j]

			if { $grpcou != $grp} {
			    if {$BonPoint} {
				set GroupeOppose [lindex $LNDG $j]
				set LePilierOppose [lindex [set ListeDesPiliersDuGroupe($GroupeOppose)] $i]
				set BonPointTmp [expr {![regexp [string toupper $CG] $LePilierOppose]}]
				set BonPoint [expr {$BonPoint && $BonPointTmp}]
			    }
			}
		    }

		    if {$BonPoint} {
			set LesPointsDuGroupe($grp) [string replace [set LesPointsDuGroupe($grp)] $i $i "*"]
		    }
		}
	    }
	}
    }

    return
}



