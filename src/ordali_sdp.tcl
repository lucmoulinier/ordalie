#
# Specificity-Determining Positions : SDPpred
#
# Implementation of the SDPpred algorithm (Kalinina et al. 2004,
# Nucleic Acids Res. 32:W424 ; Protein Sci. 13:443) : positions
# conserved within each group of sequences but differing between groups.
#
# - mutual information between residue type a and group i at column p :
#     I_p = sum_i sum_a f_p(a,i) log( f_p(a,i) / (f_p(a) f(i)) )
#   f_p(a,i) : occurrences of a in group i / column length,
#   f_p(a)   : frequency of a in the whole column,
#   f(i)     : fraction of sequences in group i.
#   20 residue types : gaps and non standard residues are not counted.
# - smoothed frequencies (small samples, similar residues) :
#     f~(a,i) = ( n(a,i) + k sqrt(n(i)) sum_b f(b,i) m(b->a) ) / ( n(i) + k sqrt(n(i)) )
#   n(i) size of group i (or of the whole alignment for f_p(a)),
#   m(b->a) substitution probability of the BLOSUM matrix closest to the
#   average identity of the group, 0 < k < 1 smoothing parameter.
# - significance : each column is shuffled NShuffle times (I_sh). As
#   proteins are more similar within groups than between groups, the
#   expected MI is a linear transform I_exp = a I_sh + b (Mirny &
#   Gelfand 2002), a and b minimizing the sum of the squared Z-scores
#   over the columns (as described by Donald & Shakhnovich 2005) :
#     Z_p = (I_p - <I_exp>) / sd(I_exp)
# - threshold : Bernoulli estimator. Z-scores sorted Z1 >= Z2 >= ... ;
#     k* = argmin_k P(at least k of the n Z-scores > Z_k),
#     binomial with p = P(N(0,1) > Z_k) ; the k* top positions are SDP.
# - columns with more than MaxGap gaps are not analyzed (-999.0) ;
#   columns with one residue type get Z = 0 (their MI only reflects the
#   gaps, whose distribution would give spurious high Z-scores).
#
# Not reproduced (details not available in the publications at hand) :
# SDPpred uses specific matrices for groups with identity >= 60 %
# (the BLOSUM closest to the identity is used here). The value of k is
# not given in the server paper : default 0.5 (Defauts(SDPSmooth)).
#

set SDPAA {A C D E F G H I K L M N P Q R S T V W Y}


#
# Conditional substitution probabilities m(b->a) of BLOSUM<num>
# (etc/blosum, NCBI), recovered from the scores :
#   q(a,b) = p(a) p(b) exp(lambda s(a,b)), lambda such that sum q = 1,
# then rows normalized. Returns 20 rows (b) of 20 values (a), order SDPAA.
#
proc SDPMatrice {num} {
    global SDPMat SDPAA OrdEtcDir

    if {[info exists SDPMat($num)]} {
	return $SDPMat($num)
    }

    # background frequencies (BLOSUM62)
    set bg [dict create A 0.078 R 0.051 N 0.041 D 0.052 C 0.024 Q 0.034 \
		E 0.059 G 0.083 H 0.025 I 0.062 L 0.092 K 0.056 M 0.024 \
		F 0.044 P 0.043 S 0.059 T 0.055 W 0.014 Y 0.034 V 0.072]

    set f [open [file join $OrdEtcDir blosum BLOSUM$num]]
    set Lcol {}
    while {[gets $f l] >= 0} {
	if {[string index $l 0] eq "#" || [string trim $l] eq ""} {
	    continue
	}
	if {$Lcol eq {}} {
	    set Lcol $l
	    continue
	}
	set b [lindex $l 0]
	foreach a $Lcol s [lrange $l 1 end] {
	    set S($b,$a) $s
	}
    }
    close $f

    # lambda by bisection
    set lo 0.01 ; set hi 2.0
    for {set it 0} {$it < 60} {incr it} {
	set lam [expr {($lo+$hi)/2.0}]
	set tot 0.0
	foreach a $SDPAA {
	    foreach b $SDPAA {
		set tot [expr {$tot + [dict get $bg $a]*[dict get $bg $b]*exp($lam*$S($b,$a))}]
	    }
	}
	if {$tot > 1.0} {set hi $lam} else {set lo $lam}
    }

    set M {}
    foreach b $SDPAA {
	set row {}
	set s 0.0
	foreach a $SDPAA {
	    set q [expr {[dict get $bg $a]*[dict get $bg $b]*exp($lam*$S($b,$a))}]
	    lappend row $q
	    set s [expr {$s + $q}]
	}
	lappend M [lmap q $row {expr {$q/$s}}]
    }
    set SDPMat($num) $M

    return $M
}


#
# BLOSUM matrix whose clustering level is the closest to the identity (%)
#
proc SDPChoixMatrice {id} {
    set best 62 ; set dmin 1e9
    foreach n {30 35 40 45 50 55 60 62 65 70 75 80 85 90 100} {
	set d [expr {abs($id - $n)}]
	if {$d < $dmin} {set dmin $d ; set best $n}
    }

    return $best
}


#
# Average pairwise identity (%) of aligned sequences, over positions
# where both have a residue. At most 300 pairs (random).
#
proc SDPIdentiteMoyenne {Lseqs} {
    set n [llength $Lseqs]
    if {$n < 2} {
	return 100.0
    }
    set Lp {}
    for {set i 0} {$i < $n-1} {incr i} {
	for {set j [expr {$i+1}]} {$j < $n} {incr j} {
	    lappend Lp $i $j
	}
    }
    set np [expr {[llength $Lp]/2}]
    if {$np > 300} {
	set Ls {}
	for {set t 0} {$t < 300} {incr t} {
	    set r [expr {2*int(rand()*$np)}]
	    lappend Ls {*}[lrange $Lp $r $r+1]
	}
	set Lp $Ls
    }
    set Lseqs [lmap s $Lseqs {split [string toupper $s] ""}]
    set sid 0.0 ; set nok 0
    foreach {i j} $Lp {
	set id 0 ; set tot 0
	foreach a [lindex $Lseqs $i] b [lindex $Lseqs $j] {
	    if {[string is upper -strict $a] && [string is upper -strict $b]} {
		incr tot
		if {$a eq $b} {incr id}
	    }
	}
	if {$tot} {
	    set sid [expr {$sid + 100.0*$id/$tot}]
	    incr nok
	}
    }

    return [expr {$nok ? $sid/$nok : 100.0}]
}


#
# ScoreDeSDP : SDPpred scores, no Tk.
#   Lseqs : aligned sequences (strings of same length)
#   Lgrp  : group index (0..G-1) of each sequence
# Returns {Lres Lmat Ab} : Lres one element per column, {Z I} or -999.0 ;
# Lmat the BLOSUM used for each group, then for the whole alignment ;
# Ab {a b} of the expected mutual information I_exp = a I_sh + b.
#
# Speed : the NShuffle permutations are drawn once and used for every
# column ; sequences are sorted by group so that a group is a substring
# of the (permuted) column. Two passes : all the columns are shuffled
# EarlyN times, the linear correction (a,b) is fitted on these values,
# and only the columns whose corrected Z is at least EarlyZ (far below
# the Bernoulli cutoff otherwise) get the remaining shuffles ; (a,b)
# is then fitted again. Testing the uncorrected Z (inflated by a ~ 5)
# stopped almost no column : 1000 shuffles for nearly all of them.
#
proc ScoreDeSDP {Lseqs Lgrp args} {
    global SDPAA

    set NSh    1000
    set K      0.5
    set MaxGap 0.3
    set Seed   ""
    set EarlyN 100
    set EarlyZ 1.5
    set Progress ""
    foreach {opt val} $args {
	switch -- $opt {
	    -nshuffle {set NSh    $val}
	    -k        {set K      $val}
	    -maxgap   {set MaxGap $val}
	    -seed     {set Seed   $val}
	    -earlyn   {set EarlyN $val}
	    -earlyz   {set EarlyZ $val}
	    -progress {set Progress $val}
	    default {error "ScoreDeSDP : unknown option $opt"}
	}
    }
    if {$Seed ne ""} {
	expr {srand($Seed)}
    }

    set N [llength $Lseqs]
    if {$N != [llength $Lgrp] || $N == 0} {
	error "ScoreDeSDP : sequences and groups lists differ"
    }
    set len [string length [lindex $Lseqs 0]]
    set G [expr {[tcl::mathfunc::max {*}$Lgrp] + 1}]

    # sequences sorted by group, upper case, non standard residues -> "."
    set Lrows {}
    foreach s $Lseqs g $Lgrp {
	lappend Lrows [list $g [string toupper $s]]
    }
    set Lrows [lsort -integer -index 0 $Lrows]
    set Lseqs {}
    foreach r $Lrows {
	set s [lindex $r 1]
	regsub -all {[^ACDEFGHIKLMNPQRSTVWY]} $s "." s
	lappend Lseqs $s
    }
    set i 0
    foreach a $SDPAA {
	set Code($a) $i
	incr i
    }

    # per group (g = G : whole alignment) : range in the column,
    # D = n + k sqrt(n), f(i), smoothing vectors V(b) = e_b + k/sqrt(n) m(b->.)
    set Lmat {}
    set deb 0
    for {set g 0} {$g <= $G} {incr g} {
	if {$g < $G} {
	    set Ls {}
	    foreach r $Lrows s $Lseqs {
		if {[lindex $r 0] == $g} {lappend Ls $s}
	    }
	    set n [llength $Ls]
	    lappend Range $deb [expr {$deb + $n - 1}]
	    incr deb $n
	} else {
	    set Ls $Lseqs
	    set n $N
	}
	set num [SDPChoixMatrice [SDPIdentiteMoyenne $Ls]]
	lappend Lmat $num
	set M [SDPMatrice $num]
	set c [expr {$K/sqrt($n)}]
	set Vg {}
	for {set b 0} {$b < 20} {incr b} {
	    set V [lmap m [lindex $M $b] {expr {$c*$m}}]
	    lset V $b [expr {[lindex $V $b] + 1.0}]
	    lappend Vg $V
	}
	set VV($g) $Vg
	set D($g) [expr {$n + $K*sqrt($n)}]
	set F($g) [expr {double($n)/$N}]
    }

    # permutations, drawn once
    set Lperm {}
    set Lidx [lsearch -all $Lseqs *]
    for {set t 0} {$t < $NSh} {incr t} {
	lappend Lperm [lsort -indices -real [lmap x $Lidx {expr {rand()}}]]
    }

    if {$EarlyN > 0 && $EarlyN < $NSh} {
	set Lperm1 [lrange $Lperm 0 $EarlyN-1]
	set Lperm2 [lrange $Lperm $EarlyN end]
    } else {
	set Lperm1 $Lperm
	set Lperm2 {}
    }

    # pass 1. Lraw : {p I <I_sh> sd(I_sh)} of the columns not shuffled
    # (one residue type) ; St(p) {I s1 s2 ns} sums of the shuffled values
    set Lres {} ; set Lraw {} ; set Lcols {}
    for {set p 0} {$p < $len} {incr p} {
	if {$Progress ne "" && $p % 50 == 0} {
	    uplevel #0 [list {*}$Progress $p $len]
	}
	set col {}
	foreach s $Lseqs {
	    lappend col [string index $s $p]
	}
	set scol [join $col ""]
	set Lt [lsort -unique [split [string map {. ""} $scol] ""]]
	set ngap [expr {$N - [string length [string map {. ""} $scol]]}]
	if {double($ngap)/$N > $MaxGap || ! [llength $Lt]} {
	    lappend Lres -999.0
	    continue
	}
	if {[llength $Lt] == 1} {
	    # one residue type (+ gaps) : nothing differs between groups,
	    # the MI only reflects the gaps -> not an SDP
	    lappend Lraw [list $p 0.0 0.0 0.0]
	    lappend Lres $p
	    continue
	}
	set Lb [lmap t $Lt {set Code($t)}]

	# whole column : L(a) = log f~(a), unchanged by shuffling
	set fa [lrepeat 20 0.0]
	foreach t $Lt b $Lb {
	    set nb [expr {$N - [string length [string map [list $t ""] $scol]]}]
	    set fa [lmap x $fa v [lindex $VV($G) $b] {expr {$x + $nb*$v}}]
	}
	set L [lmap x $fa {expr {log($x/$D($G))}}]

	SDPPrepareColonne $G $Lb $L VV D F

	# observed and shuffled mutual information ; group terms cached
	# by group composition
	set Cache {}
	set Iobs [SDPInfoMutuelle $scol $Range $Lt Cache]
	set St($p) [SDPMelange $col $Range $Lt $Lperm1 Cache [list $Iobs 0.0 0.0 0]]
	set Col($p) [list $col $Lt $Lb $L]
	lappend Lcols $p
	lappend Lres $p
    }

    # pass 2 : remaining shuffles for the columns that may be SDP
    if {$Lperm2 ne {}} {
	lassign [SDPAjuste [SDPLesStats $Lraw $Lcols St]] u v
	set i 0
	foreach p $Lcols {
	    if {$Progress ne "" && $i % 10 == 0} {
		uplevel #0 [list {*}$Progress $p $len 2]
	    }
	    incr i
	    lassign $St($p) Iobs s1 s2 ns
	    lassign [SDPMoyEt $s1 $s2 $ns] m sd
	    if {$sd > 0.0 && ($u*$Iobs - $v - $m)/$sd < $EarlyZ} {
		continue
	    }
	    lassign $Col($p) col Lt Lb L
	    SDPPrepareColonne $G $Lb $L VV D F
	    set Cache {}
	    set St($p) [SDPMelange $col $Range $Lt $Lperm2 Cache $St($p)]
	}
    }
    set Lraw [SDPLesStats $Lraw $Lcols St]
    lassign [SDPAjuste $Lraw] u v
    set Ab [list [expr {1.0/$u}] [expr {$v/$u}]]

    set Lz {}
    foreach r $Lraw {
	lassign $r p I m sd
	if {$sd <= 0.0} {
	    set z 0.0
	} else {
	    set z [expr {($u*$I - $v - $m)/$sd}]
	}
	lset Lres $p [list $z $I]
    }

    return [list $Lres $Lmat $Ab]
}


#
# Shuffled mutual information of a column (list of its residues col)
# for the permutations LP ; St {I s1 s2 ns} : sums of the values and
# of their squares, number of values, updated and returned.
#
proc SDPMelange {col Range Lt LP Cachen St} {
    upvar $Cachen Cache

    lassign $St Iobs s1 s2 ns
    foreach P $LP {
	set pcol [join [lmap i $P {lindex $col $i}] ""]
	set I [SDPInfoMutuelle $pcol $Range $Lt Cache]
	set s1 [expr {$s1 + $I}]
	set s2 [expr {$s2 + $I*$I}]
	incr ns
    }

    return [list $Iobs $s1 $s2 $ns]
}


#
# {p I <I_sh> sd(I_sh)} of the columns : Lraw (not shuffled) and the
# columns Lcols, from their sums in the array St. Sorted by column.
#
proc SDPLesStats {Lraw Lcols Stn} {
    upvar $Stn St

    foreach p $Lcols {
	lassign $St($p) Iobs s1 s2 ns
	lassign [SDPMoyEt $s1 $s2 $ns] m sd
	lappend Lraw [list $p $Iobs $m $sd]
    }

    return [lsort -integer -index 0 $Lraw]
}


#
# Expected MI : I_exp = a I_sh + b, (a,b) minimizing sum Z^2 with
# Z = (I - a <I_sh> - b) / (a sd(I_sh)). With u = 1/a, v = b/a :
# Z = (u I - v - <I_sh>) / sd, i.e. weighted least squares of
# <I_sh> on I, weights 1/sd^2. Returns {u v}.
#
proc SDPAjuste {Lraw} {
    set Sw 0.0 ; set SI 0.0 ; set SII 0.0 ; set Sm 0.0 ; set SIm 0.0
    foreach r $Lraw {
	lassign $r p I m sd
	if {$sd <= 0.0} {continue}
	set w [expr {1.0/($sd*$sd)}]
	set Sw  [expr {$Sw  + $w}]
	set SI  [expr {$SI  + $w*$I}]
	set SII [expr {$SII + $w*$I*$I}]
	set Sm  [expr {$Sm  + $w*$m}]
	set SIm [expr {$SIm + $w*$I*$m}]
    }
    set u 1.0 ; set v 0.0
    if {$Sw > 0.0} {
	set den [expr {$SII - $SI*$SI/$Sw}]
	if {$den > 0.0} {
	    set u [expr {($SIm - $SI*$Sm/$Sw)/$den}]
	    set v [expr {($u*$SI - $Sm)/$Sw}]
	}
    }
    if {$u <= 0.0} {
	# degenerate fit : no correction
	set u 1.0 ; set v 0.0
    }

    return [list $u $v]
}


#
# mean and standard deviation from the sums of the shuffled values ;
# sd = 0 when shuffling changes nothing (e.g. invariant column)
#
proc SDPMoyEt {s1 s2 n} {
    set m  [expr {$s1/$n}]
    set v  [expr {$n > 1 ? ($s2 - $n*$m*$m)/($n-1) : 0.0}]
    set sd [expr {$v > 0.0 ? sqrt($v) : 0.0}]
    if {$sd < 1e-9 * (abs($m) + 1.0)} {
	set sd 0.0
    }

    return [list $m $sd]
}


#
# For one column with residue types Lb : stores the smoothing vectors
# V(g,b) of these types, W(g,b) = V(g,b).L, and defines
# SDPTermeColonne g n_1 ... n_m = group term for the counts n_j of the
# types : f(i) [ sum_a f~ log f~ - sum_a f~ L(a) ] with
# f~(a) = sum_j n_j V(g,b_j)(a) / D(g). Generated so that the sum over
# the 20 residues is a single loop.
#
proc SDPPrepareColonne {G Lb L VVn Dn Fn} {
    global SDPV SDPW SDPD SDPF
    upvar $VVn VV $Dn D $Fn F

    unset -nocomplain SDPV SDPW SDPD SDPF
    for {set g 0} {$g < $G} {incr g} {
	set j 0
	foreach b $Lb {
	    set V [lindex $VV($g) $b]
	    set SDPV($g,$j) $V
	    set w 0.0
	    foreach v $V l $L {
		set w [expr {$w + $v*$l}]
	    }
	    set SDPW($g,$j) $w
	    incr j
	}
	set SDPD($g) $D($g)
	set SDPF($g) $F($g)
    }

    set m [llength $Lb]
    set Larg {} ; set Lfe {} ; set Lx {} ; set Llin {}
    for {set j 0} {$j < $m} {incr j} {
	lappend Larg n$j
	lappend Lfe v$j "\$SDPV(\$g,$j)"
	lappend Lx "\$n$j*\$v$j"
	lappend Llin "\$n$j*\$SDPW(\$g,$j)"
    }
    proc SDPTermeColonne [list g {*}$Larg] [format {
	global SDPV SDPW SDPD SDPF
	set sx 0.0 ; set sxl 0.0
	foreach %s {
	    set x [expr {%s}]
	    if {$x > 0.0} {
		set sx  [expr {$sx + $x}]
		set sxl [expr {$sxl + $x*log($x)}]
	    }
	}
	set Dg $SDPD($g)
	return [expr {$SDPF($g)*($sxl/$Dg - $sx/$Dg*log($Dg) - (%s)/$Dg)}]
    } [join $Lfe " "] [join $Lx " + "] [join $Llin " + "]]

    return
}


#
# I = sum_i f(i) [ sum_a f~(a,i) log f~(a,i) - sum_a f~(a,i) L(a) ]
# since f_p(a,i) = f(i) f~(a,i). scol : column (string, sequences
# sorted by group), Range : first/last index of each group,
# Lt : residue types of the column.
#
proc SDPInfoMutuelle {scol Range Lt Cachen} {
    upvar $Cachen Cache

    set I 0.0
    set g 0
    foreach {deb fin} $Range {
	set sub [string range $scol $deb $fin]
	set l [string length $sub]
	set cnt {}
	set tot 0
	foreach t $Lt {
	    set c [expr {$l - [string length [string map [list $t ""] $sub]]}]
	    lappend cnt $c
	    incr tot $c
	}
	if {$tot} {
	    set key "$g:$cnt"
	    if {[dict exists $Cache $key]} {
		set I [expr {$I + [dict get $Cache $key]}]
	    } else {
		set t [SDPTermeColonne $g {*}$cnt]
		dict set Cache $key $t
		set I [expr {$I + $t}]
	    }
	}
	incr g
    }

    return $I
}


#
# log of the upper tail of N(0,1) : log P(Z > z)
# (erfc of Numerical Recipes, relative error < 1.2e-7)
#
proc SDPLogQueueNormale {z} {
    set x [expr {abs($z)/sqrt(2.0)}]
    set t [expr {1.0/(1.0+0.5*$x)}]
    set lerfc [expr {log($t) - $x*$x - 1.26551223 + $t*(1.00002368 + $t*(0.37409196 + $t*(0.09678418 + $t*(-0.18628806 + $t*(0.27886807 + $t*(-1.13520398 + $t*(1.48851587 + $t*(-0.82215223 + $t*0.17087277))))))))}]
    if {$z >= 0} {
	return [expr {$lerfc - log(2.0)}]
    }

    return [expr {log(1.0 - 0.5*exp($lerfc))}]
}


#
# Bernoulli estimator on the Z-scores Lz of the n analyzed columns.
# Returns {kstar Zk logPmin LlogP} : number of SDP, Z-score of the last
# one, minimal log probability, log P_k for k = 1..n
#
proc SDPBernoulli {Lz} {
    set Lz [lsort -real -decreasing $Lz]
    set n [llength $Lz]
    if {$n == 0} {
	return [list 0 "" 0.0 {}]
    }
    set LF [list 0.0]
    for {set i 1} {$i <= $n} {incr i} {
	lappend LF [expr {[lindex $LF end] + log($i)}]
    }
    set best 0 ; set bestP 0.0 ; set LP {}
    for {set k 1} {$k <= $n} {incr k} {
	set lp [SDPLogQueueNormale [lindex $Lz $k-1]]
	set p  [expr {exp($lp)}]
	set lq [expr {$p < 1e-10 ? -$p : log(1.0-$p)}]
	if {$k <= $n*$p} {
	    # at least k values above Z_k is expected : P close to 1
	    set lP 0.0
	} else {
	    # log sum_{j=k..n} C(n,j) p^j q^(n-j) , terms decreasing
	    set lmax ""
	    set sum 0.0
	    for {set j $k} {$j <= $n} {incr j} {
		set lt [expr {[lindex $LF $n] - [lindex $LF $j] - [lindex $LF $n-$j] + $j*$lp + ($n-$j)*$lq}]
		if {$lmax eq ""} {set lmax $lt}
		if {$lt < $lmax - 40.0} {break}
		set sum [expr {$sum + exp($lt - $lmax)}]
	    }
	    set lP [expr {min(0.0, $lmax + log($sum))}]
	}
	lappend LP $lP
	if {$lP < $bestP} {
	    set bestP $lP ; set best $k
	}
    }
    if {$best == 0} {
	return [list 0 "" 0.0 $LP]
    }

    return [list $best [lindex $Lz $best-1] $bestP $LP]
}


#
# Groups usable for SDP : Group* entries of LNDG with at least
# Defauts(SDPMinGroupSize) sequences. PDB sequences are skipped
# unless Defauts(PDBDansPilier) is set, as for conservation.
# Returns {Lgroups Lnames Lseqs Lgrpidx}
#
proc SDPGroupesEtSequences {{MinSize ""}} {
    global LNDG SDG Sequences ListePDB Defauts

    if {$MinSize eq ""} {
	set MinSize $Defauts(SDPMinGroupSize)
    }

    if {! [info exists ListePDB]} {
	set ListePDB {}
    }
    set Lgroups {} ; set Lnames {} ; set Lseqs {} ; set Lgi {}
    set ig 0
    foreach g $LNDG {
	if {$g in {GroupeToutLeMonde grise bidon} || ! [info exists SDG($g)]} {
	    continue
	}
	set Ln {}
	foreach n [set SDG($g)] {
	    if {[string trim $n] in $ListePDB && ! $Defauts(PDBDansPilier)} {
		continue
	    }
	    if {! [info exists Sequences($n)]} {
		continue
	    }
	    lappend Ln $n
	}
	if {[llength $Ln] < $MinSize} {
	    continue
	}
	lappend Lgroups $g
	foreach n $Ln {
	    lappend Lnames $n
	    lappend Lseqs [set Sequences($n)]
	    lappend Lgi $ig
	}
	incr ig
    }

    return [list $Lgroups $Lnames $Lseqs $Lgi]
}


#
# SDPpred on the current groups (no longer in the Conservation tool :
# GroupSim, ordali_groupsim.tcl, replaces it).
# The result is a temporary conservation feature tmpCons-SDP_<n>,
# displayed at once (residues of the SDP columns coloured with the
# colour of their group), saved as Cons-SDP with the "Save" button.
#
proc LanceCalculSDP {} {
    global Cons Defauts ListeTypesDeFeatures ScoreMeth TabSF

    if {[TypeAli] eq "pasdali"} {
	FaireLire "Please load an alignment first !"
	return
    }

    lassign [SDPGroupesEtSequences] Lgroups Lnames Lseqs Lgi
    if {[llength $Lgroups] < 2} {
	FaireLire "SDP prediction needs at least 2 groups of\nat least $Defauts(SDPMinGroupSize) sequences.\nDefine groups with the Clustering tool first."
	return
    }

    FaireAttendre "Please wait ...\nSDPpred : specificity-determining positions\n($Defauts(SDPNShuffle) shuffles per column)"

    lassign [ScoreDeSDP $Lseqs $Lgi \
		 -nshuffle $Defauts(SDPNShuffle) \
		 -k        $Defauts(SDPSmooth) \
		 -maxgap   $Defauts(SDPMaxGap) \
		 -seed     $Defauts(SDPSeed) \
		 -progress SDPProgression] Lres Lmat Ab

    # cutoff : Bernoulli estimator on the analyzed columns
    set Lz {}
    foreach r $Lres {
	if {[llength $r] == 2} {
	    lappend Lz [lindex $r 0]
	}
    }
    lassign [SDPBernoulli $Lz] kstar Zk logP

    # temporary feature name, as in RunMethode
    set n 0
    foreach f $ListeTypesDeFeatures {
	if {[regexp {^(tmp)?Cons-SDP_([0-9]+)$} $f tmp tmp i] && $i > $n} {
	    set n $i
	}
    }
    set ft "tmpCons-SDP_[incr n]"
    lappend ListeTypesDeFeatures $ft
    set ScoreMeth($ft,Edit) 0

    # Z-scores drawn as one (global) line in the scores frame
    set g "GroupeToutLeMonde"
    set ScoreMeth($ft,ListeGrps) $g
    set ScoreMeth($ft,ScaleGlobal) 0
    set min 1e99 ; set max -1e99
    set Lsdp {}
    set k 0
    foreach r $Lres {
	if {[llength $r] == 2} {
	    lassign $r z s
	    set ScoreMeth($ft,$g,$k) $z
	    if {$z < $min} {set min $z}
	    if {$z > $max} {set max $z}
	    if {$kstar > 0 && $z >= $Zk} {
		lappend Lsdp [list $k $z $s]
	    }
	}
	incr k
    }
    if {$max < $min} {
	set min 0.0 ; set max 1.0
    }
    if {$max == $min} {
	set max [expr {$min + 1.0}]
    }
    set ScoreMeth($ft,$g-min) $min
    set ScoreMeth($ft,$g-max) $max

    # Feature : at each SDP, residues of each group in the group colour
    foreach sdp $Lsdp {
	lassign $sdp k z s
	set note [format "SDP Z=%.2f MI=%.3f" $z $s]
	foreach grp $Lgroups {
	    set c [CouleurO2Ordali [CouleurDuGroupe [string range $grp 5 end]]]
	    set nl [list "fstart" $k "fstop" $k "fcolor" $c "fscore" $z "fnote" $note "fcsys" "global" "ftarget" "group"]
	    foreach nom $Lnames seq $Lseqs gi $Lgi {
		if {[lindex $Lgroups $gi] eq $grp && [string index $seq $k] ni {. - " " ~}} {
		    lappend TabSF($nom,$ft) $nl
		}
	    }
	}
    }

    EcritLeBilanSDP $Lsdp $Lgroups $Lseqs $Lgi $Lmat $Ab [llength $Lz] $Zk $logP

    FaireLaSuite

    # register in the Show combobox, as LanceCalculConservation does ;
    # Cons(ConsCou) + ChangeConservation display the SDP columns
    # (Cons(Method) is left unchanged : SDP is not a Compute method)
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
    set ScoreMeth($ft,Methode) "SDP"

    ChangeConservation

    if {! [llength $Lsdp]} {
	FaireLire "SDPpred : no specificity-determining position found."
    }

    return $ft
}


#
# progress of ScoreDeSDP in the wait window
#
proc SDPProgression {p len {pass 1}} {
    global TFAt

    if {[info exists TFAt(WtLabel)] && [winfo exists $TFAt(WtLabel)]} {
	$TFAt(WtLabel) configure -text "Please wait ...\nSDPpred : specificity-determining positions\npass $pass / 2 : column $p / $len"
	update idletasks
    }

    return
}


#
# Log : parameters and cutoff, then one line per SDP (decreasing Z)
# with the main residue of each group
#
proc EcritLeBilanSDP {Lsdp Lgroups Lseqs Lgi Lmat Ab nan Zk logP} {
    global Defauts

    if {[info commands AuLog] eq ""} {
	return
    }
    AuLog ""
    AuLog "SDPpred : specificity-determining positions"
    AuLog "============================================"
    set Lg {}
    foreach grp $Lgroups num [lrange $Lmat 0 end-1] {
	lappend Lg "$grp (BLOSUM$num)"
    }
    AuLog "Groups : [join $Lg {, }] ; whole alignment BLOSUM[lindex $Lmat end]"
    AuLog "$Defauts(SDPNShuffle) shuffles, smoothing k=$Defauts(SDPSmooth), max gaps [expr {round(100*$Defauts(SDPMaxGap))}]%, $nan columns analyzed"
    AuLog [format "Expected MI = %.3f x shuffled MI + %.4f" {*}$Ab]
    if {[llength $Lsdp]} {
	AuLog [format "Bernoulli estimator : %d SDP, Z >= %.2f, P = %.3g" [llength $Lsdp] $Zk [expr {exp($logP)}]]
    } else {
	AuLog "Bernoulli estimator : no SDP"
    }
    foreach sdp [lsort -real -decreasing -index 1 $Lsdp] {
	lassign $sdp k z s
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
	AuLog [format "col %5d  Z %6.2f  MI %5.3f  %s" [expr {$k+1}] $z $s [join $Lmaj " "]]
    }

    return
}
