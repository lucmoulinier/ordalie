

#
#
# --- ordali_superposition.tcl
#
#

proc DismissSuper {} {
    FinSuper
    DetruitBoutonsOrdali

    return
}


proc FinSuper {} {
    global NomTextSeq PositionInitiale
    return
    bind $NomTextSeq <1>
    bind $NomTextSeq <2>
    bind $NomTextSeq <3>
    bind $NomTextSeq <Shift-1>

    $NomTextSeq tag bind Hel
    $NomTextSeq tag bind H31
    $NomTextSeq tag bind She
    $NomTextSeq tag bind Tur

    return
}


proc FaitSuperposition {{Init 0} {molref ""}} {
    global StrucAVoir EquivalenceZone ListePDB ZoneSuperposition LNOrdali LSOrdali

    if {[ModeI]} {
	FinSuper
    }

    # the coordinates are changed : not under a 3D viewer opened for
    # another instance
    if {! [ViewerPourInstanceCourante "superpose structures"]} {
	return
    }

    if {! [info exists StrucAVoir] || $Init} {
	ChoixPlusieursPDB
    }
    if {[llength $StrucAVoir] == 0} {
	return
    }
    if {[llength $StrucAVoir] == 1} {
	FaireLire "Please choose at least 2 structures to superpose !"
	return
    }
    unset -nocomplain EquivalenceZone

    # Verifie que les bornes des zones a superposees
    # existent dans les differents pdb
    set Nsup [VerifieZonesSuperposition]
    if {$Nsup < 3} {
	if {$Nsup == 0} {
	    set txt "No zone"
	} else {
	    set txt "Too few atomes"
	}
	FaireLire "Beware !! $txt defined to superpose structures !!"
	return
    }

    # Zones verified
    # zones in general coords.
    if {[llength $StrucAVoir] == 1} {
	set molref $StrucAVoir
    } else {
	if {[ModeI] && $molref eq ""} {
	    set molref [ChoixPDBReference]
	} else {
	    set molref [lindex $StrucAVoir 0]
	}
    }
    if {$molref eq ""} {
	return
    }

    FaireAttendre "Please wait ...\nSuperposing structures ..."

    # put reference on top of list
    set i [lsearch $StrucAVoir $molref]
    set StrucAVoir [lreplace $StrucAVoir $i $i]
    set StrucAVoir [linsert $StrucAVoir 0 $molref]

    # Associe zone superposition en coord. generales
    # aux zones en coord. PDB
    foreach mol $StrucAVoir {
	set spdb  [BonNomPDB $mol]
	set MolId [DonneIdDeAccessPDB $mol]
	set chn   [DonneChainDeAccessPDB $mol]

	# boucle sur zone.
	# Exclue prot qui ont pas la zone
	foreach z $ZoneSuperposition {
	    lassign $z x1 x2 Exc

	    if {$mol in $Exc} {
		lappend EquivalenceZone($mol) "exclue"
	    } else {
		lappend EquivalenceZone($mol) [list [list [DonnePosGS $spdb $x1] [DonnePosGS $spdb $x2]] $chn $spdb $Exc $x1 $x2]
	    }
	}
    }

    # ecrit au Log
    AuLog @begin table
    AuLog @title Superposition zones
    AuLog @begin tabular
    AuLog @titlecols [list molecules "positions ranges"]
    lappend ligne "pos. alignment"
    foreach z [set EquivalenceZone($molref)] {
	set x1  [lindex $z 4]
	set x2  [lindex $z 5]
	set chn [lindex $z 1]
	set cx1 [string trim "$chn$x1"]
	set cx2 [string trim "$chn$x2"]

	lappend ligne "$cx1-$cx2"
    }
    AuLog @row $ligne

    foreach m [array names EquivalenceZone] {
	set ligne [list $m]
	foreach z [set EquivalenceZone($m)] {
	    if {[lsearch [lindex $z 0] "exclue"] != -1} {
		lappend ligne "Discarded"
	    } else {
		set x1  [lindex [lindex $z 0] 0]
		set x2  [lindex [lindex $z 0] 1]
		set chn [lindex $z 1]
		if {$chn == "a"} {set chn " "}
		set cx1 [string trim "$chn$x1"]
		set cx2 [string trim "$chn$x2"]

		lappend ligne "$cx1-$cx2"
	    }
	}
	AuLog @row $ligne
    }
    AuLog @end
    AuLog @end

    # Do superposition
    SuperAvecOrdali
    AppliqueSuperposition

    FaireLaSuite

    return
}


proc SuperAvecOrdali {} {
    global Defauts StrucAVoir EquivalenceZone SupRotTrans

    # transformations calculees a ce tour, par molecule_chaine
    unset -nocomplain SupRotTrans

    set molref [lindex $StrucAVoir 0]
    set mref   [DonneIdDeAccessPDB $molref]
    set nref   [BonNomPDB $molref]
    set LAtS   [set Defauts(Super)]

    AuLog @begin table
    AuLog @title Superposition statistics
    AuLog @begin tabular
    AuLog [list @titlecols molecules Natoms {RMSD (A)} {MAx. deviation}]
    AuLog @typecols T I R R

    foreach elt [array names EquivalenceZone] {
	if {$elt eq $molref} {
	    continue
	}

	unset -nocomplain XX W
	unset -nocomplain Rot Trans

	set ii0 1
	set melt [DonneIdDeAccessPDB $elt]
	set LatRef {}
	set LatMov {}
	foreach z0 [set EquivalenceZone($molref)] z [set EquivalenceZone($elt)] {
	    if {$z0 eq "exclue" || $z eq "exclue"} {
		continue
	    }

	    # Traite reference
	    lassign $z0 lx chn0 pref tmp xgr1 xgr2
	    # traite elt a superposer
	    lassign $z  lx chn  pelt tmp xge1 xge2

	    for {set i $xgr1} {$i <= $xgr2} {incr i} {
		# for refernce
		set lxyz0 [$mref CoordsDeAtom $chn0 [DonnePosGS $pref $i] " CA "]
		# for moving struct.
		set lxyz  [$melt CoordsDeAtom $chn [DonnePosGS $pelt $i] " CA "]

		if {$lxyz0 eq "" || $lxyz eq ""} {
		    continue
		}

		lappend LatRef $lxyz0
		lappend LatMov $lxyz

		lassign $lxyz0 XX(1,${ii0},1) XX(2,${ii0},1) XX(3,${ii0},1)
		lassign $lxyz  XX(1,${ii0},2) XX(2,${ii0},2) XX(3,${ii0},2)
		set W($ii0) 1.
		incr ii0
	    }
	}

	incr ii0 -1
	# not enough atoms in common !
	if {$ii0 < 3} {
	    AuLog @row $mref-$elt $ii0 - -
	    puts "$molref -- $elt : only $ii0 CA in common, not superposed"
	    continue
	}

	# compute superposition
	#set resup [COMPARORTHO XX W Rot Trans]
	set resup [kabsch $LatRef $LatMov]
	set rms [format %.2f [lindex $resup 0]]
	set mxd [format %.2f [lindex $resup 1]]
	if {[llength $resup] > 2} {
	    array set Rot [lindex $resup 2]
	    array set Trans [lindex $resup 3]
	}
	
	AuLog @row $mref-$elt $ii0 $rms $mxd
	puts "$molref -- $elt : RMS = $rms ; max dev = $mxd"
	if {[lindex $resup 0] == -1} {
	    continue
	}

	# plusieurs chaines d'une meme molecule peuvent etre superposees :
	# la transformation est gardee par chaine, et non dans l'objet
	set SupRotTrans($elt) [list [array get Rot] [array get Trans]]
    }
    AuLog @end
    AuLog @end

    return
}


proc AppliqueRotation {V R T} {
    set Vt [V_MV $R * $V]
    set NewV [V_VV $Vt + $T]

    return $NewV
}


proc VMT {x y z L t} {
    lassign $L a b c
    return [expr {$x*$a + $y*$b + $z*$c +$t}]
}


proc AppliqueSuperposition {} {
    global StrucAVoir SupRotTrans

    foreach nmch [lrange $StrucAVoir 1 end] {
	# pas de transformation calculee (exclue, trop peu d'atomes ...)
	if {! [info exists SupRotTrans($nmch)]} {
	    continue
	}
	set elt [DonneIdDeAccessPDB $nmch]
	set chn [DonneChainDeAccessPDB $nmch]

	$elt RotTrans $chn {*}$SupRotTrans($nmch)
    }

    # viewer 3D ouvert : redessine avec les nouvelles coordonnees
    if {[info exists ::pgl(wogl)] && [winfo exists $::pgl(wogl)]} {
	$::pgl(wogl) postredisplay
    }

    return
}


proc SuperAvecO {} {
    global EquivalenceZone
    global StrucAVoir

    set mref [lindex $StrucAVoir 0]
    set init 0
    set CmdO {}

    foreach elt [array names EquivalenceZone] {
	if {$elt == $mref} {
	    continue
	}

	set cmdref ""
	foreach z0 [set EquivalenceZone($mref)] z [set EquivalenceZone($elt)] {
	    set xo1  [lindex [lindex $z0 0] 0]
	    set xo2  [lindex [lindex $z0 0] 1]
	    set chn0 [lindex $z0 1]
	    if {$chn0 == "a"} {
		set chn0 ""
	    }

	    set Exclue [expr {[lsearch [lindex $z 0] "exclue"] != -1}]
	    if {$Exclue} {
		continue
	    }

	    set x1   [lindex [lindex $z 0] 0]
	    set x2   [lindex [lindex $z 0] 1]
	    set chn  [lindex $z 1]
	    if {$chn == "a"} {
		set chn ""
	    }

	    if {! $init} {
		set init 1
		set cmdref "lsq_ex $mref $elt $chn0$xo1 $chn0$xo2 ; $chn$x1\n"
	    } else {
		append cmdref " $chn0$xo1 $chn0$xo2 ; $chn$x1\n"
	    }
	}

	if {$cmdref != ""} {
	    append cmdref "; ${elt}2$mref "
	    lappend CmdO $cmdref
	    set cmdref "lsq_mol ${elt}2$mref $elt ;"
	    lappend CmdO $cmdref
	    set init 0
	}
    }

    return $CmdO
}


proc VerifieOverlap {x1 x2} {
    global ZoneSuperposition

    if {! [info exists ZoneSuperposition]} {return 0}
    if {$ZoneSuperposition == {} } {return 0}

    # 1 si [x1,x2] chevauche une des zones
    foreach pos $ZoneSuperposition {
	lassign $pos xl xr
	if {$x1 <= $xr && $x2 >= $xl} {
	    return 1
	}
    }

    return 0
}


proc VerifieZonesSuperposition {} {
    global ZoneSelect ZoneSuperposition ListePDB LNOrdali StrucAVoir Sequences

    if {! [info exists ZoneSelect]} {
	set ZoneSelect [list]
    }
    # fusionne les zones qui se chevauchent ou se touchent (selection
    # repetee, zones de la superposition precedente re-affichees ...)
    # pour ne pas compter plusieurs fois un meme residu
    set ZoneSuperposition [list]
    set Lz [list]
    foreach z $ZoneSelect {
	if {[llength $z] >= 2} {lappend Lz [lrange $z 0 1]}
    }
    foreach z [lsort -integer -index 0 $Lz] {
	lassign $z x1 x2
	if {$x1 > $x2} {lassign [list $x2 $x1] x1 x2}
	lassign [lindex $ZoneSuperposition end] p1 p2
	if {$ZoneSuperposition ne {} && $x1 <= $p2 + 1} {
	    if {$x2 > $p2} {
		lset ZoneSuperposition end 1 $x2
	    }
	} else {
	    lappend ZoneSuperposition [list $x1 $x2]
	}
    }

    # On est en coordonnes generale de l'alignement
    set Lzone [list]
    foreach z $ZoneSuperposition {
	set MolSansZone {}
	lassign $z x1 x2

	set lgt [expr {$x2-$x1+1}]
	set Ltmp [lrepeat $lgt 1]
	set Lres [list]
	# Cherche la sequence du PDB
	foreach molc $StrucAVoir {
	    set mol [BonNomPDB $molc]
	    set seq [set Sequences($mol)]
	    set Lseq [split [string range $seq $x1 $x2] ""]
	    set Lseg [list]
	    foreach e $Lseq {
		lappend Lseg [regexp {[^\.]} $e]
	    }
	    if {1 ni $Lseg} {
		# nom tel que dans StrucAVoir (teste par FaitSuperposition)
		lappend MolSansZone $molc
		puts "==> no zone : $molc $z"
		continue
	    }

	    foreach e $Ltmp v $Lseg {
		lappend Lres [expr {$e & $v}]
	    }
	    set Ltmp $Lres
	    set Lres [list]
	}

	set dep -1 ; set arr -1
	set i 0
	foreach e $Ltmp {
	    if {$e} {
		if {$dep == -1} {
		    set dep [expr {$x1+$i}]
		}
	    } else {
		if {$dep != -1} {
		    set arr [expr {$x1 + $i - 1}]
		    lappend Lzone [list $dep $arr $MolSansZone]
		    set dep -1
		}
	    }
	    incr i
	}
	if {$dep != -1} {
	    lappend Lzone [list $dep $x2 $MolSansZone]
	}
    }

    set ZoneSuperposition $Lzone
    set rtot 0
    foreach z $ZoneSuperposition {
	lassign $z x1 x2 e
	set rtot [expr {$x2-$x1+1 + $rtot}]
    }

    return $rtot
}


proc superpose {} {
    set l1 [LesLignesDuFichier h1c.pdb]
    set l2 [LesLignesDuFichier h2c.pdb]

    set i 1
    foreach e1 $l1 {
	if {[string range $e1 0 2] eq "END"} {continue}
	set W($i) 1.

	set x1 [string trim [string range $e1 30 37]]
	set x2 [string trim [string range $e1 38 45]]
	set x3 [string trim [string range $e1 46 53]]

	foreach j {1 2 3} {
	    set XX($j,$i,1) [set x$j]
	}
	incr i
    }
    # 2eme fichier
    set i 1
    foreach e1 $l2 {
	if {[string range $e1 0 2] eq "END"} {continue}
	set W($i) 1.

	set x1 [string trim [string range $e1 30 37]]
	set x2 [string trim [string range $e1 38 45]]
	set x3 [string trim [string range $e1 46 53]]

	foreach j {1 2 3} {
	    set XX($j,$i,2) [set x$j]
	}
	incr i
    }

    COMPARORTHO XX W R T

    exit
    return
}


proc ANGLES {aB aANGLE aU} {

    upvar $aB B
    upvar $aANGLE ANGLE
    upvar $aU U

    # A partir de la matrice de rotation, calcule les angles d'Euler,
    # l'angle de rotation et coord. spheriques de l'axe, et les cos.
    # directeurs de l'axe
    #
    set PI [Pi]
    #    set PI 3.1415926
    set PIS2 [expr {0.5 * $PI}]
    set DEGRAD [expr {$PI/180.}]
    set DETERM 0.

    set DETERM [S_deterM [M_T B]]

    if {$DETERM <= 0.99 || $DETERM > 1.01} {
	puts " =======> Determinant = $DETERM "
	return -1
    }

    # Angles d'Euler
    set TH2 [ARCTG [expr {sqrt(pow($B(1,3),2)+pow($B(2,3),2))}] $B(3,3)]
    set ZETA [expr {1.-cos($TH2)}]

    if {$ZETA > 0.001 && $ZETA < 1.9999} {
	set TH1 [ARCTG $B(3,1) [expr {-$B(3,2)}]]
	set TH3 [ARCTG $B(1,3) $B(2,3)]
    } else {
	# Valeur arbitraire de TH3
	set TH3 0.
	if {$ZETA <= 0.001} {
	    set TH1 [ARCTG [expr {$B(1,2)-$B(2,1)}] [expr {$B(1,1)+$B(2,2)}]]
	} else {
	    set TH1 [ARCTG [expr {$B(1,2)+$B(2,1)}] [expr {$B(1,1)-$B(2,2)}]]
	}
    }

    set ALPHA    [expr {fmod(($TH1-$PIS2)/$DEGRAD+360.,360.)}]
    set BETA     [expr {$TH2/$DEGRAD}]
    set GAMMA    [expr {fmod(($TH3+$PIS2)/$DEGRAD,360.)}]
    set ANGLE(1) $ALPHA
    set ANGLE(2) $BETA
    set ANGLE(3) $GAMMA

    # ANGLE DE ROTATION ET COS. DIRECTEURS DE L'AXE
    set CKAPPA [expr {0.5*($B(1,1)+$B(2,2)+$B(3,3)-1.)}]
    set AKAPPA [ARCOS $CKAPPA]

    if {$CKAPPA > 0.9999} {
	# ROTATION NULLE. DIRECTION ARBITRAIRE
	set U(1) 0.
	set U(2) 0.
	set U(3) 1.
    } elseif {$CKAPPA < -0.999} {
	# ROTATION PROCHE DE 180
	foreach I {1 2 3} {
	    set ARG [expr {[set B($I,$I)]-$CKAPPA}]
	    if {$ARG < 0.} {
		if {$ARG < -0.01} {
		    puts "sqrt of zero "
		    return -1
		    #		    exit
		}
		set ARG 0.
	    }
	    set U($I) [expr {sqrt($ARG/(1.-$CKAPPA))}]
	}
	# DETERMINER LE SIGNE DU PLUS GRAND COS.DIR.

	set I 1
	foreach K {2 3} {
	    if {[set U($K)] > [set U($I)]} {set I $K}
	}
	set K [expr {($I%3)+1}]
	set L [expr {($K%3)+1}]

	set U($I) [SIGN [set U($I)] [expr {([set B($K,$L)]-[set B($L,$K)])}]]
	set U($K) [SIGN [set U($K)] [expr {[set U($I)]*([set B($K,$I)]+[set B($I,$K)])}]]
	set U($L) [SIGN [set U($L)] [expr {[set U($I)]*([set B($L,$I)]+[set B($I,$L)])}]]
    } else {
	# ROTATION GENERALE

	set DSK [expr {2.*sin($AKAPPA)}]
	foreach I {1 2 3} {
	    set K [expr {($I%3)+1}]
	    set L [expr {($K%3)+1}]
	    set U($I) [expr {([set B($K,$L)]-[set B($L,$K)])/$DSK}]
	}
    }

    #lulu
    set PSIZ [ARCOS $U(3)]
    set PHIZ [ARCTG $U(2) $U(1)]

    set ANGLE(4) [expr {$AKAPPA/$DEGRAD}]
    set ANGLE(5) [expr {$PSIZ/$DEGRAD}]
    set ANGLE(6) [expr {$PHIZ/$DEGRAD}]

    # Ramener a l'hemisphere nord
    if {$ANGLE(5) > 90.} {
	foreach i {1 2 3} {
	    set U($i) [expr {-[set U($i)]}]
	}
	set ANGLE(4) [expr {-$ANGLE(4)}]
	set ANGLE(5) [expr {180.-$ANGLE(5)}]
	set ANGLE(6) [expr {$ANGLE(6)+180.}]
    }

    set ANGLE(6) [expr {fmod(($ANGLE(6)+360.),360.)}]

    return
}


proc SIGN {b a} {

    if {$a < 0.} {
	return [expr {-1.*abs($b)}]
    } else {
	return [expr {abs($b)}]
    }
}


proc ARCTG {B A} {

    set ARCTG 0.

    if {abs($A) >= 0.00001 || abs($B) >= 0.00001} {
	set ARCTG [expr {atan2($B,$A)}]
    }

    return $ARCTG
}


proc ARCOS {A} {
    set absa [expr {abs($A)}]
    if {$absa > 1.} {
	if {$absa > 1.00001} {
	    # pourrait mettre un puts pour dire ....
	}
	if {$absa > 1.01} {
	    puts " =====> ARCOS"
	    return
	    #	    exit
	}
	set A [SIGN 1. $A]
    }

    set LARCOS [expr {acos($A)}]

    return $LARCOS
}


proc SMI3 {aA aAI aD} {
    upvar $aA A
    upvar $aAI AI
    upvar $aD D
    paray A
    foreach I {1 2 3} {
	set K [expr {1+($I+1)%3}]
	set M [expr {1+($I+3)%3}]
	foreach J {1 2 3} {
	    set L [expr {1+($J+1)%3}]
	    set N [expr {1+($J+3)%3}]
	    set B($I,$J) [expr {[set A($L,$K)]*[set A($N,$M)]-[set A($L,$M)]*[set A($N,$K)]}]
	}
    }

    set D 0.
    foreach I {1 2 3} {
	set D [expr {$D+[set A($I,1)]*[set B(1,$I)]}]
    }

    foreach I {1 2 3} {
	foreach J {1 2 3} {
	    set AI($I,$J) [expr {[set B($I,$J)]/$D}]
	}
    }

    return
}


proc ORTHON {aA aAA} {

    upvar $aA A
    upvar $aAA AA

    # ORTHONORMALISATION DE 3 VECTEURS, VECT. LIGNES DE A
    # LA DIRECTION DU 1ER VECT. EST CONSERVEE,
    # AINSI QUE LE PLAN DES DEUX PREMIERS VECTEURS.
    #  B CONTIENT LES COORD. RECIPROQUES
    #
    #     AA EST LE METRIQUE AA(I,J)=PROD.SCAL. A(I)*A(J)
    #
    #    METRIQUE RECIPROQUE

    SMI3 AA BB Delta
    #    set mBB [M_invM [M_T AA]]
    #    T_M BB $mBB 1

    # PROD. VECTORIELS A1*A2 ET A3*A1

    PRVECT 1 A B BB
    PRVECT 3 A B BB

    # COMPOSANTES RECIPROQUES DU 1ER VECTEUR

    foreach J {1 2 3} {
	set B(1,$J) [expr {[set A(1,1)]*[set AA(1,$J)]+[set A(1,2)]*[set AA(2,$J)]+[set A(1,3)]*[set AA(3,$J)]}]
    }

    # NORMALISATION

    foreach I {1 2 3} {
	set ANORM [expr {sqrt([set A($I,1)]*[set B($I,1)]+[set A($I,2)]*[set B($I,2)]+[set A($I,3)]*[set B($I,3)])}]
	if {$ANORM < 1.E-30} {
	    puts " STOP ORTHON"
	    exit
	}
	foreach J {1 2 3} {
	    set A($I,$J) [expr {[set A($I,$J)]/$ANORM}]
	}
    }

    return
}


proc PRVECT {I aA aB aBB} {

    upvar $aA A
    upvar $aB B
    upvar $aBB BB

    #  PRODUIT VECTORIEL DES VECTEURS LIGNES I ET J=I+1 DE LA MATRICE A
    # ( A UN FACTEUR CONSTANT PRES : LE VOL. DE LA MAILLE)

    MOD3 $I J K

    foreach L {1 2 3} {
	MOD3 $L M N
	set B($K,$L) [expr {[set A($I,$M)]*[set A($J,$N)]-[set A($I,$N)]*[set A($J,$M)]}]
    }

    #  COMPOSANTES DIRECTES

    foreach L {1 2 3} {
	set A($K,$L) [expr {[set B($K,1)]*[set BB(1,$L)]+[set B($K,2)]*[set BB(2,$L)]+[set B($K,3)]*[set BB(3,$L)]}]
    }

    return
}


proc MOD3 {I aJ aK} {

    upvar $aJ J
    upvar $aK K

    set J [expr {$I+1}]
    set K [expr {$I+2}]

    if {$J > 3} {set J [expr {$J-3}]}
    if {$K > 3} {set K [expr {$K-3}]}

    return
}



proc MATMATMAT {aA aB aC aPROD} {

    upvar $aA A
    upvar $aB B
    upvar $aC C
    upvar $aPROD PROD

    # Calcule PROD= A * B * C
    # A,B,C etant des matrices 3x3

    foreach i {1 2 3} {
	foreach j {1 2 3} {
	    set dd 0.
	    foreach k {1 2 3} {
		foreach l {1 2 3} {
		    set dd [expr {$dd+[set A($i,$k)]*[set B($k,$l)]*[set C($l,$j)]}]
		}
	    }
	    set D($i,$j) $dd
	}
    }

    foreach i {1 2 3} {
	foreach j {1 2 3} {
	    set PROD($i,$j) [set D($i,$j)]
	}
    }

    return
}


proc jROTATE {aa i j k l s ag ah tau} {
    upvar $aa a
    upvar $ah h
    upvar $ag g

    set g [expr {[set a($i,$j)]}]
    set h [expr {[set a($k,$l)]}]
    set a($i,$j) [expr {$g - $s * ($h + $g * $tau)}]
    set a($k,$l) [expr {$h + $s * ($g - $h * $tau)}]

    return
}


proc jacobi {aa av ad n} {

    upvar $aa a
    upvar $ad d
    upvar $av v

    set ERROR [expr {1.0 / 16777216.0}]
    set converge 0

    # cree la matrice unitaire

    set Un [M_unit]
    T_M v $Un

    for {set ip 0} {$ip < $n} {incr ip} {
	set b($ip) [set a($ip,$ip)]
	set d($ip) [set a($ip,$ip)]
	set z($ip) 0.0
    }

    # iteration pour converger

    set nrot 0
    for {set i 0} {$i < 128} {incr i} {
	set sm 0.0
	for {set ip 0} {$ip < $n - 1} {incr ip} {
	    for {set iq [expr {$ip+1}]} {$iq<$n} {incr iq} {
		set sm [expr {$sm + abs([set a($ip,$iq)])}]
	    }
	}

	if {$sm == 0.0} {
	    set converge 1
	    break
	}

	if {$i < 3} {
	    set thresh [expr {0.2 * $sm / ($n * $n)}]
	} else {
	    set thresh 0.0
	}

	for {set ip 0} {$ip < $n - 1} {incr ip} {
	    for {set iq [expr {$ip+1}]} {$iq<$n} {incr iq} {
		set g [expr {1000000.0 * abs([set a($ip,$iq)])}]
		if {$i > 3 && abs([set d($ip)]) + $g == abs([set d($ip)]) && abs([set d($iq)]) + $g == abs([set d($iq)])} {
		    set a($ip,$iq) 0.0
		} elseif {abs([set a($ip,$iq)]) > $thresh} {
		    set h [expr {[set d($iq)] - [set d($ip)]}]
		    if {(abs($h) + $g) == abs($h)} {
			set t [expr {[set a($ip,$iq)] / $h}]
		    } else {
			set theta [expr {0.5*$h/[set a($ip,$iq)]}]
			set t [expr {1.0 / (abs($theta) + sqrt(1.0 + $theta**2))}]
			if {$theta < 0.0} {
			    set t [expr {-1.*$t}]
			}
		    }
		    set c [expr {1.0 / sqrt(1.0 + $t * $t)}]
		    set s [expr {$t * $c}]
		    set tau [expr {$s / (1.0 + $c)}]
		    set h [expr {$t*[set a($ip,$iq)]}]
		    set z($ip) [expr {[set z($ip)] - $h}]
		    set z($iq) [expr {[set z($iq)] + $h}]
		    set d($ip) [expr {[set d($ip)] - $h}]
		    set d($iq) [expr {[set d($iq)] + $h}]
		    set a($ip,$iq) 0.0

		    for {set j 0} {$j < $ip} {incr j} {
			jROTATE a $j $ip $j $iq $s g h $tau
		    }

		    for {set j [expr {$ip+1}]} {$j < $iq} {incr j} {
			jROTATE a $ip $j $j $iq $s g h $tau
		    }

		    for {set j [expr {$iq+1}]} {$j < $n} {incr j} {
			jROTATE a $ip $j $iq $j $s g h $tau
		    }

		    for {set j 0} {$j < $n} {incr j} {
			jROTATE v $j $ip $j $iq $s g h $tau
		    }

		    incr nrot
		}
	    }
	}

	for {set ip 0} {$ip < $n} {incr ip} {
	    set b(ip) [expr {[set b($ip)] + [set z($ip)]}]
	    set d($ip) [set b($ip)]
	    set z($ip) 0.0
	}
    }

    if { $converge } {
	return $nrot
    } else {
	puts "Error: too many iterations to compute eigen vectors and eigen values."
    }

    return
}


proc kabsch_ordali {XX} {
    set La {}
    set Lb {}
    
    return
}


proc COMPARORTHO {aXX aW aMDeRot aVDeTrans} {
    upvar $aXX XX
    upvar $aW W
    upvar $aMDeRot MDeRot
    upvar $aVDeTrans VDeTrans

    # BUT :
    # LE PROGRAMME ESSAIE DE SUPERPOSER UNE MOL. B A UNE MOL
    # A EM MINIMISANT CHI**2 = SOMME (W*(X'(B)-X(A))**2), OU LA SOMM
    # EST FAITE SUR LES 3 COORDONNEES DE TOUS LES ATOMES COMMUNS.
    # X'(B) EST LA TRANSFORMEE DE X(B) PAR LE DEPLACEMENT
    # A DETERMINER, ET W = PONDERATION.
    #
    # LA METHODE PEUT SERVIR A COMPARER UNE MOLECULE A SA SYMETRIQU
    # (SI UNE MOLECULE SEMBLE ADMETTRE UN ELEMENT DE SYMETRIE NON
    # CRISTALLOGRAPHIQUE, PAR EXEMPLE), AUTREMENT DIT LA MOLECULE B
    # PEUT ETRE IDENTIQUE A A. MAIS DANS CE CAS, LES VALEURS DE CHI**2
    # ET DU NOMBRE DE DEGRES DE LIBERTE DOIVENT ETRE MODIFIEES.
    #
    # LA METHODE EST DECRITE DANS : B. REES, THESE 1969, PP. 90-94.
    #
    #    ROGRAMME REPRIS EN DECEMBRE 1974 (BR)
    #
    #...Mis sous forme de sous-programme ,pour VAX 750, en juin 84
    # Presentation modifiee en janvier 87
    #...Modif. fevrier 89: impression de la matrice en coord. absolues,
    #...et de la translation associee.
    #...Calcul de coordonnees d'un point de l'axe
    # (projection du milieu des barycentres) dans POINTFIXE
    #...Modif. avril 94 : NA transmis en argument.
    #...Ponderation fixee dans le progr. d'appel (sauf cas
    # =0). Attention : W est dimensionne a NAT alors
    # que SIG2 etait dimensionne a (NAT,2).
    #  Cas IOUT=0
    #   Nouvel argument : error
    #   Corrections dans POINTFIXE
    #...Modif. sept. 96 : COMMON/ecarts/
    #...Modif. mars  99 : les ecarts individuels pour les 10000 premiers
    #   atomes sont mis dans COMMON/ecarts/
    #...
    #   ARGUMENTS :
    #
    #	A l'entree :
    #
    # IIN  : Numero logique pour les lectures (non utilise dans cette
    #	version)
    # ====> pas utilise en tcl
    #
    # IOUT : Numero logique du fichier output (0 pour ne rien imprimer)
    # ====> pas utilise en tcl
    #
    # NATC : Nombre d'atomes pour la comparaison
    # ====> pas utilise en tcl
    #
    # NA : Nombre max. d'atomes (dimension de XX, W, NOM)
    # ====> pas utilise en tcl
    #
    # (XX(K,IAT,IMOL)K=1,3,IAT=1,NATC,IMOL=1,2) : coord.
    # pour les deux molecules, les atomes a superposer se corres-
    # pondant deux a deux. A la sortie, XX(K,IAT,2) contient les
    # coord. de la molecule B superposee a A
    #
    # W(IAT) : ponderation 	(par defaut : W=1)
    #
    # IPRINT : Si non nul, la distance apres superposition sera
    #	imprimee atome par atome
    # ====> pas utilise en tcl
    #
    # NOM(IAT) : Nom des atomes (15 caracteres). Pas utilise si
    #	IPRINT=0.
    # ====> pas utilise en tcl
    #
    #	A la sortie :
    #
    #	XBAR(K,IMOL) : coord. des barycentres des deux
    #	molecules
    #
    #	ROT : matrice de la rotation B->A
    #
    #	ANGLE : Valeurs de Alpha,Beta,Gamma et de Kappa,Psi,Phi
    #	pour cette rotation
    #	Kappa :angle de la rotation; Psi,Phi : coord. spheriques;
    #	Alpha,Beta,Gamma : angles d'Euler (convention Crowther)
    #
    #	ERROR : = .false. normalement, .true. si la superposition
    #		n'a pas pu se faire
    #		En outre les coord. d'un point de l'axe de rotation
    #		et le deplacement parallele a l'axe sont transmis
    #		dans le common /HELICON/
    #......
    #
    #
    # AUTRES OPTIONS :
    #	 	   DEFINITION D'UN SYSTEME D'AXES MOLECULAIRE, PAR LA
    #     MATRICE DE TRANSFORMATION ( COORD. MOLECULAIRES EN FONCTION
    #     DES COORDONNEES ABSOLUES (CRISTAL) + CONSTANTE). LES LIGNES DE
    #     LA MATRICE , CHACUNE AVEC LA CONSTANTE CORRESPONDANTE, SONT
    #     DONNEES EN 3 CARTES EN 4 F9.6  (ITRANS=1)
    #
    #                  DONNEE DES BARYCENTRES (CAS DES MOLECULES
    #         CENTROSYMETRIQUES)  (IBAR=1)
    #
    #                  COMPARAISON DE A A L'ENANTIOMORPHE DE B (ISYM=1).
    #
    #		   jPRINT=1 : Impressions detaillees
    #......
    #

    set NATC [llength [array names W]]

    set ITRANS 0
    set ISYM 0
    set ANOM(1) " A  "
    set ANOM(2) " B  "

    set error 0

    set jPRINT 0

    foreach IMOL {1 2} {
	foreach K {1 2 3} {
	    foreach L {1 2 3} {
		set ORTHO($K,$L,$IMOL) 0.
	    }
	    set ORTHO($K,$K,$IMOL) 1.
	}
    }

    set SW 0.
    for {set i 1} {$i <= $NATC} {incr i} {
	set SW [expr {$SW+[set W($i)]}]
    }

    # Si pas de ponderation, prendre 1 par defaut
    if {$SW < 0.0001} {
	for {set i 1} {$i <= $NATC} {incr i} {
	    set W($i) 1.
	}
    }

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set TRANS($K,$L,1) [set ORTHO($K,$L,1)]
	    set TRANS($K,$L,2) [set ORTHO($K,$L,2)]
	}
    }

    foreach I {1 2} {
	foreach K {1 2 3} {
	    set SX($K,$I) 0.
	}
    }

    for {set J 1} {$J <= $NATC} {incr J} {
	foreach I {1 2} {
	    foreach K {1 2 3} {
		set SX($K,$I) [expr {[set SX($K,$I)]+[set W($J)]*[set XX($K,$J,$I)]}]
	    }
	}
    }

    foreach I {1 2} {
	foreach K {1 2 3} {
	    set XBAR($K,$I) [expr {[set SX($K,$I)]/$SW}]
	}
    }

    puts "\n================================="
    puts "Number of superposed atoms = $NATC"
    puts ""
    puts "BARYCENTRES :"

    foreach ii {1 2} {
	puts "$ii [set ANOM($ii)] [format "%6.2f %6.2f %6.2f" [set XBAR(1,$ii)] [set XBAR(2,$ii)] [set XBAR(3,$ii)]]"
    }

    foreach K {1 2 3} {
	set SX($K,1) [expr {[set XBAR($K,1)]-[set XBAR($K,2)]}]
	set SX($K,2) [expr {0.5*([set XBAR($K,1)]+[set XBAR($K,2)])}]
    }

    puts ""
    puts "BA vector     : [format "%6.2f %6.2f %6.2f" [set SX(1,1)] [set SX(2,1)] [set SX(3,1)]]"
    puts "Middle of  AB : [format "%6.2f %6.2f %6.2f" [set SX(1,2)] [set SX(2,2)] [set SX(3,2)]]"

    # soustrait le barycentre
    foreach I {1 2} {
	for {set J 1} {$J <= $NATC} {incr J} {
	    foreach K {1 2 3} {
		set XX($K,$J,$I) [expr {[set XX($K,$J,$I)]-[set XBAR($K,$I)]}]
	    }
	}
    }

    # EXPRESSION DANS LE SYST.D'AXES D''INERTIE'
    foreach IM {1 2} {
	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		set AINER($I,$J,$IM) 0.
	    }
	}

	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		    set AINER($I,$J,$IM) [expr {[set AINER($I,$J,$IM)]-[set W($JAT)]*[set XX($I,$JAT,$IM)]*[set XX($J,$JAT,$IM)]}]
		}
	    }
	}

	foreach I {1 2 3} {
	    set AINER($I,$I,$IM) 0.
	}

	foreach I {1 2 3} {
	    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		set AINER($I,$I,$IM) [expr {\
						[set AINER($I,$I,$IM)] + \
						[set W($JAT)]*(\
								   [set XX(1,$JAT,$IM)]**2 +\
								   [set XX(2,$JAT,$IM)]**2 +\
								   [set XX(3,$JAT,$IM)]**2 -\
								   [set XX($I,$JAT,$IM)]**2)}]
	    }
	}

	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		set AI($I,$J) 0.
	    }
	}

	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		set AI($I,$J) [set AINER($I,$J,$IM)]
	    }
	}

	# Jacobi travaille avec matrices index 0.
	unset -nocomplain AT

	set mAI [M_T AI]
	unset AI
	T_M AI $mAI

	set mV [concat 2 3 3 {*}$mAI]

	mevsvd_br mV evals
	#	jacobi AI AT VV 3

	set mAT {}
	set mV [lrange $mV 3 end]
	for {set i 0} {$i < 3} {incr i} {
	    lappend mAT [lrange $mV [expr {3*$i}] [expr {3*($i+1)-1}]]
	}
	T_M AT $mAT 1

	set mAI [M_T AI]
	unset AI
	T_M AI $mAI 1

	set D [S_deterM [M_T AT]]

	if {$D < 0.} {
	    foreach I {1 2 3} {
		foreach J {1 2 3} {
		    set AT($J,$I) [expr {-1.*[set AT($J,$I)]}]
		}
	    }
	}

	foreach K {1 2 3} {
	    foreach L {1 2 3} {
		set ROT($L,$K) [set AT($K,$L)]
	    }
	}

	set MROT [M_T ROT]

	MULTMAT $MROT TRANS $IM

	for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
	    foreach K {1 2 3} {
		set XI($K,$JAT,$IM) 0.
		foreach J {1 2 3} {
		    if {$IM == 1} {set BT($J,$K) [set AT($J,$K)]}

		    set XI($K,$JAT,$IM) [expr {\
						   [set XI($K,$JAT,$IM)]+\
						   [set AT($J,$K)]*[set XX($J,$JAT,$IM)]}]
		}
	    }
	}
    }

    set CHI2(1) 0.

    foreach IM {1 2} {
	for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
	    foreach J {1 2 3} {
		set XX($J,$JAT,$IM) [set XI($J,$JAT,$IM)]
	    }
	}
    }

    # ROTATIONS ET TESTS EN CHI**2

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set ROT($K,$L) 0.
	}
    }

    foreach I {2 3 4 5} {
	# ON FERME A 350
	# ON PERMUTE LES AXES A CHAQUE ITERATION

	# on ferme a 340

	# Initialise JP !! AU PIF !!

	set JP 0

	foreach IPERM {1 2 3} {
	    foreach IM {1 2} {
		for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		    foreach J {1 2 3} {
			incr JP
			if {$JP-3 > 0} {
			    set JP [expr {$JP-3}]
			}
			set XI($JP,$JAT,$IM) [set XX($J,$JAT,$IM)]
			set ROT($JP,$J) 1.
		    }
		}
	    }

	    foreach J {1 2 3} {
		foreach K {1 2 3} {
		    set B($J,$K) 0.
		    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
			set B($J,$K) [expr {[set B($J,$K)]+[set W($JAT)]*[set XI($J,$JAT,1)]*[set XI($K,$JAT,2)]}]
		    }
		}
	    }

	    foreach L {2 3} {
		if {[set B($L,$L)] < 0} {
		    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
			set XI($L,$JAT,2) [expr {-1.*[set XI($L,$JAT,2)]}]
			set XI(1,$JAT,2) [expr {-1.*[set XI(1,$JAT,2)]}]
		    }

		    foreach J {1 2 3} {
			set ROT(1,$J) [expr {-1.*[set ROT(1,$J)]}]
			set ROT($L,$J) [expr {-1.*[set ROT($L,$J)]}]
			set B($J,1) [expr {-1.*[set B($J,1)]}]
			set B($J,$L) [expr {-1.*[set B($J,$L)]}]
		    }
		}
	    }

	    set CHI2($I) 0.
	    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		foreach J {1 2 3} {
		    set  CHI2($I) [expr {[set CHI2($I)]+[set W($JAT)]*pow(([set XI($J,$JAT,2)]-[set XI($J,$JAT,1)]),2)}]
		}
	    }

	    set CU 1.
	    set CV 1.
	    set CW 1.
	    set SU 0.
	    set SV 0.
	    set SW 0.

	    set DEN [expr {$CW*$B(1,1)+$CV*$SW*$B(1,2)-$SW*$B(2,1)+$CV*$CW*$B(2,2)-$SV*$B(3,2)}]
	    if {$DEN != 0.} {
		set U [expr {atan((-$CV*$SW*$B(1,1)+$CW*$B(1,2)-$CV*$CW*$B(2,1)-$SW*$B(2,2)+$SV*$B(3,1))/$DEN)}]
		set SU [expr {sin($U)}]
		set CU [expr {cos($U)}]
	    }

	    set DEN [expr {-$SU*$SW*$B(1,1)+$CU*$SW*$B(1,2)-$SU*$CW*$B(2,1)+$CU*$CW*$B(2,2)+$B(3,3)}]
	    if {$DEN != 0.} {
		set V [expr {atan(($SW*$B(1,3)+$CW*$B(2,3)+$SU*$B(3,1)-$CU*$B(3,2))/$DEN)}]
		set SV [expr {sin($V)}]
		set CV [expr {cos($V)}]
	    }

	    set DEN [expr {$CU*$B(1,1)+$SU*$B(1,2)-$SU*$CV*$B(2,1)+$CU*$CV*$B(2,2)+$SV*$B(2,3)}]
	    if {$DEN != 0.} {
		set WW [expr {atan((-$SU*$CV*$B(1,1)+$CU*$CV*$B(1,2)+$SV*$B(1,3)-$CU*$B(2,1)-$SU*$B(2,2))/$DEN)}]
		set SW [expr {sin($WW)}]
		set CW [expr {cos($WW)}]
	    }

	    set R(1,1) [expr {$CU*$CW-$SU*$CV*$SW}]
	    set R(1,2) [expr {$SU*$CW+$CU*$CV*$SW}]
	    set R(1,3) [expr {$SV*$SW}]
	    set R(2,1) [expr {-$CU*$SW-$SU*$CV*$CW}]
	    set R(2,2) [expr {-$SU*$SW+$CU*$CV*$CW}]
	    set R(2,3) [expr {$SV*$CW}]
	    set R(3,1) [expr {$SU*$SV}]
	    set R(3,2) [expr {-$CU*$SV}]
	    set R(3,3) $CV

	    # rempli le tableau XX avec coord de mol 1 inchangees et coords
	    # de mol 2 tournees par R

	    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		foreach J {1 2 3} {
		    set XX($J,$JAT,2) 0.
		    foreach K {1 2 3} {
			set XX($J,$JAT,2) [expr {[set XX($J,$JAT,2)]+[set R($J,$K)]*[set XI($K,$JAT,2)]}]
		    }
		}

		foreach J {1 2 3} {
		    set XX($J,$JAT,1) [set XI($J,$JAT,1)]
		}
	    }

	    set MROT [M_T ROT]
	    set MR [M_T R]

	    MULTMAT $MROT TRANS 2
	    MULTMAT $MR TRANS 2

	    T_M R $MR 1
	    T_M ROT $MROT 1
	}

	if {abs([set CHI2($I)]-[set CHI2([expr {$I-1}])])-0.01*[set CHI2($I)] <= 0.} {
	    set CHI02 [set CHI2($I)]
	    break
	}
    }

    if {$I == 5 && abs([set CHI2($I)]-[set CHI2([expr {$I-1}])])-0.01*[set CHI2($I)] > 0.} {
	puts "No convergence of CHI**2"
	set error 0
	return
    }

    set NU [expr {3*$NATC-6}]

    set SW 0.
    set SWD2 0.
    set DMIN 1000000.
    set DMAX 0.

    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
	set D2 0.
	foreach J {1 2 3} {
	    set D2 [expr {$D2+pow(([set XX($J,$JAT,2)]-[set XX($J,$JAT,1)]),2)}]
	}

	set D [expr {sqrt($D2)}]
	set SWD2 [expr {$SWD2+$D2*[set W($JAT)]}]
	set SW [expr {$SW + [set W($JAT)]}]
	if {$D < $DMIN} {set DMIN $D}
	if {$D > $DMAX} {set DMAX $D}
	if {$JAT <= 10000} {set distance($JAT) $D}
    }

    set DRMS [expr {sqrt($SWD2/$SW)}]

    puts [format "CHI**2 = %8.3f for %3d degrees of freedom" $CHI02 $NU]
    puts [format "RMS    = %8.3f , Max Dev = %8.3f" $DRMS $DMAX]

    # for [set NOM($jatmax,1)] --> [set NOM($jatmax,2)]

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set ROT($K,$L) [set TRANS($K,$L,1)]
	}
    }

    set MROT [M_T ROT]

    set mrot2 $MROT
    set MROT [M_invM $MROT]

    MULTMAT $MROT TRANS 2

    T_M ROT $MROT 1

    puts ""
    puts "TRANSFORMATION B->A :"
    puts "( axes cristallins pour chaque molecule ) :"
    puts "                xA = MATRICE * xB  +  T"
    puts ""
    puts "                  MATRIX                   T"

    foreach i {1 2 3} {
	set v {}
	foreach j {1 2 3} {
	    lappend v [set TRANS($i,$j,2)]
	}
	lappend Mat $v
	lappend x1 [set XBAR($i,2)]
    }

    set vxtrans [V_MV $Mat * $x1]

    foreach K {1 2 3} {
	set xtrans($K) [lindex $vxtrans [expr {$K-1}]]
	foreach L {1 2 3} {
	    set ROT($K,$L) [set TRANS($K,$L,2)]
	}
	set xtrans($K) [expr {[set XBAR($K,1)]-[set xtrans($K)]}]
	puts "[format "        %7.3f %7.3f %7.3f       %8.3f" [set ROT($K,1)] [set ROT($K,2)] [set ROT($K,3)] [set xtrans($K)]]"
    }

    array set MDeRot [array get ROT]
    array set VDeTrans [array get xtrans]

    set MROT [M_T ROT]

    set res [ANGLES ROT ANGLE AXE]
    if {$res == -1} {
	return [list -1 -1]
    }

    set crow [list $ANGLE(1) $ANGLE(2) $ANGLE(3)]
    set pola [list $ANGLE(4) $ANGLE(5) $ANGLE(6)]

    puts ""
    puts "Eulerian angles  (Crowther convention) :"
    puts "alpha, beta, gamma       = [Nice_V $crow %7.2f]"
    puts "Sphe. ang. kappa,psi,phi = [Nice_V $pola %7.2f]"
    puts "cosinus directeurs       = [Nice_V [V_T AXE] %7.2f]"
    puts ""

    # Projection sur l'axe de la ligne des barycentres
    set PROJ 0.
    set DIST 0.
    foreach K {1 2 3} {
	set DELTA [expr {[set XBAR($K,1)]-[set XBAR($K,2)]}]
	set DIST [expr {$DIST+$DELTA*$DELTA}]
	set PROJ [expr {$PROJ+[set AXE($K)]*$DELTA}]
    }

    set DIST [expr {sqrt($DIST)}]
    if {$DIST != 0.} {
	puts "barycentres distance BA        = [format %7.2f $DIST]"
	puts "BA projection on the axis      = [format %7.2f $PROJ]"

	#... Projection sur l'axe du milieu des barycentres AB
	set MROT  [M_T ROT]
	set vAXE  [V_T AXE]
	set vXBA1 [list $XBAR(1,1) $XBAR(2,1) $XBAR(3,1)]
	set vXBA2 [list $XBAR(1,2) $XBAR(2,2) $XBAR(3,2)]

	if {0} {
	    POINTFIXE $MROT $vAXE $vXBA1 $vXBA2 XAXE
	    puts " Projection of the BA middle point on the rotation axis = [Nice_V [V_T XAXE] %7.2f]"
	}
    }

    return [list $DRMS $DMAX]
}


proc COMPARORTHO_faux {aXX aW aMDeRot aVDeTrans} {
    upvar $aXX XX
    upvar $aW W
    upvar $aMDeRot MDeRot
    upvar $aVDeTrans VDeTrans

    # BUT :
    # LE PROGRAMME ESSAIE DE SUPERPOSER UNE MOL. B A UNE MOL
    # A EM MINIMISANT CHI**2 = SOMME (W*(X'(B)-X(A))**2), OU LA SOMM
    # EST FAITE SUR LES 3 COORDONNEES DE TOUS LES ATOMES COMMUNS.
    # X'(B) EST LA TRANSFORMEE DE X(B) PAR LE DEPLACEMENT
    # A DETERMINER, ET W = PONDERATION.
    #
    # LA METHODE PEUT SERVIR A COMPARER UNE MOLECULE A SA SYMETRIQU
    # (SI UNE MOLECULE SEMBLE ADMETTRE UN ELEMENT DE SYMETRIE NON
    # CRISTALLOGRAPHIQUE, PAR EXEMPLE), AUTREMENT DIT LA MOLECULE B
    # PEUT ETRE IDENTIQUE A A. MAIS DANS CE CAS, LES VALEURS DE CHI**2
    # ET DU NOMBRE DE DEGRES DE LIBERTE DOIVENT ETRE MODIFIEES.
    #
    # LA METHODE EST DECRITE DANS : B. REES, THESE 1969, PP. 90-94.
    #
    #    ROGRAMME REPRIS EN DECEMBRE 1974 (BR)
    #
    #...Mis sous forme de sous-programme ,pour VAX 750, en juin 84
    # Presentation modifiee en janvier 87
    #...Modif. fevrier 89: impression de la matrice en coord. absolues,
    #...et de la translation associee.
    #...Calcul de coordonnees d'un point de l'axe
    # (projection du milieu des barycentres) dans POINTFIXE
    #...Modif. avril 94 : NA transmis en argument.
    #...Ponderation fixee dans le progr. d'appel (sauf cas
    # =0). Attention : W est dimensionne a NAT alors
    # que SIG2 etait dimensionne a (NAT,2).
    #  Cas IOUT=0
    #   Nouvel argument : error
    #   Corrections dans POINTFIXE
    #...Modif. sept. 96 : COMMON/ecarts/
    #...Modif. mars  99 : les ecarts individuels pour les 10000 premiers
    #   atomes sont mis dans COMMON/ecarts/
    #...
    #   ARGUMENTS :
    #
    #	A l'entree :
    #
    # IIN  : Numero logique pour les lectures (non utilise dans cette
    #	version)
    # ====> pas utilise en tcl
    #
    # IOUT : Numero logique du fichier output (0 pour ne rien imprimer)
    # ====> pas utilise en tcl
    #
    # NATC : Nombre d'atomes pour la comparaison
    # ====> pas utilise en tcl
    #
    # NA : Nombre max. d'atomes (dimension de XX, W, NOM)
    # ====> pas utilise en tcl
    #
    # (XX(K,IAT,IMOL)K=1,3,IAT=1,NATC,IMOL=1,2) : coord.
    # pour les deux molecules, les atomes a superposer se corres-
    # pondant deux a deux. A la sortie, XX(K,IAT,2) contient les
    # coord. de la molecule B superposee a A
    #
    # W(IAT) : ponderation 	(par defaut : W=1)
    #
    # IPRINT : Si non nul, la distance apres superposition sera
    #	imprimee atome par atome
    # ====> pas utilise en tcl
    #
    # NOM(IAT) : Nom des atomes (15 caracteres). Pas utilise si
    #	IPRINT=0.
    # ====> pas utilise en tcl
    #
    #	A la sortie :
    #
    #	XBAR(K,IMOL) : coord. des barycentres des deux
    #	molecules
    #
    #	ROT : matrice de la rotation B->A
    #
    #	ANGLE : Valeurs de Alpha,Beta,Gamma et de Kappa,Psi,Phi
    #	pour cette rotation
    #	Kappa :angle de la rotation; Psi,Phi : coord. spheriques;
    #	Alpha,Beta,Gamma : angles d'Euler (convention Crowther)
    #
    #	ERROR : = .false. normalement, .true. si la superposition
    #		n'a pas pu se faire
    #		En outre les coord. d'un point de l'axe de rotation
    #		et le deplacement parallele a l'axe sont transmis
    #		dans le common /HELICON/
    #......
    #
    #
    # AUTRES OPTIONS :
    #	 	   DEFINITION D'UN SYSTEME D'AXES MOLECULAIRE, PAR LA
    #     MATRICE DE TRANSFORMATION ( COORD. MOLECULAIRES EN FONCTION
    #     DES COORDONNEES ABSOLUES (CRISTAL) + CONSTANTE). LES LIGNES DE
    #     LA MATRICE , CHACUNE AVEC LA CONSTANTE CORRESPONDANTE, SONT
    #     DONNEES EN 3 CARTES EN 4 F9.6  (ITRANS=1)
    #
    #                  DONNEE DES BARYCENTRES (CAS DES MOLECULES
    #         CENTROSYMETRIQUES)  (IBAR=1)
    #
    #                  COMPARAISON DE A A L'ENANTIOMORPHE DE B (ISYM=1).
    #
    #		   jPRINT=1 : Impressions detaillees
    #......
    #

    set NATC [llength [array names W]]

    set ITRANS 0
    set ISYM 0
    set ANOM(1) " A  "
    set ANOM(2) " B  "

    set error 0

    set jPRINT 0

    foreach IMOL {1 2} {
	foreach K {1 2 3} {
	    foreach L {1 2 3} {
		set ORTHO($K,$L,$IMOL) 0.
	    }
	    set ORTHO($K,$K,$IMOL) 1.
	}
    }

    set SW 0.
    for {set i 1} {$i <= $NATC} {incr i} {
	set SW [expr {$SW+[set W($i)]}]
    }

    # Si pas de ponderation, prendre 1 par defaut
    if {$SW < 0.0001} {
	for {set i 1} {$i <= $NATC} {incr i} {
	    set W($i) 1.
	}
    }

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set TRANS($K,$L,1) [set ORTHO($K,$L,1)]
	    set TRANS($K,$L,2) [set ORTHO($K,$L,2)]
	}
    }

    foreach I {1 2} {
	foreach K {1 2 3} {
	    set SX($K,$I) 0.
	}
    }

    for {set J 1} {$J <= $NATC} {incr J} {
	foreach I {1 2} {
	    foreach K {1 2 3} {
		set SX($K,$I) [expr {[set SX($K,$I)]+[set W($J)]*[set XX($K,$J,$I)]}]
	    }
	}
    }

    foreach I {1 2} {
	foreach K {1 2 3} {
	    set XBAR($K,$I) [expr {[set SX($K,$I)]/$SW}]
	}
    }

    puts "\n================================="
    puts "Nbr of superposed atoms = $NATC"
    puts ""
    puts "BARYCENTRES :"

    foreach ii {1 2} {
	puts "$ii [set ANOM($ii)] [format "%6.2f %6.2f %6.2f" [set XBAR(1,$ii)] [set XBAR(2,$ii)] [set XBAR(3,$ii)]]"
    }

    foreach K {1 2 3} {
	set SX($K,1) [expr {[set XBAR($K,1)]-[set XBAR($K,2)]}]
	set SX($K,2) [expr {0.5*([set XBAR($K,1)]+[set XBAR($K,2)])}]
    }

    puts ""
    puts "BA vector     : [format "%6.2f %6.2f %6.2f" [set SX(1,1)] [set SX(2,1)] [set SX(3,1)]]"
    puts "Middle of  AB : [format "%6.2f %6.2f %6.2f" [set SX(1,2)] [set SX(2,2)] [set SX(3,2)]]"

    # soustrait le barycentre

    foreach I {1 2} {
	for {set J 1} {$J <= $NATC} {incr J} {
	    foreach K {1 2 3} {
		set XX($K,$J,$I) [expr {[set XX($K,$J,$I)]-[set XBAR($K,$I)]}]
	    }
	}
    }

    # EXPRESSION DANS LE SYST.D'AXES D''INERTIE'

    foreach IM {1 2} {
	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		set AINER($I,$J,$IM) 0.
	    }
	}

	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		    set AINER($I,$J,$IM) [expr {[set AINER($I,$J,$IM)]-[set W($JAT)]*[set XX($I,$JAT,$IM)]*[set XX($J,$JAT,$IM)]}]
		}
	    }
	}

	foreach I {1 2 3} {
	    set AINER($I,$I,$IM) 0.
	}

	foreach I {1 2 3} {
	    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		set AINER($I,$I,$IM) [expr {\
						[set AINER($I,$I,$IM)] + \
						[set W($JAT)]*(\
								   [set XX(1,$JAT,$IM)]**2 +\
								   [set XX(2,$JAT,$IM)]**2 +\
								   [set XX(3,$JAT,$IM)]**2 -\
								   [set XX($I,$JAT,$IM)]**2)}]
	    }
	}

	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		set AI($I,$J) 0.
	    }
	}

	foreach I {1 2 3} {
	    foreach J {1 2 3} {
		set AI($I,$J) [set AINER($I,$J,$IM)]
	    }
	}

	# Jacobi travaille avec matrices index 0.
	unset -nocomplain AT

	set mAI [M_T AI]
	unset AI
	T_M AI $mAI

	set mV [concat 2 3 3 {*}$mAI]

	#mevsvd_br mV evals
	#	jacobi AI AT VV 3

	set mAT {}
	set mV [lrange $mV 3 end]
	for {set i 0} {$i < 3} {incr i} {
	    lappend mAT [lrange $mV [expr {3*$i}] [expr {3*($i+1)-1}]]
	}
	T_M AT $mAT 1

	set mAI [M_T AI]
	unset AI
	T_M AI $mAI 1

	set D [S_deterM [M_T AT]]

	if {$D < 0.} {
	    foreach I {1 2 3} {
		foreach J {1 2 3} {
		    set AT($J,$I) [expr {-1.*[set AT($J,$I)]}]
		}
	    }
	}

	foreach K {1 2 3} {
	    foreach L {1 2 3} {
		set ROT($L,$K) [set AT($K,$L)]
	    }
	}

	set MROT [M_T ROT]

	MULTMAT $MROT TRANS $IM

	for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
	    foreach K {1 2 3} {
		set XI($K,$JAT,$IM) 0.
		foreach J {1 2 3} {
		    if {$IM == 1} {set BT($J,$K) [set AT($J,$K)]}

		    set XI($K,$JAT,$IM) [expr {\
						   [set XI($K,$JAT,$IM)]+\
						   [set AT($J,$K)]*[set XX($J,$JAT,$IM)]}]
		}
	    }
	}
    }

    set CHI2(1) 0.

    foreach IM {1 2} {
	for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
	    foreach J {1 2 3} {
		set XX($J,$JAT,$IM) [set XI($J,$JAT,$IM)]
	    }
	}
    }

    # ROTATIONS ET TESTS EN CHI**2

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set ROT($K,$L) 0.
	}
    }

    foreach I {2 3 4 5} {

	# ON FERME A 350
	# ON PERMUTE LES AXES A CHAQUE ITERATION

	# on ferme a 340

	# Initialise JP !! AU PIF !!

	set JP 0

	foreach IPERM {1 2 3} {
	    foreach IM {1 2} {
		for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		    foreach J {1 2 3} {
			incr JP
			if {$JP-3 > 0} {
			    set JP [expr {$JP-3}]
			}
			set XI($JP,$JAT,$IM) [set XX($J,$JAT,$IM)]
			set ROT($JP,$J) 1.
		    }
		}
	    }

	    foreach J {1 2 3} {
		foreach K {1 2 3} {
		    set B($J,$K) 0.
		    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
			set B($J,$K) [expr {[set B($J,$K)]+[set W($JAT)]*[set XI($J,$JAT,1)]*[set XI($K,$JAT,2)]}]
		    }
		}
	    }

	    foreach L {2 3} {
		if {[set B($L,$L)] < 0} {
		    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
			set XI($L,$JAT,2) [expr {-1.*[set XI($L,$JAT,2)]}]
			set XI(1,$JAT,2) [expr {-1.*[set XI(1,$JAT,2)]}]
		    }

		    foreach J {1 2 3} {
			set ROT(1,$J) [expr {-1.*[set ROT(1,$J)]}]
			set ROT($L,$J) [expr {-1.*[set ROT($L,$J)]}]
			set B($J,1) [expr {-1.*[set B($J,1)]}]
			set B($J,$L) [expr {-1.*[set B($J,$L)]}]
		    }
		}
	    }

	    set CHI2($I) 0.
	    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		foreach J {1 2 3} {
		    set  CHI2($I) [expr {[set CHI2($I)]+[set W($JAT)]*pow(([set XI($J,$JAT,2)]-[set XI($J,$JAT,1)]),2)}]
		}

	    }

	    set CU 1.
	    set CV 1.
	    set CW 1.
	    set SU 0.
	    set SV 0.
	    set SW 0.

	    set DEN [expr {$CW*$B(1,1)+$CV*$SW*$B(1,2)-$SW*$B(2,1)+$CV*$CW*$B(2,2)-$SV*$B(3,2)}]
	    if {$DEN != 0.} {
		set U [expr {atan((-$CV*$SW*$B(1,1)+$CW*$B(1,2)-$CV*$CW*$B(2,1)-$SW*$B(2,2)+$SV*$B(3,1))/$DEN)}]
		set SU [expr {sin($U)}]
		set CU [expr {cos($U)}]
	    }

	    set DEN [expr {-$SU*$SW*$B(1,1)+$CU*$SW*$B(1,2)-$SU*$CW*$B(2,1)+$CU*$CW*$B(2,2)+$B(3,3)}]
	    if {$DEN != 0.} {
		set V [expr {atan(($SW*$B(1,3)+$CW*$B(2,3)+$SU*$B(3,1)-$CU*$B(3,2))/$DEN)}]
		set SV [expr {sin($V)}]
		set CV [expr {cos($V)}]
	    }

	    set DEN [expr {$CU*$B(1,1)+$SU*$B(1,2)-$SU*$CV*$B(2,1)+$CU*$CV*$B(2,2)+$SV*$B(2,3)}]
	    if {$DEN != 0.} {
		set WW [expr {atan((-$SU*$CV*$B(1,1)+$CU*$CV*$B(1,2)+$SV*$B(1,3)-$CU*$B(2,1)-$SU*$B(2,2))/$DEN)}]
		set SW [expr {sin($WW)}]
		set CW [expr {cos($WW)}]
	    }

	    set R(1,1) [expr {$CU*$CW-$SU*$CV*$SW}]
	    set R(1,2) [expr {$SU*$CW+$CU*$CV*$SW}]
	    set R(1,3) [expr {$SV*$SW}]
	    set R(2,1) [expr {-$CU*$SW-$SU*$CV*$CW}]
	    set R(2,2) [expr {-$SU*$SW+$CU*$CV*$CW}]
	    set R(2,3) [expr {$SV*$CW}]
	    set R(3,1) [expr {$SU*$SV}]
	    set R(3,2) [expr {-$CU*$SV}]
	    set R(3,3) $CV

	    # rempli le tableau XX avec coord de mol 1 inchangees et coords
	    # de mol 2 tournees par R

	    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
		foreach J {1 2 3} {
		    set XX($J,$JAT,2) 0.
		    foreach K {1 2 3} {
			set XX($J,$JAT,2) [expr {[set XX($J,$JAT,2)]+[set R($J,$K)]*[set XI($K,$JAT,2)]}]
		    }
		}

		foreach J {1 2 3} {
		    set XX($J,$JAT,1) [set XI($J,$JAT,1)]
		}
	    }

	    set MROT [M_T ROT]
	    set MR [M_T R]

	    MULTMAT $MROT TRANS 2
	    MULTMAT $MR TRANS 2

	    T_M R $MR 1
	    T_M ROT $MROT 1
	}

	if {abs([set CHI2($I)]-[set CHI2([expr {$I-1}])])-0.01*[set CHI2($I)] <= 0.} {
	    set CHI02 [set CHI2($I)]
	    break
	}
    }

    if {$I == 5 && abs([set CHI2($I)]-[set CHI2([expr {$I-1}])])-0.01*[set CHI2($I)] > 0.} {
	puts "No convergence of CHI**2"
	set error 0
	return
    }

    set NU [expr {3*$NATC-6}]

    set SW 0.
    set SWD2 0.
    set DMIN 1000000.
    set DMAX 0.

    for {set JAT 1} {$JAT <= $NATC} {incr JAT} {
	set D2 0.
	foreach J {1 2 3} {
	    set D2 [expr {$D2+pow(([set XX($J,$JAT,2)]-[set XX($J,$JAT,1)]),2)}]
	}
	set D [expr {sqrt($D2)}]

	set SWD2 [expr {$SWD2+$D2*[set W($JAT)]}]
	set SW [expr {$SW + [set W($JAT)]}]
	if {$D < $DMIN} {set DMIN $D}
	if {$D > $DMAX} {set DMAX $D}
	if {$JAT <= 10000} {set distance($JAT) $D}
    }

    set DRMS [expr {sqrt($SWD2/$SW)}]

    puts [format "CHI**2 = %8.3f for %3d degrees of freedom" $CHI02 $NU]
    puts [format "RMS    = %8.3f , Max Dev = %8.3f" $DRMS $DMAX]

    # for [set NOM($jatmax,1)] --> [set NOM($jatmax,2)]

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set ROT($K,$L) [set TRANS($K,$L,1)]
	}
    }

    set MROT [M_T ROT]

    set mrot2 $MROT
    set MROT [M_invM $MROT]

    MULTMAT $MROT TRANS 2

    T_M ROT $MROT 1

    puts ""
    puts "TRANSFORMATION B->A :"
    puts "( axes cristallins pour chaque molecule ) :"
    puts "                xA = MATRICE * xB  +  T"
    puts ""
    puts "                  MATRIX                   T"

    foreach i {1 2 3} {
	set v {}
	foreach j {1 2 3} {
	    lappend v [set TRANS($i,$j,2)]
	}
	lappend Mat $v
	lappend x1 [set XBAR($i,2)]
    }

    set vxtrans [V_MV $Mat * $x1]

    foreach K {1 2 3} {
	set xtrans($K) [lindex $vxtrans [expr {$K-1}]]
	foreach L {1 2 3} {
	    set ROT($K,$L) [set TRANS($K,$L,2)]
	}
	set xtrans($K) [expr {[set XBAR($K,1)]-[set xtrans($K)]}]
	puts "[format "        %7.3f %7.3f %7.3f       %8.3f" [set ROT($K,1)] [set ROT($K,2)] [set ROT($K,3)] [set xtrans($K)]]"
    }

    array set MDeRot [array get ROT]
    array set VDeTrans [array get xtrans]

    set MROT [M_T ROT]

    set res [ANGLES ROT ANGLE AXE]
    if {$res == -1} {return [list -1 -1]}

    set crow [list $ANGLE(1) $ANGLE(2) $ANGLE(3)]
    set pola [list $ANGLE(4) $ANGLE(5) $ANGLE(6)]

    puts ""
    puts "Eulerian angles  (Crowther convention) :"
    puts "alpha, beta, gamma       = [Nice_V $crow %7.2f]"
    puts "Sphe. ang. kappa,psi,phi = [Nice_V $pola %7.2f]"
    puts "cosinus directeurs       = [Nice_V [V_T AXE] %7.2f]"
    puts ""

    # Projection sur l'axe de la ligne des barycentres

    set PROJ 0.
    set DIST 0.
    foreach K {1 2 3} {
	set DELTA [expr {[set XBAR($K,1)]-[set XBAR($K,2)]}]
	set DIST [expr {$DIST+$DELTA*$DELTA}]
	set PROJ [expr {$PROJ+[set AXE($K)]*$DELTA}]
    }

    set DIST [expr {sqrt($DIST)}]
    if {$DIST != 0.} {
	puts "barycentres distance BA        = [format %7.2f $DIST]"
	puts "BA projection on the axis      = [format %7.2f $PROJ]"

	#... Projection sur l'axe du milieu des barycentres AB

	set MROT  [M_T ROT]
	set vAXE  [V_T AXE]
	set vXBA1 [list $XBAR(1,1) $XBAR(2,1) $XBAR(3,1)]
	set vXBA2 [list $XBAR(1,2) $XBAR(2,2) $XBAR(3,2)]

	if {0} {
	    POINTFIXE $MROT $vAXE $vXBA1 $vXBA2 XAXE
	    puts " Projection of the BA middle point on the rotation axis = [Nice_V [V_T XAXE] %7.2f]"
	}
    }

    return [list $DRMS $DMAX]
}


proc MULTMAT {MA aTRANS IMOL} {
    upvar $aTRANS TRANS

    T_M A $MA 1

    #  MULTIPLICATION MATRICIELLE (3X3).
    # LA NOUVELLE MATRICE EST MISE E

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set TRANSO($K,$L) [set TRANS($K,$L,$IMOL)]
	}
    }

    foreach K {1 2 3} {
	foreach L {1 2 3} {
	    set TRANS($K,$L,$IMOL) [expr {\
					      [set A($K,1)]*[set TRANSO(1,$L)]+\
					      [set A($K,2)]*[set TRANSO(2,$L)]+\
					      [set A($K,3)]*[set TRANSO(3,$L)]}]
	}
    }

    return
}


proc TRCOOR {NA,X,TRANS,IAT,IMOL} {

    foreach K {1 2 3} {
	set XO($K) [set X($K,$IAT,$IMOL)]
    }

    foreach K {1 2 3} {
	set X($K,$IAT,$IMOL) [expr {[set TRANS($K,1,$IMOL)]*$XO(1)+[set TRANS($K,2,$IMOL)]*$XO(2)+[set TRANS($K,3,$IMOL)]*$XO(3)}]
    }

    return
}


proc POINTFIXE {mtrans vaxe vxba1 vxba2 axaxe} {
    upvar $axaxe xaxe

    T_M trans $mtrans 1
    T_V axe $vaxe 1

    foreach i {1 2 3} {
	set xbar($i,1) [lindex $vxba1 [expr {$i-1}]]
	set xbar($i,2) [lindex $vxba2 [expr {$i-1}]]
    }

    #... Trouver les coord. XAXE de la projection sur l'axe de rotation
    #... du milieu des barycentres AB
    #... trans : matrice de rotation B->A
    #... axe : cos. dir. de l'axe
    #... xbar : barycentres  A et B
    #... Tout en coordonnees cartesiennes

    T_M aa [M_unit] 1

    #... Passage en axes locaux, X suivant l'axe, Z normal a AB, origine au milieu

    foreach k {1 2 3} {
	set xp($k) [expr {([set xbar($k,1)]+[set xbar($k,2)])/2.}]
	set cm1(1,$k) [set axe($k)]
	set cm1(2,$k) [expr {([set xbar($k,2)]-[set xbar($k,1)])}]
    }

    if {[expr {pow($cm1(2,1),2)+pow($cm1(2,2),2)+pow($cm1(2,3),2)}] < 0.000001} {
	set cm1(2,1) $cm1(1,2)
	set cm1(2,2) [expr {-1.0*$cm1(1,1)}]
	set cm1(2,3) 0.
    }

    if {[expr {pow($cm1(2,1),2)+pow($cm1(2,2),2)+pow($cm1(2,3),2)}] < 0.000001} {
	set cm1(2,2) $cm1(1,3)
	set cm1(2,3) [expr {-1.0*$cm1(1,2)}]
	set cm1(2,1) 0.
    }

    ORTHON cm1 AA
    set MCM1 [M_tM [M_T cm1]]
    T_M cm1 $MCM1 1

    # SMI3(CM1,C,DET)
    array set C [array get cm1]
    set MC [M_invM [M_T C]]

    #...	X(local)=C*(Xortho-xp)  pour origine en P

    set vxp [V_T xp]
    set VXA [TRANSFORME $vxba1 $MC $vxp]
    set VXB [TRANSFORME $vxba2 $MC $vxp]

    T_M C $MC 1
    T_V XA $VXA 1
    T_V XB $VXB 1
    T_V xp $vxp 1

    MATMATMAT C trans cm1 rot

    if {abs($rot(2,3)) < 0.000001} {
	# rotation 0 ou pi
	set ZAXE 0.
    } else {
	# Z local de l'axe
	set ZAXE [expr {$XA(2)*($rot(2,2)+1.)/$rot(2,3)}]
    }

    #...	Retour aux axes cartesiens

    foreach k {1 2 3} {
	set xaxe($k) [expr {[set cm1($k,3)] * $ZAXE + [set xp($k)]}]
    }

    return
}


proc TRANSFORME {VX MC VXP} {

    set PROV [V_VV $VX "-" $VXP]

    set VXMOL [V_MV $MC * $PROV]

    return $VXMOL
}


proc PNico {} {
    global ListePDB StrucAVoir TabSF EquivalenceZone
    puts "ListePDB $ListePDB"

    foreach {sref smol} $ListePDB {
	puts "\nMODELES $sref $smol"
	set StrucAVoir [list $sref $smol]
	set ref [DonneIdDeAccessPDB $sref]
	set chr [DonneChainDeAccessPDB $sref]
	set rot $ref
	set chn [DonneChainDeAccessPDB $smol]
	set seq [set ::Sequences($smol)]

	#set Lf $TabSF($sref,PFAM-A)
	set Lf [list]
	lappend Lf [list fstart 1 fstop [LongueurDeLAlignement] fcolor yellow fscore 0.0 fnote "whole seq."]
	foreach f $Lf {
	    DecortiqueUneFeature $f dg0 fg0 col score note
	    while {[string index $seq $dg0] eq "."} {
		incr dg0
		if {$dg0 == $fg0} {
		    puts "ca merde "
		    exit
		}
	    }
	    while {[string index $seq $fg0] eq "."} {
		incr fg0 -1
		if {$fg0 == $fg0} {
		    puts "ca merde "
		    exit
		}
	    }
	    puts "\ndg0 $dg0 fg0 $fg0 $note"

	    set Exc ""
	    lappend EquivalenceZone($sref) [list [list [DonnePosGS $sref $dg0] [DonnePosGS $sref $fg0]] $chr $sref $Exc $dg0 $fg0]
	    lappend EquivalenceZone($smol) [list [list [DonnePosGS $smol $dg0] [DonnePosGS $smol $fg0]] $chn $smol $Exc $dg0 $fg0]

	    SuperAvecOrdali
	    AppliqueSuperposition
	    ExamSupOutliers $sref $smol $dg0 $fg0
	    unset -nocomplain EquivalenceZone
	}
    }

    exit
    return
}


proc ExamSupOutliers {mref mrot d f} {
    global db StrucAVoir

    set Lf $::TabSF($mref,PFAM-A)
    puts "Domaines PFAM"
    foreach f $Lf {
	DecortiqueUneFeature $f d f col score note
	set ds [DonnePosGS $mref $d]
	set fs [DonnePosGS $mref $f]
	puts "$note $ds $fs"
    }
    $db transaction {
    # reference
    set iref  [DonneIdDeAccessPDB $mref]
    set cref [DonneChainDeAccessPDB $mref]
    set Lref [$db eval {select a.x,a.y,a.z,r.rnbr from atoms as a, chains as c, pdb as p, residues as r where \
			    p.name=$iref and \
			    c.pk_pdb=p.pk_pdb and \
			    c.name=$cref and \
			    a.pk_chains=c.pk_chains and \
			    a.aname = ' CA ' and \
			    a.pk_residues = r.pk_residues and \
			    r.type = 'Protein'}]
    # rotated
    set irot  [DonneIdDeAccessPDB $mrot]
    set crot [DonneChainDeAccessPDB $mrot]
    set Lrot [$db eval {select a.x,a.y,a.z,r.rnbr from atoms as a, chains as c, pdb as p, residues as r where \
			    p.name=$irot and \
			    c.pk_pdb=p.pk_pdb and \
			    c.name=$crot and \
			    a.pk_chains=c.pk_chains and \
			    a.aname = ' CA ' and \
			    a.pk_residues = r.pk_residues and \
			    r.type = 'Protein'}]

    }
    # compute
    set moy 0.0 ; set m2  0.0
    set rms 0.0
    set nat 0
    foreach {xr yr zr nr} $Lref {xo yo zo no} $Lrot {
	incr nat
	set xd [expr {$xo-$xr}]
	set yd [expr {$yo-$yr}]
	set zd [expr {$zo-$zr}]
	set d [expr {sqrt($xd**2+$yd**2+$zd**2)}]
	set T($nr,$no) $d

	set moy [expr {$moy + $d}]
	set m2  [expr {$m2 + $d*$d}]
	set rms [expr {$rms + $d*$d}]
    }
    set moy [expr {1.0*$moy/$nat}]
    set m2  [expr {1.0*$m2/$nat}]
    set rms [expr {sqrt(1.0*$rms/$nat)}]
    set sd  [expr {1.0*$m2 - $moy*$moy}]

    puts [format "stats\nnatoms $nat moy %6.3f sd %6.3f rms %6.3f" $moy $sd $rms]
    set Lsd [list] ; set Lrms [list]
    foreach k [array names T] {
	lassign [split $k ,] n1 n2
	set n1 [string trimleft $n1 0]
	set d $T($k)
	if {$d > ($moy + 1.5*$sd)} {
	    lappend Lsd $n1
	}
	if {$d > (1.5*$rms)} {
	    lappend Lrms $n1
	}
    }
    puts "> moy + 1.5 * sd :"
    set Lsd [lsort -integer $Lsd]
    set d -1 ; set f -1 ; set dep 1
    set res ""
    foreach e $Lsd {
	if {$e != ($f + 1)} {
	    if {! $dep} {
		if {$d != $f} {
		    append res "$d-$f "
		} else {
		    append res "$d "
		}
	    }
	    set d $e
	    set f $e
	} else {
	    set f $e
	}
	set dep 0
    }
    puts "$res"

    puts "> 1.5 * rms:"
    set Lrms [lsort -integer $Lrms]
    set d -1 ; set f -1 ; set dep 1
    set res ""
    foreach e $Lrms {
	if {$e != ($f + 1)} {
	    if {! $dep} {
		if {$d != $f} {
		    append res "$d-$f "
		} else {
		    append res "$d "
		}
	    }
	    set d $e
	    set f $e
	} else {
	    set f $e
	}
	set dep 0
    }
    puts "$res"

    return
}



proc tpc {} {
    global TDesPCI LNOrdali

    CalculeLesPCIDuMac
    foreach n1 $LNOrdali {
	if {$n1 eq "" || $n1 in $::ListePDB} {continue}
	foreach n2 $LNOrdali {
	    if {$n1 eq $n2 || $n2 eq "" || $n2 in $::ListePDB} {continue}
	    set pc $TDesPCI($n1,$n2)
	    if {$pc > 0.99} {
		puts "$n1 $n2 $TDesPCI($n1,$n2)"
	    }
	}
    }

    exit
}


proc testsuper {} {
    global bhelix bsup
    
    ChangeMode superpose
    $bhelix invoke
    FaitSuperposition 1

    return
}

    
proc tkabsch {} {
    global ListePDB StrucAVoir

    #source /home/moumou/ordali2/src/comparortho_orig.tcl
    
    set StrucAVoir $ListePDB
    BindModeSelection 
    SelectSSDeType helix
    FaitSuperposition 0 [lindex $StrucAVoir 0]

    VisualiseStructure

    return
    exit
}


    
