proc PreCalculs {} {
global TabSF ZoneSelect LNDG SDG ListeTypesDeFeatures ScoreMeth Cons Defauts LNOrdali

if {! [set Defauts(PreCompute)]} {return}

switch [TypeAli] {
"pasdali" -
"ORD" {return}
"TFA" -
"MSF" {
SetMacCourant first
CreeVue

set ZoneSelect [list [list 1 [expr {[LongueurDeLAlignement]-1}]]]
set ::Cons(OnlyGlobal) 0
GroupesZones LNDG SDG dpc
AjouteGroupeToutLeMonde
MetAJourNomsEtSeqs
EnregistreLeMac "DPC on all" "Clustering using all sequences and full length"
}
"RSF" {}
"XML" {
if {! [info exists ListeTypesDeFeatures]} {return}
if {[llength [set Lf [lsearch -all -inline -regexp $ListeTypesDeFeatures "PFAM"]]] == 0} {
return
}
foreach f $Lf {
set Lv [array names TabSF "*,$f"]
foreach v $Lv {
set Le [set TabSF($v)]
foreach e $Le {
DecortiqueUneFeature $e dg fg col score note
if {[regexp {^PROP\_} $note]} {continue}
set No [lindex [split $note "_"] 0]
lappend LP($No) [list $dg $fg]
}
}
}

foreach e [lsort [array names LP]] {
puts "\nPreCalculs PFAM $e"
# Load 1er , pas de groupes
SetMacCourant first
CreeVue

set ZoneSelect [lunique [lsort -integer -index 0 [set LP($e)]]]
set ::Cons(OnlyGlobal) 0
# Faut nettoyer zones !
set ZoneSelect [NettoieZones $ZoneSelect]
set Lexc [GroupesZones LNDG SDG dpc]
if {([llength $LNOrdali] - [llength $Lexc]) <= 3} {
FaireLire "Not enough sequences for PFAM $e"
continue
}
# Refait LNOrdali
# !! Si seqs virees par GroupesZones, ne seront plus dans LNOrdali et donc plus dans GroupeToutLeMonde
AjouteGroupeToutLeMonde
MetAJourNomsEtSeqs
# puts "PreCalculs : LNDG [llength $LNDG] $LNDG"
set Cons(Method) Multi

set ft [PrepareRunOrdali]

set Cons(ConsCou) $ft
set ScoreMeth($ft,Title) "DPC on $f $e"
set ScoreMeth($ft,Methode) Multi
set Cons(Title) "DPC on $f $e"
set Cons(ListeCons) $ft
SauveConservation
EnregistreLeMac "DPC on $f $e" "Clustering using feature $f $e, zones [join $ZoneSelect ,]"
}
}
}

set ZoneSelect [list]
set ::ZoneClusterisation [list]

puts "\n==================="
puts   "= Fin Pre-Calculs ="
puts   "==================="
puts \n

return
}


proc NettoieZones {lz} {
set Ld [list]
set Lf [list]
set Lr [list]
foreach z $lz {
lassign $z x1 x2
if {$Lr == {}} {
lappend Lr $x1 $x2
continue
}
set nr1 -1 ; set nr2 -1
set pnr1 -1 ; set pnr2 -1
set i 0
set Lc $Lr
foreach {r1 r2} $Lc {
if {$nr1 != -1} {lset Lr $i $nr1}
if {$nr2 != -1} {lset Lr [expr {$i+1}] $nr2}
if {$pnr1 != -1} {
lappend Lr $pnr1 $pnr2
}
set nr1 -1 ; set nr2 -1
set pnr1 -1 ; set pnr2 -1
incr i 2

if {$x1 >= $r1 && $x2 <= $r2} {continue}
if {$x1 < $r1 && $x2 <= $r2} {set nr1 $x1}
if {$x1 >= $r1 && $x2 > $r2} {set nr2 $x2}
if {$x1 < $r1 && $x2 > $r2} {
set nr1 $x1
set nr2 $x2
}
if {$x1 > $r2 && $x2 > $r2} {
set pnr1 $x1
set pnr2 $x2
}
}
}

set nl [list]
foreach {x y} $Lr {
lappend nl [list $x $y]
}

return $nl
}


proc MacsimDeOrdalie {} {

computeBlocks
SeqErrors
PropagateFeatures

return
}


proc ComputeBlocks {} {
global LNDG CpB LNOrdali LSOrdali TDesSeqWeights CBPCI Sequences

# start / stop of each sequence
#
# CpB : table contains all for computation
#
set CpB(Ltot) [LongueurDeLAlignement]
set Ltot $CpB(Ltot)

array set CBPCI [PCIPourBlocks]

# compute tree
set Ln [list]
set Ldst [list]
set Ldtc [list]
foreach n1 $LNOrdali {
if {$n1 eq ""} {continue}

lappend Ln $n1
foreach n2 $LNOrdali {
if {$n2 eq ""} {continue}

set pc [set CBPCI($n1,$n2)]
lappend Ldst [expr {1.-$pc}]
lappend Ldtc [expr {1.-$pc}]
}
lappend Ldtc 1.0
}
lappend Ldtc {*}[lrepeat [llength $Ln] "1.0"] 0.0
lappend Lntc {*}$Ln "fictive_sequence"
set CpB(Lseqs) $Ln

set rep [fastme $Ln $Ldst]
set ATb [DecortiqueUnArbre $rep]

# groups
# compute secator groups
set SAli [list]
foreach n $LNOrdali s $LSOrdali {
if {[string trim $n] ne ""} {
lappend SAli $n $s
}
}
puts "llength SAli [llength $SAli]"

######
#
# Pour tests, prend meme clusters que Julie !
#
######
if {1} {
set Lres [Tclcluspack $SAli -dt alignment -cm bionj -nbc secator]
puts "Lres [llength $Lres]"
#set Lres [Tclcluspack $Lval -dt coordinates -cm mm -nbc aic]
#set rep [fastme $Lntc $Ldtc]
#set Lres [Tclcluspack $rep -dt newick -cm mm -nbc secator]

ClusterSeqsDeCluspackTcl $Lres SeqsDeGrps LesNomsGrps
} else {
# prend meme cluster que rascal
LectureClusters lucky.clu SeqsDeGrps LesNomsGrps
# prend meem arbre que rascal
set Ll [LesLignesDuFichier lucky.ph]
set rep [join $Ll ""]
set ATb [DecortiqueUnArbre $rep]
}

set ngroups [llength $LesNomsGrps]
if {$ngroups < 2} {
FaireLire "Not enough groups to compute blocks !"
return
}
set CpB(LNDG) [linsert $LesNomsGrps 0 GroupeToutLeMonde]
puts "LNDG $CpB(LNDG)"
foreach g $LesNomsGrps {
lappend CpB(GroupeToutLeMonde) {*}[set SeqsDeGrps($g)]
set CpB($g) [set SeqsDeGrps($g)]
set CpB(GOri,$g) [set SeqsDeGrps($g)]
}
set CpB(LNDGOri) $CpB(LNDG)
foreach g [lrange $CpB(LNDG) 1 end] {
puts "DEBITEM $g"
foreach n [set CpB($g)] {
puts "ITEM $n"
}
}

# compute sequence weights from tree
array set TDesSeqWeights [SequenceWeight $ATb]

# Check weights
puts "DEBITEM SeqWgt"
set i 0
foreach n [set CpB(GroupeToutLeMonde)] {
puts "ITEM $n [set TDesSeqWeights($n)]"
incr i
}

# check orphans
OrphanSeqs

# computes blocks in each groups
set window 8
foreach g $CpB(LNDG) {
set CpB($g,Lpil) [CreeLesPiliersPourBlocks [set CpB($g)]]
set CpB(Blocks,$g) [list]
LesBlocks $g $window
}
update

# output
foreach g [lrange [set CpB(LNDG)] 1 end] {
puts "PGroup[string range $g 5 end]"
puts "seqs [llength [set CpB($g)]]"
puts "blck [llength [set CpB(Blocks,$g)]]"
puts "prf1 [llength [set CpB($g,Lprf1)]]"
puts "prf2 [llength [set CpB($g,Lprf2)]]"
puts "code [llength [set CpB($g,Lcode)]]"

puts "DEBITEM NwB[string range $g 5 end]"
foreach b [set CpB(Blocks,$g)] {
lassign $b d f
puts "ITEM $d $f"
}
}

set shared_cutoff 80000
set ig1 0
foreach g1 [lrange $CpB(LNDG) 1 end-1] {
incr ig1
if {[llength $CpB($g1)] < 2} {continue}

set j [expr {$ig1 + 1}]
set ig2 $ig1
foreach g2 [lrange $CpB(LNDG) $j end] {
incr ig2
if {[llength $CpB($g2)] < 2} {continue}

for {set ib1 0} {$ib1 < [llength [set CpB(Blocks,$g1)]]} {incr ib1} {
set b1  [lindex [set CpB(Blocks,$g1)] $ib1]
set cd1 [lindex [set CpB($g1,Lcode)] $ib1]
lassign $b1 f1 l1
for {set ib2 0} {$ib2 < [llength [set CpB(Blocks,$g2)]]} {incr ib2} {
set b2  [lindex [set CpB(Blocks,$g2)] $ib2]
set cd2 [lindex [set CpB($g2,Lcode)] $ib2]
lassign $b2 f2 l2

if {[BlockOverlap $f1 $l1 $f2 $l2] > 0} {
set score [ScoreBlockVsBlock $f1 $f2 [lindex [set CpB($g1,Lprf1)] $ib1] [lindex [set CpB($g2,Lprf2)] $ib2]]
if {$score > $shared_cutoff} {
if {$cd1 == 0 && $cd2 == 0} {
lset CpB($g1,Lcode) $ib1 [expr {$ig1+1}]
lset CpB($g2,Lcode) $ib2 [expr {$ig1+1}]
} elseif {$cd1 > 0} {
lset CpB($g2,Lcode) $ib2 $cd1
} elseif {$cd2 > 0} {
lset CpB($g1,Lcode) $ib1 $cd2
}
set ffirst [expr {max($f1,$f2)+1}]
set flast [expr {min($l1,$l2)+1}]
puts "SHAREDCOREBLOCK $ig1 $ig2 $ffirst $flast $score"
if {($flast-$ffirst) > 3 && ($flast-$ffirst)*$score > 1} {
lappend CpB(ShBck) [list $g1 $g2 $ffirst $flast $score]
}
}
}
}
}
}
}

# compare orphan to all subgroups
set i 2
set ig1 0
foreach g1 [lrange $CpB(LNDG) 1 end] {
incr ig1
if {[llength $CpB($g1)] != 1} {continue}
set seq [set Sequences([set CpB($g1)])]

set CpB(Blocks,$g1) [list]
set CpB(MxSc,$g1)   [list]
set CpB($g1,Lcode)  [list]
set ig2 0
foreach g2 [lrange $CpB(LNDG) 1 end] {
incr ig2
if {[llength $CpB($g2)] < 2} {continue}

for {set ib2 0} {$ib2 < [llength [set CpB(Blocks,$g2)]]} {incr ib2} {
set b2  [lindex [set CpB(Blocks,$g2)] $ib2]
set cd2 [lindex [set CpB($g2,Lcode)] $ib2]
lassign $b2 f2 l2
set prf1 [lindex [set CpB($g2,Lprf1)] $ib2]
set score [ScoreSequence $seq $prf1 $f2 $l2]
if {$score > $shared_cutoff} {
puts "seq_score $ig1 [set CpB($g1)]  $ig2 [lindex [set CpB($g2)] 0] $f2 $l2 $score"
set found 0
for {set ik 0} {$ik < [llength $CpB(Blocks,$g1)]} {incr ik} {
set bk [lindex [set CpB(Blocks,$g1)] $ik]
lassign $bk fk lk
if {[BlockOverlap $fk $lk $f2 $l2] > 0} {
set mx [lindex [set CpB(MxSc,$g1)] $ik]
if {$score > $mx} {
lset CpB(MxSc,$g1) $ik $score
lset CpB(Blocks,$g1) $ik $b2
lset CpB($g1,Lcode) $ik [expr {$ib2+1}]
}
set found 1
}
}
if {! $found} {
lappend CpB(MxSc,$g1) $score
lappend CpB(Blocks,$g1) $b2
lappend CpB($g1,Lcode) [expr {$ib2+1}]
}
update
}
}
}

lassign [set CpB(startstop,[set CpB($g1)])] deb fin
set if 0
foreach b $CpB(Blocks,$g1) c $CpB($g1,Lcode) m $CpB(MxSc,$g1) {
lassign $b f l
if {$f < $deb} {set f $deb}
if {$l < $deb} {set l $deb}
if {$f > $fin} {set f $fin}
if {$l > $fin} {set l $fin}

lset CpB(Blocks,$g1) $if [list $f $l]
puts "SHAREDCOREBLOCK $c [expr {$ig1+1}] [expr {$f+1}] [expr {$l+1}] $m"
incr if
}
update
}

# check for any local core blocks that are not shared
foreach g [lrange $CpB(LNDG) 1 end] {
if {[llength [set CpB($g)]] <= 2} {continue}
set CpB(LcBck,$g) [list]
foreach c [set CpB($g,Lcode)] b [set CpB(Blocks,$g)] {
if {$c == 0} {
puts "$g LOCALCOREBLOCK $b"
lappend CpB(LcBck,$g) [list {*}$b $c]
}
}
}

return
exit
}


proc SequenceWeight {tid} {
global Abr

set A [set Abr(Arbre,$tid)]
set Lf [$A leaves]
set nf [llength $Lf]
set LW [list]
foreach l $Lf {
set sum 0
set f $l
while {[$A parent $f] ne "root"} {
set lg [$A get $f length]
if {[$A isleaf $f]} {
set sz 1
} else {
set sz [LesFeuillesDuSousArbre $A $f]
}
puts "  node $lg $sz"
set sum [expr {$lg/$sz + $sum}]

set o [$A parent $f]
set f $o
update
}
set sum [expr {int($sum * 100)}]
puts "leaf $l [$A get $l length] $sum"
lappend LW $l $sum
}

puts "DEBITEM WOri"
set i 0
array set T $LW
foreach n [set ::CpB(GroupeToutLeMonde)] {
puts "ITEM $n [set T($n)]"
incr i
}
unset -nocomplain T

# Normalisation to 1000
# (see seqweight.c rascal code)
set sum 0
foreach {k v} $LW {
incr sum $v
}
set new [list]
if {$sum == 0} {
set LW [list]
foreach f $Lf {
lappend new $f 1
}
set sum [llength $Lf]
}
foreach {k v} $LW {
set v [expr {int($v)*1000/int($sum)}]
if {$v < 1} {set v 1}
lappend new $k $v
}

return $new
}


proc LesBlocks {grp window} {
global CpB

set nseqs [llength [set CpB($grp)]]
# matrice comparaison
array set Matrix [InitClustalMatrix gon250]

# taken from comp_blocks.c from rascal
if {$grp ne "GroupeToutLeMonde"} {
if {$nseqs < 10} {
set block_cutoff 15
} else {
set block_cutoff 10
}
set minlength 6
set conserved 0.0
} else {
if {$nseqs < 100} {
set block_cutoff 10
} elseif {$nseqs < 250} {
set block_cutoff 6
} else {
set block_cutoff 5
}
set minlength 4
set conserved 0.8
}

get_blocks $grp $block_cutoff $window $conserved $minlength

if {$grp eq "GroupeToutLeMonde"} {
foreach b $CpB(Blocks,$grp) {
lassign $b d f
puts "GLOBALCOREBLOCK $d $f"
}

return
}

set Lprf1 [list]
set Lprf2 [list]
set Lcode [list]
set Laa $Matrix(laa)
puts "Laa $Laa"
if {[llength [set CpB($grp)]] > 1} {
set fst 0
foreach b [set CpB(Blocks,$grp)] {
lappend Lprf1 [Profile1DuBlock $grp $b Matrix 1.0]
lappend Lprf2 [Profile2DuBlock $grp $b $Laa]
lappend Lcode 0
if {$grp eq "Group1" && $fst == 1} {
set fst 0
puts "\ndata Group 1 $b"
puts "profile 1"
puts [join [lindex $Lprf1 1] \n]
puts "profile 2"
puts [join [lindex $Lprf2 1] \n]
}
incr fst
}
}
set CpB($grp,Lprf1) $Lprf1
set CpB($grp,Lprf2) $Lprf2
set CpB($grp,Lcode) $Lcode

return
}


proc get_blocks {grp block_cutoff window conserved minlength} {
global CpB

set nseqs [llength [set CpB($grp)]]

if {$grp eq "GroupeToutLeMonde"} {
array set colscore [calc_normd_global $grp $window $conserved]
} else {
if {[llength [set CpB($grp)]] < 2} {
return 0
}
array set colscore [calc_normd_for_subgroup $grp $window $conserved]
}

set inregion 0
set Ltot $CpB(Ltot)
set nblocks 0
set CpB(Blocks,$grp) [list]
for {set i 0} {$i < $Ltot} {incr i} {
if {[set colscore($i)] >= $block_cutoff} {
if {! $inregion} {
set first $i
set inregion 1
}
} else {
if {$inregion} {
set last [expr {$i-1}]
if {$last >= ($first+$minlength)} {
lappend CpB(Blocks,$grp) [list $first $last]
}
set inregion 0
}
}
}
if {$inregion} {
set last $Ltot
if {$last >= ($first+$minlength)} {
lappend CpB(Blocks,$grp) [list $first $last]
}
}

if {$grp eq "GroupeToutLeMonde"} {
puts "DEBITEM BTous"
foreach b [set CpB(Blocks,$grp)] {
lassign $b f d
puts "ITEM $f $d"
}
}

return [llength $CpB(Blocks,$grp)]
}


proc calc_normd_global {grp score_win conserved} {
global CpB Sequences ListeDesAcidesAmines DistBlosum

set Lseqs [set CpB($grp)]
set nseqs [llength $Lseqs]
set Ltot $CpB(Ltot)
set ListeAA $ListeDesAcidesAmines
set Lpil [set CpB($grp,Lpil)]

# distance matrix between residue vectors
InitTBlosum gon250 1

# Inits
for {set i 0} {$i < $Ltot} {incr i} {
set CpB(ntot,$i) 0
set p [lindex $Lpil $i]
set n [string length [string map [list "." ""] $p]]
set CpB(ns,$i) $n
}
foreach n $Lseqs {
set s [set Sequences($n)]
set start [expr {[string length $s] - [string length [string trimleft $s "."]]}]
set stop  [string length [string trimright $s "."]]
for {set i $start} {$i <= $stop} {incr i} {
incr CpB(ntot,$i)
}
set CpB(startstop,$n) [list $start $stop]
}

for {set i 0} {$i < $Ltot} {incr i} {
set pori [lindex $Lpil $i]
set p [string map [list X "" Z "" "." "" " " ""] $pori]
if {[set ntot [string length $p]] < 2} {
set ColScore($i) 0.0

continue
}

set d 0.0 ; set j 0
foreach a [lrange $ListeAA 0 end-1] {
incr j
set n [expr {[string length $p] - [string length [string map [list $a ""] $p]]}]
if {! $n} {continue}

foreach b [lrange $ListeAA $j end] {
set m [expr {[string length $p] - [string length [string map [list $b ""] $p]]}]
if {! $m} {continue}

set d [expr {$d+($n*$m)*[set DistBlosum($a,$b)]}]
}
}

set d [expr {$d/double(($ntot*($ntot-1)/2.))}]
set dist [expr {exp(-1.*$d/2.)*100.}]

# Standardise scores
set ntot [set CpB(ntot,$i)]
set ns   [set CpB(ns,$i)]
set ColScore($i) [expr {$dist*exp(-10.0*($ntot-$ns)/$ntot)}]
}

for {set i 0} {$i < $Ltot} {incr i} {
set winscore($i) 0.0
}

set half_win [expr {$score_win / 2}]
if {$half_win == 0} {set half_win 1}
for {set i 0} {$i < ($half_win+1) && $i < $Ltot} {incr i} {
for {set j 0} {$j < $half_win} {incr j} {
set ij [expr {$i+$j}]
set winscore($i) [expr {[set winscore($i)] + [set ColScore($ij)]}]
}
set winscore($i) [expr {[set winscore($i)]/$score_win}]
if {[set winscore($i)] > 100} {
set winscore($i) 100
}
if {[set CpB(ns,$i)] < [set CpB(ntot,$i)]/2.0} {
set winscore($i) 0.0
}
}

for {set i 0} {($i+$score_win) < $Ltot} {incr i} {
set ih [expr {$i+$half_win}]
for {set j 0} {$j < $score_win} {incr j} {
set ij [expr {$i+$j}]
set winscore($ih) [expr {[set winscore($ih)] + [set ColScore($ij)]}]
}
set winscore($ih) [expr {[set winscore($ih)]/$score_win}]
if {[set winscore($ih)] > 100} {
set winscore($ih) 100
}
if {[set CpB(ns,$ih)] < [set CpB(ntot,$ih)]/2.0} {
set winscore($ih) 0.0
}
}

for {set i [expr {$Ltot-$score_win}]} {($i+$half_win) < $Ltot} {incr i} {
set ih [expr {$i+$half_win}]
for {set j 0} {$j < $half_win} {incr j} {
set ij [expr {$i+$j}]
set winscore($ih) [expr {[set winscore($ih)] + [set ColScore($ij)]}]
}
set winscore($ih) [expr {[set winscore($ih)]/$score_win}]
if {[set winscore($ih)] > 100} {
set winscore($ih) 100
}
if {[set CpB(ns,$ih)] < [set CpB(ntot,$ih)]/2.0} {
set winscore($ih) 0
}
}

if {$grp eq "GroupeToutLeMonde" && $conserved > 1.0} {
for {set i 0} {$i < $Ltot} {incr i} {
if {[set CpB(ns,$i)] < $nseqs*($conserved - 1.0)} {
set winscore($i) 0
}
}
} elseif {$conserved > 0.} {
for {set i 0} {$i < $Ltot} {incr i} {
if {$grp eq "GroupeToutLeMonde"} {
if {[set CpB(ns,$i)] < [set CpB(ntot,$i)]*$conserved} {
set winscore($i) 0
}
} else {
if {[set CpB(ns,$i)] != 0 && ([set CpB(ns,$i)] < [set CpB(ntot,$i)]*$conserved || [set CpB(ntot,$i)] < $nseqs*$conserved)} {
set winscore($i) 0
}
}
}
}

foreach k [lsort -integer [array names winscore]] {
puts "ITEM $k [set winscore($k)]"
}

return [array get winscore]
}


proc calc_normd_for_subgroup {grp score_win conserved} {
global CpB DistBlosum Sequences ListeDesAcidesAmines

puts "conserved $conserved"
set Lseqs [set CpB($grp)]
set nseqs [llength $Lseqs]
set Ltot  $CpB(Ltot)
set Lpil  [set CpB($grp,Lpil)]
set ListeAA $ListeDesAcidesAmines

# distance matrix between residue vectors
InitTBlosum gon250

# Inits
for {set i 0} {$i < $Ltot} {incr i} {
set p [lindex $Lpil $i]
set n [string length [string map [list "." ""] $p]]
set CpB(ns,$i) $n
set CpB(ntot,$i) 0
}
foreach n $Lseqs {
set s [set Sequences($n)]
set start [expr {[string length $s] - [string length [string trimleft $s "."]]}]
set stop  [expr {[string length [string trimright $s "."]]-1}]
for {set i $start} {$i <= $stop} {incr i} {
incr CpB(ntot,$i)
}
set CpB(startstop,$n) [list $start $stop]
}

for {set i 0} {$i < $Ltot} {incr i} {
set pori [lindex $Lpil $i]
set p [string map [list X "" Z "" "." "" " " ""] $pori]
set nres [string length $p]
if {[set CpB(ntot,$i)] < 1} {
set ColScore($i) 0.0

continue
}

set d 0.0 ; set j 0
foreach a [lrange $ListeAA 0 end-1] {
incr j
set n [expr {[string length $p] - [string length [string map [list $a ""] $p]]}]
if {! $n} {continue}

foreach b [lrange $ListeAA $j end] {
set m [expr {[string length $p] - [string length [string map [list $b ""] $p]]}]
if {! $m} {continue}

set d [expr {$d+($n*$m)*[set DistBlosum($a,$b)]}]
}
}

set nbr [expr {double($nres)*($nres-1)/2.}]
if {$nbr > 0.0} {
set d [expr {$d/$nbr}]
}
set ColScore($i) [expr {exp(-1.*$d/2.)*100.}]
if {$conserved > 0.0} {
set ntot [set CpB(ntot,$i)]
set ns   [set CpB(ns,$i)]
# standardise scores
if {$ns > 0} {
set ColScore($i) [expr {[set ColScore($i)]*exp(-10.0*($ntot-$ns)/$ntot)}]
} else {
set ColScore($i) 0.0
}
}
}

for {set i 0} {$i < $Ltot} {incr i} {
set ColScore($i) [expr {int([set ColScore($i)])}]
}

for {set i 0} {$i < $Ltot} {incr i} {
set winscore($i) 0.0
}
set half_win [expr {$score_win / 2}]
if {$half_win == 0} {set half_win 1}
for {set i 0} {$i < ($half_win+1) && $i < $Ltot} {incr i} {
for {set j 0} {$j < $score_win} {incr j} {
set ij [expr {$i+$j}]
set winscore($i) [expr {[set winscore($i)] + [set ColScore($ij)]}]
}
set winscore($i) [expr {[set winscore($i)]/$score_win}]
if {[set winscore($i)] > 100} {
set winscore($i) 100.0
}
if {[set CpB(ns,$i)] < 1} {
set winscore($i) 0.0
}
}

for {set i 0} {($i+$score_win) < $Ltot} {incr i} {
set ih [expr {$i+$half_win}]
for {set j 0} {$j < $score_win} {incr j} {
set ij [expr {$i+$j}]
set winscore($ih) [expr {[set winscore($ih)] + [set ColScore($ij)]}]
}
set winscore($ih) [expr {[set winscore($ih)]/$score_win}]
if {[set winscore($ih)] > 100} {
set winscore($ih) 100.0
}
if {[set CpB(ns,$ih)] < 1} {
set winscore($ih) 0.0
}
}

for {set i [expr {$Ltot-$score_win}]} {($i+$half_win) < $Ltot} {incr i} {
set ih [expr {$i+$half_win}]
for {set j 0} {$j < $half_win} {incr j} {
set ij [expr {$i+$j}]
set winscore($ih) [expr {[set winscore($ih)] + [set ColScore($ij)]}]
}
set winscore($ih) [expr {[set winscore($ih)]/$score_win}]
if {[set winscore($ih)] > 100} {
set winscore($ih) 100.0
}
if {[set CpB(ns,$ih)] < 1} {
set winscore($ih) 0
}
}

if {$conserved > 0.0} {
for {set i 0} {$i < $Ltot} {incr i} {
if {[set CpB(ns,$i)] != 0 && ([set CpB(ns,$i)] < [set CpB(ntot,$i)]*$conserved || [set CpB(ntot,$i)] < $nseqs*$conserved)} {
set winscore($i) 0.0
}
}
}

return [array get winscore]
}


proc Profile1DuBlock {grp block aMatrix meanpcid} {
upvar $aMatrix mat
global CpB TDesSeqWeights

set Lseqs [set CpB($grp)]
lassign $block deb fin
set sum 0.0
foreach n $Lseqs {
lassign [set CpB(startstop,$n)] first last
if {$first > $fin || $last < $deb} {
set frag($n) 1
} else {
set frag($n) 0
set sum [expr {$sum + [set TDesSeqWeights($n)]}]
}
}
if {$sum <= 0.0} {
return [list]
}

puts "SumWgt $sum"
set i 0
foreach n $Lseqs {
set wgt($n) [expr {100.*[set TDesSeqWeights($n)]/$sum}]
if {$grp eq "Group1"} {
puts "wgt $i [set wgt($n)]"
}
incr i
}

set Lprf [list]
set Laa [split [set mat(laa)] ""]
foreach p [lrange [set CpB($grp,Lpil)] $deb $fin] {
set Lcol [list]
set Lp   [split $p ""]
foreach a $Laa {
set Li [lsearch -all $Lp $a]
set s 0.0
foreach i $Li {
set n [lindex $Lseqs $i]
if {! $frag($n)} {
set s [expr {$s + [set wgt($n)]}]
}
}
lappend Lcol $s
}
lappend Lprf $Lcol
}

# debug
foreach p [lrange [set CpB($grp,Lpil)] $deb $fin] col $Lprf {
puts "$p"
puts "[join $col \n]"
}

set Prf1 [list]
set i 0
foreach col $Lprf {
puts "l= $i"
set res [list]
foreach a $Laa {
set f 0.0
foreach b $Laa v $col {
set f [expr {$f + $v*[set mat($a,$b)]}]
}
lappend res [expr {int($f/$meanpcid)}]
puts "  a $a [expr {int($f/$meanpcid)}]"
}
lappend Prf1 $res
}

return $Prf1
}


proc Profile2DuBlock {grp b Laa} {
global CpB TDesSeqWeights

set Lseqs [set CpB($grp)]
lassign $b deb fin

set sum 0.0
foreach n $Lseqs {
lassign [set CpB(startstop,$n)] first last
if {$first > $deb || $last < $fin} {
set frag($n) 1
} else {
set frag($n) 0
set sum [expr {$sum + [set TDesSeqWeights($n)]}]
}
}
if {$sum <= 0.0} {
return [list]
}

foreach n $Lseqs {
if {! $frag($n)} {
set wgt($n) [expr {100*[set TDesSeqWeights($n)]/$sum}]
}
}

set Lprf [list]
set Laa [split $Laa ""]
foreach p [lrange [set CpB($grp,Lpil)] $deb $fin] {
set Lp   [split $p ""]
set Lcol [list]
foreach a $Laa {
set sum 0.0
set Li [lsearch -all $Lp $a]
foreach i $Li {
set n [lindex $Lseqs $i]
if {! $frag($n)} {
set sum [expr {$sum + [set wgt($n)]}]
}
}
lappend Lcol [expr {10.*$sum}]
}
lappend Lprf $Lcol
}

return $Lprf
}


proc BlockOverlap {f1 l1 f2 l2} {
set len [expr {min($l1,$l2)-max($f1,$f2)+1}]

return $len
}


proc ScoreSequence {seq Lprf deb fin} {
set Laa [split "ABCDEFGHIKLMNPQRSTVWXYZ" ""]
set score 0.0
for {set i $deb} {$i < $fin} {incr i} {
set prf [lindex $Lprf $i-$deb]
if {[set c [string index $seq $i]] ne "."} {
set k [lsearch $Laa $c]
set score [expr {$score+[lindex $prf $k]}]
puts "   $c [lindex $prf $k] $score"
}
}

set l [expr {$fin-$deb}]
if {$l == 0} {
set score 0
} else {
set score [expr {$score/$l}]
}

return $score
}


proc ScoreBlockVsBlock {s1 s2 Lp1 Lp2} {

if {$Lp1 == {} || $Lp2 == {}} {
return 0
}
if {$s1 > $s2} {
set offset1 0
set offset2 [expr {$s1-$s2}]
} elseif {$s2 > $s1} {
set offset2 0
set offset1 [expr {$s2 - $s1}]
} else {
set offset1 0
set offset2 0
}
set len [expr {min(([llength $Lp1]-$offset1),([llength $Lp2]-$offset2))}]

set score 0.0
for {set i 0 ; set i1 $offset1 ; set i2 $offset2} {$i < $len} {incr i ; incr i1 ; incr i2} {
set s 0.0
foreach v [lindex $Lp1 $i1] w [lindex $Lp2 $i2] {
set s [expr {$s + $v*$w}]
}
set score [expr {$score + $s/1000.}]
}

if {$len > 0} {
set score [expr {double($score)/$len}]
} else {
set score 0.0
}

return $score
}


proc CreeLesPiliersPourBlocks {Ln} {
global Sequences LongueurTotale

set Ls {}
foreach NSeq $Ln {
lappend Ls [split [set Sequences($NSeq)] ""]
}
set Lpil [list]
for {set i 0} {$i < $LongueurTotale} {incr i} {
lappend Lpil [list [join [ExtraitListeDeListe $Ls $i] ""]]
}

return $Lpil
}


proc OrphanSeqs {} {
global CpB CBPCI

# search last cluster index
set iGrp -9999
foreach g $CpB(LNDG) {
if {[regexp {Group[0-9]+} $g]} {
set i [string range $g 5 end]
if {$i > $iGrp} {set iGrp $i}
}
}
incr iGrp
puts "iGrp $iGrp"

set Lorph [list]
# remove groups containing only one sequence
set ig 1
set Lig [list]
foreach g [lrange $CpB(LNDG) 1 end] {
if {[llength [set CpB($g)]] == 1} {
lappend Lorph [set CpB($g)]
lappend Lig $ig
unset CpB($g)
}
incr ig
}
if {$Lig != {} } {
set Lig [lsort -integer -decreasing $Lig]
foreach i $Lig {
set CpB(LNDG) [lreplace $CpB(LNDG) $i $i]
}
}

# check if seq %id < 30% in average with the group
puts "DEBITEM makeorphan"
foreach g [lrange $CpB(LNDG) 1 end] {
set Li [list]
foreach n1 [set CpB($g)] {
set mean 0.0
set nseq 0
foreach n2 [set CpB($g)] {
if {$n1 ne $n2} {
set pc [set CBPCI($n1,$n2)]
set mean [expr {$mean+$pc}]
incr nseq
}
}
set mean [expr {$mean/double($nseq)}]
if {$mean < 0.3} {
puts "ITEM orphan [format %8.6f $mean] $n1 [string range $g 5 end]"
lappend Lorph $n1
lappend Li [lsearch [set CpB($g)] $n1]
}
}
if {$Li != {} } {
set Li [lsort -integer -decreasing $Li]
foreach i $Li {
set CpB($g) [lreplace [set CpB($g)] $i $i]
}
}
}

# Start again, trying to assign orphan to a group
# (the Unclustered secator group is here a normal
# group, so sequences are taken as normal orphan)
set Li [list]
set i -1
puts "DEBITEM adding"
foreach orph $Lorph {
puts "testorph $orph"
incr i
if {$i in $Li} {
continue
}

set maxid -999.
foreach g [lrange $CpB(LNDG) 1 end] {
set nseq [llength [set CpB($g)]]
if {$nseq < 2} {continue}

set mean 0.0
foreach n1 [set CpB($g)] {
set pc [set CBPCI($orph,$n1)]
set mean [expr {$mean+$pc}]
}
puts -nonewline "tg $g [format %10.6f $mean] $nseq"
set mean [expr {$mean/double($nseq)}]
puts " [format %8.6f $mean]"
if {$mean > $maxid} {
set maxid $mean
set gb $g
}
}
if {$maxid > 0.3} {
lappend CpB($gb) $orph
lappend Li $i
puts "ITEM adding $orph [string range $gb 5 end] [format %8.6f $maxid]"
} else {
set j -1
foreach orp2 $Lorph {
incr j
if {$i != $j && $j ni $Li && [set CBPCI($orph,$orp2)] > 0.3} {
lappend Li $i $j
set newg "Group$iGrp"
lappend CpB(LNDG) $newg
lappend CpB($newg) $orph $orp2
puts "grouping [set CpB($newg)] in $newg"
incr iGrp
break
}
}
}
update
}
if {$Li != {} } {
set Li [lsort -unique -integer -decreasing $Li]
foreach i $Li {
set Lorph [lreplace $Lorph $i $i]
}
}

puts "True Orphans : $Lorph"
foreach n $Lorph {
set new "Group$iGrp"
lappend CpB(LNDG) $new
set CpB($new) $n
incr iGrp
}

puts "DEBITEM ngroupsfinal"
puts "ITEM ng [expr {[llength $CpB(LNDG)]-1}]"
foreach g [lsort [lrange $CpB(LNDG) 1 end]] {
puts "DEBITEM groupesfin[string range $g 5 end]"
foreach n [set CpB($g)] {
puts "ITEM $n"
}
}

return
}


proc PCIPourBlocks {{thr 0}} {
global CpB LNOrdali LSOrdali
puts "debut PCI"
puts "DEBITEM PCI"

set Ltot $CpB(Ltot)
set i 0
set la "A" ; set lz "Z"
foreach n1 $LNOrdali s1 $LSOrdali {
incr i
if {$n1 eq ""} {continue}

set PCI($n1,$n1) 1.0
foreach n2 [lrange $LNOrdali $i end] s2 [lrange $LSOrdali $i end] {
if {$n2 eq ""} {continue}

set len 0 ; set com 0
for {set j 0} {$j < $Ltot} {incr j} {
set ca [string index $s1 $j]
set cb [string index $s2 $j]
set ala [expr {$ca >= $la && $ca <= $lz}]
set alb [expr {$cb >= $la && $cb <= $lz}]
incr len [expr {$ala || $alb}]
incr com [expr {$ala && ($ca eq $cb)}]
}
if {$len > $thr} {
set pc [expr {double($com)/double($len)}]
} else {
set pc 0.0
}
set PCI($n1,$n2) $pc
set PCI($n2,$n1) $pc
puts "ITEM $n1 $n2 [format %8.6f [set PCI($n1,$n2)]]"
puts "ITEM $n2 $n1 [format %8.6f [set PCI($n2,$n1)]]"
}
}

puts "fin PCI"

return [array get PCI]
}


proc LesFeuillesDuSousArbre {t n} {
set nf 0
foreach c [$t children -all $n] {
incr nf [$t isleaf $c]
}

return $nf
}


proc SeqErrors {} {
global CpB Sequences

array set Matrix [InitClustalMatrix gon250]

set window 8
set conserved 0.5
set minlength 6
foreach g [lrange [set CpB(LNDG)] 1 end] {
set nseqs [llength [set CpB($g)]]
if {$nseqs < 2} {continue}

if {$nseqs < 10} {
set block_cutoff 15
} else {
set block_cutoff 10
}

unset -nocomplain CpB(Blocks,$g)
unset -nocomplain CpB($g,Lprf1)
get_blocks $g $block_cutoff $window $conserved $minlength
puts "DEBITEM SQEB[string range $g 5 end]"
set Lprf1 [list]
foreach b [set CpB(Blocks,$g)] {
lassign $b d f
puts "ITEM $d $f"
lappend Lprf1 [Profile1DuBlock $g $b Matrix 1.0]
}
set CpB($g,Lprf1) $Lprf1
}

set cut 0.75
foreach g1 [lrange $CpB(LNDG) 1 end] {
puts "length $g1 [llength [set CpB($g1)]]"
puts "DEBITEM SQE[string range $g1 5 end]"
foreach n [set CpB($g1)] {
puts "ITEM $n"
}

if {[llength [set CpB($g1)]] < 2} {continue}

set LscoTh [list]
set LscoSq [list]
set ib 0
foreach b [set CpB(Blocks,$g1)] p1 [set CpB($g1,Lprf1)] {
lassign $b deb fin
set scoSq [list]
set scoTh [list]
set in 0 ; set Li [list]
foreach n [set CpB($g1)] {
lassign [set CpB(startstop,$n)] f l
set seq [set Sequences($n)]
if {$f < $deb && $l > $fin} {
set score [ScoreSequence $seq $p1 $deb $fin]
lappend scoSq $score
lappend Li $in
puts "deberr [string range $g1 5 end] $ib [expr {int($score)}]"
puts "SEQERRO $n [string range $g1 5 end] $deb $fin $score"
} else {
lappend scoSq 0.0
}
incr in
}

if {$Li != {}} {
set lmed [list]
foreach v $Li {
lappend lmed [lindex $scoSq $v]
}
if {$g1 eq "Group1"} {
puts "MedScore [llength $lmed] $deb $fin"
}
lappend scoTh [ScoreMediane $lmed]
if {$g1 eq "Group1"} {
#puts "   [ScoreMediane $lmed]"
}
} else {
lappend scoTh 0
}
lappend LscoSq $scoSq
lappend LscoTh $scoTh
incr ib
}

foreach b [set CpB(Blocks,$g1)] s $LscoTh lsn $LscoSq {
lassign $b deb fin
foreach n [set CpB($g1)] ns $lsn {
lassign [set CpB(startstop,$n)] f l
if {$f < $deb && $l > $fin} {
if {$s > 0.0 && ($ns/$s) < $cut} {
lappend seqerr($n) 2
} else {
lappend seqerr($n) 0
}
} else {
lappend seqerr($n) 0
}
}
}

foreach n [set CpB($g1)] {
set SeqErr($n) [list]
set in_err 0
set ol -1
foreach b [set CpB(Blocks,$g1)] sc [set seqerr($n)] {
lassign $b fc lc
if {! $in_err} {
if {$sc > 1} {
if {$ol == -1} {
set s2 0
} else {
set s2 $ol
}
set s1 $lc
set in_err 1
}
} else {
if {$sc <= 1} {
set e  $fc
set e1 $ol
set in_err 0
set derr [expr {$s2+2}]
set ferr [expr {$e-1}]
puts "SEQ_ERROR $n $derr $ferr"
lappend SeqErr($n) [list $derr $ferr [DonnePosGS $n $derr] [DonnePosGS $n $ferr]]
}
}
set ob $b
lassign $ob of ol
}
if {$in_err} {
set e [expr {$CpB(Ltot)-1}]
set e1 $ol

set derr [expr {$s2+2}]
set ferr [expr {$e-1}]
puts "SEQ_ERROR $n $derr $ferr"
lappend SeqErr($n) [list $derr $ferr [DonnePosGS $n $derr] [DonnePosGS $n $ferr]]
set in_err 0
}
}
}

return
}


proc ScoreMediane {l} {

set l [lsort -real -decreasing $l]
set n [llength $l]
set t [expr {0.5 + $n/4.}]
set it [expr {int($t)}]
set itm1 [expr {$it-1}]
set nend [expr {$n-1}]
puts "   t= $t it= $it itm1= $itm1 nend= $nend"
if {($t - $it) == 0.5} {
set q3 [expr {([lindex $l $it] + [lindex $l $it+1])/2.}]
set q1 [expr {([lindex $l $nend-$it] + [lindex $l $nend-$itm1])/2.}]
} elseif {($t - $it) > 0.5} {
set q3 [lindex $l $it+1]
set q1 [lindex $l $nend-$itm1]
} else {
set q3 [lindex $l $it]
set q1 [lindex $l $nend-$it]
}

puts "q1= $q1 q3= $q3"

if {$n < 4} {
set ul [lindex $l 0]
set ll [lindex $l end]
} else {
set ul [expr {$q3 + ($q3-$q1)/2.}]
set ll [expr {$q1 - ($q3-$q1)}]
}

puts "   $ll"

return $ll
}


proc PropagateFeatures {} {
global TPCICB

foreach g $CpB(LNDG) {
foreach b [set CpB(LcBck,$g)] {
lassign $b db fb code
foreach n [set CpB($g)] {
set found 0
foreach err [set SeqErr($n)] {
lassign $err dg fg ds fs
if {[BlockOverlap $db $fb $dg $fg] >=1} {
set found 1
break
}
}
if {! $found} {
if {$fb > $db} {
AddNewFeatEntry $n $db $fb $code BLOCK LBLOCK 0.0
}
}
}
}
}

# Traite chared blocks
set n 0
foreach shb $CpB(ShBck) {
lassign $shb g1 g2 db fb score
set found 0
for {set j 0} {$j < $n} {incr j}  {
set found1 0 ; set found2 0
set ccb [lindex $CpB(CcBck) $j]
lassign $ccb Lgs dcc fcc cccode
if {[BlockOverlap $db $fb $dcc $fcc] >= 4} {
set s [expr {max($db,$dcc)}]
set e [expr {min($fb,$fcc)}]
if {$g1 in $Lgs} {
set g $g2
set found1 1
set found 1
}
if {$g2 in $Lgs} {
set g $g1
set found2 1
set found 1
}
if {($found1 && ! $found2) || ($found2 && ! $found1)} {
if {[set len [BlockOverlap $db $fb $dcc $fcc]] >= 4} {
if {($s - $dcc) > 5} {
puts "need ccblock $dcc $s"
lset ccb 2 $s
lappend CpB(CcBck) $ccb
incr n
}
set dcc $s
if {($fcc-$e) > 5} {
puts "need ccblock $e $dcc"
lset ccb 1 $e
lappend CpB(CcBck) $ccb
incr n
}
set fcc $e
if {$g eq $g1} {
set sco $score
} else {
set sco $score
}
lappend Lgs $g $sco
lset ccb 0 $Lgs
lset CpB(CcBck) $j $ccb
} else {
lassign $shb g1 g2 db fb score
lappend CpB(CcBck) [list [list $g1 $score $g2 $score] $db $fb $code]
puts "new block $code $db $fb $g1 $g2"
incr n
set found 0
}
update
}
}
}
if {! $found} {
lassign $shb g1 g2 db fb score
lappend CpB(CcBck) [list [list $g1 $score $g2 $score] $db $fb $code]
puts "new block $code $db $fb $g1 $g2"
incr n
}
update
}

set i 0
foreach cc $CpB(CcBck) {
lset CpB(CcBck) $i 3 $i
incr i
}

foreach ccb $CpB(CcBck) {
lassign $ccb Lgs dcc fcc ccode
foreach {gc sc} $Lgs {
foreach n [set CpB($gc)] {
set found 0
foreach sqe [set SeqErr($n)] {
lassign $sqe de fe dr fr
if {[BlockOverlap $dcc $fcc $de $fe] >= 1} {
set found 1
break
}
}
if {! $found} {
if {$fcc > $dcc} {
AddNewFeatEntry $n $dcc $fcc  $ccode BLOCK SBLOCK $sc
}
}
}
}
}

foreach g [lrange $CpB(LNDG) 1 end] {
foreach n [set CpB($g)] {
foreach ccb $CpB(CcBck) {
lassign $ccb Lgs dcc fcc ccode
if {$g in $Lgs} {
continue
}

set found 0
foreach {gc sc} $Lgs {
foreach ns [set CpB($gc)] {
set pci [PCISegment $n $ns $dcc $fcc]
if {$pci > 90} {
AddNewFeatEntry $n $dcc $fcc $ccode BLOCK SBLOCK [expr {int($sc/10000.0)}]
puts "addnew block $n [string range $gc 5 end] $dcc $fcc $pci"
set found 1
break
}
if {$found} {break}
}
}
}
}
}

# features SEQERR
foreach n [array names SeqErr] {
foreach sqe [set SeqErr($n)] {
lassign $sqe dg fg ds fs
AddNewFeatEntry $n $dg $fg 0 SEQERR SEQERR 0.0
}
}

# Calcule PCI sans gaps
foreach n $::LNOrdali s $::LSOrdali {
if {$n eq ""} {continue}
lappend LNom $n
lappend LSeq $s
}
set Lpci [Ccode_Pairwise2 $LSeq]
set i 0
foreach n1 $LNom {
foreach n2 $LNom {
set TPCICB($n1,$n2) [lindex $Lpci $i]
incr i
}
}

# propagate the feature within a group,
# if 2 sequences are >40% identical in the domain
# or local core blocks exist */
foreach g [lrange $CpB(LNDG) 1 end] {
if {[llength [set CpB($g)]] <= 1} {
continue
}
foreach n [set CpB($g)] {
PropagateFeattWithinGroup $n $g
}
}

# also propagate the feature if shared core
# blocks are found between 2 groups
foreach g [lrange $CpB(LNDG) 1 end] {
if {[llength [set CpB($g)]] < 1} {continue}
foreach n [set CpB($g)] {
PropagateFeattBetweenGroup $n $g
}
}

# final check
foreach n1 $CpB(GroupeToutLeMonde) {
foreach n2 $CpB(GroupeToutLeMonde) {
if {$n1 eq $n2} {continue}
}
}

return
}


proc AddNewFeatEntry {n db fb code name note score} {
global CpB

lassign [set CpB(startstop,$n)] start stop

if {$fb < $db} {return}
if {$fb < $start || $db > $stop} {return}
if {$db < $start} {set db $start}
if {$fb > $stop} {set fb $stop}

set dr [DonnePosGS $n $db]
set fr [DonnePosGS $n $fb]

switch $name {
"BLOCK" {
if($fr - $dr<4) return;
if {$note eq "SBLOCK"} {
set color $code
} elseif {note eq "LBLOCK"} {
set color 12
}
}
"REGION" {
set color 10
}
"SEQERR" {
set color 3
}
"ANCHOR" {
set color $code
}
"REPEAT" {
set color $code
}
"STRUCT" {
switch $note {
"PRED_HELIX" {set color VLRED}
"PRED_STRAND" {set color VLGREEN}
"PROP_HELIX" {set color LRED}
"PROP_STRAND" {set color LGREEN}
"HELIX" {set color RED}
"STRAND" {set color GREEN}
}
}
"TRANSMEM" {
if {[regexp {^PRED\_} $note]} {
set note "$note_$score"
set color 10
} elseif {[regexp {^PROP\_} $note]} {
,set color GRAY
} else {
set color 1
}
}
"COIL" -
"LOWCOMP" {
if {[regexp {^PRED\_} $note]} {
set color LGRAY
} elseif {[regexp {^PROP\_} $note]} {
set color GRAY
} else {
set color 6
}
}
"DOMAIN" {
switch -regexp $note {
{^PRED\_} {set color LGRAY}
{^PROP\_} {set color GRAY}
{^DNA\_BIND} {set color 2}
{^ZN_FING} {set color 3}
default {set color 1}
}
}
"PFAM-A" -
"PFAM-B" -
"PROSITE" -
"ELM" -
"DISORDER" {
if {[regexp {^PRED\_} $note]} {
set color LGRAY
} elseif {[regexp {^PROP\_} $note]} {
set color GRAY
} else {
set color $code
}
}
"SIGNAL" {
switch -regexp {
{^PRED\_} {
set note "$note_$score"
set color LGRAY
}
{PROP\_} {set color GRAY}
"NUCLEAR" {set color 1}
"CHLOROPLAST" {set color 2}
"MITOCHONDRION" {set color 3}
"MICROBODY" {set color 4}
default {set color 5}
}
}
"VARSPLIC" {
if {[regexp {^PRED\_} $note]} {
set color LGRAY
} elseif {[regexp {^PROP\_} $note]} {
set color GRAY
} else {
set color 5
}
}
"MOD_RES" {
set color 0
switch $note {
"PRED_" {set color LGRAY}
"PROP_" {set color GRAY}
"ACETYLATION" {set color 1}
"ALKYLATION" {set color 2}
"HYDROXYLATION" {set color 3}
"METHYLATION" {set color 4}
"PHOSPHORYLATION" {set color 5}
"SULFATION" {set color 6}
"PYRROLIDONE" {set color 7}
"MYRISTATE" {set color 8}
"PALMITATE" {set color 9}
"FARNESYL" {set color 10}
"GERANYL" {set color 11}
"GPI-ANCHOR" {set set color 12}
"N-ACYL" {set color 13}
}
}
"SITE" {
set color 0
switch -regexp $note {
{^PRED\_} {set color LGRAY}
{^PROP\_} {set color GRAY}
"SITE" {set color 0}
"ACT_SITE" {set color 1}
"CARBOHYD" {set color 2}
"DISULFID" {set color 3}
"BINDING" {set color 4}
"NP_BIND" {set color 5}
"CA_BIND" {set color 6}
"TRANSIT" {set color 7}
"LIPID" {set color 8}
"METAL" {set color 9}
}
}
}


lappend CpB(tb,$n) [list ftype $name fstart $start fstop $stop fcolor $color fscore $score fnote $note]

return
}


proc PCISegment {n1 n2 d f} {
set s1 [set ::Sequences($n1)]
set s2 [set ::Sequences($n1)]
set total 0 ; set count 0
for {set i $d} {$i < $f} {incr i} {
if {([set c1 [string index $s1 $i]] ne ".") && ([set c2 [string index $s2 $i]] ne ".")} {
incr total
incr count [expr {$c1 eq $c2}]
}
}

if {$total == 0} {
set score 0.0
} else {
set score [expr {100.0*$count/$total}]
}

return $score
}


proc PropagateFeatWithinGroup {n g } {
global CpB

foreach ft [set CpB(tb,$n)] {
set name [lindex $ft 1]
if {$name ni [list SWDOMAIN SIGNAL REPEAT STRUCT PFAM-A PFAM-B PROSITE SITE MODRES]} {
continue
}
set note [lindex $ft end]
if {[regexp {^PRED\_|^WARN\_|^ERROR\_|^PROP\_} $note]} {continue}

set d [lindex $ft 3]
set f [lindex $ft 5]
set dr [DonnePosGS $n $d]
set fr [DonnePosGS $n $f]
set len [expr {$fr-$dr+1}]
if {$len <= 3} {
PropaSiteWithinGroup $n $g $ft $d $f
} elseif {$len <= 15} {
PropaShortWithinGroup $n $g $ft $d $f
} else {
PropaDomainWithinGroup $n $g $ft $d $f
}
}

return
}


proc PropaSiteWithinGroup {n g ft df ff} {
global CpB

set nft [lindex $ft 1]
set dft [lindex $ft 3]
set fft [lindex $ft 5]
lassign [set CpB(startstop,$n)] deb fin
set found 0
foreach b $CpB(LcBck) {
lassign $b db fb code
if {[BlockOverlap $db $fb $df $ff] >= 1} {
set found 1
break
}
}
if {! $found} {
foreach bcc $CpB(CcBck) {
lassign $bcc Lgs dcc fcc ccode
if {$g in $Lgs} {
if {[BlockOverlap $dcc $fcc $df $ff] >= 0} {
set found 1
break
}
}
if {$found} {break}
}
}

# propagate short residue sites only if
# the residue is identical */
foreach sq [set CpB($g)] {
if {$found || $TPCICB($sq,$n) > 80.} {
if {$sq ne $n} {
if {$nft eq "STRUCT"} {
PropagateFeat $sq $ft
} else {
# if site to be propagated is on
# n/c-ter and does not match
# n/c-ter in new sequence,
# continue
lassign [set CpB(startstop,$sq)] dsq fsq
if {($dft == $deb && $dft != $dsq) || ($fft == $fin && $fsq != $fin)} {continue}
set found [CheckSiteFeat $n $sq $ft]
if {$found} {
PropagateFeat $sq $ft
}
}
}
}
}

return
}


proc PropaShortWithinGroup {n g ft df ff} {
global CpB Sequences

set pccover 0
foreach b $CpB(LcBck) {
lassign $b db fb code
if {[set lg [BlockOverlap $db $fb $df $ff]] >= 0} {
incr pccover $lg
}
}
foreach ccb $CpB(CcBck) {
if {$g in [lindex $ccb 0]} {
lassign $ccb Lgs dcc fcc ccode
if {[set lg [BlockOverlap $dcc $fcc $df $ff]] >= 0} {
incr pccover $lg
}
}
}
set pccover [expr {100.*$pccover/($ff - $df + 1)}]
set seq1 [set Sequences($n)]
foreach sq [set CpB($g)] {
if {$n eq $sq} {continue}
# propagate if more than 90% of domain is in
# local core blocks, or 2 sequences share
# more than 40% identity */
set l 0 ; set nbr 0
for {set i $df} {$i <= $ff} {incr i} {
if {[set c [string index $seq1 $i]] ne "."} {
incr n
if {$c eq [string index [set Sequences($sq)] $i]} {
incr l
}
}
set l [expr {100.*$l/$n}]
if {$pccover > 70. || [set TPCICB($n,$sq)] > 80 || $l > 50} {
switch $type {
"SITE" {
set found [CheckSiteFeat $n $sq $ft]
if {$found} {
PropagateFeat $sq $ft
}
}
"STRUCT" {
if {$l > 30} {
PropagateFeat $sq $ft
}
}
"PFAM-A" -
"PFAM-B" -
"DOMAIN" -
"PROSITE" {
if {$l > 20} {
PropagateFeat $sq $ft
}
}
default {
if {$l > 40} {
PropagateFeat $sq $ft
}
}
}
}
}
}

return
}


proc PropaDomainWithinGroup {n g ft df ff} {
global CpB Sequences

set pccover 0
foreach b $CpB(LcBck) {
lassign $b db fb code
if {[set lg [BlockOverlap $db $fb $df $ff]] >= 0} {
incr pccover $lg
}
}
foreach ccb $CpB(CcBck) {
if {$g in [lindex $ccb 0]} {
lassign $ccb Lgs dcc fcc ccode
if {[set lg [BlockOverlap $dcc $fcc $df $ff]] >= 0} {
incr pccover $lg
}
}
}
set pccover [expr {100.*$pccover/($ff - $df + 1)}]
set seq1 [set Sequences($n)]
foreach sq [set CpB($g)] {
if {$n eq $sq} {continue}
# propagate if more than 40% of domain is in
# local core blocks, or 2 sequences share
# more than 40% identity */
set l 0 ; set nbr 0
for {set i $df} {$i <= $ff} {incr i} {
if {[set c [string index $seq1 $i]] ne "."} {
incr n
if {$c eq [string index [set Sequences($sq)] $i]} {
incr l
}
}
set l [expr {100.*$l/$n}]
if {($pccover > 40. && $l > 20) || [set TPCICB($n,$sq)] > 80 || $l > 50} {
switch $type {
"PROSITE" {
puts "$n $sq $note $pccover [set TPCICB($n,$sq)] $l"
if {$l > 30} {
PropagateFeat $sq $ft
}
}
"SITE" {
set found [CheckSiteFeat $n $sq $ft]
if {$found} {
PropagateFeat $sq $ft
}
}
"STRUCT" {
if {$l > 30} {
PropagateFeat $sq $ft
}
}
"PFAM-A" -
"PFAM-B" -
"DOMAIN" {
if {$l > 20} {
PropagateFeat $sq $ft
}
}
default {
if {$l > 40} {
PropagateFeat $sq $ft
}
}
}
}
}
}

return
}


proc PropagateFeatBetweenSimilarSeq {n g} {



return
}


proc PropagateFeatBetweenGroup {n g} {
global CpB

foreach ft [set CpB(tb,$n)] {
set name [lindex $ft 1]
if {$name ni [list SWDOMAIN SIGNAL REPEAT STRUCT PFAM-A PFAM-B PROSITE SITE MODRES]} {
continue
}
set note [lindex $ft end]
if {[regexp {^PRED\_|^WARN\_|^ERROR\_|^PROP\_} $note]} {continue}

set d [lindex $ft 3]
set f [lindex $ft 5]
set dr [DonnePosGS $n $d]
set fr [DonnePosGS $n $f]
set len [expr {$fr-$dr+1}]
if {$len <= 3} {
PropaSiteBetweenGroups $n $g $ft $d $f
} elseif {$len <= 15} {
PropaShortBetweenGroups $n $g $ft $d $f
} else {
PropaDomainBetweenGroups $n $g $ft $d $f
}
}

return
}


proc PropaSiteBetweenGroups {n g ft d f} {
global CpB

lassign $ft tm type tm deb tm fin tm col tm score tm note
lassign [set CpB(startstop,$n)] ds fs
set found 0
foreach ccb $CpB(CcBck) {
lassign $bcc Lgs dcc fcc ccode
if {$g in $Lgs} {
if {[BlockOverlap $dcc $fcc $df $ff] >= 0} {
set found 1
set boncc $ccb
break
}
}
if {$found} {break}
}

# propagate single residue sites only if the
# residue is identical

if {! $found} {return}

lassign $boncc Lgs dcc fcc score
foreach gr [lrange $CpB(LNDG) 1 end] {
if {$gr eq $g} {continue}
if {$gr in $Lgs} {
foreach seq [set CpB($gr)] {
if {$type eq "STRUCT"} {
PropagateFeat $seq $ft
} else {
# don't propagate sites on
# n/c-ter between groups */
if {$ds == $deb || $fs == $fin} {
continue
}
set found [CheckSiteFeat $n $seq $ft]
if {$found} {
PropagateFeat $seq $ft
}
}
}
}
}

return
}


proc PropagateShortBetweenGroups {n g ft d f} {
global CpB Sequences

set sqn [set Sequences($n)]
set nft [lindex $ft 1]
set dft [lindex $ft 3]
set fft [lindex $ft 5]
lassign [set CpB(startstop,$n)] deb fin
foreach gr [lrange $CpB(LNDG) 1 end] {
set cov($gr) 0
}
foreach ccb $CpB(CcBck) {
lassign $ccb Lgs dcc fcc cccode
if {$g ni $Lgs} {continue}
# if the conserved core block overlaps the
# domain .... */
if {[BlockOverlap $dcc $fcc $dft $fft] >=0} {
foreach gr [lrange $CpB(LNDG) 1 end] {
if {$gr in $Lgs} {
set sq0 [lindex [set CpB($gr)] 0]
set s1 [DonnePosGS $sq0 $dcc]
set e1 [DonnePosGS $sq0 $fcc]
set s2 [DonnePosGS $sq0 $dft]
set e2 [DonnePosGS $sq0 $fft]
if {[set l [BlockOverlap $s1 $e1 $s2 $e2]] >=0} {
set cov($gr) [expr {[set cov($gr)]+$l}]
}
}
}
}
}

# propagate if more than 100% of domain is in
# shared core blocks
set dr [DonnePosGS $n $dft]
set fr [DonnePosGS $n $fft]
foreach gr [lrange $CpB(LNDG) 1 end] {
if {$gr eq $g} {continue}
set pccover [expr {100.0*[set cov($gr)]/($fr-$dr+1)}]
foreach sq [set CpB($gr)] {
if {$pccover > 70 || [set TPCICB($n,$sq)] > 80} {
set sqs [set Sequences($sq)]
set l 0 ; set nb 0
for {set kk $dft} {$kk <= $fft} {incr kk} {
if {[string index $sqn $kk] ne "."} {
incr n
if {[string index $sqn $kk] eq [string index $sqs $kk]} {
incr l
}
}
}
set l [expr {$l*100.0/$n}]
if {$nft eq "SITE"} {
set found [CheckSiteFeat $n $sq $ft]
if {$found} {
PropagateFeat $sq $ft
}
} elseif {$nft eq "STRUCT"} {
PropagateFeat $sq $ft
} elseif {$nft in [list PFAM-A PFAM-B DOMAIN PROSITE]} {
if {$l > 20} {
PropagateFeat $sq $ft
}
} elseif {$l > 40} {
PropagateFeat $sq $ft
}
}
}
}

return
}


proc PropagateDomainBetweenGroups {n g ft d f} {
global CpB Sequences

set sqn [set Sequences($n)]
set nft [lindex $ft 1]
set dft [lindex $ft 3]
set fft [lindex $ft 5]
lassign [set CpB(startstop,$n)] deb fin
foreach gr [lrange $CpB(LNDG) 1 end] {
set cov($gr) 0
}
foreach ccb $CpB(CcBck) {
lassign $ccb Lgs dcc fcc cccode
if {$g ni $Lgs} {continue}
# if the conserved core block overlaps the
# domain .... */
if {[BlockOverlap $dcc $fcc $dft $fft] >=0} {
foreach gr [lrange $CpB(LNDG) 1 end] {
if {$gr in $Lgs} {
set sq0 [lindex [set CpB($gr)] 0]
set s1 [DonnePosGS $sq0 $dcc]
set e1 [DonnePosGS $sq0 $fcc]
set s2 [DonnePosGS $sq0 $dft]
set e2 [DonnePosGS $sq0 $fft]
if {[set l [BlockOverlap $s1 $e1 $s2 $e2]] >=0} {
set cov($gr) [expr {[set cov($gr)]+$l}]
}
}
}
}
}

# propagate if more than 40% of domain is in
# shared core blocks
set dr [DonnePosGS $n $dft]
set fr [DonnePosGS $n $fft]
foreach gr [lrange $CpB(LNDG) 1 end] {
if {$gr eq $g} {continue}
set pccover [expr {100.0*[set cov($gr)]/($fr-$dr+1)}]
foreach sq [set CpB($gr)] {
if {$pccover > 70 || [set TPCICB($n,$sq)] > 80} {
set sqs [set Sequences($sq)]
set l 0 ; set nb 0
for {set kk $dft} {$kk <= $fft} {incr kk} {
if {[string index $sqn $kk] ne "." || [string index $sqs $kk] ne "."} {
incr n
if {[string index $sqn $kk] eq [string index $sqs $kk]} {
incr l
}
}
}
set l [expr {$l*100.0/$n}]
if {($pccover > 40 && $l > 20) || [set TPCICB($n,$sq)] > 80 || $l > 60} {
set l 0 ; set nb 0
for {set kk $dft} {$kk <= $fft} {incr kk} {
if {[string index $sqn $kk] ne "."} {
incr n
if {[string index $sqn $kk] eq [string index $sqs $kk]} {
incr l
}
}
}
set l [expr {$l*100.0/$n}]
if {$nft eq "PROSITE"} {
if {$l > 30} {
PropagateFeat $sq $ft
}
} elseif {$nft eq "SITE"} {
set found [CheckSiteFeat $n $sq $ft]
if {$found} {
PropagateFeat $sq $ft
}
} elseif {$nft eq "STRUCT"} {
PropagateFeat $sq $ft
} elseif {$nft in [list PFAM-A PFAM-B DOMAIN]} {
if {$l > 20} {
PropagateFeat $sq $ft
}
} elseif {$l > 40} {
PropagateFeat $sq $ft
}
}
}
}
}

return
}


proc CheckSiteFeat {n1 n2 ft} {
lassign $ft tm type tm deb tm fin tm col tm score tm note
set s1 $::Sequences($n1)
set s2 $::Sequences($n2)
set r1 [string index $s1 $deb]
set r2 [string index $s2 $deb]

set ret 0
if {$type eq "MODRES"} {
regsub -all -nocase {[^a-z]} $note "" note
switch $type {
"ACETYLATION" {
if {$r1 eq $r2} {set ret 1}
}
"AMIDATION" -
"ALKYLATION" {set ret 1}
"HYDROXYLATION" {if {$r1 in [list D N P K]} {set ret 1}}
"METHYLATION" {
if {$r1 in [list K R]} {set ret 1}
}
"PHOSPHORYLATION" {
if {$r1 in [list S T Y D H]} {set ret 1}
}
"SULFATION" {
if {$r1 eq "Y"} {set ret 1}
}
"MYRISTATE" {
if {$r1 eq "K"} {set ret 1}
}
"PALMITATE" {
if {$r1 in [list C S T]} {set ret 1}
}
"FARNESYL" -
"GERANYL" -
"NACYL" {
if {$r1 eq "C"} {set ret 1}
}
}
}

if {$type eq "SITE"} {
if {$note eq "DISULFID" && $r2 eq "C" && $r2f eq "C"} {
set ret 1
}
}

# Check that the sequences are identical
set ncom 0
for {set i $dft} {$i <= $fft} {incr i} {
if {[string index $s1 $i] eq [string index $s2 $i]} {incr ncom}
}
if {$ncom != 0} {
set pc [expr {($fft - $dft + 1)/$ncom}]
if {$pc > 50.} {set ret 1}
}

return $ret
}


proc PropagateFeat {n2 ft} {
global CpB

lassign [set CpB(startstop,$n2)] d2 f2
lassign $ft tm type tm fdeb tm ffin tm col tm score tm note
set seq2 [set Sequences($n2)]

if {$fdeb > $f2 || $ffin < $d2} {return}
if {$fdeb < $d2} {set fdeb $d2}
if {$ffin > $f2} {set ffin $f2}

while {[string index $seq2 $fdeb] eq "."} {
incr fdeb
}
while {[string index $seq2 $ffin] eq "."} {
incr ffin -1
}
if {$ffin < $fdeb} {return}
set fdres [DonnePosGS $n2 $fdeb]
set ffres [DonnePosGS $n2 $ffin]
set lg [expr {$ffres - $fdres + 1}]

# check that the feat does not exist already
foreach nf [set CpB(tb,$n2)] {
lassign $nf tm type2 tm fdeb2 tm ffin2 tm col2 tm score2 tm note2
set fd2 [DonnePosGS $n2 $fdeb2]
set ff2 [DonnePosGS $n2 $ffin2]
if {[BlockOverlap $fdres $ffres $fd2 $ff2] >= (1.0*$lg/4.0)} {
if {[regexp {^PROP\_|^PRED\_} $note2]} {
set nwnote [string range $note2 5 end]
}
} else {
set nwnote $note2
}
if {$nwnote eq $note} {
return
}
}

# Ok , create the feature
set nw [list ftype $type fstart $fdeb fstop $ffin fcolor $col fscore $score fnote "PROP_$note_from_$n1"]
lappend CpB(tp,$n2) $nw

return
}

























