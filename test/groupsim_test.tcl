#
# Unit tests of GroupSim + ConsWin (src/ordali_groupsim.tcl),
# toy cases computed by hand. No Tk needed :
#   /home/moumou/tcl/bin/tclsh8.6 test/groupsim_test.tcl
#
package require tcltest
namespace import ::tcltest::*

source [file join [file dirname [file dirname [file normalize [info script]]]] src ordali_groupsim.tcl]

proc ::tcltest::NombresProches {expected actual} {
    if {[llength $expected] != [llength $actual]} {return 0}
    foreach e $expected a $actual {
	if {abs($e - $a) > 1e-12} {return 0}
    }
    return 1
}
customMatch proche ::tcltest::NombresProches

# GroupSim alone (no window) of one column given as one string per group
proc Col {Lgroups args} {
    set Lseqs {} ; set Lgi {}
    set g 0
    foreach s $Lgroups {
	foreach r [split $s ""] {
	    lappend Lseqs $r
	    lappend Lgi $g
	}
	incr g
    }
    return [ScoreDeGroupSim $Lseqs $Lgi -window 0 {*}$args]
}

# --- GroupSim
# within : 1 in each group ; between : 0
test gs-1 {groups conserved and different} -body {Col {AAA CCC}} -match proche -result 1.0
# within 1 ; between 1
test gs-2 {same residue everywhere} -body {Col {AAA AAA}} -match proche -result 0.0
# within : AAC -> 1 identical pair / 3 = 1/3, idem CCA ;
# between : (2 A x 1 A + 1 C x 2 C) / 9 = 4/9 ; 1/3 - 4/9 = -1/9
test gs-3 {mixed groups} -body {Col {AAC CCA}} -match proche -result [expr {-1.0/9}]
# 3 groups : within 1 ; between : pairs (2,1)=1 (3,1)=0 (3,2)=0 -> 1/3
# score 2/3 (the mean over the pairs of groups, not group / rest :
# with group / rest, between = (1/2 + 1/2 + 0)/3 = 1/3 too)
test gs-4 {3 groups} -body {Col {AA AA CC}} -match proche -result [expr {2.0/3}]
# 3 groups where pairs of groups and group / rest differ :
# within : AA 1, AC 0, CC 1 -> 2/3 ;
# between : (AC,AA) 2/4 ; (CC,AA) 0 ; (CC,AC) 2/4 -> 1/3 ; score 1/3
# (group / rest : AA vs ACCC 1/4, AC vs AACC 1/2, CC vs AAAC 1/4 -> 1/3 :
# same again) ; with 4 groups of different sizes they differ :
# within : AAA 1, C 0 (one residue), CC 1, AC 0 -> 1/2
# between pairs : (C,AAA) 0 ; (CC,AAA) 0 ; (CC,C) 1 ; (AC,AAA) 3/6 ;
#   (AC,C) 1/2 ; (AC,CC) 2/4 -> (0+0+1+1/2+1/2+1/2)/6 = 5/12
# score 1/2 - 5/12 = 1/12
test gs-5 {4 groups, mean over the pairs of groups} -body {Col {AAA C CC AC}} -match proche -result [expr {1.0/12}]
# gaps : the gap is a symbol (gap/gap pair = 1) and the score is
# multiplied by the fraction of grouped residues that are not gaps.
# AA-A : 4 symbols, pairs 6, identical 3 (A) -> 1/2 ; CCCC 1 -> within 3/4
# between 0 ; non gaps 7/8 ; score 3/4 * 7/8 = 21/32
# (column gaps 1/8 > 0.1 : the column gap cutoff is raised)
test gs-6 {gaps} -body {Col {AA-A CCCC} -colgap 0.2} -match proche -result [expr {21.0/32}]
test gs-7 {column gap cutoff} -body {Col {AA-A CCCC}} -result -999.0
# group gaps 2/4 > 0.3
test gs-8 {group gap cutoff} -body {Col {A--A CCCCCCCCCCCCCCCCCCCC}} -result -999.0
# gap/gap pairs between groups count : A- vs C- -> within (0 + 0)/2,
# between 1/4, non gaps 1/2 -> -1/8
test gs-9 {gap pairs between groups} -body {Col {A- C-} -colgap 0.9 -grpgap 0.9} -match proche -result [expr {-1.0/8}]
# Ordalie gaps (.), lower case, X = gap, B = D, Z = Q
test gs-10 {residue mapping} -body {Col {bD. zQ.} -colgap 0.9 -grpgap 0.9} -match proche -result [Col {DD- QQ-} -colgap 0.9 -grpgap 0.9]
test gs-11 {X is a gap} -body {Col {AAX CCC} -colgap 0.9 -grpgap 0.9} -match proche -result [Col {AA- CCC} -colgap 0.9 -grpgap 0.9]
# residue out of the alphabet : not paired, not a gap
# AAU : 1 pair (AA) identical -> 1 ; CCC 1 ; between 0 ; no gap -> 1
test gs-12 {unknown residue} -body {Col {AAU CCC}} -match proche -result 1.0
# a sequence in no group (-1) counts only for the column gaps
test gs-13 {sequence in no group} -body {
    ScoreDeGroupSim {A A C C -} {0 0 1 1 -1} -window 0
} -result -999.0
test gs-14 {one group only} -body {ScoreDeGroupSim {A C} {0 0}} -returnCodes error -match glob -result "*at least 2 groups*"

# --- JSD (reference : pseudocount 0.001, BLOSUM62 background, log2)
# n residues A, 20 types : p(A) = (n+0.001)/(n+0.02),
# p(other) = 0.001/(n+0.02), r = (p+q)/2, JSD = 1/2 sum p log2(p/r) + q log2(q/r)
proc JSDMain {n} {
    set q $::GroupSimBg
    set d 0.0
    for {set i 0} {$i < 20} {incr i} {
	set p [expr {($i == 0 ? $n + 0.001 : 0.001)/($n + 0.02)}]
	set qi [lindex $q $i]
	set r [expr {($p+$qi)/2.0}]
	set d [expr {$d + $p*log($p/$r)/log(2) + $qi*log($qi/$r)/log(2)}]
    }
    return [expr {$d/2.0}]
}
test jsd-1 {column AAAA} -body {GroupSimJSD [list 4 {*}[lrepeat 19 0]] 0 4} -match proche -result [JSDMain 4]
# the same residues with 2 gaps : same frequencies, times 4/6
test jsd-2 {gaps scale the JSD} -body {GroupSimJSD [list 4 {*}[lrepeat 19 0]] 2 6} -match proche -result [expr {[JSDMain 4]*4.0/6}]
# column with the background composition (counts 1000 x q) : JSD ~ 0
test jsd-3 {background column} -body {
    expr {[GroupSimJSD [lmap q $::GroupSimBg {expr {round(100000*$q)}}] 0 100000] < 1e-6}
} -result 1

# --- ConsWin, window 1, lambda 0.7, by hand :
# scores  0.2 0.4  -  0.6 0.8 ; conservation 0.1 0.3 0.5 0.7 0.9
# window : col0 -> col1 0.3 ; col1 -> col0 0.1 (col2 not scored) ;
#   col3 -> col4 0.9 ; col4 -> col3 0.7
# [0,1] (min 0.1 max 0.9) : 0.25 0 - 1 0.75
# 0.3 w + 0.7 s : 0.215 0.28 - 0.72 0.785
test win-1 {ConsWin} -body {
    GroupSimConsWin {0.2 0.4 -999.0 0.6 0.8} {0.1 0.3 -999.0 0.7 0.9} 1 0.7
} -match proche -result {0.215 0.28 -999.0 0.72 0.785}
# windows cut at the ends ; a column with no scored neighbour : 0 ;
# all window values equal -> mapped to 1
test win-2 {no neighbour} -body {
    GroupSimConsWin {0.5 -999.0 -999.0 0.5} {0.2 -999.0 -999.0 0.2} 1 0.7
} -match proche -result {0.65 -999.0 -999.0 0.65}
test win-3 {lambda 1 : GroupSim only} -body {
    GroupSimConsWin {0.2 0.4 0.6} {0.9 0.1 0.5} 3 1.0
} -match proche -result {0.2 0.4 0.6}
test norm-1 {norm 01} -body {GroupSimNorm01 {2.0 -999.0 4.0 3.0}} -match proche -result {0.0 -999.0 1.0 0.5}

# --- whole pipeline on 3 columns, window 1 :
# col0 AA|CC : GroupSim 1 ; col1 AA|AA : 0 ; col2 CC|AA : 1
# conservation c0 = JSD(A2 C2), c1 = JSD(A4), c2 = c0
# window : col0 -> c1 ; col1 -> (c0+c2)/2 = c0 ; col2 -> c1
# [0,1] : c1 > c0 -> 1 0 1 ; scores 0.3+0.7 = 1, 0, 1
test pipe-1 {GroupSim + ConsWin} -body {
    ScoreDeGroupSim {AAC AAC CAA CAA} {0 0 1 1} -window 1
} -match proche -result {1.0 0.0 1.0}

cleanupTests
