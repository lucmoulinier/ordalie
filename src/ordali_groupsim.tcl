#
# Specificity-Determining Positions : GroupSim + ConsWin
#
# Translation of the reference code of Capra & Singh 2008
# (Bioinformatics 24:1473 ; group_sim_sdp.py,
# compbio.cs.princeton.edu/specificity), identity matrix.
#
# - residues : B -> D, Z -> Q, X -> gap. The gap is the 21st symbol
#   of the alphabet : with the identity matrix a gap/gap pair scores 1.
#   Other symbols (U, O, *) are not paired, but are not gaps.
# - GroupSim, for each column :
#     within  = mean over the groups of the mean identity of the pairs
#               of residues of the group (0 if less than 2 residues)
#     between = mean over the pairs of groups (g, h) of the mean
#               identity of the pairs (residue of g, residue of h)
#     score   = (1 - gap fraction of the grouped residues) * (within - between)
#   Columns with more than ColGap gaps, or with a group having more than
#   GrpGap gaps, are not scored (-999.0).
# - ConsWin : the conservation of each scored column is its
#   Jensen-Shannon divergence with the BLOSUM62 background (pseudocount
#   0.001, log2, no sequence weighting) times its fraction of non gaps.
#   For each scored column, mean conservation of the scored columns
#   of the window (Window columns on each side, the column excluded),
#   mapped to [0,1] over the alignment, then
#     score = (1 - lambda) * window conservation + lambda * GroupSim
#   (defaults of the reference : Window = 3, lambda = 0.7).
#

set GroupSimAA {A R N D C Q E G H I L K M F P S T W Y V -}

# BLOSUM62 background of the reference code (cons_window_score),
# order of GroupSimAA without the gap
set GroupSimBg {0.074 0.052 0.045 0.054 0.025 0.034 0.054 0.074
    0.026 0.068 0.099 0.058 0.025 0.047 0.039 0.057
    0.051 0.013 0.032 0.073}


#
# sequence as read by the reference code (upper case, B Z X mapped),
# with the Ordalie gaps (. ~ space) as '-'
#
proc GroupSimNettoie {seq} {
    return [string map {B D Z Q X - . - ~ - " " -} [string toupper $seq]]
}


#
# GroupSim of one column.
# Lcnt : for each group, list {counts of the 21 symbols, number of
# residues not in the alphabet}. Returns -999.0 if the column is not
# scored.
#
proc GroupSimColonne {Lcnt GrpGap} {
    set ng [llength $Lcnt]

    set within 0.0
    set ngap 0 ; set ntot 0
    foreach gc $Lcnt {
	lassign $gc Lc nunk
	set nv 0 ; set same 0
	foreach c $Lc {
	    incr nv $c
	    incr same [expr {$c*($c-1)/2}]
	}
	set gap [lindex $Lc end]
	if {double($gap)/($nv + $nunk) > $GrpGap} {
	    return -999.0
	}
	incr ngap $gap
	incr ntot [expr {$nv + $nunk}]
	if {$nv >= 2} {
	    set within [expr {$within + double($same)/($nv*($nv-1)/2)}]
	}
	lappend Lnv $nv
    }
    set within [expr {$within/$ng}]

    set between 0.0
    set np 0
    for {set i 0} {$i < $ng} {incr i} {
	set Li [lindex $Lcnt $i 0]
	for {set j 0} {$j < $i} {incr j} {
	    incr np
	    set d [expr {[lindex $Lnv $i]*[lindex $Lnv $j]}]
	    # the reference code divides by zero there : the pair
	    # counts for 0
	    if {! $d} {continue}
	    set s 0
	    foreach ci $Li cj [lindex $Lcnt $j 0] {
		incr s [expr {$ci*$cj}]
	    }
	    set between [expr {$between + double($s)/$d}]
	}
    }
    set between [expr {$between/$np}]

    return [expr {(1.0 - double($ngap)/$ntot)*($within - $between)}]
}


#
# conservation of a column (js_divergence of the reference code) :
# Lc counts of the 20 residues, ngap gaps, ntot residues of the column
#
proc GroupSimJSD {Lc ngap ntot} {
    global GroupSimBg

    set pc 0.001
    set sum 0.0
    foreach c $Lc {
	set sum [expr {$sum + $c + $pc}]
    }
    set d 0.0
    set l2 [expr {log(2.0)}]
    foreach c $Lc q $GroupSimBg {
	set p [expr {($c + $pc)/$sum}]
	set r [expr {0.5*$p + 0.5*$q}]
	set d [expr {$d + $p*(log($p/$r)/$l2) + $q*(log($q/$r)/$l2)}]
    }
    set d [expr {$d/2.0}]

    return [expr {(1.0 - double($ngap)/$ntot)*$d}]
}


#
# norm_01 of the reference code : values mapped to [0,1], -999.0 kept
#
proc GroupSimNorm01 {Ls} {
    set Lv [lsearch -all -inline -not -exact -real $Ls -999.0]
    if {! [llength $Lv]} {
	return $Ls
    }
    set min [tcl::mathfunc::min {*}$Lv]
    set max [tcl::mathfunc::max {*}$Lv]
    set range [expr {double($max - $min)}]
    set Lnew {}
    foreach s $Ls {
	if {$s == -999.0} {
	    lappend Lnew -999.0
	} elseif {$range == 0} {
	    lappend Lnew 1.0
	} else {
	    lappend Lnew [expr {($s - $min)/$range}]
	}
    }

    return $Lnew
}


#
# ConsWin : Lsdp GroupSim scores, Lcons conservation of the columns
# (-999.0 for not scored columns)
#
proc GroupSimConsWin {Lsdp Lcons Win Lambda} {
    set n [llength $Lsdp]
    set Lw {}
    for {set i 0} {$i < $n} {incr i} {
	if {[lindex $Lsdp $i] == -999.0} {
	    lappend Lw -999.0
	    continue
	}
	set sum 0.0 ; set nt 0
	set jmax [expr {min($i + $Win + 1, $n)}]
	for {set j [expr {max($i - $Win, 0)}]} {$j < $jmax} {incr j} {
	    if {$j != $i && [set c [lindex $Lcons $j]] >= 0} {
		incr nt
		set sum [expr {$sum + $c}]
	    }
	}
	lappend Lw [expr {$nt ? $sum/$nt : 0.0}]
    }
    set Lw [GroupSimNorm01 $Lw]

    set Lres {}
    foreach s $Lsdp w $Lw {
	if {$s == -999.0} {
	    lappend Lres -999.0
	} else {
	    lappend Lres [expr {(1.0 - $Lambda)*$w + $Lambda*$s}]
	}
    }

    return $Lres
}


#
# GroupSim + ConsWin of an alignment.
# Lseqs : aligned sequences, Lgi : group of each sequence (0 .. ng-1,
# -1 : in no group : counted in the column gaps and conservation only).
# Options (defaults of the reference code) :
#   -window 3 (0 : no ConsWin) -lambda 0.7 -colgap 0.1 -grpgap 0.3
#   -norm 0 (1 : GroupSim scores mapped to [0,1] before ConsWin)
# Returns one score per column, -999.0 for columns not scored.
#
proc ScoreDeGroupSim {Lseqs Lgi args} {
    global GroupSimAA

    array set Opt {-window 3 -lambda 0.7 -colgap 0.1 -grpgap 0.3 -norm 0}
    foreach {o v} $args {
	if {! [info exists Opt($o)]} {
	    error "ScoreDeGroupSim : unknown option $o"
	}
	set Opt($o) $v
    }

    set ng [expr {[tcl::mathfunc::max -1 {*}$Lgi] + 1}]
    if {$ng < 2} {
	error "ScoreDeGroupSim : at least 2 groups are needed"
    }
    for {set g 0} {$g < $ng} {incr g} {
	if {$g ni $Lgi} {
	    error "ScoreDeGroupSim : group $g has no sequence"
	}
    }

    set i 0
    foreach a $GroupSimAA {
	set Ix($a) $i
	incr i
    }
    set Lcols {}
    foreach s $Lseqs {
	lappend Lcols [split [GroupSimNettoie $s] ""]
    }
    set nseq [llength $Lseqs]
    set len [string length [lindex $Lseqs 0]]
    set z21 [lrepeat 21 0]

    set Lsdp {} ; set Lcons {}
    for {set k 0} {$k < $len} {incr k} {
	set Lcnt [lrepeat $ng [list $z21 0]]
	set Lall $z21
	foreach sc $Lcols gi $Lgi {
	    set a [lindex $sc $k]
	    if {[info exists Ix($a)]} {
		lset Lall $Ix($a) [expr {[lindex $Lall $Ix($a)] + 1}]
		if {$gi >= 0} {
		    lset Lcnt $gi 0 $Ix($a) [expr {[lindex $Lcnt $gi 0 $Ix($a)] + 1}]
		}
	    } elseif {$gi >= 0} {
		lset Lcnt $gi 1 [expr {[lindex $Lcnt $gi 1] + 1}]
	    }
	}
	set ngap [lindex $Lall end]
	if {double($ngap)/$nseq > $Opt(-colgap)} {
	    set s -999.0
	} else {
	    set s [GroupSimColonne $Lcnt $Opt(-grpgap)]
	}
	lappend Lsdp $s
	if {$s == -999.0} {
	    lappend Lcons -999.0
	} else {
	    lappend Lcons [GroupSimJSD [lrange $Lall 0 end-1] $ngap $nseq]
	}
    }

    if {$Opt(-norm)} {
	set Lsdp [GroupSimNorm01 $Lsdp]
    }
    if {$Opt(-window) > 0} {
	set Lsdp [GroupSimConsWin $Lsdp $Lcons $Opt(-window) $Opt(-lambda)]
    }

    return $Lsdp
}


#
# Conservation tool, method "GroupSim" (Compute) : GroupSim + ConsWin on the
# current groups. The result is a temporary conservation feature
# tmpCons-GroupSim_<n> : the scores are drawn as one line, the
# Defauts(GroupSimTop) best scored columns (the reference code has no
# cutoff) are marked, residues coloured with the colour of their
# group. Saved as Cons-GroupSim with the "Save" button.
#
proc LanceCalculGroupSim {} {
    global Cons Defauts ListeTypesDeFeatures ScoreMeth TabSF

    if {[TypeAli] eq "pasdali"} {
	FaireLire "Please load an alignment first !"
	return
    }

    lassign [SDPGroupesEtSequences $Defauts(GroupSimMinGroupSize)] Lgroups Lnames Lseqs Lgi
    if {[llength $Lgroups] < 2} {
	FaireLire "GroupSim needs at least 2 groups of\nat least $Defauts(GroupSimMinGroupSize) sequences.\nDefine groups with the Clustering tool first."
	return
    }

    FaireAttendre "Please wait ...\nGroupSim + ConsWin : specificity-determining positions"

    set Lres [ScoreDeGroupSim $Lseqs $Lgi \
		  -window $Defauts(GroupSimWindow) \
		  -lambda $Defauts(GroupSimLambda) \
		  -colgap $Defauts(GroupSimColGap) \
		  -grpgap $Defauts(GroupSimGrpGap)]

    # best scored columns
    set Lsc {}
    set k 0
    foreach s $Lres {
	if {$s != -999.0} {
	    lappend Lsc [list $k $s]
	}
	incr k
    }
    set ntop [expr {int(ceil($Defauts(GroupSimTop)*[llength $Lsc]))}]
    set Ltop [lrange [lsort -real -decreasing -index 1 $Lsc] 0 $ntop-1]

    # temporary feature name, as in RunMethode
    set n 0
    foreach f $ListeTypesDeFeatures {
	if {[regexp {^(tmp)?Cons-GroupSim_([0-9]+)$} $f tmp tmp i] && $i > $n} {
	    set n $i
	}
    }
    set ft "tmpCons-GroupSim_[incr n]"
    lappend ListeTypesDeFeatures $ft
    set ScoreMeth($ft,Edit) 0

    # scores drawn as one (global) line in the scores frame
    set g "GroupeToutLeMonde"
    set ScoreMeth($ft,ListeGrps) $g
    set ScoreMeth($ft,ScaleGlobal) 0
    set min 1e99 ; set max -1e99
    foreach e $Lsc {
	lassign $e k s
	set ScoreMeth($ft,$g,$k) $s
	if {$s < $min} {set min $s}
	if {$s > $max} {set max $s}
    }
    if {$max < $min} {
	set min 0.0 ; set max 1.0
    }
    if {$max == $min} {
	set max [expr {$min + 1.0}]
    }
    set ScoreMeth($ft,$g-min) $min
    set ScoreMeth($ft,$g-max) $max

    # feature : at each best column, residues of each group in the
    # group colour
    set rang 0
    foreach e $Ltop {
	lassign $e k s
	incr rang
	set note [format "GroupSim %.3f rank %d" $s $rang]
	set ig 0
	foreach grp $Lgroups {
	    set c [CouleurO2Ordali [CouleurDuGroupe [string range $grp 5 end]]]
	    set nl [list "fstart" $k "fstop" $k "fcolor" $c "fscore" $s "fnote" $note "fcsys" "global" "ftarget" "group"]
	    foreach nom $Lnames seq $Lseqs gi $Lgi {
		if {$gi == $ig && [string index $seq $k] ni {. - " " ~}} {
		    lappend TabSF($nom,$ft) $nl
		}
	    }
	    incr ig
	}
    }

    EcritLeBilanGroupSim $Ltop $Lgroups $Lseqs $Lgi [llength $Lsc]

    FaireLaSuite

    # register in the Show combobox, as LanceCalculConservation does
    if {[info exists Cons(Entry)] && $Cons(Entry) ne ""} {
	set Cons(Title) [$Cons(Entry) get]
    }
    lappend Cons(ListeCons) [list $ft $Cons(Title)]
    if {[info exists Cons(ComboSel)] && $Cons(ComboSel) ne ""} {
	set Lfeat {}
	foreach fttl $Cons(ListeCons) {
	    lappend Lfeat [lindex $fttl 0]
	}
	$Cons(ComboSel) configure -values $Cons(ListeCons) -width [PlusLongEltDe $Lfeat]
	$Cons(ComboSel) current [expr {[llength $Cons(ListeCons)]-1}]
    }
    set Cons(ConsCou) $ft
    set ScoreMeth($ft,Title)   $Cons(Title)
    set ScoreMeth($ft,Methode) "GroupSim"

    ChangeConservation

    if {! [llength $Ltop]} {
	FaireLire "GroupSim : no column could be scored\n(too many gaps)."
    }

    return $ft
}


#
# Log : parameters, then the best columns (decreasing score) with the
# main residue of each group
#
proc EcritLeBilanGroupSim {Ltop Lgroups Lseqs Lgi nsc} {
    global Defauts

    if {[info commands AuLog] eq ""} {
	return
    }
    AuLog ""
    AuLog "GroupSim + ConsWin : specificity-determining positions"
    AuLog "======================================================"
    AuLog "Groups : [join $Lgroups {, }]"
    AuLog "identity matrix, window $Defauts(GroupSimWindow), lambda $Defauts(GroupSimLambda), max gaps [expr {round(100*$Defauts(GroupSimColGap))}]% (column) [expr {round(100*$Defauts(GroupSimGrpGap))}]% (group)"
    AuLog "$nsc columns scored, [llength $Ltop] best ([expr {round(100*$Defauts(GroupSimTop))}]%) marked"
    foreach e $Ltop {
	lassign $e k s
	set Lmaj {}
	set ig 0
	foreach grp $Lgroups {
	    unset -nocomplain cnt
	    set ntot 0
	    foreach seq $Lseqs gi $Lgi {
		if {$gi != $ig} {continue}
		incr cnt([string toupper [string index $seq $k]])
		incr ntot
	    }
	    set best "" ; set nb 0
	    foreach {r c} [array get cnt] {
		if {$c > $nb} {set best $r ; set nb $c}
	    }
	    lappend Lmaj "$grp:$best[expr {round(100.0*$nb/$ntot)}]%"
	    incr ig
	}
	AuLog [format "col %5d  score %6.3f  %s" [expr {$k+1}] $s [join $Lmaj " "]]
    }

    return
}
