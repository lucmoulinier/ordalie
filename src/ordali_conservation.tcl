

#
# ordali_conservation.tcl
#
#
# PSIC: reference herein pour weights
# https://academic.oup.com/peds/article/12/5/387/1560049#


proc ScoreDeBILD {ListePil {ThrGap ""} {Lw ""} {gapScale ""}} {
    global BILDback BILDweight BILDalpha BILDAlpha

    if {! [info exists BILDback]} {
	lassign [InitScoreDeBILD] BILDback BILDweight BILDalpha BILDAlpha
    }

    set nseq [string length [lindex $ListePil 0]]

    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }

    set nseq [string length [lindex $ListePil 0]]
    if {$Lw eq ""} {
	set Lw [lrepeat $nseq 1.0]
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

    return $Lres
}


proc ScoreDeWang {ListePil {ThrGap ""} {Lw ""} {gapScale ""}} {
    #
    # Wang , 2006
    #
    # tient compte naturellement des gaps
    #
    # C     = sum_1^20 pk x log(pk / f)
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
    if {$Lw eq ""} {
	set Lw [lrepeat $nseq 1.0]
    }
    
    if {$ThrGap eq ""} {
	set ThrGap [DefineGapThreshold $nseq]
    }
    
    set Lres {}
    foreach p $ListePil {
	set pdg [string map [list X "" Z "" " " "" "." ""] $p]
	if {[set ntot [string length $pdg]] < $ThrGap} {
	    lappend Lres -999.0

	    continue
	}
	
	set v 0.0
	foreach aa $Laa f $freqaa {
	    set pk [expr {double($nseq - [string length [string map [list $aa ""] $p]])/$nseq}]
	    if {$pk > 0.0} {
		set v [expr {$v + $pk*log($pk/$f)}]
	    }
	}
	lappend Lres $v
    }
    
    return $Lres
}




