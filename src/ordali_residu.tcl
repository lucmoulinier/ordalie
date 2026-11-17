
#
# --- ordali_residu.tcl
#

proc TerminateChoose4Multi {w what} {
    global Cons

    destroy $w
    if {$what eq "cancel"} {
	set Cons(multi,ListMeth) {}
    } else {
	set List {}
	foreach key [array names Cons "multi,meth-*"] {
	    if {$Cons($key)} {
		set meth [lindex [split $key "-"] 1]
		switch $meth {
		    "Mean Distance" {lappend List "Thompson"}
		    "Vector Norm" {lappend List "Norm"}
		    "Liu" {lappend List "Liu"}
		    "BILD" -
		    "Shannon" -
		    "JSD" {lappend List $meth}
		}
	    }
	}
	set Cons(multi,ListMeth) $List
    }

    return
}


proc ChooseMethodsForMulti {} {
    global Cons Defauts

    set w ".choosemeth"
    if {[winfo exists $w]} {
	raise $w
	return
    }

    toplevel $w
    wm title $w "Select methods"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    frame $w.f
    grid $w.f -row 0 -column 0 -sticky news

    label $w.f.lgen \
	-text "Select scoring methods to use \nfor clustering computation" \
	-font TitleFone \
	-fg $Defauts(ForeAppli) \
	-anchor w -justify left \
	-relief flat -bd 0
    grid $w.f.lgen -row 0 -column 0 -sticky ew -pady {10 20}

    set Lmeth {"BILD" "Shannon" "Liu" "Mean Distance" "JSD" "Vector Norm"}
    set nrow 1
    foreach mth $Lmeth {
	set Cons(multi,meth-$mth) 0
	set obj [string tolower [lindex $mth 0]]
	checkbutton $w.f.$obj \
	    -text "$mth" \
	    -onvalue 1 \
	    -offvalue 0 \
	    -relief flat \
	    -variable Cons(multi,meth-$mth)
        grid $w.f.$obj -row $nrow -column 0 -sticky w
	incr nrow
    }			    	 

    # Frame Boutons OK default
    ttk::frame $w.f.btn \
	-style FrmBtnCtrl.TFrame
    grid $w.f.btn -row $nrow -column 0 -sticky ew -pady {20 10}
    button $w.f.btn.cancel \
	-text "Cancel" \
	-background red \
	-command [list TerminateChoose4Multi $w cancel]
    button $w.f.btn.cebon \
	-text " OK " \
	-background green1 \
	-command [list TerminateChoose4Multi $w ok]

    grid $w.f.btn.cancel -row 0 -column 0 -pady 5
    grid $w.f.btn.cebon  -row 0 -column 1 -pady 5
    grid columnconfig $w.f.btn {0 1} -weight 1

    FenetreAuCentre $w

    tkwait window $w

    set ret [llength $Cons(multi,ListMeth)]
    
    return $ret
}


proc MontreCacheScores {pos} {
    global NomTextSeq NomFenetreOrdali CestLeScore ListeScore

    # norm dis nVp mcos dist Ranganatan
    if {[info exists CestLeScore]} {destroy $CestLeScore}
    if {! [info exists ListeScore]} {return}

    lassign [split $pos .] ys xs
    lassign [$NomTextSeq bbox $pos] x y q t
    incr y -10

    set lx [lindex $ListeScore $xs]
    set no [lindex $lx 0]
    set ds [lindex $lx 1]
    set vp [lindex $lx 2]
    set mc [lindex $lx 3]
    set di [lindex $lx 4]
    set dg [lindex $lx 5]
    set TexteActions "En x = [expr {$xs+1}], \nnorm ... : $no\ndisp ... : $ds\nnrVp ... : $vp\nmcos ... : $mc\ndist ... : $di\ndelG ... : $dg"
    set CestLeScore "$NomFenetreOrdali.sco"

    message $CestLeScore \
	-borderwidth 3 \
	-relief raise \
	-width 800 \
	-justify left \
	-text $TexteActions \
	-background "lightyellow" \
	-foreground "black" \
	-font "CourierNew 16 bold"

    place $CestLeScore -x $x -y $y \
	-anchor sw \
	-in $NomFenetreOrdali

    return
}



proc ColorieScore {} {
    global ListeScore
    global NomTextSeq
    global LNOrdali

    ColorieSelonFeature "Clear"
    DefinitionGroupes nogroups
    update idletasks
    set N 10
    set Nseqs [llength $LNOrdali]
    if {$Nseqs < 10} {return}

    if {! [ModeI]} {return}

    $NomTextSeq configure -state normal

    set coul [list red magenta brown orange yellow dimgray green cyan forestgreen blue]
    foreach c $coul {
	$NomTextSeq tag configure SCORE$c -background $c -foreground black
    }

    set Ny 1
    if {$Nseqs > 20} {
	set Ny 2
    }

    #    norm dis nVp mcos dist Ranganatan

    set f [open "resul.dat" w]
    foreach l $ListeScore {
	puts $f $l
    }
    close $f

    foreach n {0 1 2 3 4 5} {
	set liste [ExtraitListeDeListe $ListeScore $n]

	set Lt [lsort -unique -increasing -real $liste]
	set i 0
	if {[lindex $Lt $i] == -999.} {
	    incr i
	}
	set min [lindex $Lt $i]
	set max [lindex $Lt end]
	set step [expr {($max - $min) / $N}]

	set j 0
	foreach e $liste {
	    if {$e == -999.0} {
		incr j
		continue
	    }
	    foreach i {0 1 2 3 4 5 6 7 8 9} c $coul {
		set d [expr {$min + $i * $step}]
		set f [expr {$d + $step}]
		if {$e >= $d && $e < $f} {
		    set p [expr {$n * $Ny + 1}]
		    $NomTextSeq tag add SCORE$c $p.$j
		    break
		}
	    }
	    incr j
	}
    }

    update idletasks

    #    $NomTextSeq configure -state disabled

    return
}


proc VerificationAvantCalculs {} {
    global TableScore

    set ncols [llength [set TableScore(1)]]
    for {set x 0} {$x < $ncols} {incr x} {
	set l 0
	foreach i [array names TableScore] {
	    lappend l [lindex [set TableScore($i)] $x]
	}
	set l [lsort -unique $l]
	if {[llength $l] == 1} {return 0}
	set neuf [lsearch $l -999.]
	if {$neuf != -1} {
	    set l [lreplace $l $neuf $neuf]
	}
	if {[llength $l] == 1} {return 0}
    }

    return 1
}


proc LanceLesCalculs {lc ngrp relatif {what "pfam"}} {

    CreeListeScore $ngrp

    NormalisationColonnes

    # AIC/BIC - MixtureModel
    #puts "$lc"
    #puts "$::ListeScore"
    #set Lgr [Tclcluspack $::ListeScore -dt coordinates -cm mm -nbc aic -wc]
    set Lgr [Tclcluspack $::ListeScore -dt coordinates -cm kmeans -nbc dpc -wc]

    set order decreasing
    switch $what {
	"pfam" {
	    set rep [LanceTestsPfam $Lgr -order $order -nomgrr $ngrp -method $lc]
	}
	"bali" {
	    set rep [LanceTestsBali $Lgr -order $order -nomgrr $ngrp -method $lc]
	}
	default {
	    set rep [LanceTestsPDB  $Lgr -order $order -relatif $relatif -nomgrr $ngrp]
	}
    }


    # pour shunter Al2Co !
    if {"7" in $lc} {set rep 1}

    return $rep
}


proc CalculeValParColonne {} {
    global ListeScore LNOrdali

    puts "NSeqs     : [llength $LNOrdali]"

    ScoreDeRosace
    ScoreDeThompson
    ScoreDeRanganatan

    CreeListeScore
    set ListeScoreOri $ListeScore

    set ListeScore [ExtraitListeDeListe $ListeScore 0]
    NormalisationColonnes
    EcritPourDPC "g-tdpc.dat"

    CreeListeScore "0 4 5"
    NormalisationColonnes
    EcritPourDPC "ngd-tdpc.dat"

    set ListeScore $ListeScoreOri

    return
}



proc CreeFeaturesMethod {ft} {
    global Couleurs ListeTypesDeFeatures SDG TabSF ConsMeth ScoreMeth Defauts ListePDB

    # ORD file : called by CreeVue before the PDB
    # are known (TraitePDBDeLAlignement)
    if {! [info exists ListePDB]} {
	set ListePDB {}
    }

    if {$ft ni $ListeTypesDeFeatures} {
	lappend ListeTypesDeFeatures $ft
    }

    set s 0.0
    set note ""
    foreach {t v} [array get ConsMeth] {
	if {$t eq "IdenGlob"} {
	    lassign [set Couleurs($t)] tmp c
	    set g "GroupeToutLeMonde"
	    set target "all"
	} elseif {$t eq "ConsGlob"} {
	    lassign [set Couleurs($t)] tmp c
	    set g "GroupeToutLeMonde"
	    set target "all"
	} else {
	    # ex: group4
	    set i [string range $t 5 end]
	    set c [CouleurO2Ordali [CouleurDuGroupe $i]]
	    set g $t
	    set target "group"
	}

	set note $t
	foreach e $v {
	    set s [set ScoreMeth($ft,$g,$e)]

	    set nl [list "fstart" $e "fstop" $e "fcolor" $c "fscore" $s "fnote" $note "fcsys" "global" ftarget $target]
	    foreach n [set SDG($g)] {
		if {[string trim $n] in $ListePDB && ! [set Defauts(PDBDansPilier)]} {continue}
		lappend TabSF($n,$ft) $nl
	    }
	}
    }

    set ScoreMeth($ft,Edit) 0

    return
}


proc CreeFeaturesScore {idn g l1 l2} {
    global ListeTypesDeFeatures LNDG NomTextSeq SDG Couleurs TabSF

    if {! [ModeI]} {return}

    set idn [string toupper $idn]
    if {$idn ni $ListeTypesDeFeatures} {
	lappend ListeTypesDeFeatures $idn
    }

    set s 0.0
    set t ""
    set tag2 ""
    set c2 ""
    if {$g == ""} {
	set g "GroupeToutLeMonde"
	set tag  "IdenGlob"
	set tag2 "ConsGlob"
	set c2 [$NomTextSeq tag cget ${tag2} -background]
    } else {
	set i [lsearch $LNDG $g]
	set tag "CoulG$i"
    }
    set c [$NomTextSeq tag cget $tag -background]

    foreach n [set SDG($g)] {
	foreach e $l1 {
	    set d $e
	    set f $e
	    set nl [list $d $f $c $s $t]
	    lappend TabSF($n,$idn) $nl
	}
	if {$tag2 ne ""} {
	    foreach e $l2 {
		set d $e
		set f $e
		set nl [list $d $f ${c2} $s $t]
		lappend TabSF($n,$idn) $nl
	    }
	}
    }

    return
}


proc AssigneValParPos {} {
    global TableScore
    global ListeScore
    global LNOrdali
    global SDG
    global LNDG
    global ListeDesPiliersDuGroupe
    global TestCourant

    RecupereReference
    CreeFeaturesOrdali

    foreach g [lrange $LNDG 0 end-1] {
	if {[info exists TableScore]} {
	    array unset TableScore
	    catch {unset TableScore}
	}
	puts "Nom Grp   : $g"
	puts "NSeqs     : [llength $SDG($g)]"
	if {$g == "GroupeToutLeMonde"} {set g ""}

	ScoreDeRosace $g
	ScoreDeThompson   $g
	ScoreDeRanganatan $g

	CreeListeScore $g

	# fait les differentes combinaisons de parametres
	#
	#    norm dsp nVp mcos dist Ranganatan
	#     0    1   2   3    4     5
	#     n    p   v   m    d     g

	LanceLesCalculs 5 $g
	LanceLesCalculs 4 $g
	LanceLesCalculs 0 $g
	LanceLesCalculs 45 $g
	LanceLesCalculs 045 $g
    }

    return
}



proc EnleveConservationGlobale {} {
    global ConsMeth TbScores

    set LExc [concat [set ConsMeth(IdenGlob)] [set ConsMeth(ConsGlob)]]

    foreach e $LExc {
	foreach m $TbScores(Lcols) {
	    lset TbScores(Score,$m) $e -999.0
	}
    }

    return
}


proc LanceTests {fres ident {nomgrp ""}} {
    global ConsRef
    global LNDG

    set IdG 0
    if {$nomgrp != ""} {
	set IdG [lsearch $LNDG $nomgrp]
	incr IdG 2
    }

    # lecture clusters.
    # Calcule norme moyenne de chaque cluster
    # Gres : Tab indexe par le residu, donne le groupe
    # Tres : Tab indexe par le groupe, donne les resius

    set Lf [LesLignesDuFichier $fres]
    set nc [string trim [lindex [split [lindex $Lf 0] ":"] 1]]
    puts "NClusters : $nc"

    if {$nc < 2} {
	set g "OneCluster"
	set fmt "%15s :: %4d | %5d %6d %5s | %5d %6d %5s | %5d"
	puts "[format $fmt $ident-$g -1 -1 -1 -1 -1 -1 -1 -1]"
	return
    }

    set d 2
    for {set i 0} {$i < $nc} {incr i} {
	set ngr "gr$i"
	set ne [lindex [split [lindex $Lf $d] "="] 1]
	if {! $ne} {continue}
	set id [expr {$d + 1}]
	set if [expr {$d + $ne}]
	set Lv {}
	set SVec 0.
	set mv 0.
	set nval 0
	for {set j $id} {$j <= $if} {incr j} {
	    set vals [lindex $Lf $j]
	    set listev [split $vals "\t"]
	    set v [lindex $listev 0]
	    lappend Lv $v
	    set Gres($v) $ngr

	    set Vec [lrange $listev 1 end]
	    foreach e $Vec {
		set mv [expr {$mv + $e}]
		incr nval
	    }
	}
	set Tres($ngr) $Lv

	set Mnorm [expr {$mv/$nval}]
	set TNormI($ngr) $Mnorm
	set TNormV($Mnorm) $ngr

	set d [expr {$if + 2}]
    }

    # cherche cluster avec + grde norme
    # nel : nbr d'element de ce cluster

    set lv [lsort -decreasing -real [array names TNormV]]
    if {$lv == {}} {
	puts "\t===> 1 cluster vide !!!"
	return
    }

    set top [set TNormV([lindex $lv 0])]
    set nel [llength [set Tres($top)]]
    set lel [set Tres($top)]
    set dos [set TNormV([lindex $lv 1])]
    set ne2 [llength [set Tres($dos)]]
    set le2 [set Tres($dos)]
    if {! [llength $lv]} {
	set dos -1
	set ne2 0
	set le2 {}
    }

    if {[ModeI]} {CreeFeaturesScore $ident $nomgrp $lel $le2}

    # cree tableau t(type de conservation, no de cluster) = nbr residue

    foreach g [array names ConsRef] {
	set l [set ConsRef($g)]
	foreach v $l {
	    if {! [info exists Gres($v)]} {continue}
	    set ng [set Gres($v)]
	    if {[info exists tmp($g,$ng)]} {
		incr tmp($g,$ng)
	    } else {
		set tmp($g,$ng) 1
	    }
	}
    }

    # Pour un type de conservation donne,
    # - on cherche dans combien de groupes sont contenus les residues consideres
    # - on prend le nbr total de residus contenus dans ces groupes

    set Lar [array names tmp]
    foreach g [array names ConsRef] {
	set Li [lsearch -all -inline -regexp $Lar $g]
	set resli {}
	set cmptr 0
	foreach n $Li {
	    set ln [split $n ","]
	    set ng [lindex $ln 1]
	    set nbr [llength [set Tres($ng)]]
	    lappend resli [list $ng $nbr]
	    incr cmptr $nbr
	}
	set resli [lsort -index 1 -decreasing -integer $resli]
	set Comp($g) $resli
	set LeCmptr($g) $cmptr
    }

    # Affiche resultats

    set fmt "%15s :: %4d | %5d %6d %5s | %5d %6d %5s | %5d"
    set Ltype [ReordonneTypeCons]
    if {$nomgrp != ""} {set nomgrp [lindex $Ltype $IdG]}

    # fait par type
    # IdenGlob
    # ========
    set gafaire $nomgrp
    if {$nomgrp == ""} {
	set gafaire "IdenGlob"
	set g  "IdenGlob"
	set g2 "ConsGlob"
	#	if {! [llength [set ConsRef($gafaire)]]} {break}

	set ngrp [llength [set Comp($g)]]
	set nori [llength [set ConsRef($g)]]
	set ecar [expr {$nori - [set LeCmptr($g)]}]
	set pgr  [lindex [lindex [set Comp($g)] 0] 0]
	set emg  $nel
	set dmg  [expr {$nori - $nel}]
	set ncons 0
	if {$dmg < 0 && [info exists ConsRef($g2)]} {
	    set lori [set ConsRef($g2)]
	    foreach e $lel {
		if {[lsearch $lori $e] != -1} {incr ncons}
	    }
	}
	puts "[format $fmt $ident-$g $nori $ngrp $ecar $pgr $emg $dmg $top $ncons]"
    }

    #    EnleveCluster [set Tres($top)]

    # ConsGlob
    # ========

    set g $nomgrp
    if {$nomgrp == ""} {set g "ConsGlob"}
    set ngrp [llength [set Comp($g)]]
    set nori [llength [set ConsRef($g)]]
    set ecar [expr {$nori - [set LeCmptr($g)]}]
    set pgr  [lindex [lindex [set Comp($g)] 0] 0]
    set emg  $ne2
    set dmg  [expr {$nori - $ne2}]
    set ncons 0
    puts "[format $fmt $ident-$g $nori $ngrp $ecar $pgr $emg $dmg $top $ncons]"

    return
}


proc TraiteResultatClusteringTcl {Lres ident {nomgrp ""} {method "dpc"}} {
    global ConsMeth LNDG

    set IdG 0
    if {$nomgrp ne ""} {
	set IdG [lsearch $LNDG $nomgrp]
	incr IdG 2
    } else {
	set ConsMeth(IdenGlob) {}
	set ConsMeth(ConsGlob) {}
    }

    # Calcule norme moyenne de chaque cluster
    # Gres : Tab indexe par le residu, donne le groupe
    # Tres : Tab indexe par le groupe, donne les resius

    set i 1
    foreach c $Lres {
	set ngr "gr$i"
	set Lv {}
	set mv 0.0
	set nval 0
	foreach ind $c {
	    set listev [lrange $ind 1 end]
	    set v [lindex $ind 0]
	    lappend Lv $v
	    set Gres($v) $ngr

	    foreach e $listev {
		set mv [expr {$mv + $e}]
		incr nval
	    }
	}
	if {! $nval} {continue}
	set Tres($ngr) $Lv

	set Mnorm [expr {$mv/$nval}]
	set TNormI($ngr) $Mnorm
	set TNormV($Mnorm) $ngr
	incr i
    }

    # cherche cluster avec + grde norme
    # nel : nbr d'element de ce cluster
    # ne2 : nbr elemes cluster No 2

    set lv [lsort -decreasing -real [array names TNormV]]
    if {[llength $lv] > 1} {
	set top [set TNormV([lindex $lv 0])]
	set nel [llength [set Tres($top)]]
	set lel [set Tres($top)]
	if {[llength $lv] > 2} {
	    set dos [set TNormV([lindex $lv 1])]
	    set ne2 [llength [set Tres($dos)]]
	    set le2 [set Tres($dos)]
	} else {
	    set dos -1
	    set ne2 0
	    set le2 {}
	}
    } else {
	set nel 0
	set lel {}
	set ne2 0
	set le2 {}
    }

    # remplit tableau des conservations
    set Lret {}
    if {$nomgrp eq ""} {
	set ConsMeth(IdenGlob) $lel
	set ConsMeth(ConsGlob) $le2
	lappend Lret IdenGlob $lel ConsGlob $le2
    } else {
	set ConsMeth($nomgrp) $lel
	lappend Lret $nomgrp $lel
    }

    return $Lret
}


proc TraiteResultatClustering {fres ident {nomgrp ""} {method "dpc"}} {
    global ConsMeth LNDG

    # Lit fichier .clu de CLUSPACK , mais
    # AVEC LES COORDONNEES !!

    set IdG 0
    if {$nomgrp ne ""} {
	set IdG [lsearch $LNDG $nomgrp]
	incr IdG 2
    } else {
	set ConsMeth(IdenGlob) {}
	set ConsMeth(ConsGlob) {}
    }

    # lecture clusters.
    # Calcule norme moyenne de chaque cluster
    # Gres : Tab indexe par le residu, donne le groupe
    # Tres : Tab indexe par le groupe, donne les resius

    set Lf [LesLignesDuFichier $fres]
    lappend Lf ""

    set i 1
    foreach l [lrange $Lf 2 end] {
	if {[regexp -nocase {^Cluster|^Unclustered} $l]} {
	    set ngr "gr$i"
	    set Lv {}
	    set mv 0.
	    set nval 0
	} elseif {$l ne ""} {
	    if {! [info exists ngr]} {
		puts "[join $Lf \n]"
	    }
	    set listev [split $l "\t"]
	    set v [lindex $listev 0]
	    lappend Lv $v
	    set Gres($v) $ngr

	    foreach e [lrange $listev 1 end] {
		set mv [expr {$mv + $e}]
		incr nval
	    }
	} else {
	    if {! $nval} {continue}
	    set Tres($ngr) $Lv

	    set Mnorm [expr {$mv/$nval}]
	    set TNormI($ngr) $Mnorm
	    set TNormV($Mnorm) $ngr
	    incr i
	}
    }

    # cherche cluster avec + grde norme
    # nel : nbr d'element de ce cluster
    # ne2 : nbr elemes cluster No 2

    set lv [lsort -decreasing -real [array names TNormV]]
    if {[llength $lv] > 1} {
	set top [set TNormV([lindex $lv 0])]
	set nel [llength [set Tres($top)]]
	set lel [set Tres($top)]
	if {[llength $lv] > 2} {
	    set dos [set TNormV([lindex $lv 1])]
	    set ne2 [llength [set Tres($dos)]]
	    set le2 [set Tres($dos)]
	} else {
	    set dos -1
	    set ne2 0
	    set le2 {}
	}
    } else {
	set nel 0
	set lel {}
	set ne2 0
	set le2 {}
    }

    # remplit tableau des conservations
    set Lout {}
    if {$nomgrp eq ""} {
	set ConsMeth(IdenGlob) $lel
	set ConsMeth(ConsGlob) $le2
	set Lout [list IdenGlob $lel ConsGlob $le2]
    } else {
	set ConsMeth($nomgrp) $lel
    }

    return $Lout
}



proc LanceTestsPDB {Lres args} {
    global NId NCo NConsDansId NConsDansCo PABCourant LNDG ConsRef

    set method "dpc"
    set order "decreasing"
    set nomgrp ""
    set relatif 1
    foreach {k v} $args {
	switch $k {
	    "-nomgrp"  {
		if {$v eq {}} {set $v ""}
		set nomgrp $v
	    }
	    "-method"  {set method $v}
	    "-order"   {set order $v}
	    "-relatif" {set relatif $v}
	}
    }

    set IdG 0
    if {$nomgrp ne ""} {
	set IdG [lsearch $LNDG $nomgrp]
	incr IdG 2
    }

    # lecture clusters.
    # Calcule norme moyenne de chaque cluster
    # Gres : Tab indexe par le residu, donne le groupe
    # Tres : Tab indexe par le groupe, donne les resius

    set i 1
    foreach c $Lres {
	set ngr "gr$i"
	set Lv {}
	set mv 0.
	set nval 0
	foreach ind $c {
	    set listev [lrange $ind 1 end]
	    set v [lindex $ind 0]
	    lappend Lv $v
	    set Gres($v) $ngr

	    foreach e $listev {
		set mv [expr {$mv + $e}]
		incr nval
	    }
	}
	if {! $nval} {continue}
	set Tres($ngr) $Lv

	set Mnorm [expr {$mv/$nval}]
	set TNormI($ngr) $Mnorm
	set TNormV($Mnorm) $ngr
	incr i
    }

    # cherche cluster avec + grde norme
    # nel : nbr d'element de ce cluster

    set Lclus [lsort -$order -real [array names TNormV]]
    if {$Lclus == {}} {
	puts "\t===> 1 cluster vide !!"
	return 0
    }
    if {[llength $Lclus] == 1} {
	puts "\t==> Only ONE cluster !"
	return 0
    }

    set top [set TNormV([lindex $Lclus 0])]
    set nel [llength [set Tres($top)]]
    set lel [set Tres($top)]
    if {[llength $Lclus] <= 1} {
	set dos -1
	set ne2 0
	set le2 {}
    } else {
	set dos [set TNormV([lindex $Lclus 1])]
	set ne2 [llength [set Tres($dos)]]
	set le2 [set Tres($dos)]
    }

    set LConsSA {}
    if {[info exists ConsRef($PABCourant,sa)]} {
	set LConsSA [set ConsRef($PABCourant,sa)]
    }
    set LConsNA {}
    if {[info exists ConsRef($PABCourant,nsa)]} {
	set LConsNA [set ConsRef($PABCourant,nsa)]
    }
    incr NId $nel
    incr NCo $ne2
    if {[land $lel $le2] != {}} {
	puts "PROBLEME !"
	puts "Residues in both indetity and Conservation !"
	return 0
    }

    foreach {a n1 n2} $LConsSA {
	if {$relatif} {
	    set x1 [CorrespondanceSeqGen $PABCourant $n1]
	    set x2 [CorrespondanceSeqGen $PABCourant $n2]
	} else {
	    set x1 $n1
	    set x2 $n2
	}

	if {$x1 eq "" || $x2 eq ""} {
	    puts "$PABCourant $n1 $n2 $x1 $x2"
	}

	for {set i $x1} {$i <= $x2} {incr i} {
	    if {$i in $lel} {incr NConsDansId}
	    if {$i in $le2} {incr NConsDansCo}
	}
    }

    return 1
}


proc LanceTestsBali {Lres args} {
    global NId NCo NTt NConsDansId NConsDansCo NConsDansTt PABCourant LNDG LConsSA

    set NId 0 ; set NCo 0 ; set NTt 0
    set NConsDansId 0
    set NConsDansCo 0
    set NConsDansTt 0

    set method "dpc"
    set order "decreasing"
    set nomgrp ""
    set relatif 1
    foreach {k v} $args {
	switch $k {
	    "-nomgrp"  {
		if {$v eq {}} {set $v ""}
		set nomgrp $v
	    }
	    "-method"  {set method $v}
	    "-order"   {set order $v}
	    "-relatif" {set relatif $v}
	}
    }

    # lecture clusters.
    # Calcule norme moyenne de chaque cluster
    # Gres : Tab indexe par le residu, donne le groupe
    # Tres : Tab indexe par le groupe, donne les resius

    set i 1
    set vtot 0
    foreach c $Lres {
	set ngr "gr$i"
	set Lv {}
	set mv 0.
	set nval 0
	foreach ind $c {
	    set listev [lrange $ind 1 end]
	    set v [lindex $ind 0]
	    lappend Lv $v
	    set Gres($v) $ngr

	    foreach e $listev {
		set mv [expr {$mv + $e}]
		incr nval
		incr vtot
	    }
	}
	if {! $nval} {continue}
	set Tres($ngr) $Lv

	set Mnorm [expr {$mv/$nval}]
	set TNormI($ngr) $Mnorm
	set TNormV($Mnorm) $ngr
	incr i
    }

    # cherche cluster avec + grde norme
    # nel : nbr d'element de ce cluster
    set Lclus [lsort -$order -real [array names TNormV]]
    puts "[join $method +] : $vtot [llength $Lclus]"
    if {$Lclus == {}} {
	puts "\t===> 1 cluster vide !!"
	return 0
    }
    if {[llength $Lclus] == 1} {
	puts "\t==> Only ONE cluster !"
	return 0
    }

    set top [set TNormV([lindex $Lclus 0])]
    set nel [llength [set Tres($top)]]
    set lel [set Tres($top)]
    if {[llength $Lclus] <= 1} {
	set dos -1
	set ne2 0
	set le2 {}
    } else {
	set dos [set TNormV([lindex $Lclus 1])]
	set ne2 [llength [set Tres($dos)]]
	set le2 [set Tres($dos)]
    }

    set NId $nel
    set NCo $ne2
    set NTt [expr {$nel + $ne2}]
    set NConsDansId 0
    set NConsDansCo 0
    set NConsDansTt 0

    foreach e $lel {
	if {$e in $LConsSA} {
	    incr NConsDansId
	    incr NConsDansTt
	}
    }
    foreach e $le2 {
	if {$e in $LConsSA} {
	    incr NConsDansCo
	    incr NConsDansTt
	}
    }

    return 1
}


proc LanceTestsPfam {Lres args} {
    global NId NCo NTt NConsDansId NConsDansCo NConsDansTt PABCourant LNDG

    set NId 0 ; set NCo 0 ; set NTt 0
    set NConsDansId 0
    set NConsDansCo 0
    set NConsDansTt 0

    set method "dpc"
    set order "decreasing"
    set nomgrp ""
    set relatif 1
    foreach {k v} $args {
	switch $k {
	    "-nomgrp"  {
		if {$v eq {}} {set $v ""}
		set nomgrp $v
	    }
	    "-method"  {set method $v}
	    "-order"   {set order $v}
	    "-relatif" {set relatif $v}
	}
    }

    # lecture clusters.
    # Calcule norme moyenne de chaque cluster
    # Gres : Tab indexe par le residu, donne le groupe
    # Tres : Tab indexe par le groupe, donne les resius

    set i 1
    set vtot 0
    foreach c $Lres {
	set ngr "gr$i"
	set Lv {}
	set mv 0.
	set nval 0
	foreach ind $c {
	    set listev [lrange $ind 1 end]
	    set v [lindex $ind 0]
	    lappend Lv $v
	    set Gres($v) $ngr

	    foreach e $listev {
		set mv [expr {$mv + $e}]
		incr nval
		incr vtot
	    }
	}
	if {! $nval} {continue}
	set Tres($ngr) $Lv

	set Mnorm [expr {$mv/$nval}]
	set TNormI($ngr) $Mnorm
	set TNormV($Mnorm) $ngr
	incr i
    }

    # cherche cluster avec + grde norme
    # nel : nbr d'element de ce cluster
    set Lclus [lsort -$order -real [array names TNormV]]
    puts "[join $method +] : $vtot [llength $Lclus]"
    if {$Lclus == {}} {
	puts "\t===> 1 cluster vide !!"
	return 0
    }
    if {[llength $Lclus] == 1} {
	puts "\t==> Only ONE cluster !"
	return 0
    }

    set top [set TNormV([lindex $Lclus 0])]
    set nel [llength [set Tres($top)]]
    set lel [set Tres($top)]
    if {[llength $Lclus] <= 1} {
	set dos -1
	set ne2 0
	set le2 {}
    } else {
	set dos [set TNormV([lindex $Lclus 1])]
	set ne2 [llength [set Tres($dos)]]
	set le2 [set Tres($dos)]
    }

    set LConsSA {}
    foreach {a x1 x2} [set ConsRef(${PABCourant},sa)] {
	for {set i $x1} {$i <= $x2} {incr i} {
	    lappend LConsSA $i
	}
    }
    if {0 && $method eq "Norm"} {
	set lv [lsort -real -decreasing -index 1 $::ListeScore]
	puts "[join [lrange $lv 0 20] \n]"
	puts "LConsSA $LConsSA"
	puts "lel $lel"
    }
    set LConsNA {}
    foreach {a x1 x2} [set ConsRef(${PABCourant},nsa)] {
	for {set i $x1} {$i <= $x2} {incr i} {
	    lappend LConsNA $i
	}
    }

    if {[land $lel $le2] != {}} {
	puts "PROBLEME !"
	puts "Residues in both indetity and Conservation !"
	return 0
    }

    set NId $nel
    set NCo $ne2
    #set NTt [expr {$nel + $ne2}]
    set NTt $nel
    set NConsDansId 0
    set NConsDansCo 0
    set NConsDansTt 0
    #puts "lel  $lel"
    #puts "lcsa $LConsSA"
    foreach e $lel {
	if {$e in $LConsSA} {
	    incr NConsDansId
	    incr NConsDansTt
	}
	if {$e in $LConsNA} {
	    incr NConsDansCo
	    incr NConsDansTt
	}
    }

    if {0} {
	foreach e $le2 {
	    if {$e in $LConsNA} {incr NConsDansCo}
	}
    }

    return 1
}


proc ExtraitRadicalDuGroupe {a} {
    set i -1
    set pasnb 0
    while {! $pasnb} {
	incr i
	set pasnb [regexp {[0-9]} [string index $a $i]]
    }
    set ea [string range $a 0 [expr {$i-1}]]

    return $ea
}


proc ReordonneTypeCons {{plein ""}} {
    global ConsRef

    set l [array names ConsRef]

    set new {}
    foreach e {"IdenGlob" "ConsGlob" "SimiGlob"} {
	set i [lsearch $l $e]
	if {$i != -1} {
	    set l [lreplace $l $i $i]
	    lappend new $e
	} else {
	    if {$plein != ""} {lappend new $e}
	}
    }

    set lg [lsort -integer -decreasing [lsearch -all -regexp $l "Gris"]]
    foreach i $lg {
	set l [lreplace $l $i $i]
    }

    set lg [lsort -integer -decreasing [lsearch -all -regexp $l "oin"]]
    foreach i $lg {
	set l [lreplace $l $i $i]
    }

    set l [lsort -command TrieNomGroupe $l]
    set new [concat $new $l]

    return $new
}



proc RecupereReference {} {
    global TableauCouleurEtGroupe
    global ConsRef
    global LNDG

    set LesVals [array get TableauCouleurEtGroupe]
    foreach {v b} $LesVals {
	set l [split $v ","]
	set r [lindex $l 0]
	set g [lindex $l 1]
	# augmente r car ali commence a 0 !
	incr r

	lappend ConsRef($b) $r
    }

    if {! [info exists ConsRef(IdenGlob)]} {set ConsRef(IdenGlob) {} }
    if {! [info exists ConsRef(ConsGlob)]} {set ConsRef(ConsGlob) {} }
    if {! [info exists ConsRef(SimiGlob)]} {set ConsRef(SimiGlob) {} }

    VerifieNbrDeGroupes

    return
}



proc VerifieNbrDeGroupes {} {

    global ConsRef
    global LNDG

    update
    set lori [lrange $LNDG 1 end-1]
    set lori [lsort -command TrieNomGroupe $lori]
    set lgrf [lrange [ReordonneTypeCons "plein"] 3 end]
    set nlg [expr {[llength $lgrf] - 3}]
    set nbg [expr {[llength $LNDG] - 2}]
    if {$nlg == $nbg} {return}
    if {$nbg == 1} {
	set LNDG [lreplace $LNDG 1 1]
	return
    }

    set rep 0
    set Radical "CoulG"
    foreach a $lori b $lgrf {
	set x [ExtraitNoDuGroupe $a]
	set y [ExtraitNoDuGroupe $b]
	if {$x == $y} {continue}
	set nwg "$Radical$x"
	set ConsRef($nwg) {}
	set rep 1
	break
    }

    if {$rep} {set rep [VerifieNbrDeGroupes]}

    return $rep
}



proc LoadNorMD {} {
    global LNorMD

    #set rep [file join [RepGenLuc] msf_nature Rascal Leon]
    #aF travaille sur les msf de rascal
    set rep [file join [RepGenLuc] msf_nature Rascal]
    set Ll [LesLignesDuFichier [file join $rep "NorMD.out"]]
    set Tot 0.
    set Inf 0
    set Tsp 0.
    foreach l $Ll {
	set f [lindex $l 0]
	set n [lindex $l 1]
	set LNorMD($f) $n
	set Tot [expr {$Tot + $n}]
	if {$n < 0.3} {
	    incr Inf
	} else {
	    set Tsp [expr {$Tsp + $n}]
	}
    }

    puts ""
    puts "Nombre alignt ........: [llength $Ll]"
    puts "Nombre alignt > 0.3 ..: [expr {[llength $Ll] - $Inf}]"
    puts "NorMD moyen ..........: [expr {$Tot / [llength $Ll]}]"
    puts "NorMD > 0.4 moyen ....: [expr {$Tsp /([llength $Ll] - $Inf)}]"
    puts ""

    return
}



proc LoadReferencePDB {} {
    global TNResConsNSA TNResConsSA ConsRef

    set rep [file join [RepGenLuc] AnalyseSelection]
    set Ll [LesLignesDuFichier [file join $rep "resSitePDB.txt"]]
    set sa 0
    set sna 0
    set NResConsSA  0
    set NResConsNSA 0
    set Prems 1
    foreach l $Ll {
	if {[regexp {^gPDB} $l]} {
	    if {$Prems} {
		set Prems 0
	    } else {
		set TNResConsSA($f)  $NResConsSA
		set TNResConsNSA($f) $NResConsNSA
		set NResConsSA  0
		set NResConsNSA 0
	    }
	    set f [lindex $l 0]
	    continue
	}
	if {[regexp "site actif" $l]} {
	    set sa 1
	    set sna 0
	    continue
	}
	if {[regexp "site non actif" $l]} {
	    set sna 1
	    set sa 0
	    continue
	}
	if {[regexp {^[A-Z]} $l]} {
	    set aa [lindex $l 0]
	    set n  [lindex $l 1]
	    if {$sa} {
		lappend ConsRef($f,sa) $aa $n
		incr NResConsSA
	    } else {
		lappend ConsRef($f,sna) $aa $n
		incr NResConsNSA
	    }
	    continue
	}
    }
    set TNResConsSA($f)  $NResConsSA
    set TNResConsNSA($f) $NResConsNSA

    return
}



proc LoadReference {} {

    global ConsRef

    unset ConsRef

    set Lf [LesLignesDuFichier "logasp.all"]
    foreach l $Lf {
	set Ll [split $l ":"]
	set ng [lindex $Ll 0]
	set lr [lindex $Ll 1]
	regsub -all {\.} $ng "" ng
	regsub -all {\(} $lr "" lr
	regsub -all {\)} $lr "" lr
	regsub -all " " $lr "" lr
	set Res [split $lr ","]

	set ConsRef($ng) $Res
    }

    return
}



proc EcritListeScore {{f ""}} {

    global ListeScore

    if {$f == ""} {set f "brute.dat"}
    set f [open $f w]
    set i 1
    foreach e $ListeScore {
	set le [join $e " "]
	puts $f "$i $le"
	incr i
    }
    close $f

    return
}


proc CreeListeScore {{g ""}} {
    global ListeScore TbScores

    if {$g ne ""} {
	EnleveConservationGlobale
    }

    set len [llength [set TbScores(Score,[lindex $TbScores(Lcols) 0 ])]]
    set Lidx {}
    for {set i 0} {$i < $len} {incr i} {
	lappend Lidx $i
    }
    set ListeScore {}
    foreach i $Lidx {
	set ligne [list $i]
	set cok 1
	foreach sco [set TbScores(Lcols)] {
	    if {[set val [lindex [set TbScores(Score,$sco)] $i]] == -999.0} {
		set cok 0
		break
	    }
	    lappend ligne $val
	}
	if {$cok} {
	    lappend ListeScore $ligne
	}
    }

    return $ListeScore
}


proc NormalisationColonnes {} {
    global ListeScore

    # Fait normalisation
    set n [llength $ListeScore]
    if {! $n} {
	return 0
    }

    set c [llength [lindex $ListeScore 0]]
    # colonne 0 est un flag, commence a 1
    for {set i 1} {$i < $c} {incr i} {
	set l$i [ExtraitListeDeListe $ListeScore $i]
	if {[llength [lsort -unique [set l$i]]] == 1} {
	    puts "==> only ONE value : [lindex [set l$i] 0] repeated [llength [set l$i]] times, col $i of ListeScore"
	    return 0
	}
	set nl$i [Standardise [set l$i]]
    }

    # get columns indexes
    set tmp [ExtraitListeDeListe $ListeScore 0]
    set new {}
    for {set j 0} {$j < $n} {incr j} {
	set l [lindex $tmp $j]
	for {set i 1} {$i < $c} {incr i} {
	    lappend l [lindex [set nl$i] $j]
	}
	lappend new $l
    }

    set ListeScore $new

    return 1
}


proc EcritPourDPC {{filout ""}} {
    global OrdTmpDir ListeScore

    if {$filout eq ""} {set filout [file join $OrdTmpDir "[pid]_ficdpc.dat"]}
    set f [open $filout w]

    set nv [expr {[llength [lindex $ListeScore 0]] - 1}]
    set comp [llength $ListeScore]
    puts $f "$comp\t$nv"
    puts $f ""
    foreach s $ListeScore {
	puts $f [join $s "\t"]
    }

    close $f

    return
}


proc DefineGapThreshold {nseq} {
    set thr [expr {int($nseq*$::Defauts(PCThrGap))}]
    if {$thr < $::Defauts(MinThrGap)} {
	set thr $::Defauts(MinThrGap)
    }

    return $thr
}


##########################################
#
# SCORING FUNCTIONS
#
##########################################
#
# Symbol frequency :
# ------------------
# - Kabat : variability, no weighting
# - Ranganatan : conservation , no weighting
#
# Stereo-chemical :
# -----------------
# - Norm : conservation, no weighting
# - RPCA : conservation, no weighting
#
# Symbol entropy :
# ----------------
# - Wang : conservation, no weighting
# - Capra : conservation, no weighting
#
# Stereochemically sensitive entropy :
# ------------------------------------
# - entrop1 : conservation, no weighting
# - Williamson : conservation, no weighting
# - Caffrey : conservation, no weighting
#
# Substitution matrix :
# ---------------------
# - Thompson : conservation, no weighting
# - SanderSP : conservation, weighted
# - Valdar : conservation, weighted
# - Peivar : conservation, no weighting
# - Liu2 : conservation, no weighting
# - Karlin : conservation
#

proc InitScoreDeBILD {} {
    global BILDback BILDweight BILDalpha BILDAlpha

    package require math
    set data [DirichletMixtureData]

    set cmp -1
    set weight {}
    set Alpha {}
    set alpha {}
    for {set m 0} {$m < 20} {incr m} {
	incr cmp
	lappend weight [lindex $data $cmp]
	set sAlpha 0.0
	set lalpha {}
	for {set i 0} {$i < 20} {incr i} {
	    incr cmp
	    set v [lindex $data $cmp]
	    lappend lalpha $v
	    set sAlpha [expr {$sAlpha + $v}]
	}
	lappend alpha $lalpha
	lappend Alpha $sAlpha
    }

    set BILDback {}
    for {set i 0} {$i < 20} {incr i} {
	set sBack 0.0
	for {set m 0} {$m < 20} {incr m} {
	    set sBack [expr {$sBack + [lindex $weight $m] * [lindex [lindex $alpha $m] $i] / [lindex $Alpha $m]}]
	}
	lappend BILDback $sBack
    }

    return [list $BILDback $weight $alpha $Alpha]
}


proc ScoreDeShannon {ListePil {ThrGap ""}} {
    # Compute shannon entropy

    set scores {}
    set n_total [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $n_total]
    }

    # Normalisation par log2(20)
    set H_max  [expr {log(20.0) / log(2.0)}]

    foreach column $ListePil {
	set pdg [string map {"X" "" "Z" "" "\." ""} $column]
        if {[string length $pdg] < $ThrGap} {
            lappend scores -999.0
            continue
        }

        # Compter gaps et résidus
        array unset counts
        set n_res  0
        set n_gaps 0
        foreach residue [split $column ""] {
            if {$residue eq "." || $residue eq "Z" || $residue eq "X"} {
                incr n_gaps
            } else {
                incr counts($residue)
                incr n_res
            }
        }

        # Fraction de gaps
        set f_gaps [expr {double($n_gaps) / $n_total}]

        # Entropie de Shannon sur les résidus non-gap
        set H 0.0
        foreach residue [array names counts] {
            set p [expr {double($counts($residue)) / $n_res}]
            set H [expr {$H - $p * log($p) / log(2.0)}]
        }

        set H_norm [expr {$H / $H_max}]
        # Score final : conservation pondérée par la fraction de gaps
        set score [expr {(1.0 - $H_norm) * (1.0 - $f_gaps)}]
        lappend scores $score

        array unset counts
    }

    return $scores
}


proc ScoreDeCodine {ListePil {ThrGap ""}} {
    global VolPol
    
    # Base sur volume - polarite
    if {! [info exists VolPol]} {
	InitialiseVolPol
    }

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set Laa [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lres {}
    foreach p $ListePil {
	set pdg [string map {X "" Z "" " " "" "\." "" - ""} $p]
	if {[set ntot [string length $pdg]] < $ThrGap} {
	    lappend Lres -999.0
	    
	    continue
	}
	
	set svp 0.0 ; set sv 0.0 ; set sp 0.0
	foreach aa [split $pdg ""] {
	    lassign $VolPol($aa) v p
	    set svp [expr {$svp + $v*$p}]
	    set sv  [expr {$sv + $v*$v}]
	    set sp  [expr {$sp + $p*$p}]
	}
	set sim [expr {$svp/(sqrt($sv)*sqrt($sp))}]
	lappend Lres $sim
    }

    return $Lres
}


proc ScoreDeBILD_EST_MIEUX_DANS_ordali_conservation {ListePil {ThrGap ""}} {
    global BILDback BILDweight BILDalpha BILDAlpha

    if {! [info exists BILDback]} {
	lassign [InitScoreDeBILD] BILDback BILDweight BILDalpha BILDAlpha
    }

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set Laa [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lres {}
    foreach p $ListePil {
	set pdg [string map {X "" Z "" " " "" "." "" - ""} $p]
	if {[set ntot [string length $pdg]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}

	set caa {}
	set count 0
	foreach a $Laa {
	    set n [expr {$ntot - [string length [string map [list $a ""] $pdg]]}]
	    lappend caa $n
	    incr count $n
	}

	set bild 0.0 ; set logprob 0.0
	for {set m 0} {$m < 20} {incr m} {
	    set logprob [expr { \
				    log([lindex $BILDweight $m]) + \
				    [::math::ln_Gamma [lindex $BILDAlpha $m]] - \
				    [::math::ln_Gamma [::tcl::mathop::+ [lindex $BILDAlpha $m] $count]]}]
	    for {set i 0} {$i < 20} {incr i} {
		set logprob [expr {$logprob + \
				       [::math::ln_Gamma [::tcl::mathop::+ [lindex [lindex $BILDalpha $m] $i] [lindex $caa $i]]] - \
				       [::math::ln_Gamma [lindex [lindex $BILDalpha $m] $i]]}]
	    }
	    if {$m == 0} {
		set bild $logprob
	    } elseif {$bild > $logprob} {
		set bild [expr {$bild + log(1.0+exp($logprob-$bild))}]
	    } else {
		set bild [expr {$logprob+log(1.0+exp($bild-$logprob))}]
	    }
	}

	for {set i 0} {$i < 20} {incr i} {
	    set bild [expr {$bild - [lindex $caa $i]*log([lindex $BILDback $i])}]
	}
	set bild [expr {$bild / log(2.0)}]

	lappend Lres $bild
    }
    #puts "\nScoreDeBILD :"
    #plist $Lres %6.3f

    return $Lres
}


proc ScoreDeWang_EST_MIEUX_DANS_ordali_conservation {ListePil {ThrGap ""}} {
    # Wang , 2006
    #
    # C     = sum_1^20 pkxlog(pk/f)
    # pk    = frequency of aa at position x
    # f     = observed frequency of aa in databases

    # from MAFFT
    set aamafft "ARNDCQEGHILKMFPSTWYV"
    set freqaa [list 0.077 0.051 0.043 0.052 0.020 0.041 0.062 0.074 0.023 0.052 0.091 0.059 0.024 0.040 0.051 0.069 0.059 0.014 0.032 0.066]
    # from Ranganatan
    #    set freqaa [list 0.072658 0.024692 0.050007 0.061087 0.041774 0.071589 0.023392 0.052691 0.063923 0.089093 0.023150 0.042931 0.052228 0.039871 0.052012 0.073087 0.055606 0.063321 0.012720 0.032955]
    #    set aamafft "ACDEFGHIKLMNPQRSTVWY"
    set Laa [split $aamafft ""]

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lv {}
    foreach p $ListePil {
	set pdg [string map [list X "" Z "" " " "" "." ""] $p]
	if {[string length $pdg] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set v 0.0
	foreach aa $Laa f $freqaa {
	    set pk [expr {double($nseq - [string length [string map [list $aa ""] $p]])/$nseq}]
	    if {$pk > 0.0} {
		set v [expr {$v + $pk*log($pk/$f)}]
	    }
	}
	lappend Lv $v
    }

    return $Lv
}


proc ScoreDeCaffrey {ListePil {ThrGap ""}} {
    # Caffrey et al, 2004
    #
    # C = -Tr(mxlog20(m)), Tr(m) = matrix trace = 1
    # m : density matrix at column x, computed as
    #   = mfreq x Blosum62 , mfreq beeing the
    # frequency matrix, all diagonal elements are aa
    # freaquencies and all other terms = 0
    # Blosum is blosum62 frequencies matrix
    #
    # gap pen = nres/nseq
    # S= 1 - nres/nseq x C

    package require math::linearalgebra

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
	
    # set-up matrices
    set Mb [::math::linearalgebra::mkMatrix 20 20 0.0]
    set Mf [::math::linearalgebra::mkMatrix 20 20 0.0]
    set Mr [::math::linearalgebra::mkMatrix 20 20 0.0]
    array set Mori [InitialiseBlosum62f]
    set Laa [split [set Mori(laa)] ""]

    set i 0
    foreach a $Laa {
	set vec {}
	foreach b $Laa {
	    lappend vec [set Mori($a,$b)]
	}
	lset Mb $i $vec
	incr i
    }

    set Lv {}
    foreach p $ListePil {
	set pdg [string map [list X "" Z "" " " "" "." ""] $p]
	if {[set lpdg [string length $pdg]] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set i 0
	foreach a $Laa {
	    set pk [expr {(double($lpdg-[string length [string map [list $a ""] $pdg]]))/double($lpdg)}]
	    lset Mf $i $i $pk
	    incr i
	}
	#puts "Mf :"
	#puts [::math::linearalgebra::show $Mf]
	#puts ""

	set Mr [::math::linearalgebra::matmul $Mf $Mb]

	#puts "Mr brute"
	#puts [::math::linearalgebra::show $Mr]
	#puts ""

	# scale so that Tr(Mr)=1
	set sum 0.0
	for {set i 0} {$i < 20} {incr i} {
	    set sum [expr {$sum + [lindex [lindex $Mr $i] $i]}]
	}
	set sum [expr {1.0/$sum}]
	set Mr [::math::linearalgebra::scale $sum $Mr]
	#puts "Mr scaled $sum"
	#puts [::math::linearalgebra::show $Mr]
	#puts ""

	if {1} {
	    # calcule Mr x log20(Mr)
	    for {set i 0} {$i < 20} {incr i} {
		for {set j 0} {$j < 20} {incr j} {
		    set x [lindex [lindex $Mr $i] $j]
		    if {$x > 0} {
			set x [expr {$x*log($x)}]
			lset Mr $i $j $x
		    }
		}
	    }
	    # c= -Tr(Mr)
	    set sum 0.0
	    for {set i 0} {$i < 20} {incr i} {
		set sum [expr {$sum - [lindex [lindex $Mr $i] $i]/log(20.)}]
	    }
	} else {
	    # calcule vecteurs propres
	    set Vp [lindex [::math::linearalgebra::determineSVD $Mr] 1]
	    #set Vp [lindex [::math::linearalgebra::eigenvectorsSVD $Mr] 1]

	    set svp 0.0
	    foreach v $Vp {
		set svp [expr {$svp + $v}]
	    }
	    #puts "svp $svp\n"

	    set sum 0
	    foreach v $Vp {
		if {$v > 0} {
		    set sum [expr {$sum - $v*log($v)/log(20.)}]
		}
	    }
	}

	lappend Lv [expr {double($lpdg)/$nseq*$sum}]
    }
    set tmp [lsort -real -unique $Lv]
    if {[set min [lindex $tmp 0]] == -999.0} {
	set min [lindex $tmp 1]
    }
    set max [lindex $tmp end]

    # revert
    set Lres {}
    foreach v $Lv {
	if {$v != -999.0} {
	    set v [expr {$max - $v + $min}]
	}
	lappend Lres $v
    }

    return $Lres
}


proc ScoreDeCapra {ListePil {ThrGap ""}} {
    # Capra et all, 2007, bioinformatics
    #
    # RE(pk,q) = pk x ln(pk/q)
    # pk = probability of an aminoacid  at site k
    # q  = database proportion of an aminoacid
    # C = (RE(pk,r) + RE(q,r))/2, r=(pk + q)/2
    #
    #
    # from MAFFT
    set aamafft "ARNDCQEGHILKMFPSTWYV"
    set freqaa [list 0.077 0.051 0.043 0.052 0.020 0.041 0.062 0.074 0.023 0.052 0.091 0.059 0.024 0.040 0.051 0.069 0.059 0.014 0.032 0.066]
    # from Ranganatan
    #    set freqaa [list 0.072658 0.024692 0.050007 0.061087 0.041774 0.071589 0.023392 0.052691 0.063923 0.089093 0.023150 0.042931 0.052228 0.039871 0.052012 0.073087 0.055606 0.063321 0.012720 0.032955]
    #    set aamafft "ACDEFGHIKLMNPQRSTVWY"
    set Laa [split $aamafft ""]

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lv {}
    foreach p $ListePil {
	set pdg [string map [list X "" Z "" " " "" "." ""] $p]
	if {[set lpdg [string length $pdg]] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set v 0.0
	foreach aa $Laa f $freqaa {
	    set pk [expr {(double($nseq - [string length [string map [list $aa ""] $p]]))/double($nseq)}]
	    set r [expr {($pk+$f)/2.}]
	    if {$pk > 0} {
		set Rpkr [expr {$pk*log($pk/$r)}]
	    } else {
		set Rpkr 0.0
	    }
	    set Rqr [expr {$f*log($f/$r)}]
	    set v [expr {$v + ($Rpkr + $Rqr)/2.}]
	}
	lappend Lv $v
    }

    return $Lv
}


proc ScoreDeKarlin {ListePil {ThrGap ""}} {
    # Karlin
    #
    # C(x) = sum_ixsum_j>i M(a,b)x 2/(N(N-1))
    # M(a,b) = m(a,b)/sqrt(m(a,a)xm(b,b))
    # m is the blosum62 matrix

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    # scale matrix
    array set Mori [InitClustalMatrix blosum62]
    set Lnon [list average X laa]
    foreach k [array names Mori] {
	lassign [split $k ,] a b
	if {$a eq $b || $a in $Lnon || $b in $Lnon} {
	    set Tmat($a,$a) 1.0
	} else {
	    set Tmat($a,$b) [expr {double([set Mori($a,$b)])/sqrt([set Mori($a,$a)]*[set Mori($b,$b)])}]
	}
    }

    set Lv {}
    foreach p $ListePil {
	set pdg [string map [list X "" Z "" U "" B "" J "" " " "" "." "" "-" ""] $p]
	if {[set lpdg [string length $pdg]] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set i -1 ; set sum 0.0
	set Ltpdg [split $pdg ""]
	foreach a $Ltpdg {
	    incr i
	    foreach b [lrange $Ltpdg $i+1 end] {
		set sum [expr {$sum + [set Tmat($a,$b)]}]
	    }
	}
	lappend Lv [expr {$sum * 2./($nseq*($nseq-1))}]
    }

    return $Lv
}


proc ScoreDePeivar {ListePil {ThrGap ""}} {
    # Pei et all 2001
    #
    # S     = sqrt(sum_1^20(pk(i)-p(i))**2)
    # pk(i) = proportion of i at site k
    # p(i)  = proportion of i in the alignment

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set ListeAA [list A C D E F G H I K L M N P Q R S T V W Y]
    foreach aa $ListeAA {
	set ntot$aa 0
    }

    set Lv {}
    foreach p $ListePil {
	set pdg [string map [list X "" Z "" " " "" "." "" "-" ""] $p]
	if {[set lpdg [string length $pdg]] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set vec $lpdg
	foreach aa $ListeAA {
	    set naa [expr {$lpdg - [string length [string map [list $aa ""] $pdg]]}]
	    incr ntot$aa $naa
	    lappend vec $naa
	}
	lappend Lv $vec
    }

    set ntot 0
    foreach aa $ListeAA {
	incr ntot [set ntot$aa]
    }

    set Lres {}
    foreach v $Lv {
	if {$v == -999.} {
	    lappend Lres $v
	    continue
	}

	set nv [lindex $v 0]
	set sum 0.0
	foreach aa $ListeAA x [lrange $v 1 end] {
	    set sum [expr {$sum + ((double($x)/$nv)-(double([set ntot$aa])/$ntot))**2}]
	}
	lappend Lres [expr {sqrt($sum)}]
    }

    return $Lres
}


proc ScoreDeSanderSP {ListePil Ln LPCI {ThrGap ""}} {
    # Sander and Schneider 1991
    # weighted sum of pairs
    #
    # Sk     = scale x sum_i^N sum_j>i^N wijxM(a,b)
    # scale  = 1./(sum_i,j wij)
    # M(a,b) = M(a,b)/sqrt(M(a,a)xM(b,b))

    set nseq [string length [lindex $ListePil 0]]

    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    # weighting scale
    set scale 0.0
    foreach {k v} $LPCI {
	lassign [split $k ,] a b
	if {$a ne $b} {
	    if {! [info exists T($a,$b)]} {
		set scale [expr {$scale + (1. - [lindex $v 0])}]
		set T($a,$b) 1
		set T($b,$a) 1
	    }
	}
    }
    unset T
    set scale [expr {1.0/$scale}]

    # scale matrix
    #array set Mori [InitClustalMatrix pam250]
    array set Mori [InitClustalMatrix blosum62]
    set Lnon [list average X laa]
    foreach k [array names Mori] {
	lassign [split $k ,] a b
	if {$a eq $b || $a in $Lnon || $b in $Lnon} {
	    set Tmat($a,$a) 1.0
	} else {
	    set Tmat($a,$b) [expr {double([set Mori($a,$b)])/sqrt([set Mori($a,$a)]*[set Mori($b,$b)])}]
	}
    }

    # main loop
    array set T $LPCI
    set Lv {}
    set Laa [list A C D E F G H I K L M N P Q R S T V W Y]
    foreach p $ListePil {
	set pdg [string map {X "" Z "" " " "" "." ""} $p]
	if {[string length $pdg] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set v 0.0
	set Lp [split $p ""]
	set i -1
	foreach ca $Lp {
	    incr i
	    if {$ca ni $Laa} {
		continue
	    }
	    set a [lindex $Ln $i]
	    set j $i
	    foreach cb [lrange $Lp $i+1 end] {
		incr j
		if {$cb ni $Laa} {
		    continue
		}
		set b [lindex $Ln $j]
		set v [expr {$v + (1.0 - [lindex [set T($a,$b)] 0])*[set Tmat($ca,$cb)]}]
	    }
	}
	lappend Lv [expr {$scale*$v}]
    }

    return $Lv
}


proc ScoreDeKabat {ListePil {ThrGap ""}} {
    # Wu TT, Kabat EA. An analysis of the sequences of the variable regions of Bence Jones proteins and myeloma light chains and their implications for antibody complementarity. J Exp Med 1970; 132: 211Â–249.
    #
    # V = k/n1xN
    # k  : number of different kind of aa in column
    # n1 : number of times the most present aa in col
    # N  : number of seqs

    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lv {}
    foreach pori $ListePil {
	set p [string map [list X "" Z "" " " "" "." "" "-" ""] $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lv -999.0

	    continue
	}

	set nkind 0 ; set nmax 0
	foreach a $ListeAA {
	    set n [expr {$ntot - [string length [string map [list $a ""] $p]]}]
	    if {$n > 0} {
		if {$n > $nmax} {
		    set nmax $n
		}
		incr nkind
	    }
	}
	set v [expr {double($nkind)/double($nmax)*double($nseq)}]

	lappend Lv $v
    }

    set tmp [lsort -real -unique $Lv]
    if {[set min [lindex $tmp 0]] == -999.0} {
	set min [lindex $tmp 1]
    }
    set max [lindex $tmp end]

    # revert
    set Lres {}
    foreach v $Lv {
	if {$v != -999.0} {
	    set v [expr {$max - $v + $min}]
	}
	lappend Lres $v
    }

    # WARNING !
    # highest score of Kabat depends on the number of seqs !

    return $Lres
}


proc ScoreDeWilliamson {ListePil {ThrGap ""}} {
    # Williamson RM. Information theory analysis of the
    # relationship between primary sequence structure and
    # ligand recognition among a class of facilitated
    # transporters.
    # J Theor Biol 1995; 174: 179
    #
    #
    # V = sum_i^K Pixln(Pi/Pmi)
    # K=9 :
    # [VLIM] [FWY] [ST] [NQ] [HKR] [DE] [AG] [P] [C].
    # Pi  : fractional frequency for classe i
    # Pmi : fractional frequancy for class i over the whole alignment
    # This score does not account for gaps.

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lclas [list VLIM FWY ST NQ HKR DE AG P C]
    foreach c $Lclas {
	set sum$c 0
    }
    set Lpat [list \
		  [list V "" L "" I "" M ""] \
		  [list F "" W "" Y ""] \
		  [list S "" T ""] \
		  [list N "" Q ""] \
		  [list R "" H "" K ""] \
		  [list D "" E ""] \
		  [list A "" G ""] \
		  [list C ""] \
		  [list P ""]]

    set Lres {}
    set nRTot 0
    foreach pori $ListePil {
	set p [string map [list X "" Z "" " " "" "." ""] $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}

	incr nRTot $ntot
	set ltmp {}
	foreach c $Lclas pat $Lpat {
	    set n [expr {$ntot - [string length [string map $pat $p]]}]
	    incr sum$c $n
	    lappend ltmp [expr {double($n)/$ntot}]
	}
	lappend Lres $ltmp
    }

    if {$nRTot == 0} {
	puts "Something wrong !\nNo residues !"
	return [lrepeat [llength $ListePil] -999.0]
    }

    # compute global fractions
    foreach c $Lclas {
	set f$c [expr {double([set sum$c])/$nRTot}]
    }

    # reprend tout
    set Lv {}
    set smax -9999999999999999.
    set smin  9999999999999999.
    foreach r $Lres {
	if {$r == -999.0} {
	    lappend Lv $r
	} else {
	    set s 0.0
	    foreach c $Lclas v $r {
		if {$v > 0 && [set f$c] > 0.0} {
		    set s [expr {$s + $v*log($v/[set f$c])}]
		}
	    }
	    if {$s > $smax} {set smax $s}
	    if {$s < $smin} {set smin $s}
	    lappend Lv $s
	}
    }

    # revert the list
    set Lres {}
    foreach r $Lv {
	if {$r != -999.0} {
	    set r [expr {$smax - $r + $smin}]
	}
	lappend Lres $r
    }

    return $Lres
}


proc ScoreDeValdar {ListePil Ln LPCI {ThrGap ""}} {
    # Valdar and Thornton, 2002
    #
    # C= lambdaxsum_i^Nsum_j>i^N wiwjxM(Si(x)Sj(x))
    # N      : nbr sequences
    # lambda : (sum_i^Nsum_j>i^N wiwj)-1
    # wi     : weight of sequence Si
    #
    #     wi   = 1/(N-1)sum_i!=j^N d(Si,Sj)
    # d(Si,Sj) = distance from sequence Si to Sj ,
    #          = 1- 1/nALIxsum_x=1^NALI M(Si(x),Sj(x))
    # nALI : nbr of positions that have aa in Si and/or Sj
    #
    #

    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    # PET matrix
    set Lmat [InitialisePET91]
    set Lmat [lsort -stride 2 -index 1 -real $Lmat]
    set min [expr {double([lindex $Lmat 1])}]
    set max [expr {double([lindex $Lmat end])}]

    # scale matrix
    array set Mori $Lmat
    set Lnon [list average X laa]
    foreach k [array names Mori] {
	lassign [split $k ,] a b
	if {$a ni $Lnon && $b ni $Lnon} {
	    set Tmat($a,$b) [expr {(double([set Mori($a,$b)])-$min)/($max-$min)}]
	}
	set Tmat($a,.) 0. ; set Tmat(.,$a) 0.
	set Tmat($b,.) 0. ; set Tmat(.,$b) 0.
    }

    # weight calculation
    array set T $LPCI
    set Lw {}
    foreach n $Ln {
	set w 0.0
	foreach t $Ln {
	    if {$t ne $n} {
		set w [expr {$w + (1. - [lindex [set T($n,$t)] 0])}]
	    }
	}
	lappend Lw [expr {$w/($nseq-1)}]
    }

    # scale calculation
    set scale 0.0
    set i 1
    foreach w1 [lrange $Lw 0 end-1] {
	foreach w2 [lrange $Lw $i end] {
	    set scale [expr {$scale + $w1*$w2}]
	}
	incr i
    }
    set scale [expr {2.0 / $scale}]

    set Lv {}
    set Laa [list A C D E F G H I K L M N P Q R S T V W Y]
    foreach pori $ListePil {
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[string length $p] < $ThrGap} {
	    lappend Lv -999.0
	    continue
	}

	set val 0.0
	set Lp [split $pori ""]
	set i -1
	foreach a $Lp wi $Lw {
	    incr i
	    foreach b [lrange $Lp $i+1 end] wj [lrange $Lw $i+1 end] {
		if {$a in $Laa && $b in $Laa} {
		    set val [expr {$val + $wi*$wj*[set Tmat($a,$b)]}]
		}
	    }
	}
	lappend Lv [expr {$scale * $val}]
    }

    return $Lv
}


proc ScoreDeEntrop1 {ListePil {ThrGap ""}} {
    # Moulinier and Wicker
    
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list CIVLMFYW HNDEQKRST AGP] \
		   [list C IVLM FYW H NDE QKR STAGP] \
		   [list C IV LM FWY H ND EQ KR ST AG P] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]
    set NbFam [llength $Lclas]

    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend LS -999.0
	    continue
	}
	
	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas [llength $Lc]
	    incr ntotclas $nclas
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]

		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		#set r [expr {(double($n) - ($nseq-$ntot)/$nclas)/$nseq}]
		if {$r > 0.0} {
		    set sa [expr {$sa - $r*log($r)}]
		}
	    }
	    set sa [expr {$sa/log(double($nclas))}]
	}
	#set sa [expr {$sa/$ntotclas}]
	set sa [expr {$sa/$NbFam}]
	lappend LS $sa
	if {$sa > $Smax} {
	    set Smax $sa
	}
    }

    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    set s [expr {$Smax - $s}]
	}
	lappend Lres $s
    }
    
    return $Lres
}


proc ScoreDeEntrop2 {ListePil {ThrGap ""}} {
    global TableScore TRPCA
    
    set nseq [string length [lindex $ListePil 0]]
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list CIVLMFYW HNDEQKRST AGP] \
		   [list C IVLM FYW H NDE QKR STAGP] \
		   [list C IV LM FWY H ND EQ KR ST AG P] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]

    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < 4} {
	    lappend LS -999.0
	    continue
	}
	
	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas [llength $Lc]
	    incr ntotclas $nclas
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]
		
		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		if {$r == 0.0} {continue}

		set sa [expr {$sa - $r*log($r)}]
	    }
	}

	set sa [expr {$sa/$ntotclas}]
	lappend LS $sa
	if {$sa > $Smax} {
	    set Smax $sa
	}
    }
    
    set i 1
    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    set s [expr {exp(-1.0*$s)}]
	}
	lappend TableScore($i) $s
	lappend Lres $s

	incr i
    }

    return $Lres
}


proc ScoreDeEnpCube {ListePil} {
    global LNDG TableScore TRPCA
    
    set nseq [string length [lindex $ListePil 0]]
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list CIVLMFYW HNDEQKRST AGP] \
		   [list C IVLM FYW H NDE QKR STAGP] \
		   [list C IV LM FWY H ND EQ KR ST AG P] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]

    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < 4} {
	    lappend LS -999.0
	    continue
	}
	
	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas [llength $Lc]
	    incr ntotclas $nclas
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]

		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		set sa [expr {$sa + $r*$r*$r}]
	    }
	}

	set sa [expr {$sa/$ntotclas}]
	lappend LS $sa
	if {$sa > $Smax} {set Smax $sa}
    }

    set i 1
    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    #set s [expr {$Smax-$s}]
	}
	lappend TableScore($i) $s
	lappend Lres $s

	incr i
    }

    return $Lres
}


proc ScoreDeEntrop3 {ListePil {ThrGap ""}} {
    global LNDG TableScore TRPCA
    
    set nseq [string length [lindex $ListePil 0]]
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list CIVLMFYW HNDEQKRST AGP] \
		   [list C IVLM FYW QNDE KRH STAGP] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]
    
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend LS -999.0
	    continue
	}

	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas [llength $Lc]
	    incr ntotclas $nclas
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]

		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		if {$r == 0.0} {continue}

		set sa [expr {$sa - $r*log($r)}]
	    }
	}
	
	set sa [expr {$sa/$ntotclas}]
	lappend LS $sa
	if {$sa > $Smax} {
	    set Smax $sa
	}
    }

    set i 1
    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    set s [expr {$Smax - $s}]
	}
	lappend Lres $s
	lappend TableScore($i) $s

	incr i
    }

    return $Lres
}


proc ScoreDeEntrop4 {ListePil {ThrGap ""}} {
    global LNDG TableScore TRPCA
    
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list CIVLMFYW HNDEQKRST AGP] \
		   [list C IVLM FYW QNDE KRH STAGP] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]

    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "\." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend LS -999.0
	    continue
	}

	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas [llength $Lc]
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]

		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		if {$r == 0.0} {
		    continue
		}
		
		set sa [expr {$sa - $r*log($r)}]

		incr ntotclas
	    }
	}
	
	set sa [expr {$sa/$ntotclas}]
	lappend LS $sa
	if {$sa > $Smax} {
	    set Smax $sa
	}
    }
    
    set i 1
    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    set s [expr {exp(-1.0*$s)}]
	}
	lappend TableScore($i) $s
	lappend Lres $s
	
	incr i
    }

    return $Lres
}


proc ScoreDeEntrop5 {ListePil {ThrGap ""}} {
    global LNDG TableScore TRPCA
    
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list C IVLM FYW QNDE KRH STAGP] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]

    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend LS -999.0
	    continue
	}

	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas [llength $Lc]
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]

		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		if {$r == 0.0} {continue}

		set sa [expr {$sa - $r*log($r)}]

		incr ntotclas
	    }
	}

	set sa [expr {$sa/$ntotclas}]
	lappend LS $sa
	if {$sa > $Smax} {set Smax $sa}
    }

    set i 1
    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    set s [expr {$Smax - $s}]
	}
	lappend TableScore($i) $s
	lappend Lres $s

	incr i
    }

    return $Lres
}


proc ScoreDeEntrop6 {ListePil {ThrGap ""}} {
    global LNDG TableScore TRPCA
    
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lclas [list \
		   [list C IVLM FYW QNDE KRH STAGP] \
		   [list C I V L M F W Y H N D E Q K R S T A G P]]

    set LS {}
    set Smax 0.
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend LS -999.0
	    continue
	}

	set sa 0.
	set ntotclas 0
	foreach Lc $Lclas {
	    set nclas  [llength $Lc]
	    set p $pori
	    foreach a $Lc {
		set n [regsub -all "\[$a\]" $p "" tmp]

		set r [expr {(double($n) + ($nseq-$ntot)/$nclas)/$nseq}]
		if {$r == 0.0} {continue}

		set sa [expr {$sa - $r*log($r)}]

		incr ntotclas
	    }
	}

	set sa [expr {$sa/$ntotclas}]
	lappend LS $sa
	if {$sa > $Smax} {set Smax $sa}
    }

    set i 1
    set Lres {}
    foreach s $LS {
	if {$s != -999.0} {
	    set s [expr {exp(-1.0*$s)}]
	}
	lappend TableScore($i) $s
	lappend Lres $s
	
	incr i
    }

    return $Lres
}


proc ScoreDeRPCA {ListePil {ThrGap ""}} {
    global TRPCA

    if {! [info exists TRPCA]} {
	InitialiseRPCA
    }
    
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set Lres {}
    foreach pori $ListePil {
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}

	set sn 0.
	set Vp [list 0.0 0.0 0.0]
	foreach a $ListeAA {
	    set n [regsub -all "$a" $p "" tmp]
	    if {! $n} {
		continue
	    }
	    
	    set Vp [V_VV $Vp + [V_SV $n * [set TRPCA($a)]]]
	    set sn [expr {$sn+$n*[set TRPCA(Norm$a)]}]
	}
	set nVp [S_nV $Vp]
	set C [expr {$nVp/$sn*$ntot/$nseq}]
	lappend Lres $C
    }

    return $Lres
}


proc ScoreDeLiu {ListePil {ThrGap ""}} {
    global TBLiu ListeDesAcidesAmines
    
    if {! [info exists TBLiu]} {
	InitialiseBLiu
    }
    
    set ListeAA [split "ARNDCQEGHILKMFPSTWYV" ""]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lres {}
    foreach pori $ListePil {
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}

	set nmax -1
	foreach a $ListeAA {
	    if {[set n [regsub -all $a $p "" tmp]] > $nmax} {
		set nmax $n
		set amax $a
	    }
	}
	set s 0.
	foreach a $ListeAA {
	    set n [expr {$ntot - [string length [string map [list $a ""] $p]]}]
	    if {! $n} {
		continue
	    }

	    set s [expr {$s + double($n)*[set TBLiu($amax,$a)]}]
	}
	set s [expr {$s/double($nseq)}]
	lappend Lres $s
    }

    return $Lres
}


proc ScoreDeLiu_old {ListePil {ThrGap ""}} {
    global ListeDesAcidesAmines TBLiu

    if {! [info exists TBLiu]} {
	InitialiseBLiu
    }

    set ListeAA [lrange $ListeDesAcidesAmines 0 end-1]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lres {}
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}
	set nmax -1
	foreach a $ListeAA {
	    if {[set n [regsub -all $a $p "" tmp]] > $nmax} {
		set nmax $n
		set amax $a
	    }
	}
	set s 0.
	foreach a $ListeAA {
	    set n [regsub -all $a $p "" p]
	    if {! $n} {
		continue
	    }

	    set s [expr {$s + double($n)*log([set TBLiu($amax,$a)])}]
	}
	set s [expr {$s/double($nseq)}]
	lappend Lres $s
    }

    return $Lres
}


proc ScoreAl2Co {ListePil} {
    global LNDG SDG TableScore Sequences OrdTmpDir TableScore

    # Pour Shunter TableScore
    if {1} {
	foreach i [array names TableScore] {
	    lappend TableScore($i) -999.0
	}
    }
    return

    if {$ngrp eq ""} {set ngrp [lindex $LNDG 0]}

    set fa [file join $OrdTmpDir [pid]_tmp_al2co.aln]
    set fo [file join $OrdTmpDir [pid]_tmp_al2co.out]

    CreeLeAln $fa
    if {[catch {set res [exec al2co -i $fa -o $fo -f 0]} Msg]} {
	# Attention ! on commence a 1 , donc <=
	for {set i 1} {$i <= [LongueurDeLAlignement]} {incr i} {
	    lappend TableScore($i) -999.0
	}
    } else {
	set L [LesLignesDuFichier $fo]
	set i 1
	foreach l $L {
	    if {[regexp {^\*} $l]} {break}
	    lassign $l ix n c s
	    if {$s eq "*"} {set c -999.0}
	    lappend TableScore($i) $c
	    incr i
	}
    }

    file delete -force $fa $fo

    return
}


proc ScoreDeVolPol {ListePil {ThrGap ""}} {
    global ListeDesAcidesAmines VolPol
    
    # Base sur volume - polarite
    if {! [info exists VolPol]} {
	InitialiseVolPol
    }

    set ListeAA [lrange $ListeDesAcidesAmines 0 end-1]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    #puts "Piliers [llength $ListePil]"
    set Lres {}
    foreach pori $ListePil {
	set p [string map {X "" Z "" " " "" "\." ""} $pori]

	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0
	    
	    continue
	}
	set sn 0.
	set Vp [list 0.0 0.0]
	foreach a $ListeAA {
	    set n [regsub -all "$a" $p "" tmp]
	    #puts "$a $n"
	    if {$n == 0} {
		continue
	    }
	    
	    set Vp [V_VV $Vp + [V_SV $n * [set VolPol($a)]]]
	    set sn [expr {$sn + $n*[set VolPol(Norm$a)]}]
	    #puts "$p | $a | $sn"
	}
	set nVp [S_nV $Vp]
	#puts "nVp $nVp sn $sn ntot $ntot nseq $nseq"
	set C [expr {$nVp/$sn*$ntot/$nseq}]
	lappend Lres $C
    }

    return $Lres
}


proc ScoreDeNorm {ListePil {ThrGap ""}} {
    global Rosace
    
    if {! [info exists Rosace]} {
	InitialiseRosace
    }
    
    set ListeAA [list A C D E F G H I K L M N P Q R S T V W Y]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    set Lres {}
    foreach pori $ListePil {
	set p [string map {B "" J "" X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    #puts "$p $ntot $ThrGap"
	    lappend Lres -999.0

	    continue
	}

	set sn 0.
	set Vp {0.0 0.0}
	foreach a $ListeAA {
	    set n [expr {$ntot - [string length [string map [list $a ""] $p]]}]
	    if {! $n} {
		continue
	    }

	    set Vp [V_VV $Vp + [V_SV $n * [set Rosace($a)]]]
	    set sn [expr {$sn + $n * [set Rosace(Norm$a)]}]
	}
	# norme vecteur resultant
	set nVp [S_nV $Vp]
	# Somme des normes
	set SnV $sn

	set norm [expr {($nVp/$sn)*$ntot/$nseq}]
	lappend Lres $norm
    }

    #set Lres [Standardise $Lres]
    
    return $Lres
}


proc ScoreDeSurf {ListePil {ThrGap ""}} {
    global ListeDesAcidesAmines Rosace

    if {! [info exists Rosace]} {
	InitialiseRosace
    }
    
    set ListeAA [lrange $ListeDesAcidesAmines 0 end-1]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set SfMax -99999999.0
    set LS {}
    foreach pori $ListePil {
	set p [string map {X "" Z "" " " "" "." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend LS -999.0

	    continue
	}
	
	set Vp [list 0.0 0.0]
	foreach a $ListeAA {
	    set n [regsub -all "$a" $p "" tmp]
	    if {! $n} {
		continue
	    }

	    set Vp [V_VV $Vp + [V_SV $n * [set Rosace($a)]]]
	}
	# Vp en 2D , passe 3D
	lappend Vp 0.0
	
	set surf 0.0
	foreach a $ListeAA {
	    set n [regsub -all "$a" $p "" tmp]
	    if {! $n} {
		continue
	    }
	    
	    set NVa [V_SV $n * [set Rosace($a)]]
	    # 2D -> 3D
	    lappend NVa 0.0
	    set vec [Vectoriel $Vp $NVa]

	    # produit vectoriel est aire du parallelogramme entre u et v
	    # aire triangle = 0.5 * aire
	    set surf [expr {$surf + 0.5*[S_nV $vec]}]
	    if {0 && $n == 20} {
		puts $a
		puts $NVa
		puts $Vp
		puts $surf
		puts $vec
		exit
	    }
	}

	set srft [expr {$surf * $ntot / $nseq}]
	#set srft [expr {sqrt($surf)/$nVp*$ntot/$nseq}]
	set srft $surf
	lappend LS $srft
	
	if {$srft > $SfMax} {
	    set SfMax $srft
	}
    }

    set Lres {}
    foreach s $LS {
	if {$s > -999.0} {
	    set s [expr {$SfMax - $s}]
	}
	lappend Lres $s
    }

    return $Lres
}


proc ScoreDeRosace {ListePil {ThrGap ""}} {
    global ListeDesAcidesAmines TableScore Rosace
    
    if {! [info exists Rosace]} {
	InitialiseRosace
    }
    
    set ListeAA [lrange $ListeDesAcidesAmines 0 end-1]
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set i 1
    set Angx -999.0 ; set Angn  999.0
    set SfMin 9999999. ; set SfMax -9999999.0
    foreach pori $ListePil {
	set p $pori
	set p [string map {X "" Z "" " " "" "\." ""} $pori]
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend TableScore($i) -999.0 -999.0 -999.0 -999.0
	    incr i
	    continue
	}

	set sn 0.
	set Vp [list 0.0 0.0]
	set Angle 0.
	set surf 0.
	foreach a $ListeAA {
	    set n [regsub -all "$a" $p "" tmp]
	    if {! $n} {continue}

	    set Vp [V_VV $Vp + [V_SV $n * [set Rosace($a)]]]
	    set sn [expr {$sn + $n * [set Rosace(Norm$a)]}]
	}
	# norme vecteur resultant
	set nVp [S_nV $Vp]
	# Somme des normes
	set SnV $sn

	# param 1 : Norm
	set norm [expr {($nVp/$sn)*$ntot/$nseq}]

	foreach a $ListeAA {
	    set n [regsub -all "$a" $p "" tmp]
	    if {! $n} {continue}

	    # param 2 : Somme surfaces triangles
	    set Va  [set Rosace($a)]
	    set NVa [V_SV $n * $Va]
	    set nVa [expr {$n * [set Rosace(Norm$a)]}]
	    set Vc  [V_VV $Vp - $NVa]
	    set nVc [S_nV $Vc]
	    set st [SurfaceTriangle $nVa $nVc $nVp]
	    set surf [expr {$surf + $st}]

	    # param 3 : Somme angles
	    set sca [S_VV $Vp * $NVa]
	    set cos [expr {$sca/($nVa*$nVp)}]
	    if {$cos <= -1.0} {
		set Angle [expr {$Angle + $n * 180.}]
	    } elseif {$cos > -1. && $cos < 1.} {
		set Angle [expr {$Angle + $n * acos($cos)*180./[Pi]}]
	    }
	}

	# param 2 : Surface
	if {$surf > $SfMax} {set SfMax $surf}
	if {$surf < $SfMin} {set SfMin $surf}
	#set srf [expr {exp(-1.0*$surf)*$ntot/$nseq}]
	#set srf2 [expr {exp(-1.0*$surf*$ntot/$nseq)}]
	#set srf3 [expr {exp(-1.0*sqrt($surf))}]
	set srft [expr {sqrt($surf)/$nVp*$ntot/$nseq}]
	#	set srft2 [expr {exp(-1.0*sqrt($surf)/$nVp*$ntot/$nseq)}]
	set srft3 [expr {exp(-1.0*sqrt($surf)/$nVp)*$ntot/$nseq}]

	if {$Angle > $Angx} {set Angx $Angle}
	if {$Angle < $Angn} {set Angn $Angle}
	set Angle [expr {$Angle*$ntot/$nseq}]

	# write
	# on a norm srf nVp <rien>
	lappend TableScore($i) $norm $srft $Angle $srft3

	incr i
    }

    if {0} {
	foreach i [array names TableScore] {
	    set l [set TableScore($i)]
	    lset l 1 [expr {$SfMax+$SfMin-[lindex $l 1]}]
	    lset l 2 [expr {$Angx+$Angn-[lindex $l 2]}]
	    set TableScore($i) $l
	}
    }

    return
}


proc ScoreDeThompson {ListePil {ThrGap ""}} {
    global DistBlosum
    
    if {! [info exists DistBlosum]} {
	InitTBlosum gon250
    }
    
    # les 20 acides amines standard (ne depend plus de la
    # liste globale ListeDesAcidesAmines)
    set ListeAA {A C D E F G H I K L M N P Q R S T V W Y}
    set nseq [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lres {}
    foreach pori $ListePil {
	incr i
	set p [string map {X "" Z "" "." "" " " ""} $pori]
	
	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}

	set d 0.
	set npw [expr {$ntot*$ntot}]
	set j 0
	foreach a [lrange $ListeAA 0 end-1] {
	    set n [regsub -all "$a" $p "" tmp]
	    incr j
	    if {! $n} {continue}

	    foreach b [lrange $ListeAA $j end] {
		set m [regsub -all "$b" $p "" tmp]
		if {! $m} {continue}

		set d [expr {$d+$n*$m*[set DistBlosum($a,$b)]}]
	    }
	}

	set dist [expr {double($ntot)/$nseq*exp(-1.*$d/$npw)*100.}]
	lappend Lres $dist
    }
    #set Lres [Standardise $Lres]
    
    return $Lres
}


proc ScoreDeRanganatan {ListePil {ThrGap ""}} {
    global ListeDesAcidesAmines
    
    # from MAFFT
    # set freqaa [list 0.077 0.051 0.043 0.052 0.020 0.041 0.062 0.074 0.023 0.052 0.091 0.059 0.024 0.040 0.051 0.069 0.059 0.014 0.032 0.066]
    # set aamafft "ARNDCQEGHILKMFPSTWYV"
    
    # from Ranganatan
    set freqaa [list 0.072658 0.024692 0.050007 0.061087 0.041774 0.071589 0.023392 0.052691 0.063923 0.089093 0.023150 0.042931 0.052228 0.039871 0.052012 0.073087 0.055606 0.063321 0.012720 0.032955]
    set aamafft "ACDEFGHIKLMNPQRSTVWY"

    set sp 0.
    foreach s $freqaa {
	set sp [expr {$sp+$s}]
    }
    # puts "somme des frequences naturelles : $sp"

    set ListeAA [split $aamafft ""]
    foreach a $ListeAA f $freqaa {
	set Fnat($a) $f
    }

    set nseqs  [string length [lindex $ListePil 0]]
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseqs]
    }
    
    # Calcul proba sur l'ensemble de l'alignement
    set N $nseqs
    foreach a $ListeAA {
	set n [expr {[set Fnat($a)]*$N}]
	set LnpA($a) [CalculeLogProba2 $N $n [set Fnat($a)]]
    }

    # Calcule proba sur chaque colonne
    set N $nseqs
    if {$N < 170} {
	set Fct "CalculeLogProba1"
    } else {
	set Fct "CalculeLogProba2"
    }

    set Lres {}
    foreach p $ListePil {
	set p [string map {B "" J "" Z "" X "" "." "" " " ""} $p]
	if {[string length $p] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}
	set sum 0.
	set na [string length $p]
	foreach a $ListeAA {
	    set n [expr {$na - [string length [string map [list $a ""] $p]]}]
	    if {! $n} {continue}
	    set f [set Fnat($a)]

	    set Lnp [CalculeLogProba2 $N $n $f]
	    set sum [expr {$sum+pow($Lnp-[set LnpA($a)],2)}]
	}
	set dG [expr {sqrt($sum)}]
	# set dG [expr {sqrt($sum)*$na/$nseqs}]
	# set dG [expr {(sqrt($sum)*$na)/20.}]
	# set dG [expr {sqrt($sum)*0.0001*$na}]
	# if {$i > 200 && $i < 221} {puts "pos $i dG $dG"}
	lappend Lres $dG
    }

    return $Lres
}


proc DispersionDeColonne {p} {
    global ListeDesAcidesAmines Rosace

    if {! [info exists Rosace]} {InitialiseRosace}

    set ListeAA [lrange $ListeDesAcidesAmines 0 end-1]
    set ntot [string length $p]

    # compute mean vec of the column
    set Vp [list 0.0 0.0]
    set nvec {}
    foreach a $ListeAA {
	set n [expr {$ntot - [string length [string map [list $a ""] $p]]}]
	if {$n} {
	    set Vp [V_VV $Vp + [V_SV $n * [set Rosace($a)]]]
	}
	lappend nvec $n
    }
    set nVp [S_nV $Vp]

    # now compute angle dispersion
    set ma 0.0
    set m2a 0.0
    set na 0
    foreach a $ListeAA n $nvec {
	if {$n} {
	    # AngleEntre renvoie angle positif
	    set ang [AngleEntre $Vp [set Rosace($a)]]
	    if {$ang > [Pi]} {
		set ang [expr {[2Pi] - $ang}]
	    }
	    set ma  [expr {$ma + $n*$ang}]
	    set m2a [expr {$m2a + $n*$n*$ang*$ang}]
	    incr na $n
	}
    }
    set ma [expr {$ma/$na}]
    set ect [expr {sqrt($m2a/$na-$ma*$ma)}]
    if {$ma < 0.000001} {set ma 0.0}

    return [list $Vp $ma $ect]
}


proc DispersionDesPiliers {ListePil} {
    global ListeDesAcidesAmines Rosace

    if {! [info exists Rosace]} {InitialiseRosace}

    set ListeAA [lrange $ListeDesAcidesAmines 0 end-1]
    set nseq [string length [lindex $ListePil 0]]
    set ThrGap [DefineGapThreshold $nseq]

    set Lres {}
    foreach pori $ListePil {
	set p [string map {X "" Z "" "." "" " " ""} $pori]

	if {[set ntot [string length $p]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}

	lappend Lres [DispersionDeColonne $p]
    }

    return $Lres
}


proc ColonneOverlap {v1 v2 ang1 ang2 ec1 ec2} {
    set v1 [V_nV $v1]
    lassign $v1 x1 y1
    set a1 [expr {atan2($y1,$x1)}]
    #puts "a1ori $a1"
    set a1p $a1
    if {$a1p < 0.0} {
	set a1p [expr {$a1p + [2Pi]}]
    }

    set v2 [V_nV $v2]
    lassign $v2 x2 y2
    set a2 [expr {atan2($y2,$x2)}]
    #puts "a2ori $a2"
    set a2p $a2
    if {$a2p < 0.0} {
	set a2p [expr {$a2p + [2Pi]}]
    }
    #puts "a1p $a1p"
    #puts "a2p $a2p"

    # renverse
    if {$a2p > $a1p} {
	#puts "inverse a1 <-> a2"
	set tmp $a1 ; set a1 $a2 ; set a2 $tmp
	set tmp $a1p ; set a1p $a2p ; set a2p $tmp
	set tmp $ang1 ; set ang1 $ang2 ; set ang2 $tmp
	set tmp $ec1 ; set ec1 $ec2 ; set ec2 $tmp
    }

    # Cas special de Pi
    if {$a1p eq [Pi] &&  $a2 < 0.} {
	#puts "-> a1p Pi"
	set a1 -$a1
    }
    if {$a2p eq [Pi] &&  $a1 < 0.} {
	#puts "-> a2p Pi"
	set a2 -$a2
    }

    set a1m [expr {$a1p - $ang1}]
    set a1x [expr {$a1p + $ang1}]
    set a2m [expr {$a2p - $ang2}]
    set a2x [expr {$a2p + $ang2}]
    foreach v {a1m a1x a2m a2x} {
	if {[set $v] < 0.0} {
	    set $v [expr {[2Pi] - [set $v]}]
	}
	if {[set $v] > [2Pi]} {
	    set $v [expr {[set $v] - [2Pi]}]
	}
	if {[set $v] > [Pi]} {
	    #set $v [expr {[2Pi] - [set $v]}]
	}
    }

    puts ""
    puts "a1 $a1 a1p $a1p ang1 $ang1"
    puts "a1m $a1m a1x $a1x"
    puts "a2 $a2 a2p $a2p ang2 $ang2"
    puts "a2m $a2m a2x $a2x"
    if {($a1m - $a2x) < 0.0} {
	# overlap
	return 1
    } else {
	return 0
    }
}


proc CalculeLogProba1 {N n Fn} {
    set N "${N}."
    set n "${n}."
    set Nmn [expr {$N-$n}]

    set EN   [factorial1 $N]
    set En   [factorial1 $n]
    set ENmn [factorial1 $Nmn]

    set p1 [expr {log($EN/($En*$ENmn))}]
    set p2 [expr {$n*log($Fn)}]
    set p3 [expr {${Nmn}*log(1.-$Fn)}]

    return [expr {$p1+$p2+$p3}]
}


proc CalculeLogProba2 {N n Fn} {

    set Nmn [expr {$N-$n}]

    set p1 [expr {[LnFn $N]-([LnFn $n]+[LnFn ${Nmn}])}]
    set p2 [expr {$n*log($Fn)}]
    set p3 [expr {${Nmn}*log(1.-$Fn)}]

    return [expr {$p1+$p2+$p3}]
}


proc LnFn {n} {

    if {$n == 0} {
	return 1.
    } else {
	return [expr {log(sqrt(2.*3.1415926))+($n+0.5)*log($n)-$n}]
    }
}


proc InitTBlosum {{mat blosum62} {positive 0}} {
    global DistBlosum

    # Distances entre acides amines (lignes de la matrice
    # $mat). Ne modifie plus la liste globale
    # ListeDesAcidesAmines : elle etait remplacee par la
    # chaine "ACDESGHIKLMNPQRSTVWY" (1 seul element de
    # liste, F absent, S double), ce qui cassait ensuite la
    # methode Threshold et ScoreDeThompson. La matrice
    # demandee est maintenant utilisee (blosum62 etait
    # imposee quelle que soit la demande).
    array set TBlosum [InitClustalMatrix $mat $positive]

    set ListeAA [split $TBlosum(laa) ""]

    set i 1

    foreach a $ListeAA {
	set DistBlosum($a,$a) 0.0
	foreach b [lrange $ListeAA $i end] {
	    set d 0.
	    foreach c $ListeAA {
		set diff [expr {([set TBlosum($a,$c)]-[set TBlosum($b,$c)])/1000.}]
		set d [expr {$d + $diff*$diff}]
	    }
	    set DistBlosum($a,$b) [expr {sqrt($d)}]
	    set DistBlosum($b,$a) [expr {sqrt($d)}]
	}
	incr i
    }

    return
}


proc InitialiseRPCA {} {
    global TRPCA

    set Lv [split [InitRPCA] \n]
    lassign $Lv lx ly lz

    set Laa [split "ARNDCQEGHILKMFPSTWYV" ""]
    foreach a $Laa x [split $lx] y [split $ly] z [split $lz] {
	set x [expr {10.*$x}]
	set y [expr {10.*$y}]
	set z [expr {10.*$z}]
	set TRPCA($a) [list $x $y $z]
	set TRPCA(Norm$a) [S_nV [set TRPCA($a)]]
    }

    return
}


proc InitialiseVolPol {} {
    global VolPol
    
    set lvp [split [IniVolPol] \n]
    foreach l $lvp {
	set l [string trim $l]
	if {$l eq ""} {
	    continue
	}
	regsub -all { +} $l " " l
	lassign [split $l " "] n v p

	set VolPol($n) [list $v $p]
	set VolPol(Norm$n) [S_nV [set VolPol($n)]]
    }

    return
}


proc InitialiseRosace {} {
    global OrdEtcDir Rosace

    if {1} {
	set Ll [LesLignesDuFichier [file join $OrdEtcDir AAtab.dat]]
	foreach l $Ll {
	    set l [string trim $l]
	    lassign [split $l] n x y
	    set RosX($n) $x
	    set RosY($n) $y
	}
    } else {
	set LRos [IniRosace]
	set i 1
	foreach l $LRos {
	    lassign [split $l ","] v a
	    if {$i <= 20} {
	    set RosX($a) $v
	    } else {
		set RosY($a) $v
	    }
	    incr i
	}
    }
    
    foreach a [array names RosX] {
	set x [set RosX($a)]
	set y [set RosY($a)]
	lassign [V_nV [list $x $y]] xn yn
	set Rosace($a) [list $x $y]
	set Rosace(Norm$a) [S_nV [set Rosace($a)]]
    }

    return
}


proc LPABLuc {} {

    return [LesLignesDuFichier [file join [RepGenLuc] prottfa ListeDesPABs]]

    set Ll [LesLignesDuFichier [file join [RepGenLuc] fiches bornesdespabs]]
    foreach l $Ll {
	if { ! [YaPABdans $Ligne] } {
	    continue
	}
	ExtraireDe $Ligne Nom Debut Fin Orient
	set  Boite        $Nom
	lappend ListeDesPABs $Nom
    }

    return $ListeDesPABs
}

proc RepGenLuc {} {
    return "/genomics/link/286PDB/"
}

proc AnalyseTestClusterPos {f} {
    set Ll [LesLignesDuFichier $f]
    set res {}
    set vutype 0
    foreach l $Ll {
	if {[regexp {^type } $l]} {
	    if {$res != {} } {
		lappend LRes $res
	    }
	    set res [lindex [split $l " "] 1]
	    set vutype 1
	}
	if {[regexp {^\t} $l] && $vutype} {
	    lappend res [lindex [split $l " "] end]
	}
    }
    lappend LRes $res

    set fmt "%14s |[string repeat "%6.3f" 3] |[string repeat "%6.3f" 3]"

    # Trie sur Identite (1er cluster)
    #puts "Tri sur Sum (sens+spec) : Identite"
    set LRes [lsort -real -decreasing -index 3 $LRes]
    foreach e $LRes {
a	puts [format $fmt {*}$e]
    }

    # Trie sur global (1er et 2eme cluster)
    puts "\nTri sur Sum (sens+spec) : global"
    set LRes [lsort -real -decreasing -index 6 $LRes]
    foreach e $LRes {
	puts [format $fmt {*}$e]
    }

    exit
}


proc TestClusterPos {{file ""}} {
    global LNOrdali PABCourant OrdTmpDir FichierMSF Defauts SDG NomSeqSel
    global NId NCo NConsDansId NConsDansCo TableScore LNorMD ConsRef Sequences
    global VariablesAuDepart TNResConsNSA TNResConsSA LongueurTotale LongTot

    set FichierMSF ""

    NousAllonsAuBoulot $OrdTmpDir

    LoadReferencePDB
    LoadNorMD
    LesDefauts
    NettoieLeTmp

    set rep "[RepGenLuc]/msf"
    #set repLeon [file join [RepGenLuc] "msf_nature" "Rascal" "Leon"]
    #aF on prend les fichiers issus de Rascal et non pas de leon!
    set repRascal [file join [RepGenLuc] "msf_nature" "Rascal"]

    if {$file ne ""} {
	set LesFiles $file
	if {[string index [string trim $file] end] == "+"} {
	    set tmp [LPABLuc]
	    set file [string range $file 0 end-1]
	    set i [lsearch $tmp $file]
	    set LesFiles [lrange $tmp $i end]
	}
    } else {
	set LesFiles   [LPABLuc]
	#aF je ne veux pas traiter l ensemble de la liste, mais simplement certains PAB, contenu dans le fichier fichierPAB
	#set fichierPAB [file join [RepGenLuc] "Typification" "ResuThese" "listeComQualSansrm"]
	#set LesFiles [LesLignesDuFichier $fichierPAB]
    }

    set NomSeqSel {}
    # Types de conservations a tester
    # Originaux :
    # set Ltypes [list 0 1 2 4 5 04 05 45 045 6 7 8 9]
    # set Ntypes [list Norm Surf Angle Dist Delta Norm+Dist Norm+Delta Dist+Delta Norm+Dist+Delta VolPol Al2Co Liu RPCA]
    #
    # to work
    set Ltypes [list 0 1 2 3 4 5 6 8 9]
    set Ntypes [list Norm Surf Angle Surf2 Dist Delta VolPol Liu RPCA]

    set LongTot 0
    foreach type $Ltypes {
	set TNConsId($type) 0
	set TNConsCo($type) 0
	set TNId($type) 0
	set TNCo($type) 0
    }

    set VariablesAuDepart [info globals]

    LesDefauts TypeAli MSF
    LesDefauts Mode "Batch"
    set NAli 0
    set NResConsSA 0
    set NResConsNSA 0
    foreach n $LesFiles {
	# set fic [file join $repLeon $n]
	#aF a modifie repLeon en repRascal
	set fic [file join $repRascal $n]
	if {! [file exists $fic]} {
	    puts " >>$fic<< doesn t exists !"
	    puts " -----------------------\n\n"
	    continue
	}
	file mkdir [file join $OrdTmpDir [pid]_rascal]
	file copy -force $fic [file join $OrdTmpDir [pid]_rascal $n]
	set FichierMSF [file join $OrdTmpDir [pid]_rascal $n]
	LesDefauts FichierMSF $FichierMSF
	puts "==========="
	puts "| $n |"
	puts "==========="
	set PABCourant $n

	if {[set LNorMD($n)] < 0.3} {
	    puts ""
	    puts " >>> NorMD est < a 0.3 <<<"
	    puts ""
	    FermeFichier
	    continue
	}
	LoadingAlignement
	#	::profiler::reset
	MetAJourGroupes

	set NSqs [llength $SDG(GroupeToutLeMonde)]
	puts "NSeqs : $NSqs"
	if {$NSqs < 10} {
	    puts "Les than 10 Sequences !!"
	    FermeFichier
	    continue
	}

	if {[info exists TableScore]} {unset TableScore}
	set grp ""

	ScoreDeNorm   $grp ; # 0 1 2 3
	ScoreDeSurf   $grp ; # 0 1 2 3
	ScoreDeThompson   $grp ; # 4
	ScoreDeRanganatan $grp ; # 5
	ScoreDeVolPol $grp ; # 6
	ScoreAl2Co    $grp ; # 7
	ScoreDeLiu    $grp ; # 8
	ScoreDeLiu2   $grp ; # 8
	ScoreDeRPCA     $grp ; # 9

	set rep1 [VerificationAvantCalculs]
	if {! $rep1} {
	    puts "Une des methode foireuse !!"
	    puts "skip alignement\n"
	} else {
	    set BonTousTypes 1
	    foreach type $Ltypes tnom $Ntypes {
		set NConsDansId 0
		set NConsDansCo 0
		set NId 0
		set NCo 0
		set rep2 [LanceLesCalculs $type $grp]
		update

		if {$rep2} {
		    set tmp_TNConsId($type) $NConsDansId
		    set tmp_TNConsCo($type) $NConsDansCo
		    set tmp_TNId($type) $NId
		    set tmp_TNCo($type) $NCo
		} else {
		    set BonTousTypes 0
		    break
		}
	    }

	    if {$BonTousTypes} {
		incr LongTot $LongueurTotale
		incr NAli
		incr NResConsSA [set TNResConsSA($n)]
		incr NResConsNSA [set TNResConsNSA($n)]
		foreach type $Ltypes tnom $Ntypes {
		    incr TNConsId($type) [set tmp_TNConsId($type)]
		    incr TNConsCo($type) [set tmp_TNConsCo($type)]
		    incr TNId($type) [set tmp_TNId($type)]
		    incr TNCo($type) [set tmp_TNCo($type)]
		}
	    }
	}
	file delete -force [file join $OrdTmpDir [pid]_rascal $n]
	FermeFichier
	puts ""
	puts ""

	#AfficheProfileResults
    }

    # Calcul Specificite et Sensibilite
    puts ""
    puts ""
    puts "========================="
    puts "=    R E S U L T A T S  ="
    puts "========================="
    puts ""
    puts "Nombre alignements ..............: $NAli"
    puts "Longueur totale .................: $LongTot"
    puts "Nombre residus site actif .......: $NResConsSA"
    puts "Nombre residus NON site actif ...: $NResConsNSA"
    puts ""

    set NResCons ${NResConsSA}
    foreach t $Ltypes tnom $Ntypes {
	# Sens = VraiPos/(VraiPos + FauxNeg)
	# Spec = VraiNeg/(VraiNeg + FauxPos)

	# VraiPos : Identi ET SA
	# FauxNeg : SA non vu (non identifie)
	# VraiNeg : lg - sa - colo cons qui sont pas sites
	# FauxNeg : Sa qui ne sont pas dans une col de cons

	if {$t == 7} {continue}

	set NConsId "[set TNConsId($t)]."
	set NId     "[set TNId($t)]."

	# Pour Identite
	set sensId [expr {1.*$NConsId/$NResCons}]
	set specId [expr {1.*($LongTot - $NId - ($NResCons - $NConsId))/(($LongTot - $NId - ($NResCons - $NConsId))+($NId - $NConsId))}]
	set SumSensSpecId [expr {($sensId + $specId) - 1.0}]

	# Pour Global (Identite+Cons)
	set NTt     [expr {$NId + [set TNCo($t)]}]
	set NConsTt [expr {$NConsId + [set TNConsCo($t)]}]
	set sensTt [expr {$NConsTt/$NResCons}]
	set specTt [expr {1.*($LongTot - $NTt - ($NResCons - $NConsTt))/(($LongTot - $NTt - ($NResCons - $NConsTt))+($NTt - $NConsTt))}]
	set SumSensSpecTt [expr {($sensTt + $specTt) - 1.0}]

	#	CalculSensibiliteSpecificite $NConsId [expr {$NId-$NConsId}] [expr {$LongTot - $NId}]

	puts ""
	puts "type $tnom :"
	puts "--------------"
	puts "Nombre residus Identite........... : $NId"
	puts "Nombre residus Ident+Cons .........: $NTt"
	puts "Nombre residus SA typifie Iden ....: $NConsId"
	puts "Nbr resi SA typifie Iden+Cons .....: $NConsTt"
	set fmt "%s %5.3f"
	puts ""
	puts [format $fmt "\tsensibilite Identite ......:" $sensId]
	puts [format $fmt "\tspecificite Identite ......:" $specId]
	puts [format $fmt "\tSomme sens+spec Identite...:" $SumSensSpecId]
	puts [format $fmt "\tsensibilite totale ........:" $sensTt]
	puts [format $fmt "\tspecificite totale ........:" $specTt]
	puts [format $fmt "\tSomme sens+spec totale ....:" $SumSensSpecTt]
	puts ""
	puts ""
    }


    exit
}


proc CalculeScoresColonne {{file ""}} {
    global ListeScore TableScore LNOrdali FichierMSF Defauts

    set FichierMSF ""

    LesDefauts

    set fic $file

    LesDefauts CheckSeq 0
    LesDefauts Mode "Batch"

    if {! [file exists $fic]} {
	puts " >>$fic<< doesn t exists !"
	puts " -----------------------\n\n"
	exit
    }

    set FichierMSF $fic
    puts "==========="
    puts "| $FichierMSF |"
    puts "==========="

    LesDefauts FichierMSF $FichierMSF
    LesDefauts TypeAli MSF
    LoadingAlignement
    set NSqs [llength $LNOrdali]
    puts "NSeqs : $NSqs"
    if {$NSqs <= 3} {
	puts "TOO FEW SEQUENCES !"
	exit
    }

    unset -nocomplain TableScore
    set grp ""
    ScoreDeNorm    $grp ; # 0 1 2 3
    ScoreDeSurf    $grp ; # 0 1 2 3
    ScoreDeThompson    $grp   ; # 4
    ScoreDeRanganatan  $grp   ; # 5
    ScoreDeVolPol  $grp   ; # 6
    ScoreAl2Co     $grp   ; # 7
    ScoreDeLiu     $grp   ; # 8
    ScoreDeLiu2    $grp   ; # 8
    ScoreDeRPCA    $grp   ; # 9
    ScoreDeEntrop1 $grp   ; # 9
    ScoreDeEntrop2 $grp   ; # 9
    ScoreDeEntrop3 $grp   ; # 9
    ScoreDeEntrop4 $grp   ; # 9

    CreeListeScore
    set f [open "brute.dat" w]
    set fmt "%7.3f"
    set fmt "%2d[string repeat $fmt 7]"
    foreach e $ListeScore {
	puts $f [format $fmt {*}$e]
    }
    close $f

    exit

}


proc StockScores {f g {DoNorm 1}} {
    global ScoreMeth ListeScore

    if {$g eq "" || $g eq "all" || $g eq "All"} {
	set g "GroupeToutLeMonde"
    }
    # once per group : saved once per group (EnregistreLeMac)
    if {! [info exists ScoreMeth($f,ListeGrps)] || $g ni $ScoreMeth($f,ListeGrps)} {
	lappend ScoreMeth($f,ListeGrps) $g
    }
    # forget the previous scores of this group : columns of a
    # longer alignment (previous instance) would be saved with it
    array unset ScoreMeth "[string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $f,$g],*"
    set Li [ExtraitListeDeListe $ListeScore 0]
    set nvar [expr {[llength [lindex $ListeScore 0]] - 1}]
    set nval [expr {$nvar * [llength $Li]}]
    if {$nvar == 1} {
	set Lval [ExtraitListeDeListe $ListeScore 1]
    } else {
	foreach l $ListeScore {
	    set m 0.
	    foreach e [lrange $l 1 end] {
		set m [expr {$m + $e}]
	    }
	    set m [expr {$m/$nval}]
	    lappend Lval $m
	}
    }

    if {$DoNorm} {
	set nlval [Standardise $Lval]
    } else {
	set nlval $Lval
    }

    set min 99999999. ; set max -99999999.
    foreach i $Li v $nlval {
	set ScoreMeth($f,$g,$i) $v
	if {$v < $min} {set min $v}
	if {$v > $max} {set max $v}
    }
    set ScoreMeth($f,${g}-min) $min
    set ScoreMeth($f,${g}-max) $max
    set ScoreMeth($f,ScaleGlobal) 0

    return
}


proc RunMethode {methode {Grp ""}} {
    global ConsMeth ScoreMeth LNDG SDG LNOrdali TableScore OrdTmpDir ListeTypesDeFeatures ListeDesPiliersDuGroupe TbScores Cons

    set NSqs [llength $SDG(GroupeToutLeMonde)]
    if {$NSqs <= 3} {
	FaireLire "Too few sequences ! !"
	return
    }

    switch $methode {
	"Cluster" {
	    #set cols [list Norm Thompson]
	    set cols $Cons(multi,ListMeth)
	    set ident "Multi"
	    set lameth "Multi"
	    set ft "Cons-Multi"
	}
	"VectorNorm" {
	    set cols Norm
	    set ident "VectorNorm"
	    set lameth "Vector Norm"
	    set ft "Cons-VectorN"
	}
	"MeanDistance" {
	    set cols Thompson
	    set ident "MeanDistance"
	    set lameth "Mean Distance"
	    set ft "Cons-MeanD"
	}
	"Liu" -
	"Liu2" -
	"BILD" -
	"JSD" -
	"Shannon" -
	"Peivar" -
	"Ranganatan" -
	"Capra" -
	"Caffrey" -
	"Kabat" -
	"Karlin" {
	    set cols $methode
	    set ident $methode
	    set lameth $methode
	    set ft "Cons-$methode"
	}
	"User" {
	    set cols ""
	    set ident "User"
	    set lameth "User"
	    set ft "Cons-User"
	}
    }

    FaireAttendre "Please wait ...\nComputing residue conservation using $lameth method"

    # Check if the feature name already exists.
    # If yes , find a new name
    set Lf $ListeTypesDeFeatures
    if {! [llength [lsearch -regexp -all $Lf "${ft}_"]]} {
	set i 1
    } else {
	set Li [lsearch -all -inline -regexp $Lf "${ft}_"]
	set nmax -1
	foreach f $Li {
	    set n [string range $f [expr {[string last "_" $f]+1}] end]
	    if {$n > $nmax} {
		set nmax $n
	    }
	}
	set i [expr {$nmax+1}]
    }
    # at this point , we have a temporary name
    set ft "tmp${ft}_$i"
    unset -nocomplain ConsMeth
    set ScoreMeth($ft,Edit) 0

    if {$Grp eq ""} {
	set LGrp $LNDG
    } else {
	set LGrp $Grp
    }

    if {! [info exists ListeDesPiliersDuGroupe]} {
	CreeLesPiliers
    }

    if {[llength $cols] > 1} {
	set doStandardise 1
    } else {
	set doStandardise 0
    }
    unset -nocomplain TbScores
    set TbScores(Lcols) $cols
    foreach g $LGrp {
	if {$g eq "bidon" || $g eq "grise"} {
	    continue
	}
	if {[llength [set SDG($g)]] <= 3} {
	    puts "\t VIRE g= $g size [llength [set SDG($g)]]"
	    continue
	}

	array unset TbScore "Score,*"
	set ListePil [set ListeDesPiliersDuGroupe($g)]

	if {$g eq "GroupeToutLeMonde"} {
	    set g ""
	}

	foreach c $cols {
	    set sco [ScoreDe$c $ListePil]
	    if {$doStandardise} {
		set sco [Standardise $sco]
	    }
	    set TbScores(Score,$c) $sco
	}

	CreeListeScore $g

	set cok [NormalisationColonnes]
	if {! $cok} {
	    puts "\tNormalisation failed g= $g size [llength [set SDG($g)]]"

	    continue
	}

	StockScores $ft $g

	set Lclus [Tclcluspack $::ListeScore -dt coordinates -cm mm -nbc aic -wc]
	TraiteResultatClusteringTcl $Lclus $ident $g "mixturemodels"
    }

    CreeFeaturesMethod $ft

    FaireLaSuite .runmth

    return $ft
}


proc ReformateRes {} {

    set Li [LesLignesDuFichier "log"]

    set Tt 0
    set Suite 0
    foreach l $Li {
	if {[regexp "SPDB" $l]} {
	    set n [string range $l 2 8]
	    set R($n) {}
	    if {$Suite} {set Tt 1}
	    if {! $Tt && !$Suite} {
		set R(Alignt) {}
		set Suite 1
	    }
	}
	if {[regexp "NSeqs" $l]} {
	    lappend R($n) [string range $l 8 end]
	    if {! $Tt} {lappend R(Alignt) "NSeqs"}
	}
	if {[regexp "NSites" $l]} {
	    lappend R($n) [string range $l 9 end]
	    if {! $Tt} {lappend R(Alignt) "NSites"}
	}
	if {[regexp "Comment" $l]} {
	    set Cmt [string trim [string range $l 19 end]]
	    regsub -all " " $Cmt "" Cmt
	}
	if {[regexp "NClus" $l]} {
	    lappend R($n) [string range $l 12 end]
	    if {! $Tt} {lappend R(Alignt) "NClus$Cmt"}
	}
	if {[regexp "NGroup" $l] && [regexp "IdenGlob" $l]} {
	    lappend R($n) [string range $l 18 end]
	    if {! $Tt} {lappend R(Alignt) "NGrp$Cmt"}
	}
	if {[regexp "Compar" $l] && [regexp "IdenGlob" $l]} {
	    lappend R($n) [string range $l 18 end]
	    if {! $Tt} {lappend R(Alignt) "Cmpr$Cmt"}
	}
    }

    set f [open "resu.dat" w]
    foreach r [lsort [array names R]] {
	if {[llength [set R($r)]] == 0} {continue}
	puts $f "$r\t[join [set R($r)] "\t"]"
    }
    close $f

    return
}


proc AnaProsite {} {

    package require sqlite3

    set db root
    sqlite3 $db /home/moumou/Prosite/Prosite.sql

    set Lp [$db eval {select accession, pattern, uniprot_id, uniprot_type from prosite where type = 'PATTERN'}]
    puts "[llength $Lp]"
    set pris 0
    foreach {ac pat lid ltype} $Lp {
	if {! [regexp {\[} $pat]} {continue}
	if {[regexp {\{} $pat]} {continue}
	if {$lid == "NULL"} {continue}
	set Lbid {}
	foreach id $lid ty $ltype {
	    if {$ty eq "N" || $ty eq "P" || $ty eq "T"} {
		lappend Lbid $id
	    }
	}
	if {[llength $Lbid] < 10} {continue}

	incr pris
	puts "$ac"
	puts "$pat"
	puts "lg $ac [llength $Lbid]"
	puts ""
    }

    puts "nb bons prosite : $pris"

    exit
}


proc tsco {} {
    global LNDG SDG LNOrdali Sequences LongueurTotale ListeDesPiliersDuGroupe

    DecortiqueUnTFA /home/moumou/ordali/alitest/neo.tfa LNOrdali Sequences
    set LNDG GroupeToutLeMonde
    set SDG(GroupeToutLeMonde) $LNOrdali
    set LongueurTotale [string length [set Sequences([lindex [array names Sequences] 0])]]
    CreeLesPiliers

    #set Lw [ScoreDeWilliamson [set ListeDesPiliersDuGroupe(GroupeToutLeMonde)]]
    #set Lk [ScoreDeKabat [set ListeDesPiliersDuGroupe(GroupeToutLeMonde)]]
    #set Le [ScoreDeEntrop1 [set ListeDesPiliersDuGroupe(GroupeToutLeMonde)]]
    set Lns {}
    foreach n $LNOrdali {
	lappend Lns $n [set Sequences($n)]
    }
    set LPCI [CalculeLesPCIGenerique $Lns]
    set Ls [ScoreDeSanderSP [set ListeDesPiliersDuGroupe(GroupeToutLeMonde)] $LNOrdali $LPCI]
    puts "[join $Ls \n]"

    exit
}


proc tpros {} {
    package require sqlite3

    set db root
    sqlite3 $db /home/moumou/Prosite/Prosite.sql

    set pt1 [$db eval {select pattern from prosite where accession='PS00118'}]
    set pt2 [$db eval {select pattern from prosite where accession='PS00119'}]
    $db close

    set f /home/moumou/work/moumou/BenchPfam/PF00068.14
    DecortiqueUnTFA $f Ln Sq
    puts "nseq [llength $Ln]"

    set rg1 [Pattern2Regexp $pt1]
    set rg2 [Pattern2Regexp $pt2]
    puts "pt1 $pt1\nrg1 $rg1"
    puts "pt2 $pt2\nrg2 $rg2\n"

    #set np1 [regsub -all "\(" $rg1 "" tmp]
    set np1 0
    set Lv1 {}
    for {set i 0} {$i < $np1} {incr i} {
	lappend Lv1 sv1$i
    }
    set np2 0
    #set np2 [regsub -all "\(" $rg2 "" tmp]
    set Lv2 {}
    for {set i 0} {$i < $np2} {incr i} {
	lappend Lv2 sv2$i
    }
    set nr1 0 ; set nr2 0 ; set nr12 0
    foreach n $Ln {
	set s [set Sq($n)]
	set sdg [string map [list "." ""] $s]
	set rp1 [regexp -inline -indices $rg1 $sdg]
	set rp2 [regexp -inline -indices $rg2 $sdg]
	if {$rp1 ne "" && $rp2 ne ""} {
	    puts "$sdg"
	    puts "rp1 $rp1"
	    puts "rp2 $rp2"
	    #incr nr1 $rp1
	    #incr nr2 $rp2
	    #if {$rp1 && $rp2} {incr nr12}
	}
    }
    puts "$nr1 $nr2 $nr12"

    exit
}


proc Pattern2Regexp {pat} {
    if {[s
	 tring index $pat 0] eq "{" && [string index $pat end] eq "}"} {
	set pat [string range $pat 1 end-1]
    }

    set Lmot [split $pat -]
    set reg ""
    foreach e $Lmot {
	switch -regexp -- $e {
	    {^\[} {set o $e}
	    {\(} {
		set o [string map [list "(" "\{" ")" "\}"] $e]
	    }
	    {\{} {
		set l [string length [string range $e 1 end-1]]
		set o "\."
		if {0 && $l > 1} {
		    append o "\{$l\}"
		}
	    }
	    default {set o $e}
	}
	set o [string map [list ">" "$" "<" "^" x "\." X "\."] $o]
	if {! [regexp {\.} $o]} {
	    set o "($o)"
	}
	append reg $o
    }

    return $reg
}

proc tDis {} {
    set p "YMMAAAAAYAAKCAQRQ"
    puts "$p"
    lassign [DispersionDeColonne $p] v a e
    puts "v  $v"
    puts "vn [V_nV $v]"
    puts "a  $a"
    puts "e  $e"
    puts "[join  \n]"

    set v2 [list 0.207 -0.978]
    puts [ColonneOverlap $v $v2 1.03 0.0 1.06 0.0]

    exit
}


proc TSB {} {
    CreeLesPiliers
    set Lp [set ::ListeDesPiliersDuGroupe(GroupeToutLeMonde)]
    set sc [ScoreDeJSD $Lp]
    foreach p $Lp s $sc {
	puts "$p [format %6.2f $s]"
    }

    exit
}


proc tscore {} {
    CreeLesPiliers
    set Lpil [set ::ListeDesPiliersDuGroupe(GroupeToutLeMonde)]
    set Lv [ScoreDeSurf $Lpil]
    foreach p $Lpil v $Lv {
	puts "$p [format %7.2f $v]"
    }
    
    exit
}


proc tvec {} {
    foreach {x1 y1 x2 y2} {1.0 0.5 -1.0 0.5 1.0 0.5 1.0 -0.5} {
	set u  [list $x1 $y1 0.0]
	set nu [S_nV $u]
	set v  [list $x2 $y2 0.0]
	set nv [S_nV $v]
	set w  [Vectoriel $u $v]
	set nw [S_nV $w]
	set sin [expr {$nw / ($nu * $nv)}]
	set sca [Scalaire $u $v]
	set cos [expr {$sca / ($nu * $nv)}]
	puts "cos $cos"
	puts "sin $sin"
	set alf [expr {atan($sin/$cos)}]
	puts "alf $alf"
	puts "nw $nw"
	if {$alf < 0.0} {
	    set alf [expr {atan(-1.)+$alf}]
	}
	set srf [expr {$nu*sin($alf)*$nv}]
	puts "srf $srf"
	puts ""
    }
    
    exit
}

    
proc debrosace {} {
    global Rosace VolPol

    InitialiseVolPol
    InitialiseRosace
    set Laa {A C D E F G H I K L M N P Q R S T V W Y}

    unset Rosace
    array set Rosace [array get VolPol]
    foreach a $Laa {
	lassign $Rosace($a) x y
	lappend Lx $x
	lappend Ly $y
	lappend Lxya $x $y $a
    }
    puts "min -max X"
    set Lxya [lsort -real -index 0 -stride 3 $Lxya]
    foreach {x y a} $Lxya {
	puts [format "%6.2f %6.2f %s" $x $y $a]
    }
    puts "\nmin - max y" 
    set Lxya [lsort -real -index 1 -stride 3 $Lxya]
    foreach {x y a} $Lxya {
	puts [format "%6.2f %6.2f %s" $x $y $a]
    }

    #set Lx [CentreVecteur $Lx]
    #set Ly [CentreVecteur $Ly]
    #set Lx [ReScale $Lx]
    #set Ly [ReScale $Ly]
    foreach x $Lx y $Ly a $Laa {
	set Rosace($a) [list $x $y]
	set Rosace(Norm$a) [S_nV [list $x $y]]
    }
    
    parray Rosace
    exit
}


proc aatab {} {
    set Ll [LesLignesDuFichier AAtab.dat]
    set mx 0.0
    set my 0.0
    foreach l $Ll {
	set l [string trim $l]
	lassign [split $l] a x y
	set TX($a) $x
	set TY($a) $y
	lappend Laa $a
	lappend Lx $x
	lappend Ly $y
	set mx [expr {$mx + $x}]
	set my [expr {$my + $y}]
    }
    set mx [expr {$mx / [llength $Laa]}]
    set my [expr {$my / [llength $Laa]}]
    puts "mx $mx"
    puts "my $my"
    puts [join $Laa]

    set Laa [split "ARNDCQEGHILKMFPSTWYV" ""]
    InitialiseVolPol
    global VolPol
    set Lx {}
    set Ly {}
    foreach a $Laa {
	set x $TX($a)
	set y $TY($a)
	lassign $VolPol($a) x y
	lappend Lx $x
	lappend Ly $y
    }
    set Lx [Standardise $Lx]
    set LY [Standardise $Ly]
    foreach a $Laa x $Lx y $Ly {
	puts "$a [format %6.2f [S_nV [list $x $y]]]"
    }
    puts "\nCorre X"
    CorrelationAxe $Lx
    puts "\nCorre Y:"
    CorrelationAxe $Ly
    
    exit
}


proc tnewmulti {} {
    global Cons

    ChangeMode conservation
    
    set Cons(Method) "Multi"
    set Cons(multi,ListMeth) [list Liu2 BILD JSD Thompson Norm]
    puts $Cons(multi,ListMeth)
    set ft [PrepareRunOrdali]

    exit
    return
}


proc tsha {} {
    CreeLesPiliers
    set ListePil $::ListeDesPiliersDuGroupe(GroupeToutLeMonde)
    ScoreDeShannon $ListePil

    exit
}


			      
