
#
#
# ordali_data.tcl
#


proc InitPAM15 {} {
    set pam "Default scoring matrix used by GAP for the comparison of protein
sequences.  GAP uses the method of Needleman/Wunsch/Sellers to make
alignments.

Dayhoff table (Schwartz, R. M. and Dayhoff, M. O. \[1979\] in Atlas of
Protein Sequence and Structure, Dayhoff, M. O. Ed, pp. 353-358, National
Biomedical Research Foundation, Washington D.C.) rescaled by dividing
each value by the sum of its row and column, and normalizing to a mean
of 0 and standard deviation of 1.0.  The value for FY (Phe-Tyr) = RW =
1.425.  Perfect matches are set to 1.5 and no matches on any row are
better than perfect matches. 

Table used by Gribskov and Burgess NAR 14(16) 6745-6763

                     December 29, 1986  12:46

  A    B    C    D    E     F    G    H    I    K     L    M    N    P    Q     R    S    T    V    W     Y    Z  ..
 1.5  0.2  0.3  0.3  0.3  -0.5  0.7 -0.1  0.0  0.0  -0.1  0.0  0.2  0.5  0.2  -0.3  0.4  0.4  0.2 -0.8  -0.3  0.2 A
      1.1 -0.4  1.1  0.7  -0.7  0.6  0.4 -0.2  0.4  -0.5 -0.3  1.1  0.1  0.5   0.1  0.3  0.2 -0.2 -0.7  -0.3  0.6 B
           1.5 -0.5 -0.6  -0.1  0.2 -0.1  0.2 -0.6  -0.8 -0.6 -0.3  0.1 -0.6  -0.3  0.7  0.2  0.2 -1.2   1.0 -0.6 C
                1.5  1.0  -1.0  0.7  0.4 -0.2  0.3  -0.5 -0.4  0.7  0.1  0.7   0.0  0.2  0.2 -0.2 -1.1  -0.5  0.9 D
                     1.5  -0.7  0.5  0.4 -0.2  0.3  -0.3 -0.2  0.5  0.1  0.7   0.0  0.2  0.2 -0.2 -1.1  -0.5  1.1 E

                           1.5 -0.6 -0.1  0.7 -0.7   1.2  0.5 -0.5 -0.7 -0.8  -0.5 -0.3 -0.3  0.2  1.3   1.4 -0.7 F
                                1.5 -0.2 -0.3 -0.1  -0.5 -0.3  0.4  0.3  0.2  -0.3  0.6  0.4  0.2 -1.0  -0.7  0.3 G
                                     1.5 -0.3  0.1  -0.2 -0.3  0.5  0.2  0.7   0.5 -0.2 -0.1 -0.3 -0.1   0.3  0.5 H
                                          1.5 -0.2   0.8  0.6 -0.3 -0.2 -0.3  -0.3 -0.1  0.2  1.1 -0.5   0.1 -0.2 I
                                               1.5  -0.3  0.2  0.4  0.1  0.4   0.8  0.2  0.2 -0.2  0.1  -0.6  0.4 K

                                                     1.5  1.3 -0.4 -0.3 -0.1  -0.4 -0.4 -0.1  0.8  0.5   0.3 -0.2 L
                                                          1.5 -0.3 -0.2  0.0   0.2 -0.3  0.0  0.6 -0.3  -0.1 -0.1 M
                                                               1.5  0.0  0.4   0.1  0.3  0.2 -0.3 -0.3  -0.1  0.4 N
                                                                    1.5  0.3   0.3  0.4  0.3  0.1 -0.8  -0.8  0.2 P
                                                                         1.5   0.4 -0.1 -0.1 -0.2 -0.5  -0.6  1.1 Q

                                                                               1.5  0.1 -0.1 -0.3  1.4  -0.6  0.2 R
                                                                                    1.5  0.3 -0.1  0.3  -0.4  0.0 S
                                                                                         1.5  0.2 -0.6  -0.3  0.1 T
                                                                                              1.5 -0.8  -0.1 -0.2 V
                                                                                                   1.5   1.1 -0.8 W

                                                                                                         1.5 -0.6 Y
                                                                                                              1.1 Z"
    
set pam [split $pam \n]
set header 0
set go 0
foreach l $pam {
    set l [string trim $l]
    if {$l eq ""} {
	continue
    }

    if {[string range $l end-1 end] eq "\.\."} {
	set go 1
	set laa [string range $l 0 end-2]
	regsub -all { +} $laa " " laa
	set laa [split $laa " "]
	set i 0
	continue
    }
    if {! $go} {
	continue
    }

    # lit scores
    regsub -all { +|\t} $l " " l
    set l [split $l " "]
    set a [lindex $laa $i]
    foreach b [lrange $laa $i end] v [lrange $l 0 end-1] {
	set mtx($a,$b) $v
	set mtx($b,$a) $v
    }
    incr i
}

set mtx(laa) [join $laa ""]

return [array get mtx]
}




proc OriginalDayhoff2 {} {
    set d "A  B  C  D  E    F  G  H  I  K    L  M  N  P  Q    R  S  T  V  W    X  Y  Z
10  8  6  8  8    4  9  7  7  7    6  7  8  9  8    6  9  9  8  2    8  5  8  A
   10  4 11 10    3  8  9  6  9    5  6 10  7  9    7  8  8  6  3    8  5 10  B
      20  3  3    4  5  5  6  3    2  3  4  5  3    4  8  6  6  0    8  8  3  C
         12 11    2  9  9  6  8    4  5 10  7 10    7  8  8  6  1    8  4 11  D
            12    3  8  9  6  8    5  6  9  7 10    7  8  8  6  1    8  4 11  E

                 17  3  6  9  3   10  8  4  3  3    4  5  5  7  8    8 15  3  F
                    13  6  5  6    4  5  8  7  7    5  9  8  7  1    8  3  7  G
                       14  6  8    6  6 10  8 11   10  7  7  6  5    8  8  6  H
                          13  6   10 10  6  6  6    6  7  8 12  3    8  7  6  I
                             13    5  8  9  7  9   11  8  8  6  5    8  4  8  K

                                  14 12  5  5  6    5  5  6 10  6    8  7  5  L
                                     14  6  6  7    8  6  7 10  4    8  6  6  M
                                        10  7  9    8  9  8  6  4    8  6  9  N
                                           14  8    8  9  8  7  2    8  3  8  P
                                              12    9  7  7  6  3    8  4 11  Q

                                                   14  8  7  6 10    8  4 11  R
                                                      10  9  7  6    8  5  8  S
                                                         11  8  3    8  5  7  T
                                                            12  2    8  6  6  V
                                                               25    8  8  2  W

                                                                     8  8  8  X
                                                                       18  4  Y
                                                                          11  Z"

    set Ld [split $d "\n"]
    set Laa [string trim [lindex $Ld 0]]
    regsub -all { +} $Laa " " Laa
    set Laa [split $Laa " "]

    set ia 0
    foreach d [lrange $Ld 1 end] {
	set d [string trim $d]
	if {$d eq ""} {continue}

	regsub -all { +} $d " " d
	set Lv [split $d " "]
	set aacou [lindex $Lv end]
	foreach v [lrange $Lv 0 end-1] aa [lrange $Laa $ia end] {
	    set t($aacou,$aa) $v
	    set t($aa,$aacou) $v
	}
	incr ia
    }
    #parray t

    return [array get t]
}


proc OriginalDayhoff {} {

    set d "C  12.0
S  -0.0  1.6
T  -2.2  1.3  2.6
P  -2.7  0.9  0.3  5.9
A  -2.0  1.1  1.2  1.1  1.8
G  -3.3  1.1 -0.0 -0.5  1.3  4.8
N  -3.6  0.7  0.4 -0.5  0.2  0.4  2.0
D  -5.1  0.3 -0.1 -1.0  0.3  0.6  2.1  3.9
E  -5.3 -0.0 -0.4 -0.6  0.3  0.2  1.4  3.4  3.9
Q  -5.3 -0.5 -0.8  0.2 -0.4 -1.2  0.8  1.6  2.5  4.1
H  -3.4 -0.8 -1.3 -0.3 -1.4 -2.1  1.6  0.7  0.6  2.9  6.6
R  -3.6 -0.3 -0.9 -0.2 -1.6 -2.6 -0.0 -1.3 -1.1  1.2  1.5  6.1
K  -5.4 -0.2 -0.0 -1.2 -1.2 -1.7  1.0  0.1 -0.1  0.7 -0.1  3.4  4.7
M  -5.2 -1.6 -0.6 -2.1 -1.2 -2.8 -1.8 -2.6 -2.2 -1.0 -2.2 -0.5  0.4  6.6
I  -2.3 -1.4  0.1 -2.0 -0.5 -2.6 -1.8 -2.4 -2.0 -2.0 -2.5 -2.0 -1.9  2.2  4.6
L  -6.0 -2.8 -1.7 -2.6 -1.9 -4.0 -2.9 -4.0 -3.3 -1.8 -2.1 -3.0 -2.9  3.7  2.4  6.0
V  -1.9 -1.0  0.3 -1.2  0.2 -1.4 -1.8 -2.2 -1.8 -1.9 -2.3 -2.5 -2.5  1.8  3.7  1.8  4.3
F  -4.3 -3.2 -3.1 -4.6 -3.5 -4.8 -3.5 -5.6 -5.4 -4.7 -1.8 -4.5 -5.3  0.2  1.0  1.8 -1.2  9.1
Y   0.4 -2.8 -2.8 -5.0 -3.5 -5.3 -2.1 -4.3 -4.3 -4.0 -0.1 -4.2 -4.5 -2.5 -1.0 -0.9 -2.5  7.0 10.2
W  -7.5 -2.3 -5.0 -5.5 -5.6 -6.8 -3.9 -6.6 -6.8 -4.6 -2.5  2.3 -3.3 -4.1 -5.0 -1.7 -6.1  0.5  0.0 17.3"
    
    set Ld [split $d \n]
    set Laa {}
    foreach l $Ld {
	set l [string trim $l]
	regsub -all { +} $l " " l
	set Lv [split $l " "]
	set aacou [lindex $Lv 0]
	lappend Laa $aacou
	foreach v [lrange $Lv 1 end] aa $Laa {
	    set t($aacou,$aa) $v
	    set t($aa,$aacou) $v
	}
    }

    return [array get t]
}


proc InitGeneticCode {} {
    global CodeGen

    set tcode "
XXX X XXX
PHE F TTT TTC
LEU L TTA TTG CTT CTC CTA CTG
ILE I ATT ATC ATA
MET M ATG
VAL V GTT GTC GTA GTG
SER S TCT TCC TCA TCG AGT AGC
PRO P CCT CCC CCA CCG
THR T ACT ACC ACA ACG
ALA A GCT GCC GCA GCG
TYR Y TAT TAC
HIS H CAT CAC
GLN Q CAA CAG
ASN N AAT AAC
LYS K AAA AAG
ASP D GAT GAC
GLU E GAA GAG
CYS C TGT TGC
TRP W TGG TGA
ARG R CGT CGC CGA CGG AGA AGG
GLY G GGT GGC GGA GGG
"

    set Lc [split $tcode \n]
    foreach l $Lc {
	if {$l eq ""} {continue}

	set Lv [split [string trim $l] " "]
	set aa3 [lindex $Lv 0]
	set aa1 [lindex $Lv 1]

	foreach cdn [lrange $Lv 2 end] {
	    lappend CodeGen($aa3) $cdn
	    set CodeGen($cdn) $aa1
	}
    }

    return
}


proc InitialiseBlosum62f {} {
    # blosum62.qij / frequencies or aa
    
    set laa "ARNDCQEGHILKMFPSTWYV"
    set Laa [split $laa ""]
    set blosum62f "
    # BLOSUM Clustered Target Frequencies=qij
    # Blocks Database = /data/blocks_5.0/blocks.dat
    # Cluster Percentage: >= 62
    # A R N D C Q E G H I L K M F P S T W Y V
    0.0215
    0.0023 0.0178
    0.0019 0.0020 0.0141
    0.0022 0.0016 0.0037 0.0213
    0.0016 0.0004 0.0004 0.0004 0.0119
    0.0019 0.0025 0.0015 0.0016 0.0003 0.0073
    0.0030 0.0027 0.0022 0.0049 0.0004 0.0035 0.0161
    0.0058 0.0017 0.0029 0.0025 0.0008 0.0014 0.0019 0.0378
    0.0011 0.0012 0.0014 0.0010 0.0002 0.0010 0.0014 0.0010 0.0093
    0.0032 0.0012 0.0010 0.0012 0.0011 0.0009 0.0012 0.0014 0.0006 0.0184
    0.0044 0.0024 0.0014 0.0015 0.0016 0.0016 0.0020 0.0021 0.0010 0.0114 0.0371
    0.0033 0.0062 0.0024 0.0024 0.0005 0.0031 0.0041 0.0025 0.0012 0.0016 0.0025 0.0161
    0.0013 0.0008 0.0005 0.0005 0.0004 0.0007 0.0007 0.0007 0.0004 0.0025 0.0049 0.0009 0.0040
    0.0016 0.0009 0.0008 0.0008 0.0005 0.0005 0.0009 0.0012 0.0008 0.0030 0.0054 0.0009 0.0012 0.0183
    0.0022 0.0010 0.0009 0.0012 0.0004 0.0008 0.0014 0.0014 0.0005 0.0010 0.0014 0.0016 0.0004 0.0005 0.0191
    0.0063 0.0023 0.0031 0.0028 0.0010 0.0019 0.0030 0.0038 0.0011 0.0017 0.0024 0.0031 0.0009 0.0012 0.0017 0.0126
    0.0037 0.0018 0.0022 0.0019 0.0009 0.0014 0.0020 0.0022 0.0007 0.0027 0.0033 0.0023 0.0010 0.0012 0.0014 0.0047 0.0125
    0.0004 0.0003 0.0002 0.0002 0.0001 0.0002 0.0003 0.0004 0.0002 0.0004 0.0007 0.0003 0.0002 0.0008 0.0001 0.0003 0.0003 0.0065
    0.0013 0.0009 0.0007 0.0006 0.0003 0.0007 0.0009 0.0008 0.0015 0.0014 0.0022 0.0010 0.0006 0.0042 0.0005 0.0010 0.0009 0.0009 0.0102
    0.0051 0.0016 0.0012 0.0013 0.0014 0.0012 0.0017 0.0018 0.0006 0.0120 0.0095 0.0019 0.0023 0.0026 0.0012 0.0024 0.0036 0.0004 0.0015 0.0196 "
    
    set i 0
    foreach l [split $blosum62f \n] {
	set l [string map {"\t" "" "\n" ""} [string trim $l]]
	if {[string index $l 0] eq "#" || $l eq ""} {
	    continue
	}
	regsub -all { +} $l " " l
	set l [split $l " "]

	set a [lindex $Laa $i]
	for {set j 0} {$j <= $i} {incr j} {
	    set b [lindex $Laa $j]
	    set v [lindex $l $j]
	    set M($a,$b) $v
	    set M($b,$a) $v
	}
	incr i
    }
    set M(laa) $laa

    return [array get M]
}

    
proc InitialisePET91 {} {
    # Taken from the AAIndex database
    # 

    set data "
    # H JOND920103
    # D The 250 PAM PET91 matrix (Jones et al., 1992)
    # R LIT:1814076 PMID:1633570
    # A Jones, D.T., Taylor, W.R. and Thornton, J.M.
    # T The rapid generation of mutation data matrices from protein sequences
    # J CABIOS 8, 275-282 (1992)
    # M rows = ARNDCQEGHILKMFPSTWYV, cols = ARNDCQEGHILKMFPSTWYV
    2.
    -1.      5.
    0.      0.      3.
    0.     -1.      2.      5.
    -1.     -1.     -1.     -3.     11.
    -1.      2.      0.      1.     -3.      5.
    -1.      0.      1.      4.     -4.      2.      5.
    1.      0.      0.      1.     -1.     -1.      0.      5.
    -2.      2.      1.      0.      0.      2.      0.     -2.      6.
    0.     -3.     -2.     -3.     -2.     -3.     -3.     -3.     -3.      4.
    -1.     -3.     -3.     -4.     -3.     -2.     -4.     -4.     -2.      2.      5.
    -1.      4.      1.      0.     -3.      2.      1.     -1.      1.     -3.     -3.      5.
    -1.     -2.     -2.     -3.     -2.     -2.     -3.     -3.     -2.      3.      3.     -2.      6.
    -3.     -4.     -3.     -5.      0.     -4.     -5.     -5.      0.      0.      2.     -5.      0.      8.
    1.     -1.     -1.     -2.     -2.      0.     -2.     -1.      0.     -2.      0.     -2.     -2.     -3.      6.
    1.     -1.      1.      0.      1.     -1.     -1.      1.     -1.     -1.     -2.     -1.     -1.     -2.      1.      2.
    2.     -1.      1.     -1.     -1.     -1.     -1.     -1.     -1.      1.     -1.     -1.      0.     -2.      1.      1.      2.
    -4.      0.     -5.     -5.      1.     -3.     -5.     -2.     -3.     -4.     -2.     -3.     -3.     -1.     -4.     -3.     -4.     15.
    -3.     -2.     -1.     -2.      2.     -2.     -4.     -4.      4.     -2.     -1.     -3.     -2.      5.     -3.     -1.     -3.      0.      9.
    1.     -3.     -2.     -2.     -2.     -3.     -2.     -2.     -3.      4.      2.     -3.      2.      0.     -1.     -1.      0.     -3.     -3.      4.
    # //
    "
    set Laa ARNDCQEGHILKMFPSTWYV
    set Lm [split $data \n]
    set i 0
    foreach l $Lm {
	regsub -all { +} [string trim $l] " " l
	if {$l ne "" && [string index $l 0] ne "#"} {
	    set Lv [split $l " "]
	    set a [string index $Laa $i]
	    for {set j 0} {$j <= $i} {incr j} {
		set b [string index $Laa $j]
		set v [lindex $Lv $j]
		set M($a,$b) $v
		set M($b,$a) $v
	    }
	    incr i
	}
    }

    return [array get M]
}


proc InitialiseBLiu {} {
    global TBLiu
	
    set mat "A 10 3 4 3 5 3 5 2 5 5 4 5 4 3 4 4 4 7 4 6 2 3 4
    B 3 10 3 8 6 3 4 4 3 2 4 2 2 8 3 5 4 6 3 2 2 2 5
    C 4 3 10 3 2 3 3 2 5 5 2 5 4 3 2 2 3 4 3 4 3 3 2
    D 3 8 3 10 7 3 4 3 3 2 4 2 2 6 4 5 3 6 3 2 2 2 6
    E 5 6 2 7 10 3 3 4 3 3 6 3 3 5 4 7 5 6 3 3 2 3 8
    F 3 3 3 3 3 10 3 4 5 5 3 5 5 3 2 3 3 3 2 4 4 7 3
    G 5 4 3 4 3 3 10 2 2 2 3 2 2 5 3 3 3 6 2 2 3 2 3
    H 2 4 2 3 4 4 2 10 3 3 4 3 3 5 3 4 4 4 2 2 3 6 4
    I 5 3 5 3 3 5 2 3 10 9 2 8 6 3 2 3 3 3 3 9 2 3 3
    J 5 2 5 2 3 5 2 3 9 10 2 9 6 3 2 3 3 3 3 8 2 3 3
    K 4 4 2 4 6 3 3 4 2 2 10 3 4 5 4 6 7 6 3 3 2 3 6
    L 5 2 5 2 3 5 2 3 8 9 3 10 7 3 2 4 4 3 3 7 3 3 3
    M 4 2 4 2 3 5 2 3 6 6 4 7 10 3 3 5 4 4 3 7 3 3 4
    N 3 8 3 6 5 3 5 5 3 3 5 3 3 10 3 5 5 7 4 2 2 3 5
    P 4 3 2 4 4 2 3 3 2 2 4 2 3 3 10 4 3 4 3 3 2 2 4
    Q 4 5 2 5 7 3 3 4 3 3 6 4 5 5 4 10 6 6 3 3 3 3 8
    R 4 4 3 3 5 3 3 4 3 3 7 4 4 5 3 6 10 4 3 2 2 3 5
    S 7 6 4 6 6 3 6 4 3 3 6 3 4 7 4 6 4 10 6 3 2 3 6
    T 4 3 3 3 3 2 2 2 3 3 3 3 3 4 3 3 3 6 10 6 3 3 3
    V 6 2 4 2 3 4 2 2 9 8 3 7 7 2 3 3 2 3 6 10 2 4 3
    W 2 2 3 2 2 4 3 3 2 2 2 3 3 2 2 3 2 2 3 2 10 6 2
    Y 3 2 3 2 3 7 2 6 3 3 3 3 3 3 2 3 3 3 3 4 6 10 3
    Z 4 5 2 6 8 3 3 4 3 3 6 3 4 5 4 8 5 6 3 3 2 3 10"

    set lmat [split $mat \n]
    foreach l $lmat {
	if {[regexp {^\#} $l]} {
	    continue
	}
	set l [string map [list "\t" ""] $l]
	regsub -all { +} [string trim $l] " " l
	if {$l eq ""} {
	    continue
	}
	set Lv [split $l " "]
	lappend Laas [lindex $Lv 0]
	lappend Lval [lrange $Lv 1 end]
    }

    foreach a $Laas l $Lval {
	foreach b $Laas v $l {
	    if {$v == 10} {set v 12}
	    set TBLiu($a,$b) [expr {double($v)}]
	}
    }

    return
}


proc InitRPCA {} {
    set lpca "-0.03321226115344578 -0.11387825720514409 -0.22416505603164735 -0.20918526423622633 0.20138722682215107 -0.15137648641007362 -0.14400440513856536 -0.42777360088067506 -0.019577591705696975 0.2532802673970912 0.29919512078613575 -0.2134906880145011 0.09557293424375313 0.3791053228772117 -0.1283964403623 -0.21500354107131917 -0.16441814984544625 0.39728684887162297 0.22747378232324078 0.1911802387338345
0.22805692460681184 -0.0062771564423803 -0.015913385336226146 -0.005792371664023655 0.10264273871909664 -0.03090518610436776 -0.033938370405318136 0.18274445484841986 -0.17578830526813807 0.083108732593751 0.019193250960873705 0.007636490622739857 -0.025374878078663884 -0.16515347581850442 0.08174128951967097 0.12683154820269357 0.030620696769400806 -0.3398491801590555 -0.1789062118645277 0.1153223942977476
-0.009534124621060316 -0.22563399392023 0.027957348993080455 0.04512231840752419 0.34453460416856857 -0.09609904083263208 -0.25661141737339377 0.5360106253844271 -0.14136970178315464 -0.07892902460086294 -0.14428327504767074 -0.18774744259553774 -0.0614222195759302 0.02624689724748815 -0.05150025840387371 0.013382957062699822 0.1293802637083716 0.10336605301238586 0.011297589492219524 0.015831841277580794
"
     set lpca "-0.2550000000000008 -5.155000000000001 -6.0550000000000015 -5.455000000000002 8.945 -5.155000000000001 -6.355000000000001 -6.655000000000001 -2.3550000000000004 6.645 7.145 -7.5550000000000015 2.044999999999998 10.244999999999997 -3.755000000000001 -5.455000000000002 -3.3550000000000004 10.844999999999999 5.844999999999999 5.844999999999999
2.7570499999999996 -0.3539500000000011 0.35304999999999964 0.48104999999999976 1.5870499999999996 -0.26695000000000135 -0.6899500000000014 4.321049999999999 -2.3729500000000012 0.2650499999999987 -0.7429500000000004 0.11104999999999876 -0.6469500000000004 -2.7079500000000003 1.1250499999999999 1.995049999999999 1.0130499999999998 -4.642950000000001 -2.5829500000000003 0.9990499999999987
-0.10749999999999998 -0.3675 0.1825 0.2025 0.5025 -0.0875 -0.3975 1.1725 -0.1775 -0.3275 -0.4475 -0.2475 -0.15749999999999997 -0.07749999999999999 -0.06749999999999999 0.0825 0.3225 0.14250000000000002 -0.017499999999999988 -0.1275"

    return $lpca
}


proc IniVolPol {} {
    #
    # Tire directement de MAFFT :
    set lvolpol "
    A 31.0 8.1	
    R 124.0 10.5
    N 56.0 11.6
    D 54.0 13.0
    B 55.0 12.0
    C 55.0 5.5
    Q 85.0 10.5
    E 83.0 12.3
    G 3.0 9.0
    H 96.0 10.4
    I 111.0 5.2
    L 111.0 4.9
    J 111.0 5.05
    K 119.0 11.3
    M 105.0 5.7
    F 132.0 5.2
    P 32.5 8.0
    S 32.0 9.2
    T 61.0 8.6
    W 170.0 5.4
    Y 136.0 6.2
    V 84.0 5.9"

    # Volume/Polarite de MAFFT.
    # Met a l'echelle, rotation pour fitter les axes
    # du VRP.
    if {0} {
	set lvolpol "A -4.148493661429663 0.15375170408070496
    C -2.2708161909098723 1.9304380623466315
    D -2.3490527521815303 -3.1946187403435418
    E -0.08019247530344983 -2.716280105425793
    F 3.7533990270077893 2.135440334454238
    G -6.339117377036085 -0.46125511224211607
    H 0.9368828212281034 -1.4179323820776153
    I 2.1104312403029724 2.135440334454238
    K 2.736323730476236 -2.0329391984004364
    L 2.1104312403029724 2.340442606561845
    M 1.641011872673025 1.79376988094156
    N -2.1925796296382143 -2.2379414705080425
    P -4.031138819522176 0.22208579478324036
    Q 0.07628064723986605 -1.4862664727801507
    R 3.1275065368345256 -1.4862664727801507
    S -4.070257100158005 -0.5979232936471869
    T -1.8013968232799247 -0.18791874943197326
    V -0.0019559140317918933 1.6571016995364887
    W 6.7263883553307915 1.9987721530491669
    Y 4.066345272094421 1.4520994274288819"
    }

    return $lvolpol
}


proc IniRosace {} {

    set lRosace [list "-3.40,A" "0.90,R" "-1.70,N" "-3.40,D" "-1.85,C" "-1.45,Q" "-3.40,E" "-5.15,G" "1.80,H" "1.50,I" "2.85,L" "-0.45,K" "2.05,M" "5.70,F" "-5.15,P" "-2.32,S" "-1.95,T" "7.45,W" "7.55,Y" "0.10,V" "0.40,A" "-4.25,R" "-1.60,N" "-2.45,D" "5.30,C" "-2.40,Q" "-1.50,E" "0.70,G" "-2.70,H" "2.75,I" "2.90,L" "-3.35,K" "2.10,M" "0.75,F" "-0.50,P" "0.20,S" "1.45,T" "-1.85,W" "-0.15,Y" "2.80,V"]
    return $lRosace
}


proc InitGon250 {} {

    set lgon [list "# benner-gonnet matrix" "# pam := 250" "# print (DayhoffM (NewLogPAM1, pam));" "# DayMatrix(Peptide, pam=250, Simil: max=14.152, min=-5.161, max offdiag=5.080," "#  del=-19.814-1.396*(k-1))" "    A    R    N    D    C    Q    E    G    H    I    L    K    M    F    P    S    T    W    Y    V    B    Z    X    *" "  2.4 -0.6 -0.3 -0.3  0.5 -0.2  0.0  0.5 -0.8 -0.8 -1.2 -0.4 -0.7 -2.3  0.3  1.1  0.6 -3.6 -2.2  0.1  0.0  0.0  0.0 -5.2" " -0.6  4.7  0.3 -0.3 -2.2  1.5  0.4 -1.0  0.6 -2.4 -2.2  2.7 -1.7 -3.2 -0.9 -0.2 -0.2 -1.6 -1.8 -2.0  0.0  0.0  0.0 -5.2" " -0.3  0.3  3.8  2.2 -1.8  0.7  0.9  0.4  1.2 -2.8 -3.0  0.8 -2.2 -3.1 -0.9  0.9  0.5 -3.6 -1.4 -2.2  0.0  0.0  0.0 -5.2" " -0.3 -0.3  2.2  4.7 -3.2  0.9  2.7  0.1  0.4 -3.8 -4.0  0.5 -3.0 -4.5 -0.7  0.5  0.0 -5.2 -2.8 -2.9  0.0  0.0  0.0 -5.2" "  0.5 -2.2 -1.8 -3.2 11.5 -2.4 -3.0 -2.0 -1.3 -1.1 -1.5 -2.8 -0.9 -0.8 -3.1  0.1 -0.5 -1.0 -0.5  0.0  0.0  0.0  0.0 -5.2" " -0.2  1.5  0.7  0.9 -2.4  2.7  1.7 -1.0  1.2 -1.9 -1.6  1.5 -1.0 -2.6 -0.2  0.2  0.0 -2.7 -1.7 -1.5  0.0  0.0  0.0 -5.2" "  0.0  0.4  0.9  2.7 -3.0  1.7  3.6 -0.8  0.4 -2.7 -2.8  1.2 -2.0 -3.9 -0.5  0.2 -0.1 -4.3 -2.7 -1.9  0.0  0.0  0.0 -5.2" "  0.5 -1.0  0.4  0.1 -2.0 -1.0 -0.8  6.6 -1.4 -4.5 -4.4 -1.1 -3.5 -5.2 -1.6  0.4 -1.1 -4.0 -4.0 -3.3  0.0  0.0  0.0 -5.2" " -0.8  0.6  1.2  0.4 -1.3  1.2  0.4 -1.4  6.0 -2.2 -1.9  0.6 -1.3 -0.1 -1.1 -0.2 -0.3 -0.8  2.2 -2.0  0.0  0.0  0.0 -5.2" " -0.8 -2.4 -2.8 -3.8 -1.1 -1.9 -2.7 -4.5 -2.2  4.0  2.8 -2.1  2.5  1.0 -2.6 -1.8 -0.6 -1.8 -0.7  3.1  0.0  0.0  0.0 -5.2" " -1.2 -2.2 -3.0 -4.0 -1.5 -1.6 -2.8 -4.4 -1.9  2.8  4.0 -2.1  2.8  2.0 -2.3 -2.1 -1.3 -0.7  0.0  1.8  0.0  0.0  0.0 -5.2" " -0.4  2.7  0.8  0.5 -2.8  1.5  1.2 -1.1  0.6 -2.1 -2.1  3.2 -1.4 -3.3 -0.6  0.1  0.1 -3.5 -2.1 -1.7  0.0  0.0  0.0 -5.2" " -0.7 -1.7 -2.2 -3.0 -0.9 -1.0 -2.0 -3.5 -1.3  2.5  2.8 -1.4  4.3  1.6 -2.4 -1.4 -0.6 -1.0 -0.2  1.6  0.0  0.0  0.0 -5.2" " -2.3 -3.2 -3.1 -4.5 -0.8 -2.6 -3.9 -5.2 -0.1  1.0  2.0 -3.3  1.6  7.0 -3.8 -2.8 -2.2  3.6  5.1  0.1  0.0  0.0  0.0 -5.2" "  0.3 -0.9 -0.9 -0.7 -3.1 -0.2 -0.5 -1.6 -1.1 -2.6 -2.3 -0.6 -2.4 -3.8  7.6  0.4  0.1 -5.0 -3.1 -1.8  0.0  0.0  0.0 -5.2" "  1.1 -0.2  0.9  0.5  0.1  0.2  0.2  0.4 -0.2 -1.8 -2.1  0.1 -1.4 -2.8  0.4  2.2  1.5 -3.3 -1.9 -1.0  0.0  0.0  0.0 -5.2" "  0.6 -0.2  0.5  0.0 -0.5  0.0 -0.1 -1.1 -0.3 -0.6 -1.3  0.1 -0.6 -2.2  0.1  1.5  2.5 -3.5 -1.9  0.0  0.0  0.0  0.0 -5.2" " -3.6 -1.6 -3.6 -5.2 -1.0 -2.7 -4.3 -4.0 -0.8 -1.8 -0.7 -3.5 -1.0  3.6 -5.0 -3.3 -3.5 14.2  4.1 -2.6  0.0  0.0  0.0 -5.2" " -2.2 -1.8 -1.4 -2.8 -0.5 -1.7 -2.7 -4.0  2.2 -0.7  0.0 -2.1 -0.2  5.1 -3.1 -1.9 -1.9  4.1  7.8 -1.1  0.0  0.0  0.0 -5.2" "  0.1 -2.0 -2.2 -2.9  0.0 -1.5 -1.9 -3.3 -2.0  3.1  1.8 -1.7  1.6  0.1 -1.8 -1.0  0.0 -2.6 -1.1  3.4  0.0  0.0  0.0 -5.2" "  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0 -5.2" "  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0 -5.2" "  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0 -5.2" " -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2 -5.2  1"]

    return $lgon
}


proc InitTkCol {} {
    global TkCol ListeTkCol

    set TkCol(alice\ blue) [list 240 248 255]
    set TkCol(AliceBlue) [list 240 248 255]
    set TkCol(antique\ white) [list 250 235 215]
    set TkCol(AntiqueWhite) [list 250 235 215]
    set TkCol(AntiqueWhite1) [list 255 239 219]
    set TkCol(AntiqueWhite2) [list 238 223 204]
    set TkCol(AntiqueWhite3) [list 205 192 176]
    set TkCol(AntiqueWhite4) [list 139 131 120]
    set TkCol(aquamarine) [list 127 255 212]
    set TkCol(aquamarine1) [list 127 255 212]
    set TkCol(aquamarine2) [list 118 238 198]
    set TkCol(aquamarine3) [list 102 205 170]
    set TkCol(aquamarine4) [list 69 139 116]
    set TkCol(azure) [list 240 255 255]
    set TkCol(azure1) [list 240 255 255]
    set TkCol(azure2) [list 224 238 238]
    set TkCol(azure3) [list 193 205 205]
    set TkCol(azure4) [list 131 139 139]
    set TkCol(beige) [list 245 245 220]
    set TkCol(bisque) [list 255 228 196]
    set TkCol(bisque1) [list 255 228 196]
    set TkCol(bisque2) [list 238 213 183]
    set TkCol(bisque3) [list 205 183 158]
    set TkCol(bisque4) [list 139 125 107]
    set TkCol(black) [list 0 0 0]
    set TkCol(blanched\ almond) [list 255 235 205]
    set TkCol(BlanchedAlmond) [list 255 235 205]
    set TkCol(blue) [list 0 0 255]
    set TkCol(blue\ violet) [list 138 43 226]
    set TkCol(blue1) [list 0 0 255]
    set TkCol(blue2) [list 0 0 238]
    set TkCol(blue3) [list 0 0 205]
    set TkCol(blue4) [list 0 0 139]
    set TkCol(BlueViolet) [list 138 43 226]
    set TkCol(brown) [list 165 42 42]
    set TkCol(brown1) [list 255 64 64]
    set TkCol(brown2) [list 238 59 59]
    set TkCol(brown3) [list 205 51 51]
    set TkCol(brown4) [list 139 35 35]
    set TkCol(burlywood) [list 222 184 135]
    set TkCol(burlywood1) [list 255 211 155]
    set TkCol(burlywood2) [list 238 197 145]
    set TkCol(burlywood3) [list 205 170 125]
    set TkCol(burlywood4) [list 139 115 85]
    set TkCol(cadet\ blue) [list 95 158 160]
    set TkCol(CadetBlue) [list 95 158 160]
    set TkCol(CadetBlue1) [list 152 245 255]
    set TkCol(CadetBlue2) [list 142 229 238]
    set TkCol(CadetBlue3) [list 122 197 205]
    set TkCol(CadetBlue4) [list 83 134 139]
    set TkCol(chartreuse) [list 127 255 0]
    set TkCol(chartreuse1) [list 127 255 0]
    set TkCol(chartreuse2) [list 118 238 0]
    set TkCol(chartreuse3) [list 102 205 0]
    set TkCol(chartreuse4) [list 69 139 0]
    set TkCol(chocolate) [list 210 105 30]
    set TkCol(chocolate1) [list 255 127 36]
    set TkCol(chocolate2) [list 238 118 33]
    set TkCol(chocolate3) [list 205 102 29]
    set TkCol(chocolate4) [list 139 69 19]
    set TkCol(coral) [list 255 127 80]
    set TkCol(coral1) [list 255 114 86]
    set TkCol(coral2) [list 238 106 80]
    set TkCol(coral3) [list 205 91 69]
    set TkCol(coral4) [list 139 62 47]
    set TkCol(cornflower\ blue) [list 100 149 237]
    set TkCol(CornflowerBlue) [list 100 149 237]
    set TkCol(cornsilk) [list 255 248 220]
    set TkCol(cornsilk1) [list 255 248 220]
    set TkCol(cornsilk2) [list 238 232 205]
    set TkCol(cornsilk3) [list 205 200 177]
    set TkCol(cornsilk4) [list 139 136 120]
    set TkCol(cyan) [list 0 255 255]
    set TkCol(cyan1) [list 0 255 255]
    set TkCol(cyan2) [list 0 238 238]
    set TkCol(cyan3) [list 0 205 205]
    set TkCol(cyan4) [list 0 139 139]
    set TkCol(dark\ blue) [list 0 0 139]
    set TkCol(dark\ cyan) [list 0 139 139]
    set TkCol(dark\ goldenrod) [list 184 134 11]
    set TkCol(dark\ gray) [list 169 169 169]
    set TkCol(dark\ green) [list 0 100 0]
    set TkCol(dark\ grey) [list 169 169 169]
    set TkCol(dark\ khaki) [list 189 183 107]
    set TkCol(dark\ magenta) [list 139 0 139]
    set TkCol(dark\ olive\ green) [list 85 107 47]
    set TkCol(dark\ orange) [list 255 140 0]
    set TkCol(dark\ orchid) [list 153 50 204]
    set TkCol(dark\ red) [list 139 0 0]
    set TkCol(dark\ salmon) [list 233 150 122]
    set TkCol(dark\ sea\ green) [list 143 188 143]
    set TkCol(dark\ slate\ blue) [list 72 61 139]
    set TkCol(dark\ slate\ gray) [list 47 79 79]
    set TkCol(dark\ slate\ grey) [list 47 79 79]
    set TkCol(dark\ turquoise) [list 0 206 209]
    set TkCol(dark\ violet) [list 148 0 211]
    set TkCol(DarkBlue) [list 0 0 139]
    set TkCol(DarkCyan) [list 0 139 139]
    set TkCol(DarkGoldenrod) [list 184 134 11]
    set TkCol(DarkGoldenrod1) [list 255 185 15]
    set TkCol(DarkGoldenrod2) [list 238 173 14]
    set TkCol(DarkGoldenrod3) [list 205 149 12]
    set TkCol(DarkGoldenrod4) [list 139 101 8]
    set TkCol(DarkGray) [list 169 169 169]
    set TkCol(DarkGreen) [list 0 100 0]
    set TkCol(DarkGrey) [list 169 169 169]
    set TkCol(DarkKhaki) [list 189 183 107]
    set TkCol(DarkMagenta) [list 139 0 139]
    set TkCol(DarkOliveGreen) [list 85 107 47]
    set TkCol(DarkOliveGreen1) [list 202 255 112]
    set TkCol(DarkOliveGreen2) [list 188 238 104]
    set TkCol(DarkOliveGreen3) [list 162 205 90]
    set TkCol(DarkOliveGreen4) [list 110 139 61]
    set TkCol(DarkOrange) [list 255 140 0]
    set TkCol(DarkOrange1) [list 255 127 0]
    set TkCol(DarkOrange2) [list 238 118 0]
    set TkCol(DarkOrange3) [list 205 102 0]
    set TkCol(DarkOrange4) [list 139 69 0]
    set TkCol(DarkOrchid) [list 153 50 204]
    set TkCol(DarkOrchid1) [list 191 62 255]
    set TkCol(DarkOrchid2) [list 178 58 238]
    set TkCol(DarkOrchid3) [list 154 50 205]
    set TkCol(DarkOrchid4) [list 104 34 139]
    set TkCol(DarkRed) [list 139 0 0]
    set TkCol(DarkSalmon) [list 233 150 122]
    set TkCol(DarkSeaGreen) [list 143 188 143]
    set TkCol(DarkSeaGreen1) [list 193 255 193]
    set TkCol(DarkSeaGreen2) [list 180 238 180]
    set TkCol(DarkSeaGreen3) [list 155 205 155]
    set TkCol(DarkSeaGreen4) [list 105 139 105]
    set TkCol(DarkSlateBlue) [list 72 61 139]
    set TkCol(DarkSlateGray) [list 47 79 79]
    set TkCol(DarkSlateGray1) [list 151 255 255]
    set TkCol(DarkSlateGray2) [list 141 238 238]
    set TkCol(DarkSlateGray3) [list 121 205 205]
    set TkCol(DarkSlateGray4) [list 82 139 139]
    set TkCol(DarkSlateGrey) [list 47 79 79]
    set TkCol(DarkTurquoise) [list 0 206 209]
    set TkCol(DarkViolet) [list 148 0 211]
    set TkCol(deep\ pink) [list 255 20 147]
    set TkCol(deep\ sky\ blue) [list 0 191 255]
    set TkCol(DeepPink) [list 255 20 147]
    set TkCol(DeepPink1) [list 255 20 147]
    set TkCol(DeepPink2) [list 238 18 137]
    set TkCol(DeepPink3) [list 205 16 118]
    set TkCol(DeepPink4) [list 139 10 80]
    set TkCol(DeepSkyBlue) [list 0 191 255]
    set TkCol(DeepSkyBlue1) [list 0 191 255]
    set TkCol(DeepSkyBlue2) [list 0 178 238]
    set TkCol(DeepSkyBlue3) [list 0 154 205]
    set TkCol(DeepSkyBlue4) [list 0 104 139]
    set TkCol(dim\ gray) [list 105 105 105]
    set TkCol(dim\ grey) [list 105 105 105]
    set TkCol(DimGray) [list 105 105 105]
    set TkCol(DimGrey) [list 105 105 105]
    set TkCol(dodger\ blue) [list 30 144 255]
    set TkCol(DodgerBlue) [list 30 144 255]
    set TkCol(DodgerBlue1) [list 30 144 255]
    set TkCol(DodgerBlue2) [list 28 134 238]
    set TkCol(DodgerBlue3) [list 24 116 205]
    set TkCol(DodgerBlue4) [list 16 78 139]
    set TkCol(firebrick) [list 178 34 34]
    set TkCol(firebrick1) [list 255 48 48]
    set TkCol(firebrick2) [list 238 44 44]
    set TkCol(firebrick3) [list 205 38 38]
    set TkCol(firebrick4) [list 139 26 26]
    set TkCol(floral\ white) [list 255 250 240]
    set TkCol(FloralWhite) [list 255 250 240]
    set TkCol(forest\ green) [list 34 139 34]
    set TkCol(ForestGreen) [list 34 139 34]
    set TkCol(gainsboro) [list 220 220 220]
    set TkCol(ghost\ white) [list 248 248 255]
    set TkCol(GhostWhite) [list 248 248 255]
    set TkCol(gold) [list 255 215 0]
    set TkCol(gold1) [list 255 215 0]
    set TkCol(gold2) [list 238 201 0]
    set TkCol(gold3) [list 205 173 0]
    set TkCol(gold4) [list 139 117 0]
    set TkCol(goldenrod) [list 218 165 32]
    set TkCol(goldenrod1) [list 255 193 37]
    set TkCol(goldenrod2) [list 238 180 34]
    set TkCol(goldenrod3) [list 205 155 29]
    set TkCol(goldenrod4) [list 139 105 20]
    set TkCol(gray) [list 190 190 190]
    set TkCol(gray0) [list 0 0 0]
    set TkCol(gray1) [list 3 3 3]
    set TkCol(gray2) [list 5 5 5]
    set TkCol(gray3) [list 8 8 8]
    set TkCol(gray4) [list 10 10 10]
    set TkCol(gray5) [list 13 13 13]
    set TkCol(gray6) [list 15 15 15]
    set TkCol(gray7) [list 18 18 18]
    set TkCol(gray8) [list 20 20 20]
    set TkCol(gray9) [list 23 23 23]
    set TkCol(gray10) [list 26 26 26]
    set TkCol(gray11) [list 28 28 28]
    set TkCol(gray12) [list 31 31 31]
    set TkCol(gray13) [list 33 33 33]
    set TkCol(gray14) [list 36 36 36]
    set TkCol(gray15) [list 38 38 38]
    set TkCol(gray16) [list 41 41 41]
    set TkCol(gray17) [list 43 43 43]
    set TkCol(gray18) [list 46 46 46]
    set TkCol(gray19) [list 48 48 48]
    set TkCol(gray20) [list 51 51 51]
    set TkCol(gray21) [list 54 54 54]
    set TkCol(gray22) [list 56 56 56]
    set TkCol(gray23) [list 59 59 59]
    set TkCol(gray24) [list 61 61 61]
    set TkCol(gray25) [list 64 64 64]
    set TkCol(gray26) [list 66 66 66]
    set TkCol(gray27) [list 69 69 69]
    set TkCol(gray28) [list 71 71 71]
    set TkCol(gray29) [list 74 74 74]
    set TkCol(gray30) [list 77 77 77]
    set TkCol(gray31) [list 79 79 79]
    set TkCol(gray32) [list 82 82 82]
    set TkCol(gray33) [list 84 84 84]
    set TkCol(gray34) [list 87 87 87]
    set TkCol(gray35) [list 89 89 89]
    set TkCol(gray36) [list 92 92 92]
    set TkCol(gray37) [list 94 94 94]
    set TkCol(gray38) [list 97 97 97]
    set TkCol(gray39) [list 99 99 99]
    set TkCol(gray40) [list 102 102 102]
    set TkCol(gray41) [list 105 105 105]
    set TkCol(gray42) [list 107 107 107]
    set TkCol(gray43) [list 110 110 110]
    set TkCol(gray44) [list 112 112 112]
    set TkCol(gray45) [list 115 115 115]
    set TkCol(gray46) [list 117 117 117]
    set TkCol(gray47) [list 120 120 120]
    set TkCol(gray48) [list 122 122 122]
    set TkCol(gray49) [list 125 125 125]
    set TkCol(gray50) [list 127 127 127]
    set TkCol(gray51) [list 130 130 130]
    set TkCol(gray52) [list 133 133 133]
    set TkCol(gray53) [list 135 135 135]
    set TkCol(gray54) [list 138 138 138]
    set TkCol(gray55) [list 140 140 140]
    set TkCol(gray56) [list 143 143 143]
    set TkCol(gray57) [list 145 145 145]
    set TkCol(gray58) [list 148 148 148]
    set TkCol(gray59) [list 150 150 150]
    set TkCol(gray60) [list 153 153 153]
    set TkCol(gray61) [list 156 156 156]
    set TkCol(gray62) [list 158 158 158]
    set TkCol(gray63) [list 161 161 161]
    set TkCol(gray64) [list 163 163 163]
    set TkCol(gray65) [list 166 166 166]
    set TkCol(gray66) [list 168 168 168]
    set TkCol(gray67) [list 171 171 171]
    set TkCol(gray68) [list 173 173 173]
    set TkCol(gray69) [list 176 176 176]
    set TkCol(gray70) [list 179 179 179]
    set TkCol(gray71) [list 181 181 181]
    set TkCol(gray72) [list 184 184 184]
    set TkCol(gray73) [list 186 186 186]
    set TkCol(gray74) [list 189 189 189]
    set TkCol(gray75) [list 191 191 191]
    set TkCol(gray76) [list 194 194 194]
    set TkCol(gray77) [list 196 196 196]
    set TkCol(gray78) [list 199 199 199]
    set TkCol(gray79) [list 201 201 201]
    set TkCol(gray80) [list 204 204 204]
    set TkCol(gray81) [list 207 207 207]
    set TkCol(gray82) [list 209 209 209]
    set TkCol(gray83) [list 212 212 212]
    set TkCol(gray84) [list 214 214 214]
    set TkCol(gray85) [list 217 217 217]
    set TkCol(gray86) [list 219 219 219]
    set TkCol(gray87) [list 222 222 222]
    set TkCol(gray88) [list 224 224 224]
    set TkCol(gray89) [list 227 227 227]
    set TkCol(gray90) [list 229 229 229]
    set TkCol(gray91) [list 232 232 232]
    set TkCol(gray92) [list 235 235 235]
    set TkCol(gray93) [list 237 237 237]
    set TkCol(gray94) [list 240 240 240]
    set TkCol(gray95) [list 242 242 242]
    set TkCol(gray96) [list 245 245 245]
    set TkCol(gray97) [list 247 247 247]
    set TkCol(gray98) [list 250 250 250]
    set TkCol(gray99) [list 252 252 252]
    set TkCol(gray100) [list 255 255 255]
    set TkCol(green) [list 0 255 0]
    set TkCol(green\ yellow) [list 173 255 47]
    set TkCol(green1) [list 0 255 0]
    set TkCol(green2) [list 0 238 0]
    set TkCol(green3) [list 0 205 0]
    set TkCol(green4) [list 0 139 0]
    set TkCol(GreenYellow) [list 173 255 47]
    set TkCol(grey) [list 190 190 190]
    set TkCol(grey0) [list 0 0 0]
    set TkCol(grey1) [list 3 3 3]
    set TkCol(grey2) [list 5 5 5]
    set TkCol(grey3) [list 8 8 8]
    set TkCol(grey4) [list 10 10 10]
    set TkCol(grey5) [list 13 13 13]
    set TkCol(grey6) [list 15 15 15]
    set TkCol(grey7) [list 18 18 18]
    set TkCol(grey8) [list 20 20 20]
    set TkCol(grey9) [list 23 23 23]
    set TkCol(grey10) [list 26 26 26]
    set TkCol(grey11) [list 28 28 28]
    set TkCol(grey12) [list 31 31 31]
    set TkCol(grey13) [list 33 33 33]
    set TkCol(grey14) [list 36 36 36]
    set TkCol(grey15) [list 38 38 38]
    set TkCol(grey16) [list 41 41 41]
    set TkCol(grey17) [list 43 43 43]
    set TkCol(grey18) [list 46 46 46]
    set TkCol(grey19) [list 48 48 48]
    set TkCol(grey20) [list 51 51 51]
    set TkCol(grey21) [list 54 54 54]
    set TkCol(grey22) [list 56 56 56]
    set TkCol(grey23) [list 59 59 59]
    set TkCol(grey24) [list 61 61 61]
    set TkCol(grey25) [list 64 64 64]
    set TkCol(grey26) [list 66 66 66]
    set TkCol(grey27) [list 69 69 69]
    set TkCol(grey28) [list 71 71 71]
    set TkCol(grey29) [list 74 74 74]
    set TkCol(grey30) [list 77 77 77]
    set TkCol(grey31) [list 79 79 79]
    set TkCol(grey32) [list 82 82 82]
    set TkCol(grey33) [list 84 84 84]
    set TkCol(grey34) [list 87 87 87]
    set TkCol(grey35) [list 89 89 89]
    set TkCol(grey36) [list 92 92 92]
    set TkCol(grey37) [list 94 94 94]
    set TkCol(grey38) [list 97 97 97]
    set TkCol(grey39) [list 99 99 99]
    set TkCol(grey40) [list 102 102 102]
    set TkCol(grey41) [list 105 105 105]
    set TkCol(grey42) [list 107 107 107]
    set TkCol(grey43) [list 110 110 110]
    set TkCol(grey44) [list 112 112 112]
    set TkCol(grey45) [list 115 115 115]
    set TkCol(grey46) [list 117 117 117]
    set TkCol(grey47) [list 120 120 120]
    set TkCol(grey48) [list 122 122 122]
    set TkCol(grey49) [list 125 125 125]
    set TkCol(grey50) [list 127 127 127]
    set TkCol(grey51) [list 130 130 130]
    set TkCol(grey52) [list 133 133 133]
    set TkCol(grey53) [list 135 135 135]
    set TkCol(grey54) [list 138 138 138]
    set TkCol(grey55) [list 140 140 140]
    set TkCol(grey56) [list 143 143 143]
    set TkCol(grey57) [list 145 145 145]
    set TkCol(grey58) [list 148 148 148]
    set TkCol(grey59) [list 150 150 150]
    set TkCol(grey60) [list 153 153 153]
    set TkCol(grey61) [list 156 156 156]
    set TkCol(grey62) [list 158 158 158]
    set TkCol(grey63) [list 161 161 161]
    set TkCol(grey64) [list 163 163 163]
    set TkCol(grey65) [list 166 166 166]
    set TkCol(grey66) [list 168 168 168]
    set TkCol(grey67) [list 171 171 171]
    set TkCol(grey68) [list 173 173 173]
    set TkCol(grey69) [list 176 176 176]
    set TkCol(grey70) [list 179 179 179]
    set TkCol(grey71) [list 181 181 181]
    set TkCol(grey72) [list 184 184 184]
    set TkCol(grey73) [list 186 186 186]
    set TkCol(grey74) [list 189 189 189]
    set TkCol(grey75) [list 191 191 191]
    set TkCol(grey76) [list 194 194 194]
    set TkCol(grey77) [list 196 196 196]
    set TkCol(grey78) [list 199 199 199]
    set TkCol(grey79) [list 201 201 201]
    set TkCol(grey80) [list 204 204 204]
    set TkCol(grey81) [list 207 207 207]
    set TkCol(grey82) [list 209 209 209]
    set TkCol(grey83) [list 212 212 212]
    set TkCol(grey84) [list 214 214 214]
    set TkCol(grey85) [list 217 217 217]
    set TkCol(grey86) [list 219 219 219]
    set TkCol(grey87) [list 222 222 222]
    set TkCol(grey88) [list 224 224 224]
    set TkCol(grey89) [list 227 227 227]
    set TkCol(grey90) [list 229 229 229]
    set TkCol(grey91) [list 232 232 232]
    set TkCol(grey92) [list 235 235 235]
    set TkCol(grey93) [list 237 237 237]
    set TkCol(grey94) [list 240 240 240]
    set TkCol(grey95) [list 242 242 242]
    set TkCol(grey96) [list 245 245 245]
    set TkCol(grey97) [list 247 247 247]
    set TkCol(grey98) [list 250 250 250]
    set TkCol(grey99) [list 252 252 252]
    set TkCol(grey100) [list 255 255 255]
    set TkCol(honeydew) [list 240 255 240]
    set TkCol(honeydew1) [list 240 255 240]
    set TkCol(honeydew2) [list 224 238 224]
    set TkCol(honeydew3) [list 193 205 193]
    set TkCol(honeydew4) [list 131 139 131]
    set TkCol(hot\ pink) [list 255 105 180]
    set TkCol(HotPink) [list 255 105 180]
    set TkCol(HotPink1) [list 255 110 180]
    set TkCol(HotPink2) [list 238 106 167]
    set TkCol(HotPink3) [list 205 96 144]
    set TkCol(HotPink4) [list 139 58 98]
    set TkCol(indian\ red) [list 205 92 92]
    set TkCol(IndianRed) [list 205 92 92]
    set TkCol(IndianRed1) [list 255 106 106]
    set TkCol(IndianRed2) [list 238 99 99]
    set TkCol(IndianRed3) [list 205 85 85]
    set TkCol(IndianRed4) [list 139 58 58]
    set TkCol(ivory) [list 255 255 240]
    set TkCol(ivory1) [list 255 255 240]
    set TkCol(ivory2) [list 238 238 224]
    set TkCol(ivory3) [list 205 205 193]
    set TkCol(ivory4) [list 139 139 131]
    set TkCol(khaki) [list 240 230 140]
    set TkCol(khaki1) [list 255 246 143]
    set TkCol(khaki2) [list 238 230 133]
    set TkCol(khaki3) [list 205 198 115]
    set TkCol(khaki4) [list 139 134 78]
    set TkCol(lavender) [list 230 230 250]
    set TkCol(lavender\ blush) [list 255 240 245]
    set TkCol(LavenderBlush) [list 255 240 245]
    set TkCol(LavenderBlush1) [list 255 240 245]
    set TkCol(LavenderBlush2) [list 238 224 229]
    set TkCol(LavenderBlush3) [list 205 193 197]
    set TkCol(LavenderBlush4) [list 139 131 134]
    set TkCol(lawn\ green) [list 124 252 0]
    set TkCol(LawnGreen) [list 124 252 0]
    set TkCol(lemon\ chiffon) [list 255 250 205]
    set TkCol(LemonChiffon) [list 255 250 205]
    set TkCol(LemonChiffon1) [list 255 250 205]
    set TkCol(LemonChiffon2) [list 238 233 191]
    set TkCol(LemonChiffon3) [list 205 201 165]
    set TkCol(LemonChiffon4) [list 139 137 112]
    set TkCol(light\ blue) [list 173 216 230]
    set TkCol(light\ coral) [list 240 128 128]
    set TkCol(light\ cyan) [list 224 255 255]
    set TkCol(light\ goldenrod) [list 238 221 130]
    set TkCol(light\ goldenrod\ yellow) [list 250 250 210]
    set TkCol(light\ gray) [list 211 211 211]
    set TkCol(light\ green) [list 144 238 144]
    set TkCol(light\ grey) [list 211 211 211]
    set TkCol(light\ pink) [list 255 182 193]
    set TkCol(light\ salmon) [list 255 160 122]
    set TkCol(light\ sea\ green) [list 32 178 170]
    set TkCol(light\ sky\ blue) [list 135 206 250]
    set TkCol(light\ slate\ blue) [list 132 112 255]
    set TkCol(light\ slate\ gray) [list 119 136 153]
    set TkCol(light\ slate\ grey) [list 119 136 153]
    set TkCol(light\ steel\ blue) [list 176 196 222]
    set TkCol(light\ yellow) [list 255 255 224]
    set TkCol(LightBlue) [list 173 216 230]
    set TkCol(LightBlue1) [list 191 239 255]
    set TkCol(LightBlue2) [list 178 223 238]
    set TkCol(LightBlue3) [list 154 192 205]
    set TkCol(LightBlue4) [list 104 131 139]
    set TkCol(LightCoral) [list 240 128 128]
    set TkCol(LightCyan) [list 224 255 255]
    set TkCol(LightCyan1) [list 224 255 255]
    set TkCol(LightCyan2) [list 209 238 238]
    set TkCol(LightCyan3) [list 180 205 205]
    set TkCol(LightCyan4) [list 122 139 139]
    set TkCol(LightGoldenrod) [list 238 221 130]
    set TkCol(LightGoldenrod1) [list 255 236 139]
    set TkCol(LightGoldenrod2) [list 238 220 130]
    set TkCol(LightGoldenrod3) [list 205 190 112]
    set TkCol(LightGoldenrod4) [list 139 129 76]
    set TkCol(LightGoldenrodYellow) [list 250 250 210]
    set TkCol(LightGray) [list 211 211 211]
    set TkCol(LightGreen) [list 144 238 144]
    set TkCol(LightGrey) [list 211 211 211]
    set TkCol(LightPink) [list 255 182 193]
    set TkCol(LightPink1) [list 255 174 185]
    set TkCol(LightPink2) [list 238 162 173]
    set TkCol(LightPink3) [list 205 140 149]
    set TkCol(LightPink4) [list 139 95 101]
    set TkCol(LightSalmon) [list 255 160 122]
    set TkCol(LightSalmon1) [list 255 160 122]
    set TkCol(LightSalmon2) [list 238 149 114]
    set TkCol(LightSalmon3) [list 205 129 98]
    set TkCol(LightSalmon4) [list 139 87 66]
    set TkCol(LightSeaGreen) [list 32 178 170]
    set TkCol(LightSkyBlue) [list 135 206 250]
    set TkCol(LightSkyBlue1) [list 176 226 255]
    set TkCol(LightSkyBlue2) [list 164 211 238]
    set TkCol(LightSkyBlue3) [list 141 182 205]
    set TkCol(LightSkyBlue4) [list 96 123 139]
    set TkCol(LightSlateBlue) [list 132 112 255]
    set TkCol(LightSlateGray) [list 119 136 153]
    set TkCol(LightSlateGrey) [list 119 136 153]
    set TkCol(LightSteelBlue) [list 176 196 222]
    set TkCol(LightSteelBlue1) [list 202 225 255]
    set TkCol(LightSteelBlue2) [list 188 210 238]
    set TkCol(LightSteelBlue3) [list 162 181 205]
    set TkCol(LightSteelBlue4) [list 110 123 139]
    set TkCol(LightYellow) [list 255 255 224]
    set TkCol(LightYellow1) [list 255 255 224]
    set TkCol(LightYellow2) [list 238 238 209]
    set TkCol(LightYellow3) [list 205 205 180]
    set TkCol(LightYellow4) [list 139 139 122]
    set TkCol(lime\ green) [list 50 205 50]
    set TkCol(LimeGreen) [list 50 205 50]
    set TkCol(linen) [list 250 240 230]
    set TkCol(magenta) [list 255 0 255]
    set TkCol(magenta1) [list 255 0 255]
    set TkCol(magenta2) [list 238 0 238]
    set TkCol(magenta3) [list 205 0 205]
    set TkCol(magenta4) [list 139 0 139]
    set TkCol(maroon) [list 176 48 96]
    set TkCol(maroon1) [list 255 52 179]
    set TkCol(maroon2) [list 238 48 167]
    set TkCol(maroon3) [list 205 41 144]
    set TkCol(maroon4) [list 139 28 98]
    set TkCol(medium\ aquamarine) [list 102 205 170]
    set TkCol(medium\ blue) [list 0 0 205]
    set TkCol(medium\ orchid) [list 186 85 211]
    set TkCol(medium\ purple) [list 147 112 219]
    set TkCol(medium\ sea\ green) [list 60 179 113]
    set TkCol(medium\ slate\ blue) [list 123 104 238]
    set TkCol(medium\ spring\ green) [list 0 250 154]
    set TkCol(medium\ turquoise) [list 72 209 204]
    set TkCol(medium\ violet\ red) [list 199 21 133]
    set TkCol(MediumAquamarine) [list 102 205 170]
    set TkCol(MediumBlue) [list 0 0 205]
    set TkCol(MediumOrchid) [list 186 85 211]
    set TkCol(MediumOrchid1) [list 224 102 255]
    set TkCol(MediumOrchid2) [list 209 95 238]
    set TkCol(MediumOrchid3) [list 180 82 205]
    set TkCol(MediumOrchid4) [list 122 55 139]
    set TkCol(MediumPurple) [list 147 112 219]
    set TkCol(MediumPurple1) [list 171 130 255]
    set TkCol(MediumPurple2) [list 159 121 238]
    set TkCol(MediumPurple3) [list 137 104 205]
    set TkCol(MediumPurple4) [list 93 71 139]
    set TkCol(MediumSeaGreen) [list 60 179 113]
    set TkCol(MediumSlateBlue) [list 123 104 238]
    set TkCol(MediumSpringGreen) [list 0 250 154]
    set TkCol(MediumTurquoise) [list 72 209 204]
    set TkCol(MediumVioletRed) [list 199 21 133]
    set TkCol(midnight\ blue) [list 25 25 112]
    set TkCol(MidnightBlue) [list 25 25 112]
    set TkCol(mint\ cream) [list 245 255 250]
    set TkCol(MintCream) [list 245 255 250]
    set TkCol(misty\ rose) [list 255 228 225]
    set TkCol(MistyRose) [list 255 228 225]
    set TkCol(MistyRose1) [list 255 228 225]
    set TkCol(MistyRose2) [list 238 213 210]
    set TkCol(MistyRose3) [list 205 183 181]
    set TkCol(MistyRose4) [list 139 125 123]
    set TkCol(moccasin) [list 255 228 181]
    set TkCol(navajo\ white) [list 255 222 173]
    set TkCol(NavajoWhite) [list 255 222 173]
    set TkCol(NavajoWhite1) [list 255 222 173]
    set TkCol(NavajoWhite2) [list 238 207 161]
    set TkCol(NavajoWhite3) [list 205 179 139]
    set TkCol(NavajoWhite4) [list 139 121 94]
    set TkCol(navy) [list 0 0 128]
    set TkCol(navy\ blue) [list 0 0 128]
    set TkCol(NavyBlue) [list 0 0 128]
    set TkCol(old\ lace) [list 253 245 230]
    set TkCol(OldLace) [list 253 245 230]
    set TkCol(olive\ drab) [list 107 142 35]
    set TkCol(OliveDrab) [list 107 142 35]
    set TkCol(OliveDrab1) [list 192 255 62]
    set TkCol(OliveDrab2) [list 179 238 58]
    set TkCol(OliveDrab3) [list 154 205 50]
    set TkCol(OliveDrab4) [list 105 139 34]
    set TkCol(orange) [list 255 165 0]
    set TkCol(orange\ red) [list 255 69 0]
    set TkCol(orange1) [list 255 165 0]
    set TkCol(orange2) [list 238 154 0]
    set TkCol(orange3) [list 205 133 0]
    set TkCol(orange4) [list 139 90 0]
    set TkCol(OrangeRed) [list 255 69 0]
    set TkCol(OrangeRed1) [list 255 69 0]
    set TkCol(OrangeRed2) [list 238 64 0]
    set TkCol(OrangeRed3) [list 205 55 0]
    set TkCol(OrangeRed4) [list 139 37 0]
    set TkCol(orchid) [list 218 112 214]
    set TkCol(orchid1) [list 255 131 250]
    set TkCol(orchid2) [list 238 122 233]
    set TkCol(orchid3) [list 205 105 201]
    set TkCol(orchid4) [list 139 71 137]
    set TkCol(pale\ goldenrod) [list 238 232 170]
    set TkCol(pale\ green) [list 152 251 152]
    set TkCol(pale\ turquoise) [list 175 238 238]
    set TkCol(pale\ violet\ red) [list 219 112 147]
    set TkCol(PaleGoldenrod) [list 238 232 170]
    set TkCol(PaleGreen) [list 152 251 152]
    set TkCol(PaleGreen1) [list 154 255 154]
    set TkCol(PaleGreen2) [list 144 238 144]
    set TkCol(PaleGreen3) [list 124 205 124]
    set TkCol(PaleGreen4) [list 84 139 84]
    set TkCol(PaleTurquoise) [list 175 238 238]
    set TkCol(PaleTurquoise1) [list 187 255 255]
    set TkCol(PaleTurquoise2) [list 174 238 238]
    set TkCol(PaleTurquoise3) [list 150 205 205]
    set TkCol(PaleTurquoise4) [list 102 139 139]
    set TkCol(PaleVioletRed) [list 219 112 147]
    set TkCol(PaleVioletRed1) [list 255 130 171]
    set TkCol(PaleVioletRed2) [list 238 121 159]
    set TkCol(PaleVioletRed3) [list 205 104 127]
    set TkCol(PaleVioletRed4) [list 139 71 93]
    set TkCol(papaya\ whip) [list 255 239 213]
    set TkCol(PapayaWhip) [list 255 239 213]
    set TkCol(peach\ puff) [list 255 218 185]
    set TkCol(PeachPuff) [list 255 218 185]
    set TkCol(PeachPuff1) [list 255 218 185]
    set TkCol(PeachPuff2) [list 238 203 173]
    set TkCol(PeachPuff3) [list 205 175 149]
    set TkCol(PeachPuff4) [list 139 119 101]
    set TkCol(peru) [list 205 133 63]
    set TkCol(pink) [list 255 192 203]
    set TkCol(pink1) [list 255 181 197]
    set TkCol(pink2) [list 238 169 184]
    set TkCol(pink3) [list 205 145 158]
    set TkCol(pink4) [list 139 99 108]
    set TkCol(plum) [list 221 160 221]
    set TkCol(plum1) [list 255 187 255]
    set TkCol(plum2) [list 238 174 238]
    set TkCol(plum3) [list 205 150 205]
    set TkCol(plum4) [list 139 102 139]
    set TkCol(powder\ blue) [list 176 224 230]
    set TkCol(PowderBlue) [list 176 224 230]
    set TkCol(purple) [list 160 32 240]
    set TkCol(purple1) [list 155 48 255]
    set TkCol(purple2) [list 145 44 238]
    set TkCol(purple3) [list 125 38 205]
    set TkCol(purple4) [list 85 26 139]
    set TkCol(red) [list 255 0 0]
    set TkCol(red1) [list 255 0 0]
    set TkCol(red2) [list 238 0 0]
    set TkCol(red3) [list 205 0 0]
    set TkCol(red4) [list 139 0 0]
    set TkCol(rosy\ brown) [list 188 143 143]
    set TkCol(RosyBrown) [list 188 143 143]
    set TkCol(RosyBrown1) [list 255 193 193]
    set TkCol(RosyBrown2) [list 238 180 180]
    set TkCol(RosyBrown3) [list 205 155 155]
    set TkCol(RosyBrown4) [list 139 105 105]
    set TkCol(royal\ blue) [list 65 105 225]
    set TkCol(RoyalBlue) [list 65 105 225]
    set TkCol(RoyalBlue1) [list 72 118 255]
    set TkCol(RoyalBlue2) [list 67 110 238]
    set TkCol(RoyalBlue3) [list 58 95 205]
    set TkCol(RoyalBlue4) [list 39 64 139]
    set TkCol(saddle\ brown) [list 139 69 19]
    set TkCol(SaddleBrown) [list 139 69 19]
    set TkCol(salmon) [list 250 128 114]
    set TkCol(salmon1) [list 255 140 105]
    set TkCol(salmon2) [list 238 130 98]
    set TkCol(salmon3) [list 205 112 84]
    set TkCol(salmon4) [list 139 76 57]
    set TkCol(sandy\ brown) [list 244 164 96]
    set TkCol(SandyBrown) [list 244 164 96]
    set TkCol(sea\ green) [list 46 139 87]
    set TkCol(SeaGreen) [list 46 139 87]
    set TkCol(SeaGreen1) [list 84 255 159]
    set TkCol(SeaGreen2) [list 78 238 148]
    set TkCol(SeaGreen3) [list 67 205 128]
    set TkCol(SeaGreen4) [list 46 139 87]
    set TkCol(seashell) [list 255 245 238]
    set TkCol(seashell1) [list 255 245 238]
    set TkCol(seashell2) [list 238 229 222]
    set TkCol(seashell3) [list 205 197 191]
    set TkCol(seashell4) [list 139 134 130]
    set TkCol(sienna) [list 160 82 45]
    set TkCol(sienna1) [list 255 130 71]
    set TkCol(sienna2) [list 238 121 66]
    set TkCol(sienna3) [list 205 104 57]
    set TkCol(sienna4) [list 139 71 38]
    set TkCol(sky\ blue) [list 135 206 235]
    set TkCol(SkyBlue) [list 135 206 235]
    set TkCol(SkyBlue1) [list 135 206 255]
    set TkCol(SkyBlue2) [list 126 192 238]
    set TkCol(SkyBlue3) [list 108 166 205]
    set TkCol(SkyBlue4) [list 74 112 139]
    set TkCol(slate\ blue) [list 106 90 205]
    set TkCol(slate\ gray) [list 112 128 144]
    set TkCol(slate\ grey) [list 112 128 144]
    set TkCol(SlateBlue) [list 106 90 205]
    set TkCol(SlateBlue1) [list 131 111 255]
    set TkCol(SlateBlue2) [list 122 103 238]
    set TkCol(SlateBlue3) [list 105 89 205]
    set TkCol(SlateBlue4) [list 71 60 139]
    set TkCol(SlateGray) [list 112 128 144]
    set TkCol(SlateGray1) [list 198 226 255]
    set TkCol(SlateGray2) [list 185 211 238]
    set TkCol(SlateGray3) [list 159 182 205]
    set TkCol(SlateGray4) [list 108 123 139]
    set TkCol(SlateGrey) [list 112 128 144]
    set TkCol(snow) [list 255 250 250]
    set TkCol(snow1) [list 255 250 250]
    set TkCol(snow2) [list 238 233 233]
    set TkCol(snow3) [list 205 201 201]
    set TkCol(snow4) [list 139 137 137]
    set TkCol(spring\ green) [list 0 255 127]
    set TkCol(SpringGreen) [list 0 255 127]
    set TkCol(SpringGreen1) [list 0 255 127]
    set TkCol(SpringGreen2) [list 0 238 118]
    set TkCol(SpringGreen3) [list 0 205 102]
    set TkCol(SpringGreen4) [list 0 139 69]
    set TkCol(steel\ blue) [list 70 130 180]
    set TkCol(SteelBlue) [list 70 130 180]
    set TkCol(SteelBlue1) [list 99 184 255]
    set TkCol(SteelBlue2) [list 92 172 238]
    set TkCol(SteelBlue3) [list 79 148 205]
    set TkCol(SteelBlue4) [list 54 100 139]
    set TkCol(tan) [list 210 180 140]
    set TkCol(tan1) [list 255 165 79]
    set TkCol(tan2) [list 238 154 73]
    set TkCol(tan3) [list 205 133 63]
    set TkCol(tan4) [list 139 90 43]
    set TkCol(thistle) [list 216 191 216]
    set TkCol(thistle1) [list 255 225 255]
    set TkCol(thistle2) [list 238 210 238]
    set TkCol(thistle3) [list 205 181 205]
    set TkCol(thistle4) [list 139 123 139]
    set TkCol(tomato) [list 255 99 71]
    set TkCol(tomato1) [list 255 99 71]
    set TkCol(tomato2) [list 238 92 66]
    set TkCol(tomato3) [list 205 79 57]
    set TkCol(tomato4) [list 139 54 38]
    set TkCol(turquoise) [list 64 224 208]
    set TkCol(turquoise1) [list 0 245 255]
    set TkCol(turquoise2) [list 0 229 238]
    set TkCol(turquoise3) [list 0 197 205]
    set TkCol(turquoise4) [list 0 134 139]
    set TkCol(violet) [list 238 130 238]
    set TkCol(violet\ red) [list 208 32 144]
    set TkCol(VioletRed) [list 208 32 144]
    set TkCol(VioletRed1) [list 255 62 150]
    set TkCol(VioletRed2) [list 238 58 140]
    set TkCol(VioletRed3) [list 205 50 120]
    set TkCol(VioletRed4) [list 139 34 82]
    set TkCol(wheat) [list 245 222 179]
    set TkCol(wheat1) [list 255 231 186]
    set TkCol(wheat2) [list 238 216 174]
    set TkCol(wheat3) [list 205 186 150]
    set TkCol(wheat4) [list 139 126 102]
    set TkCol(white) [list 255 255 255]
    set TkCol(white\ smoke) [list 245 245 245]
    set TkCol(WhiteSmoke) [list 245 245 245]
    set TkCol(yellow) [list 255 255 0]
    set TkCol(yellow\ green) [list 154 205 50]
    set TkCol(yellow1) [list 255 255 0]
    set TkCol(yellow2) [list 238 238 0]
    set TkCol(yellow3) [list 205 205 0]
    set TkCol(yellow4) [list 139 139 0]
    set TkCol(YellowGreen) [list 154 205 50]

    set ListeTkCol [array names TkCol]

    return $ListeTkCol
}


proc InitHydrophobicityAA4 {} {
    global THydroAA

    # Eisenberg hydrophobicity scale
    # used by macsims
    #
    # Reference:
    # Eisenberg, D., Schwarz, E., Komaromy, M., and Wall, R. (1984).
    # Analysis of membrane and surface protein sequences with the hydrophobic moment plot.
    # /J Mol Biol/, 179(1):125-142.

    set data "A Alanine
0.62
C Cysteine
0.29
D Aspartic acid
-0.90
E Glutamic acid
-0.74
F Phenylalanine
1.19
G Glycine
0.48
H Histidine
-0.40
I Isoleucine
1.38
K Lysine
-1.50
L Leucine
1.06
M Methionine
0.64
N Asparagine
-0.78
P Proline
0.12
Q Glutamine
-0.85
R Arginine
-2.53
S Serine
-0.18
T Threonine
-0.05
V Valine
1.08
W Tryptophan
0.81
Y Tyrosine
0.26"

    set Ldata [split $data \n]
    array set THydroAA {}
    foreach {k v} $Ldata {
	lassign [split $k " "] aa name
	set THydroAA($aa) $v
    }

    return
}


proc InitHydrophobicityAA3 {} {
    global THydroAA

    # Reference
    # Fauchère, J., and Pliska, V. 1983. Hydrophobic parameters {pi} of amino-acid side chains from the partitioning of N-acetyl-amino-acid amides. Eur. J. Med. Chem. 8: 369–375
    set hydro "Ala:
0.310
Arg:
-1.010
Asn:
-0.600
Asp:
-0.770
Cys:
1.540
Gln:
-0.220
Glu:
-0.640
Gly:
0.000
His:
0.130
Ile
1.800
Leu:
1.700
Lys:
-0.990
Met:
1.230
Phe:
1.790
Pro:
0.720
Ser:
-0.040
Thr:
0.260
Trp:
2.250
Tyr:
0.960
Val:
1.220"
    set Lhydro [split $hydro \n]
    foreach {r v} $Lhydro {
	regsub ":" [string trim $r] "" r
	set r [string toupper $r]
	set v [string trim $v]
	set r [AutreCodeLuc $r]
	set THydroAA($r) $v
    }

	return
}


proc InitHydrophobicityAA2 {} {
    global THydroAA

    # Kyte–Doolittle hydrophobicity scale
    # Reference: Kyte J, Doolittle RF. (1982) J. Mol. Biol.
    set hydroScale {
	A 1.8
	R -4.5
	N -3.5
	D -3.5
	C 2.5
	Q -3.5
	E -3.5
	G -0.4
	H -3.2
	I 4.5
	L 3.8
	K -3.9
	M 1.9
	F 2.8
	P -1.6
	S -0.8
	T -0.7
	W -0.9
	Y -1.3
	V 4.2
    }
    
    # Convert list to array
    array set THydroAA $hydroScale

    return
}


proc InitHydrophobicityAA {} {
    global THydroAA

    # Engelman hydrophobicity scales
    # or GES scales
    # 
    # Engelman DM et al, 1986 
    # (cf Biblio/dbs.bib : dbs:gesscales

    array set THydroAA {A -1.6 B 0.0 C -2.0 D 9.2 E 8.2 F -3.7 G -1.0 H 3.0 I -3.1 J 0.0 K 8.8 L -2.8 M -3.4 N 4.8 O 0.0 P 0.2 Q 4.1 R 12.3 S -0.6 T -1.2 U 0.0 V -2.6 W -1.9 X 0.0 Y 0.7 Z 0.0}
    
    return
}


proc InitASA {} {
    global ASAaa ASAan

    set ASAaa(A) 239.0
    set ASAaa(R) 384.1
    set ASAaa(N) 293.2
    set ASAaa(D) 282.4
    set ASAaa(C) 270.2
    set ASAaa(Q) 320.2
    set ASAaa(E) 333.9
    set ASAaa(G) 209.6
    set ASAaa(H) 333.5
    set ASAaa(I) 312.5
    set ASAaa(L) 317.7
    set ASAaa(K) 358.2
    set ASAaa(M) 335.1
    set ASAaa(F) 359.2
    set ASAaa(P) 269.1
    set ASAaa(S) 250.1
    set ASAaa(T) 274.9
    set ASAaa(W) 414.4
    set ASAaa(Y) 371.6
    set ASAaa(V) 286.3

    set ASAan(A) 524.7
    set ASAan(T) 479.6
    set ASAan(C) 485.1
    set ASAan(G) 517.1
    set ASAan(U) 476.1

    return
}


proc InitCode3l1l {} {
    global AutreCodeLuc
    
    set Lcd {I ILE L LEU M MET M MSE V VAL Y TYR Y PTR W TRP C CYH C CYS C SEC R ARG E GLU Q GLN K LYS K LYX D ASP N ASN A ALA F PHE S SER S SEP P PRO P CPR H HIS G GLY T THR T TPO O HOH}
    
    foreach {Nom AA} $Lcd {
	set AutreCodeLuc($AA) $Nom
	if {$AA eq "MSE" || $AA eq "CPR" || $AA eq "CYH" || $AA eq "SEC" || $AA eq "PTR" || $AA eq "SEP" || $AA eq "TPO"} {continue}
	set AutreCodeLuc($Nom) $AA
    }
    
    return
}


proc InitChemicals {} {
    global Chm

    set Chm(Ac,na) 89
    set Chm(Ac,nm) Actinium
    set Chm(Ac,wg) 227
    set Chm(Ac,vdw) 0
    set Chm(Ag,na) 47
    set Chm(Ag,nm) Silver
    set Chm(Ag,wg) 107.8682
    set Chm(Ag,vdw) 1.72
    set Chm(Al,na) 13
    set Chm(Al,nm) Aluminum
    set Chm(Al,wg) 26.9815
    set Chm(Al,vdw) 1.7
    set Chm(Am,na) 95
    set Chm(Am,nm) Americium
    set Chm(Am,wg) 243
    set Chm(Am,vdw) 0
    set Chm(Ar,na) 18
    set Chm(Ar,nm) Argon
    set Chm(Ar,wg) 39.948
    set Chm(Ar,vdw) 1.88
    set Chm(As,na) 33
    set Chm(As,nm) Arsenic
    set Chm(As,wg) 74.9216
    set Chm(As,vdw) 1.85
    set Chm(At,na) 85
    set Chm(At,nm) Astatine
    set Chm(At,wg) 210
    set Chm(At,vdw) 0
    set Chm(Au,na) 79
    set Chm(Au,nm) Gold
    set Chm(Au,wg) 196.9665
    set Chm(Au,vdw) 1.66
    set Chm(B,na) 5
    set Chm(B,nm) Boron
    set Chm(B,wg) 10.811
    set Chm(B,vdw) 1.7
    set Chm(Ba,na) 56
    set Chm(Ba,nm) Barium
    set Chm(Ba,wg) 137.327
    set Chm(Ba,vdw) 0
    set Chm(Be,na) 4
    set Chm(Be,nm) Beryllium
    set Chm(Be,wg) 9.0122
    set Chm(Be,vdw) 1.7
    set Chm(Bh,na) 107
    set Chm(Bh,nm) Bohrium
    set Chm(Bh,wg) 264
    set Chm(Bh,vdw) 0
    set Chm(Bi,na) 83
    set Chm(Bi,nm) Bismuth
    set Chm(Bi,wg) 208.9804
    set Chm(Bi,vdw) 0
    set Chm(Bk,na) 97
    set Chm(Bk,nm) Berkelium
    set Chm(Bk,wg) 247
    set Chm(Bk,vdw) 0
    set Chm(Br,na) 35
    set Chm(Br,nm) Bromine
    set Chm(Br,wg) 79.904
    set Chm(Br,vdw) 1.85
    set Chm(C,na) 6
    set Chm(C,nm) Carbon
    set Chm(C,wg) 12.0107
    set Chm(C,vdw) 1.70
    set Chm(Ca,na) 20
    set Chm(Ca,nm) Calcium
    set Chm(Ca,wg) 40.078
    set Chm(Ca,vdw) 2.23
    set Chm(Cd,na) 48
    set Chm(Cd,nm) Cadmium
    set Chm(Cd,wg) 112.411
    set Chm(Cd,vdw) 1.58
    set Chm(Ce,na) 58
    set Chm(Ce,nm) Cerium
    set Chm(Ce,wg) 140.116
    set Chm(Ce,vdw) 0
    set Chm(Cf,na) 98
    set Chm(Cf,nm) Californium
    set Chm(Cf,wg) 251
    set Chm(Cf,vdw) 0
    set Chm(Cl,na) 17
    set Chm(Cl,nm) Chlorine
    set Chm(Cl,wg) 35.453
    set Chm(Cl,vdw) 1.75
    set Chm(Cm,na) 96
    set Chm(Cm,nm) Curium
    set Chm(Cm,wg) 247
    set Chm(Cm,vdw) 0
    set Chm(Co,na) 27
    set Chm(Co,nm) Cobalt
    set Chm(Co,wg) 58.9332
    set Chm(Co,vdw) 2.23
    set Chm(Cr,na) 24
    set Chm(Cr,nm) Chromium
    set Chm(Cr,wg) 51.9961
    set Chm(Cr,vdw) 2.23
    set Chm(Cs,na) 55
    set Chm(Cs,nm) Cesium
    set Chm(Cs,wg) 132.9055
    set Chm(Cs,vdw) 0
    set Chm(Cu,na) 29
    set Chm(Cu,nm) Copper
    set Chm(Cu,wg) 63.546
    set Chm(Cu,vdw) 1.4
    set Chm(Db,na) 105
    set Chm(Db,nm) Dubnium
    set Chm(Db,wg) 262
    set Chm(Db,vdw) 0
    set Chm(Dy,na) 66
    set Chm(Dy,nm) Dysprosium
    set Chm(Dy,wg) 162.5
    set Chm(Dy,vdw) 0
    set Chm(Er,na) 68
    set Chm(Er,nm) Erbium
    set Chm(Er,wg) 167.259
    set Chm(Er,vdw) 0
    set Chm(Es,na) 99
    set Chm(Es,nm) Einsteinium
    set Chm(Es,wg) 252
    set Chm(Es,vdw) 0
    set Chm(Eu,na) 63
    set Chm(Eu,nm) Europium
    set Chm(Eu,wg) 151.964
    set Chm(Eu,vdw) 0
    set Chm(F,na) 9
    set Chm(F,nm) Fluorine
    set Chm(F,wg) 18.9984
    set Chm(F,vdw) 1.47
    set Chm(Fe,na) 26
    set Chm(Fe,nm) Iron
    set Chm(Fe,wg) 55.845
    set Chm(Fe,vdw) 2.23
    set Chm(Fm,na) 100
    set Chm(Fm,nm) Fermium
    set Chm(Fm,wg) 257
    set Chm(Fm,vdw) 0
    set Chm(Fr,na) 87
    set Chm(Fr,nm) Francium
    set Chm(Fr,wg) 223
    set Chm(Fr,vdw) 0
    set Chm(Ga,na) 31
    set Chm(Ga,nm) Gallium
    set Chm(Ga,wg) 69.723
    set Chm(Ga,vdw) 1.87
    set Chm(Gd,na) 64
    set Chm(Gd,nm) Gadolinium
    set Chm(Gd,wg) 157.25
    set Chm(Gd,vdw) 0
    set Chm(Ge,na) 32
    set Chm(Ge,nm) Germanium
    set Chm(Ge,wg) 72.64
    set Chm(Ge,vdw) 0
    set Chm(H,na) 1
    set Chm(H,nm) Hydrogen
    set Chm(H,wg) 1.0079
    set Chm(H,vdw) 1.2
    set Chm(He,na) 2
    set Chm(He,nm) Helium
    set Chm(He,wg) 4.0026
    set Chm(He,vdw) 1.4
    set Chm(Hf,na) 72
    set Chm(Hf,nm) Hafnium
    set Chm(Hf,wg) 178.49
    set Chm(Hf,vdw) 0
    set Chm(Hg,na) 80
    set Chm(Hg,nm) Mercury
    set Chm(Hg,wg) 200.59
    set Chm(Hg,vdw) 1.55
    set Chm(Ho,na) 67
    set Chm(Ho,nm) Holmium
    set Chm(Ho,wg) 164.9303
    set Chm(Ho,vdw) 0
    set Chm(Hs,na) 108
    set Chm(Hs,nm) Hassium
    set Chm(Hs,wg) 277
    set Chm(Hs,vdw) 0
    set Chm(I,na) 53
    set Chm(I,nm) Iodine
    set Chm(I,wg) 126.9045
    set Chm(I,vdw) 1.98
    set Chm(In,na) 49
    set Chm(In,nm) Indium
    set Chm(In,wg) 114.818
    set Chm(In,vdw) 1.93
    set Chm(Ir,na) 77
    set Chm(Ir,nm) Iridium
    set Chm(Ir,wg) 192.217
    set Chm(Ir,vdw) 0
    set Chm(K,na) 19
    set Chm(K,nm) Potassium
    set Chm(K,wg) 39.0983
    set Chm(K,vdw) 2.75
    set Chm(Kr,na) 36
    set Chm(Kr,nm) Krypton
    set Chm(Kr,wg) 83.8
    set Chm(Kr,vdw) 2.02
    set Chm(La,na) 57
    set Chm(La,nm) Lanthanum
    set Chm(La,wg) 138.9055
    set Chm(La,vdw) 0
    set Chm(Li,na) 3
    set Chm(Li,nm) Lithium
    set Chm(Li,wg) 6.941
    set Chm(Li,vdw) 1.82
    set Chm(Lr,na) 103
    set Chm(Lr,nm) Lawrencium
    set Chm(Lr,wg) 262
    set Chm(Lr,vdw) 0
    set Chm(Lu,na) 71
    set Chm(Lu,nm) Lutetium
    set Chm(Lu,wg) 174.967
    set Chm(Lu,vdw) 0
    set Chm(Md,na) 101
    set Chm(Md,nm) Mendelevium
    set Chm(Md,wg) 258
    set Chm(Md,vdw) 0
    set Chm(Mg,na) 12
    set Chm(Mg,nm) Magnesium
    set Chm(Mg,wg) 24.305
    set Chm(Mg,vdw) 1.73
    set Chm(Mn,na) 25
    set Chm(Mn,nm) Manganese
    set Chm(Mn,wg) 54.938
    set Chm(Mn,vdw) 2.23
    set Chm(Mo,na) 42
    set Chm(Mo,nm) Molybdenum
    set Chm(Mo,wg) 95.94
    set Chm(Mo,vdw) 0
    set Chm(Mt,na) 109
    set Chm(Mt,nm) Meitnerium
    set Chm(Mt,wg) 268
    set Chm(Mt,vdw) 0
    set Chm(N,na) 7
    set Chm(N,nm) Nitrogen
    set Chm(N,wg) 14.0067
    set Chm(N,vdw) 1.55
    set Chm(Na,na) 11
    set Chm(Na,nm) Sodium
    set Chm(Na,wg) 22.9897
    set Chm(Na,vdw) 2.27
    set Chm(Nb,na) 41
    set Chm(Nb,nm) Niobium
    set Chm(Nb,wg) 92.9064
    set Chm(Nb,vdw) 0
    set Chm(Nd,na) 60
    set Chm(Nd,nm) Neodymium
    set Chm(Nd,wg) 144.24
    set Chm(Nd,vdw) 0
    set Chm(Ne,na) 10
    set Chm(Ne,nm) Neon
    set Chm(Ne,wg) 20.1797
    set Chm(Ne,vdw) 0
    set Chm(Ni,na) 28
    set Chm(Ni,nm) Nickel
    set Chm(Ni,wg) 58.6934
    set Chm(Ni,vdw) 1.63
    set Chm(No,na) 102
    set Chm(No,nm) Nobelium
    set Chm(No,wg) 259
    set Chm(No,vdw) 0
    set Chm(Np,na) 93
    set Chm(Np,nm) Neptunium
    set Chm(Np,wg) 237
    set Chm(Np,vdw) 0
    set Chm(O,na) 8
    set Chm(O,nm) Oxygen
    set Chm(O,wg) 15.9994
    set Chm(O,vdw) 1.52
    set Chm(Os,na) 76
    set Chm(Os,nm) Osmium
    set Chm(Os,wg) 190.23
    set Chm(Os,vdw) 0
    set Chm(P,na) 15
    set Chm(P,nm) Phosphorus
    set Chm(P,wg) 30.9738
    set Chm(P,vdw) 1.8
    set Chm(Pa,na) 91
    set Chm(Pa,nm) Protactinium
    set Chm(Pa,wg) 231.0359
    set Chm(Pa,vdw) 0
    set Chm(Pb,na) 82
    set Chm(Pb,nm) Lead
    set Chm(Pb,wg) 207.2
    set Chm(Pb,vdw) 2.02
    set Chm(Pd,na) 46
    set Chm(Pd,nm) Palladium
    set Chm(Pd,wg) 106.42
    set Chm(Pd,vdw) 1.63
    set Chm(Pm,na) 61
    set Chm(Pm,nm) Promethium
    set Chm(Pm,wg) 145
    set Chm(Pm,vdw) 0
    set Chm(Po,na) 84
    set Chm(Po,nm) Polonium
    set Chm(Po,wg) 209
    set Chm(Po,vdw) 0
    set Chm(Pr,na) 59
    set Chm(Pr,nm) Praseodymium
    set Chm(Pr,wg) 140.9077
    set Chm(Pr,vdw) 0
    set Chm(Pt,na) 78
    set Chm(Pt,nm) Platinum
    set Chm(Pt,wg) 195.078
    set Chm(Pt,vdw) 1.75
    set Chm(Pu,na) 94
    set Chm(Pu,nm) Plutonium
    set Chm(Pu,wg) 244
    set Chm(Pu,vdw) 0
    set Chm(Ra,na) 88
    set Chm(Ra,nm) Radium
    set Chm(Ra,wg) 226
    set Chm(Ra,vdw) 0
    set Chm(Rb,na) 37
    set Chm(Rb,nm) Rubidium
    set Chm(Rb,wg) 85.4678
    set Chm(Rb,vdw) 0
    set Chm(Re,na) 75
    set Chm(Re,nm) Rhenium
    set Chm(Re,wg) 186.207
    set Chm(Re,vdw) 0
    set Chm(Rf,na) 104
    set Chm(Rf,nm) Rutherfordium
    set Chm(Rf,wg) 261
    set Chm(Rf,vdw) 0
    set Chm(Rh,na) 45
    set Chm(Rh,nm) Rhodium
    set Chm(Rh,wg) 102.9055
    set Chm(Rh,vdw) 0
    set Chm(Rn,na) 86
    set Chm(Rn,nm) Radon
    set Chm(Rn,wg) 222
    set Chm(Rn,vdw) 0
    set Chm(Ru,na) 44
    set Chm(Ru,nm) Ruthenium
    set Chm(Ru,wg) 101.07
    set Chm(Ru,vdw) 0
    set Chm(S,na) 16
    set Chm(S,nm) Sulfur
    set Chm(S,wg) 32.065
    set Chm(S,vdw) 1.8
    set Chm(Sb,na) 51
    set Chm(Sb,nm) Antimony
    set Chm(Sb,wg) 121.76
    set Chm(Sb,vdw) 0
    set Chm(Sc,na) 21
    set Chm(Sc,nm) Scandium
    set Chm(Sc,wg) 44.9559
    set Chm(Sc,vdw) 2.23
    set Chm(Se,na) 34
    set Chm(Se,nm) Selenium
    set Chm(Se,wg) 78.96
    set Chm(Se,vdw) 1.9
    set Chm(Sg,na) 106
    set Chm(Sg,nm) Seaborgium
    set Chm(Sg,wg) 266
    set Chm(Sg,vdw) 0
    set Chm(Si,na) 14
    set Chm(Si,nm) Silicon
    set Chm(Si,wg) 28.0855
    set Chm(Si,vdw) 2.1
    set Chm(Sm,na) 62
    set Chm(Sm,nm) Samarium
    set Chm(Sm,wg) 150.36
    set Chm(Sm,vdw) 0
    set Chm(Sn,na) 50
    set Chm(Sn,nm) Tin
    set Chm(Sn,wg) 118.71
    set Chm(Sn,vdw) 2.17
    set Chm(Sr,na) 38
    set Chm(Sr,nm) Strontium
    set Chm(Sr,wg) 87.62
    set Chm(Sr,vdw) 0
    set Chm(Ta,na) 73
    set Chm(Ta,nm) Tantalum
    set Chm(Ta,wg) 180.9479
    set Chm(Ta,vdw) 0
    set Chm(Tb,na) 65
    set Chm(Tb,nm) Terbium
    set Chm(Tb,wg) 158.9253
    set Chm(Tb,vdw) 0
    set Chm(Tc,na) 43
    set Chm(Tc,nm) Technetium
    set Chm(Tc,wg) 98
    set Chm(Tc,vdw) 0
    set Chm(Te,na) 52
    set Chm(Te,nm) Tellurium
    set Chm(Te,wg) 127.6
    set Chm(Te,vdw) 2.06
    set Chm(Th,na) 90
    set Chm(Th,nm) Thorium
    set Chm(Th,wg) 232.0381
    set Chm(Th,vdw) 0
    set Chm(Ti,na) 22
    set Chm(Ti,nm) Titanium
    set Chm(Ti,wg) 47.867
    set Chm(Ti,vdw) 2.23
    set Chm(Tl,na) 81
    set Chm(Tl,nm) Thallium
    set Chm(Tl,wg) 204.3833
    set Chm(Tl,vdw) 1.96
    set Chm(Tm,na) 69
    set Chm(Tm,nm) Thulium
    set Chm(Tm,wg) 168.9342
    set Chm(Tm,vdw) 0
    set Chm(U,na) 92
    set Chm(U,nm) Uranium
    set Chm(U,wg) 238.0289
    set Chm(U,vdw) 1.86
    set Chm(V,na) 23
    set Chm(V,nm) Vanadium
    set Chm(V,wg) 50.9415
    set Chm(V,vdw) 2.23
    set Chm(W,na) 74
    set Chm(W,nm) Tungsten
    set Chm(W,wg) 183.84
    set Chm(W,vdw) 0
    set Chm(Xe,na) 54
    set Chm(Xe,nm) Xenon
    set Chm(Xe,wg) 131.293
    set Chm(Xe,vdw) 2.16
    set Chm(Y,na) 39
    set Chm(Y,nm) Yttrium
    set Chm(Y,wg) 88.9059
    set Chm(Y,vdw) 0
    set Chm(Yb,na) 70
    set Chm(Yb,nm) Ytterbium
    set Chm(Yb,wg) 173.04
    set Chm(Yb,vdw) 0
    set Chm(Zn,na) 30
    set Chm(Zn,nm) Zinc
    set Chm(Zn,wg) 65.39
    set Chm(Zn,vdw) 1.39
    set Chm(Zr,na) 40
    set Chm(Zr,nm) Zirconium
    set Chm(Zr,wg) 91.224
    set Chm(Zr,vdw) 0

    foreach v [array names Chm *,na] {
	set na [set Chm($v)]
	lassign [split $v ,] n tmp 
	set r [set Chm($n,vdw)]
	set Chm(${na},vdw) $r
    }

    #SampleVdW
    InitResidueTypes

    return
}


proc NoAtomicDe {e} {
    if {[string length $e] == 2} {
	set e [string totitle $e]
    }
    if {! [info exists ::Chm($e,na)]} {
	return 0
    } else {
	return [set ::Chm($e,na)]
    }
}


proc SymboleDeNoAtomic {na} {
    # element symbol from the atomic number (columns 77-78 of
    # the PDB format), "" if unknown
    global Chm ChmSymbole

    if {! [info exists ChmSymbole]} {
	foreach k [array names Chm "*,na"] {
	    set ChmSymbole($Chm($k)) [lindex [split $k ,] 0]
	}
    }
    if {! [info exists ChmSymbole($na)]} {
	return ""
    }

    return [string toupper $ChmSymbole($na)]
}


proc VdWDe {e} {
    return [set ::Chm($e,vdw)]
}


proc InitMasses {} {
    global TMassesAA

    set TMassesAA(A)	71.0788
    set TMassesAA(R) 156.1875
    set TMassesAA(N) 114.1038
    set TMassesAA(D) 115.0886
    set TMassesAA(C) 103.1388
    set TMassesAA(E) 129.1155
    set TMassesAA(Q) 128.1307
    set TMassesAA(G)  57.0519
    set TMassesAA(H) 137.1411
    set TMassesAA(I) 113.1594
    set TMassesAA(L) 113.1594
    set TMassesAA(K) 128.1741
    set TMassesAA(M) 131.1926
    set TMassesAA(F) 147.1766
    set TMassesAA(P)  97.1167
    set TMassesAA(S)  87.0782
    set TMassesAA(T) 101.1051
    set TMassesAA(W) 186.2132
    set TMassesAA(Y) 163.1760
    set TMassesAA(V)  99.1326
    set TMassesAA(U) 150.0388
    set TMassesAA(O) 237.3018

    set TMassesAA(B) [expr {($TMassesAA(D)+$TMassesAA(N))/2.}]
    set TMassesAA(Z) [expr {($TMassesAA(E)+$TMassesAA(Q))/2.}]
    set TMassesAA(J) [expr {($TMassesAA(I)+$TMassesAA(L))/2.}]
    set TMassesAA(X)   0.0
    set TMassesAA(x)   0.0

    set TMassesAA(H2O)	18.01524

    return
}


proc CreateMapping {FileOrLines} {
    if {[file exists $FileOrLines]} {
	set Lignes [LesLignesDuFichier $FileOrLines]
    } elseif {[string first "\n" $FileOrLines] != -1} {
	set Lignes [split $FileOrLines \n]
    } else {
	if {[llength $FileOrLines] == 0 || $FileOrLines eq ""} {
	    FaireLire "Error ! Bad mapping file !"
	    return
	}
	set Lignes $FileOrLines
    }

    set Lmap {}
    set isSpace 0 ; set isPoint 0
    foreach l $Lignes {
	regsub -all { +} [string trim $l] " " l
	lassign [split $l " "] n f b
	if {[string tolower $n] eq "space"} {
	    set n " "
	    set isSpace 1
	}
	if {$n eq "."} {
	    set isPoint 1
	}
	lappend Lmap [list $n $f $b]
    }
    if {! $isPoint} {
	lappend Lmap [list "." black dimgrey]
    }
    if {! $isSpace} {
	lappend Lmap [list " " white white]
    }    

    return $Lmap
    }


proc EditorMappingData {} {
    if {[info exists ::TypeSeq] && $::TypeSeq eq "DNA"} {
	set Lignes "A white red
    G black orange
    C white blue
    T black green1
    U black green1
    X black white
    N white black
    . white black
    Space white white"
    } else {
	# protein default
	set Lignes "I white magenta
    J white magenta
    L white magenta
    M white magenta
    V white magenta
    R white blue
    K white blue
    F white red
    Y white red
    W white red
    D white forestgreen
    B white forestgreen
    E white forestgreen
    Z black green1
    Q black green1
    P white black
    G black orange
    H black cyan
    N black cyan
    S white darkviolet
    T white darkviolet
    A white darkviolet
    U white darkviolet
    C white darkviolet
    X black dimgrey
    . black dimgrey
    0 black white
    1 black white
    2 black white
    3 black white
    4 black white
    5 black white
    6 black white
    7 black white
    8 black white
    9 black white
    Space dimgrey dimgrey"
    }

    set Lmap [CreateMapping $Lignes]
    set LmapBW {}
    foreach a {A B C D E F G H I J K L M N P Q R S T U V W Y "." " "} {
	lappend LmapBW [list $a black white]
    }
    LesDefauts MappingBW $LmapBW

    return $Lmap
}


proc ColorBlindMappingData {} {
    # residues mapping with colors adapted for
    # colorblind people (daltoniens).
    # Given by M. Sissler

    set txt "S white #7B3294
T white #7B3294
A white #7B3294
C white #7B3294
I white #CC79A7
L white #CC79A7
M white #CC79A7
V white #CC79A7
F white #E69F00
Y white #E69F00
W white #E69F00
R white #0072B2
K white #0072B2
H black #56B4E9
N black #56B4E9
D white #009E73
E white #009E73
Q black #7F7F7F
P white #000000
G black #F0E442
Space white white"
    
    set Lmap [CreateMapping $txt]

    return $Lmap
}


proc DonneResidueType {r} {
    if {[info exists ::TResidueType([string trim $r],type)]} {
	return [set ::TResidueType([string trim $r],type)]
    } else {
	return "ligand"
    }
}


proc InitResidueTypes {} {
    global OrdEtcDir TResidueType
    
    set Ll [LesLignesDuFichier [file join $OrdEtcDir "comp.txt"]]
    foreach l $Ll {
	lassign [split $l \t] res type tmp code
	set TResidueType($res,code1l) $code
	set type [string trim [string map [list ' "" \" "" - " "] $type]]
	if {[regexp {LINKING|TERMINUS} $type]} {
	    if {[regexp {PEPTIDE} $type]} {
		set TResidueType($res,type) "Protein"
	    } elseif {[regexp {RNA|DNA} $type]} {
		set TResidueType($res,type) "Nucleic"
	    } else {
		set TResidueType($res,type) "ligand"
	    }
	} else {
	    set TResidueType($res,type) "ligand"
	}
	    
	lappend Lt $type
    }

    return
}


proc CreeImagesDeFonte {} {
    package require Tk
    #package require Img
    
    set Lignes "I white magenta
    J white magenta
    L white magenta
    M white magenta
    V white magenta
    R white blue
    K white blue
    F white red
    Y white red
    W white red
    D white forestgreen
    B white forestgreen
    E white forestgreen
    Z black green1
    Q black green1
    P white black
    G black orange
    H black cyan
    N black cyan
    S white darkviolet
    T white darkviolet
    A white darkviolet
    U white darkviolet
    C white darkviolet
    X black dimgrey
    . black dimgrey
    0 black white
    1 black white
    2 black white
    3 black white
    4 black white
    5 black white
    6 black white
    7 black white
    8 black white
    9 black white
    Space white white"

    set Lmap {}
    foreach l [split $Lignes \n] {
	lassign [split [string trim $l] " "] n f b
	lappend Lmap [list $n $f $b]
    }

    font create FonteImg -family CourierNew -size 8 -weight normal

    set w ".b"
    label $w \
	    -font FonteImg \
	    -bd 0 \
	    -padx 0 -pady 0 \
	    -width 1 -height 1 \
	    -anchor <center
    pack $w
    update idletasks
    
    foreach size {6 8 10 12 14 16 18 20} {
	font configure FonteImg -size $size

	file mkdir [file join CN $size]
	foreach e $Lmap {
	    lassign $e n f b
	    if {$n eq "Space"} {
		set c " "
	    } else {
		set c $n
	    }
	    $w configure \
		    -bg $b -fg $f \
		    -text "$c"
	    update idletasks
	    after 200
	    set img "CN_${size}_$n"

	    image create photo $img \
		    -format window -data $w
	    update idletasks
	    set f [file join CN $size $img.png]
	    $img write $f -format png
	}
    }

    font delete FonteImg

    exit
}


proc InitClustalMatrix {mat {positive 0} {scale 100} {Centre 0}} {
    # Taken from matrices.h from ClustalW source sode 
    # with kind permissions of J.D. Thompson.
    
    set amino_acid_order "ABCDEFGHIKLMNPQRSTVWXYZ"

    set Tmat(blosum30) "
    4,
    0,  5,
    -3, -2, 17,
    0,  5, -3,  9,
    0,  0,  1,  1,  6,
    -2, -3, -3, -5, -4, 10,
    0,  0, -4, -1, -2, -3,  8,
    -2, -2, -5, -2,  0, -3, -3, 14,
    0, -2, -2, -4, -3,  0, -1, -2,  6,
    0,  0, -3,  0,  2, -1, -1, -2, -2,  4,
    -1, -1,  0, -1, -1,  2, -2, -1,  2, -2,  4,
    1, -2, -2, -3, -1, -2, -2,  2,  1,  2,  2,  6,
    0,  4, -1,  1, -1, -1,  0, -1,  0,  0, -2,  0,  8,
    -1, -2, -3, -1,  1, -4, -1,  1, -3,  1, -3, -4, -3, 11,
    1, -1, -2, -1,  2, -3, -2,  0, -2,  0, -2, -1, -1,  0,  8,
    -1, -2, -2, -1, -1, -1, -2, -1, -3,  1, -2,  0, -2, -1,  3,  8,
    1,  0, -2,  0,  0, -1,  0, -1, -1,  0, -2, -2,  0, -1, -1, -1,  4,
    1,  0, -2, -1, -2, -2, -2, -2,  0, -1,  0,  0,  1,  0,  0, -3,  2,  5,
    1, -2, -2, -2, -3,  1, -3, -3,  4, -2,  1,  0, -2, -4, -3, -1, -1,  1,  5,
    -5, -5, -2, -4, -1,  1,  1, -5, -3, -2, -2, -3, -7, -3, -1,  0, -3, -5, -3, 20,
    0, -1, -2, -1, -1, -1, -1, -1,  0,  0,  0,  0,  0, -1,  0, -1,  0,  0,  0, -2, -1,
    -4, -3, -6, -1, -2,  3, -3,  0, -1, -1,  3, -1, -4, -2, -1,  0, -2, -1,  1,  5, -1,  9,
    0,  0,  0,  0,  5, -4, -2,  0, -3,  1, -1, -1, -1,  0,  4,  0, -1, -1, -3, -1,  0, -2,  4"
    
    set Tmat(blosum40) "
    5,
    -1,  5,
    -2, -2, 16,
    -1,  6, -2,  9,
    -1,  1, -2,  2,  7,
    -3, -3, -2, -4, -3,  9,
    1, -1, -3, -2, -3, -3,  8,
    -2,  0, -4,  0,  0, -2, -2, 13,
    -1, -3, -4, -4, -4,  1, -4, -3,  6,
    -1,  0, -3,  0,  1, -3, -2, -1, -3,  6,
    -2, -3, -2, -3, -2,  2, -4, -2,  2, -2,  6,
    -1, -3, -3, -3, -2,  0, -2,  1,  1, -1,  3,  7,
    -1,  4, -2,  2, -1, -3,  0,  1, -2,  0, -3, -2,  8,
    -2, -2, -5, -2,  0, -4, -1, -2, -2, -1, -4, -2, -2, 11,
    0,  0, -4, -1,  2, -4, -2,  0, -3,  1, -2, -1,  1, -2,  8,
    -2, -1, -3, -1, -1, -2, -3,  0, -3,  3, -2, -1,  0, -3,  2,  9,
    1,  0, -1,  0,  0, -2,  0, -1, -2,  0, -3, -2,  1, -1,  1, -1,  5,
    0,  0, -1, -1, -1, -1, -2, -2, -1,  0, -1, -1,  0,  0, -1, -2,  2,  6,
    0, -3, -2, -3, -3,  0, -4, -4,  4, -2,  2,  1, -3, -3, -3, -2, -1,  1,  5,
    -3, -4, -6, -5, -2,  1, -2, -5, -3, -2, -1, -2, -4, -4, -1, -2, -5, -4, -3, 19,
    0, -1, -2, -1, -1, -1, -1, -1, -1, -1, -1,  0, -1, -2, -1, -1,  0,  0, -1, -2, -1,
    -2, -3, -4, -3, -2,  4, -3,  2,  0, -1,  0,  1, -2, -3, -1, -1, -2, -1, -1,  3, -1,  9,
    -1,  2, -3,  1,  5, -4, -2,  0, -4,  1, -2, -2,  0, -1,  4,  0,  0, -1, -3, -2, -1, -2,  5"
    
    set Tmat(blosum45) "
    5,
    -1,  4,
    -1, -2, 12,
    -2,  5, -3,  7,
    -1,  1, -3,  2,  6,
    -2, -3, -2, -4, -3,  8,
    0, -1, -3, -1, -2, -3,  7,
    -2,  0, -3,  0,  0, -2, -2, 10,
    -1, -3, -3, -4, -3,  0, -4, -3,  5,
    -1,  0, -3,  0,  1, -3, -2, -1, -3,  5,
    -1, -3, -2, -3, -2,  1, -3, -2,  2, -3,  5,
    -1, -2, -2, -3, -2,  0, -2,  0,  2, -1,  2,  6,
    -1,  4, -2,  2,  0, -2,  0,  1, -2,  0, -3, -2,  6,
    -1, -2, -4, -1,  0, -3, -2, -2, -2, -1, -3, -2, -2,  9,
    -1,  0, -3,  0,  2, -4, -2,  1, -2,  1, -2,  0,  0, -1,  6,
    -2, -1, -3, -1,  0, -2, -2,  0, -3,  3, -2, -1,  0, -2,  1,  7,
    1,  0, -1,  0,  0, -2,  0, -1, -2, -1, -3, -2,  1, -1,  0, -1,  4,
    0,  0, -1, -1, -1, -1, -2, -2, -1, -1, -1, -1,  0, -1, -1, -1,  2,  5,
    0, -3, -1, -3, -3,  0, -3, -3,  3, -2,  1,  1, -3, -3, -3, -2, -1,  0,  5,
    -2, -4, -5, -4, -3,  1, -2, -3, -2, -2, -2, -2, -4, -3, -2, -2, -4, -3, -3, 15,
    0, -1, -2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -2, -1,
    -2, -2, -3, -2, -2,  3, -3,  2,  0, -1,  0,  0, -2, -3, -1, -1, -2, -1, -1,  3, -1,  8,
    -1,  2, -3,  1,  4, -3, -2,  0, -3,  1, -2, -1,  0, -1,  4,  0,  0, -1, -3, -2, -1, -2,  4"

    set Tmat(blosum62) "
    8,
    -4,  8,
    0, -6, 18,
    -4,  8, -6, 12,
    -2,  2, -8,  4, 10,
    -4, -6, -4, -6, -6, 12,
    0, -2, -6, -2, -4, -6, 12,
    -4,  0, -6, -2,  0, -2, -4, 16,
    -2, -6, -2, -6, -6,  0, -8, -6,  8,
    -2,  0, -6, -2,  2, -6, -4, -2, -6, 10,
    -2, -8, -2, -8, -6,  0, -8, -6,  4, -4,  8,
    -2, -6, -2, -6, -4,  0, -6, -4,  2, -2,  4, 10,
    -4,  6, -6,  2,  0, -6,  0,  2, -6,  0, -6, -4, 12,
    -2, -4, -6, -2, -2, -8, -4, -4, -6, -2, -6, -4, -4, 14,
    -2,  0, -6,  0,  4, -6, -4,  0, -6,  2, -4,  0,  0, -2, 10,
    -2, -2, -6, -4,  0, -6, -4,  0, -6,  4, -4, -2,  0, -4,  2, 10,
    2,  0, -2,  0,  0, -4,  0, -2, -4,  0, -4, -2,  2, -2,  0, -2,  8,
    0, -2, -2, -2, -2, -4, -4, -4, -2, -2, -2, -2,  0, -2, -2, -2,  2, 10,
    0, -6, -2, -6, -4, -2, -6, -6,  6, -4,  2,  2, -6, -4, -4, -6, -4,  0,  8,
    -6, -8, -4, -8, -6,  2, -4, -4, -6, -6, -4, -2, -8, -8, -4, -6, -6, -4, -6, 22,
    0, -2, -4, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -4, -2, -2,  0,  0, -2, -4, -2,
    -4, -6, -4, -6, -4,  6, -6,  4, -2, -4, -2, -2, -4, -6, -2, -4, -4, -4, -2,  4, -2, 14,
    -2,  2, -6,  2,  8, -6, -4,  0, -6,  2, -6, -2,  0, -2,  6,  0,  0, -2, -4, -6, -2, -4,  8"
    
    set Tmat(blosum80) "
    7,
    -3,  6,
    -1, -6, 13,
    -3,  6, -7, 10,
    -2,  1, -7,  2,  8,
    -4, -6, -4, -6, -6, 10,
    0, -2, -6, -3, -4, -6,  9,
    -3, -1, -7, -2,  0, -2, -4, 12,
    -3, -6, -2, -7, -6, -1, -7, -6,  7,
    -1, -1, -6, -2,  1, -5, -3, -1, -5,  8,
    -3, -7, -3, -7, -6,  0, -7, -5,  2, -4,  6,
    -2, -5, -3, -6, -4,  0, -5, -4,  2, -3,  3,  9,
    -3,  5, -5,  2, -1, -6, -1,  1, -6,  0, -6, -4,  9,
    -1, -4, -6, -3, -2, -6, -5, -4, -5, -2, -5, -4, -4, 12,
    -2, -1, -5, -1,  3, -5, -4,  1, -5,  2, -4, -1,  0, -3,  9,
    -3, -2, -6, -3, -1, -5, -4,  0, -5,  3, -4, -3, -1, -3,  1,  9,
    2,  0, -2, -1, -1, -4, -1, -2, -4, -1, -4, -3,  1, -2, -1, -2,  7,
    0, -1, -2, -2, -2, -4, -3, -3, -2, -1, -3, -1,  0, -3, -1, -2,  2,  8,
    -1, -6, -2, -6, -4, -2, -6, -5,  4, -4,  1,  1, -5, -4, -4, -4, -3,  0,  7,
    -5, -8, -5, -8, -6,  0, -6, -4, -5, -6, -4, -3, -7, -7, -4, -5, -6, -5, -5, 16,
    -1, -3, -4, -3, -2, -3, -3, -2, -2, -2, -2, -2, -2, -3, -2, -2, -1, -1, -2, -5, -2,
    -4, -5, -5, -6, -5,  4, -6,  3, -3, -4, -2, -3, -4, -6, -3, -4, -3, -3, -3,  3, -3, 11,
    -2,  0, -7,  1,  6, -6, -4,  0, -6,  1, -5, -3, -1, -2,  5,  0, -1, -2, -4, -5, -1, -4,  6"
    
    set Tmat(pam20) "
    6,
    -5,  6,
    -8,-14, 10,
    -4,  6,-16,  8,
    -3,  0,-16,  2,  8,
    -9,-12,-15,-17,-16,  9,
    -3, -4,-11, -4, -5,-10,  7,
    -8, -2, -8, -5, -6, -7,-10,  9,
    -6, -7, -7, -9, -6, -3,-13,-11,  9,
    -8, -3,-16, -6, -5,-16, -8, -8, -7,  7,
    -7,-10,-17,-15,-10, -4,-12, -7, -2, -9,  7,
    -6,-12,-16,-13, -8, -5,-10,-13, -2, -3,  0, 11,
    -5,  6,-13,  1, -3,-10, -4, -1, -6, -2, -8,-11,  8,
    -2, -8, -9, -9, -7,-11, -7, -5,-10, -8, -8, -9, -7,  8,
    -5, -4,-16, -4,  0,-15, -8,  0, -9, -4, -6, -5, -5, -4,  9,
    -8, -9, -9,-12,-11,-10,-11, -3, -6, -1,-10, -5, -7, -5, -2,  9,
    -1, -2, -4, -5, -5, -7, -3, -7, -8, -5, -9, -6, -1, -3, -6, -4,  7,
    -1, -4, -9, -6, -7,-10, -7, -8, -3, -4, -8, -5, -3, -5, -7, -8,  0,  7,
    -3, -9, -7, -9, -8, -9, -7, -7,  1,-10, -3, -2, -9, -7, -8, -9, -8, -4,  7,
    -16,-11,-18,-17,-19, -6,-17, -8,-16,-14, -7,-15, -9,-16,-15, -3, -6,-15,-18, 13,
    -4, -6,-11, -7, -6, -9, -6, -6, -6, -6, -7, -6, -4, -6, -6, -7, -4, -5, -6,-13, -6,
    -9, -7, -5,-13, -9,  1,-16, -4, -7,-10, -8,-13, -5,-16,-14,-11, -8, -7, -8, -6, -9, 10,
    -4, -1,-16,  0,  6,-16, -6, -2, -7, -5, -8, -6, -4, -5,  7, -5, -6, -7, -8,-17, -6,-11,  6"
    
    set Tmat(pam60) "
    5,
    -2,  5,
    -5, -9,  9,
    -2,  5,-10,  7,
    -1,  2,-10,  3,  7,
    -6, -8, -9,-11,-10,  8,
    0, -2, -7, -2, -2, -7,  6,
    -5,  0, -6, -2, -3, -4, -6,  8,
    -3, -4, -4, -5, -4, -1, -7, -6,  7,
    -5, -1,-10, -2, -3,-10, -5, -4, -4,  6,
    -4, -7,-11, -9, -7, -1, -8, -4,  0, -6,  6,
    -3, -6,-10, -7, -5, -2, -6, -7,  1,  0,  2, 10,
    -2,  5, -7,  2,  0, -6, -1,  1, -4,  0, -5, -6,  6,
    0, -4, -6, -5, -3, -7, -4, -2, -6, -4, -5, -6, -4,  7,
    -3, -1,-10, -1,  2, -9, -5,  2, -5, -1, -3, -2, -2, -1,  7,
    -5, -5, -6, -6, -6, -7, -7,  0, -4,  2, -6, -2, -3, -2,  0,  8,
    1,  0, -1, -2, -2, -5,  0, -4, -4, -2, -6, -4,  1,  0, -3, -2,  5,
    1, -2, -5, -3, -4, -6, -3, -5, -1, -2, -5, -2, -1, -2, -4, -4,  1,  6,
    -1, -5, -4, -6, -4, -5, -4, -5,  3, -6, -1,  0, -5, -4, -5, -5, -4, -1,  6,
    -10, -8,-12,-11,-12, -3,-11, -5,-10, -8, -4, -9, -6,-10, -9,  0, -4, -9,-11, 13,
    -2, -3, -6, -3, -3, -5, -3, -3, -3, -3, -4, -3, -2, -3, -3, -4, -2, -2, -3, -8, -3,
    -6, -5, -2, -8, -7,  3,-10, -2, -4, -7, -5, -7, -3,-10, -8, -8, -5, -5, -5, -3, -5,  9,
    -2,  1,-10,  2,  5,-10, -3,  0, -4, -2, -5, -4, -1, -2,  6, -2, -3, -4, -5,-11, -3, -7,  5"
    
    set Tmat(pam120) "
    3,
    0,  4,
    -3, -6,  9,
    0,  4, -7,  5,
    0,  3, -7,  3,  5,
    -4, -5, -6, -7, -7,  8,
    1,  0, -4,  0, -1, -5,  5,
    -3,  1, -4,  0, -1, -3, -4,  7,
    -1, -3, -3, -3, -3,  0, -4, -4,  6,
    -2,  0, -7, -1, -1, -7, -3, -2, -3,  5,
    -3, -4, -7, -5, -4,  0, -5, -3,  1, -4,  5,
    -2, -4, -6, -4, -3, -1, -4, -4,  1,  0,  3,  8,
    -1,  3, -5,  2,  1, -4,  0,  2, -2,  1, -4, -3,  4,
    1, -2, -4, -3, -2, -5, -2, -1, -3, -2, -3, -3, -2,  6,
    -1,  0, -7,  1,  2, -6, -3,  3, -3,  0, -2, -1,  0,  0,  6,
    -3, -2, -4, -3, -3, -5, -4,  1, -2,  2, -4, -1, -1, -1,  1,  6,
    1,  0,  0,  0, -1, -3,  1, -2, -2, -1, -4, -2,  1,  1, -2, -1,  3,
    1,  0, -3, -1, -2, -4, -1, -3,  0, -1, -3, -1,  0, -1, -2, -2,  2,  4,
    0, -3, -3, -3, -3, -3, -2, -3,  3, -4,  1,  1, -3, -2, -3, -3, -2,  0,  5,
    -7, -6, -8, -8, -8, -1, -8, -3, -6, -5, -3, -6, -4, -7, -6,  1, -2, -6, -8, 12,
    -1, -1, -4, -2, -1, -3, -2, -2, -1, -2, -2, -2, -1, -2, -1, -2, -1, -1, -1, -5, -2,
    -4, -3, -1, -5, -5,  4, -6, -1, -2, -5, -2, -4, -2, -6, -5, -5, -3, -3, -3, -2, -3,  8,
    -1,  2, -7,  3,  4, -6, -2,  1, -3, -1, -3, -2,  0, -1,  4, -1, -1, -2, -3, -7, -1, -5,  4"
    

    set Tmat(pam250) "
    2,
    0,  3,
    -2, -4, 12,
    0,  3, -5,  4,
    0,  3, -5,  3,  4,
    -3, -4, -4, -6, -5,  9,
    1,  0, -3,  1,  0, -5,  5,
    -1,  1, -3,  1,  1, -2, -2,  6,
    -1, -2, -2, -2, -2,  1, -3, -2,  5,
    -1,  1, -5,  0,  0, -5, -2,  0, -2,  5,
    -2, -3, -6, -4, -3,  2, -4, -2,  2, -3,  6,
    -1, -2, -5, -3, -2,  0, -3, -2,  2,  0,  4,  6,
    0,  2, -4,  2,  1, -3,  0,  2, -2,  1, -3, -2,  2,
    1, -1, -3, -1, -1, -5,  0,  0, -2, -1, -3, -2,  0,  6,
    0,  1, -5,  2,  2, -5, -1,  3, -2,  1, -2, -1,  1,  0,  4,
    -2, -1, -4, -1, -1, -4, -3,  2, -2,  3, -3,  0,  0,  0,  1,  6,
    1,  0,  0,  0,  0, -3,  1, -1, -1,  0, -3, -2,  1,  1, -1,  0,  2,
    1,  0, -2,  0,  0, -3,  0, -1,  0,  0, -2, -1,  0,  0, -1, -1,  1,  3,
    0, -2, -2, -2, -2, -1, -1, -2,  4, -2,  2,  2, -2, -1, -2, -2, -1,  0,  4,
    -6, -5, -8, -7, -7,  0, -7, -3, -5, -3, -2, -4, -4, -6, -5,  2, -2, -5, -6, 17,
    0, -1, -3, -1, -1, -2, -1, -1, -1, -1, -1, -1,  0, -1, -1, -1,  0,  0, -1, -4, -1,
    -3, -3,  0, -4, -4,  7, -5,  0, -1, -4, -1, -2, -2, -5, -4, -4, -3, -3, -2,  0, -2, 10,
    0,  2, -5,  3,  3, -5,  0,  2, -2,  0, -3, -2,  1,  0,  3,  0,  0, -1, -2, -6, -1, -4,  3"
    
    set Tmat(pam350) "
    2,
    1,  3,
    -2, -5, 18,
    1,  3, -6,  4,
    1,  3, -6,  4,  4,
    -4, -5, -5, -6, -6, 13,
    2,  1, -4,  1,  1, -6,  5,
    -1,  1, -4,  1,  1, -2, -2,  7,
    0, -2, -3, -2, -2,  2, -2, -2,  5,
    -1,  1, -6,  1,  0, -6, -1,  1, -2,  5,
    -2, -4, -7, -4, -4,  3, -4, -2,  4, -3,  8,
    -1, -2, -6, -3, -2,  1, -3, -2,  3,  0,  5,  6,
    0,  2, -4,  2,  2, -4,  1,  2, -2,  1, -3, -2,  2,
    1,  0, -3,  0,  0, -5,  0,  0, -2, -1, -3, -2,  0,  6,
    0,  2, -6,  2,  3, -5, -1,  3, -2,  1, -2, -1,  1,  1,  4,
    -1,  0, -4, -1,  0, -5, -2,  2, -2,  4, -3,  0,  1,  0,  2,  7,
    1,  1,  0,  1,  0, -4,  1, -1, -1,  0, -3, -2,  1,  1,  0,  0,  1,
    1,  0, -2,  0,  0, -3,  1, -1,  0,  0, -2, -1,  1,  1,  0, -1,  1,  2,
    0, -2, -2, -2, -2, -1, -1, -2,  4, -2,  3,  2, -2, -1, -2, -3, -1,  0,  5,
    -7, -6,-10, -8, -8,  1, -8, -3, -6, -4, -2, -5, -5, -7, -5,  4, -3, -6, -7, 27,
    0,  0, -3, -1,  0, -2, -1,  0,  0, -1, -1,  0,  0,  0,  0, -1,  0,  0,  0, -5, -1,
    -4, -4,  1, -5, -5, 11, -6,  0,  0, -5,  0, -2, -3, -6, -5, -5, -3, -3, -2,  1, -2, 14,
    0,  2, -6,  3,  3, -6,  0,  2, -2,  1, -3, -2,  2,  0,  3,  1,  0,  0, -2, -7,  0, -5,  3"
    
    set Tmat(idmat) "
    10,
    0, 10,
    0, 0, 10,
    0, 0, 0, 10,
    0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,10"
    
    set Tmat(gon40) "
    92,
    0,   0,
    -31,   0, 163,
    -56,   0,-135, 111,
    -37,   0,-140,  16, 105,
    -92,   0, -64,-152,-143, 126,
    -32,   0, -91, -51, -76,-152, 105,
    -65,   0, -67, -41, -40, -50, -81, 145,
    -76,   0, -87,-150,-106, -39,-158, -94, 104,
    -54,   0,-132, -47, -13,-127, -79, -34, -86, 103,
    -68,   0, -85,-155,-108, -13,-141, -85,   5, -85,  89,
    -45,   0, -63,-130, -80, -16,-114, -60,  10, -57,  16, 140,
    -62,   0, -83,   6, -38,-104, -40,  -7, -99, -20,-112, -91, 115,
    -37,   0,-137, -69, -60,-128, -87, -71,-108, -62, -83,-119, -78, 124,
    -43,   0,-113, -32,  10,-100, -71,   0, -91,   2, -60, -35, -25, -46, 118,
    -61,   0, -86, -77, -50,-130, -69, -31,-103,  19, -84, -81, -47, -73,  -6, 112,
    0,   0, -35, -36, -41,-111, -37, -48, -95, -43, -95, -64, -11, -35, -35, -51,  99,
    -25,   0, -59, -47, -52, -90, -85, -46, -51, -34, -78, -44, -27, -42, -39, -52,  13, 100,
    -22,   0, -43,-133, -74, -58,-122, -98,  28, -82, -18, -22,-103, -86, -79, -88, -74, -25,  97,
    -120,   0, -68,-171,-131,  -6,-108, -70, -93,-127, -71, -72,-119,-149, -87, -63, -98,-120,-115, 181,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -95,   0, -56, -98,-107,  31,-129,   5, -76, -88, -64, -66, -62,-106, -81, -75, -69, -87, -73,   1,   0, 135,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"
    
    set Tmat(gon80) "
    75,
    0,   0,
    -10,   0, 154,
    -31,   0, -93,  96,
    -17,   0, -94,  31,  88,
    -64,   0, -39,-111,-102, 114,
    -11,   0, -61, -26, -47,-115,  97,
    -39,   0, -43, -17, -17, -26, -53, 127,
    -43,   0, -54,-106, -73, -15,-114, -64,  86,
    -30,   0, -88, -21,   4, -89, -50, -12, -59,  85,
    -43,   0, -55,-109, -75,   7,-104, -57,  22, -58,  77,
    -26,   0, -39, -88, -53,   3, -83, -38,  25, -37,  31, 117,
    -34,   0, -55,  21, -13, -75, -18,   9, -71,  -2, -79, -62,  97,
    -16,   0, -93, -42, -35, -93, -58, -45, -75, -37, -58, -78, -48, 114,
    -22,   0, -76,  -9,  23, -70, -44,  14, -60,  17, -39, -19,  -6, -24,  95,
    -36,   0, -60, -44, -23, -90, -43, -10, -71,  33, -58, -53, -22, -45,  11,  97,
    14,   0, -15, -14, -19, -77, -16, -25, -62, -20, -64, -41,   5, -14, -15, -27,  78,
    -5,   0, -34, -24, -27, -62, -52, -24, -28, -15, -49, -25,  -7, -20, -18, -27,  25,  81,
    -6,   0, -21, -89, -51, -31, -86, -65,  41, -54,   3,   1, -69, -57, -51, -60, -43,  -9,  80,
    -87,   0, -43,-124, -98,  16, -81, -43, -63, -89, -44, -45, -86,-112, -62, -41, -72, -87, -80, 173,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -65,   0, -32, -69, -74,  49, -94,  21, -47, -60, -35, -37, -39, -76, -53, -50, -46, -58, -47,  23,   0, 123,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"
    
    set Tmat(gon120) "
    59,
    0,   0,
    -1,   0, 144,
    -18,   0, -69,  82,
    -9,   0, -68,  35,  72,
    -48,   0, -26, -87, -78, 102,
    -3,   0, -45, -14, -31, -92,  90,
    -26,   0, -31,  -7,  -6, -14, -37, 110,
    -27,   0, -36, -80, -55,  -3, -87, -48,  72,
    -19,   0, -64,  -8,  11, -67, -34,  -2, -44,  69,
    -30,   0, -39, -82, -57,  15, -82, -42,  28, -44,  66,
    -17,   0, -26, -64, -40,  11, -65, -28,  29, -27,  34,  95,
    -20,   0, -41,  26,  -1, -58,  -7,  14, -55,   5, -61, -46,  80,
    -6,   0, -68, -28, -22, -72, -41, -31, -56, -24, -44, -56, -32, 105,
    -12,   0, -56,   1,  25, -53, -30,  17, -43,  20, -30, -14,   1, -14,  74,
    -23,   0, -45, -27, -10, -68, -30,  -1, -53,  36, -44, -38, -10, -30,  16,  83,
    16,   0,  -7,  -5,  -9, -58,  -6, -14, -44, -10, -47, -29,  10,  -5,  -7, -15,  60,
    2,   0, -21, -13, -15, -47, -35, -14, -17,  -6, -34, -16,   0, -10,  -9, -16,  26,  64,
    0,   0, -11, -65, -38, -17, -65, -47,  42, -39,  13,  10, -50, -42, -36, -44, -28,  -3,  65,
    -68,   0, -29, -96, -78,  27, -66, -28, -46, -68, -29, -31, -68, -89, -49, -30, -57, -67, -59, 166,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -48,   0, -20, -53, -56,  55, -74,  26, -31, -44, -20, -22, -28, -59, -38, -37, -35, -42, -33,  33,   0, 111,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"
    
    set Tmat(gon160) "
    46,
    0,   0,
    3,   0, 135,
    -11,   0, -53,  70,
    -4,   0, -52,  34,  59,
    -38,   0, -18, -70, -62,  91,
    2,   0, -34,  -7, -21, -76,  82,
    -18,   0, -23,  -1,  -1,  -7, -27,  93,
    -18,   0, -25, -62, -43,   3, -70, -37,  59,
    -12,   0, -48,  -1,  13, -53, -24,   2, -35,  55,
    -22,   0, -29, -65, -45,  19, -67, -32,  30, -34,  57,
    -12,   0, -19, -50, -31,  14, -52, -21,  29, -21,  34,  76,
    -12,   0, -31,  26,   5, -47,  -2,  15, -44,   8, -48, -36,  65,
    -1,   0, -52, -19, -14, -58, -30, -22, -43, -16, -35, -42, -22,  96,
    -7,   0, -42,   6,  23, -41, -21,  17, -32,  20, -24, -12,   5,  -8,  56,
    -16,   0, -35, -16,  -3, -53, -21,   3, -41,  35, -35, -29,  -4, -21,  17,  71,
    16,   0,  -2,   0,  -3, -45,  -1,  -8, -33,  -4, -36, -23,  11,   0,  -2,  -9,  44,
    5,   0, -14,  -6,  -8, -36, -24,  -8, -12,  -2, -24, -11,   3,  -4,  -4,  -9,  23,  50,
    1,   0,  -6, -49, -30,  -8, -52, -35,  40, -30,  17,  14, -38, -32, -27, -34, -20,   0,  53,
    -55,   0, -21, -78, -64,  32, -55, -19, -34, -54, -20, -22, -55, -74, -40, -24, -47, -54, -45, 158,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -37,   0, -13, -42, -44,  56, -60,  27, -20, -35, -11, -13, -22, -48, -29, -29, -28, -32, -24,  38,   0, 100,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"
    
    set Tmat(gon250) "
     24,
      0, 0,
      5, 0, 115,
     -3, 0, -32,  47,
      0, 0, -30,  27,  36,
    -23, 0,  -8, -45, -39,  70,
    5,   0, -20,   1,  -8, -52,  66,
    -8,   0, -13,   4,   4,  -1, -14,  60,
    -8,   0, -11, -38, -27,  10, -45, -22,  40,
    -4,   0, -28,   5,  12, -33, -11,   6, -21,  32,
    -12,   0, -15, -40, -28,  20, -44, -19,  28, -21,  40,
    -7,   0,  -9, -30, -20,  16, -35, -13,  25, -14,  28,  43,
    -3,   0, -18,  22,   9, -31,   4,  12, -28,   8, -30, -22,  38,
    3,   0, -31,  -7,  -5, -38, -16, -11, -26,  -6, -23, -24,  -9,  76,
    -2,   0, -24,   9,  17, -26, -10,  12, -19,  15, -16, -10,   7,  -2,  27,
    -6,   0, -22,  -3,   4, -32, -10,   6, -24,  27, -22, -17,   3,  -9,  15,  47,
    11,   0,   1,   5,   2, -28,   4,  -2, -18,   1, -21, -14,   9,   4,   2,  -2,  22,
    6,   0,  -5,   0,  -1, -22, -11,  -3,  -6,   1, -13,  -6,   5,   1,   0,  -2,  15,  25,
    1,   0,   0, -29, -19,   1, -33, -20,  31, -17,  18,  16, -22, -18, -15, -20, -10,   0,  34,
    -36,   0, -10, -52, -43,  36, -40,  -8, -18, -35,  -7, -10, -36, -50, -27, -16, -33, -35, -26, 142,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -22,   0,  -5, -28, -27,  51, -40,  22,  -7, -21,   0,  -2, -14, -31, -17, -18, -19, -19, -11,  41,   0,  78,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"
    
    set Tmat(gon300) "
    16,
    0,   0,
    5,   0, 104,
    -1,   0, -24,  37,
    1,   0, -23,  23,  27,
    -18,   0,  -5, -37, -31,  60,
    5,   0, -15,   3,  -4, -42,  58,
    -6,   0, -10,   5,   4,   0, -10,  45,
    -6,   0,  -7, -30, -21,  11, -36, -16,  33,
    -2,   0, -21,   6,  11, -26,  -7,   5, -17,  24,
    -9,   0, -10, -32, -22,  19, -36, -14,  25, -17,  33,
    -5,   0,  -6, -24, -16,  15, -28, -10,  22, -11,  24,  31,
    -1,   0, -14,  18,   9, -25,   5,  10, -22,   8, -24, -17,  27,
    3,   0, -23,  -4,  -2, -30, -11,  -8, -20,  -3, -18, -19,  -6,  66,
    -1,   0, -18,   9,  14, -20,  -6,   9, -15,  13, -13,  -8,   7,  -1,  18,
    -4,   0, -17,   0,   5, -25,  -6,   6, -19,  22, -18, -13,   4,  -6,  13,  37,
    8,   0,   1,   5,   3, -22,   4,  -1, -14,   2, -17, -11,   7,   4,   2,   0,  15,
    5,   0,  -3,   1,   1, -17,  -7,  -1,  -4,   2,  -9,  -5,   4,   2,   1,  -1,  11,  17,
    0,   0,   1, -23, -15,   4, -26, -15,  26, -13,  17,  15, -17, -14, -12, -15,  -8,   0,  26,
    -29,   0,  -7, -42, -36,  36, -34,  -5, -13, -28,  -4,  -6, -30, -41, -23, -14, -27, -28, -19, 132,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -17,   0,  -3, -22, -22,  46, -33,  18,  -3, -17,   3,   1, -12, -25, -14, -14, -15, -15,  -7,  40,   0,  67,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"
    
    set Tmat(gon350) "
    10,
    0,   0,
    4,   0,  93,
    0,   0, -19,  29,
    1,   0, -17,  19,  20,
    -14,   0,  -3, -30, -25,  51,
    5,   0, -12,   4,  -2, -35,  51,
    -4,   0,  -8,   5,   4,   1,  -7,  33,
    -4,   0,  -5, -24, -17,  11, -29, -13,  27,
    -1,   0, -16,   6,   9, -21,  -4,   5, -13,  18,
    -7,   0,  -7, -25, -18,  18, -30, -11,  22, -14,  28,
    -4,   0,  -4, -19, -13,  14, -23,  -8,  19,  -9,  21,  23,
    0,   0, -11,  15,   9, -20,   5,   8, -18,   7, -19, -14,  20,
    3,   0, -18,  -2,   0, -25,  -7,  -5, -16,  -2, -15, -14,  -3,  56,
    0,   0, -14,   8,  11, -16,  -4,   7, -11,  10, -11,  -7,   6,   0,  12,
    -2,   0, -13,   2,   6, -20,  -4,   6, -15,  18, -14, -11,   4,  -4,  10,  28,
    6,   0,   1,   5,   3, -18,   5,   0, -11,   2, -13,  -9,   6,   4,   2,   1,  10,
    4,   0,  -2,   2,   1, -13,  -5,  -1,  -3,   2,  -7,  -4,   4,   2,   1,   0,   8,  11,
    0,   0,   2, -18, -12,   5, -21, -11,  22, -10,  16,  14, -13, -11,  -9, -12,  -6,   0,  21,
    -24,   0,  -4, -35, -29,  35, -30,  -3,  -9, -23,  -1,  -3, -24, -34, -19, -12, -22, -23, -14, 124,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    -14,   0,  -1, -18, -17,  42, -27,  15,  -1, -14,   5,   2, -10, -20, -11, -12, -12, -12,  -4,  39,   0,  57,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0"

    # List of available matrices
    if {$mat eq "list"} {
	return [lsort [array names Tmat]]
    }
    
    set val [set Tmat($mat)]
    set val [string map [list "\n" "" " " ""] $val]
    set Lv [split $val ,]
    set Laa [split $amino_acid_order ""]
    #lappend Laa ""
    set naa [llength $Laa]
    set ix 0 ; set min 99999999. ; set ave 0.0
    for {set i 0} {$i < $naa} {incr i} {
	set a [lindex $Laa $i]
	for {set j 0} {$j <= $i} {incr j} {
	    set b [lindex $Laa $j]
	    set v [lindex $Lv $ix]
	    set min [expr {$v<$min?$v:$min}]
	    if {$a != $b} {
		set ave [expr {$ave + $v}]
	    }

	    set mtx($a,$b) [expr {$v * $scale}]
	    set mtx($b,$a) [expr {$v * $scale}]
	    
	    incr ix
	}
    }
    set mtx(average) [expr {-1.0*$ave/($naa*($naa-1.)/2.)}]
    set min [expr {$min*$scale}]

    if {$positive && $min < 0.} {
	foreach k [array names mtx "*,*"] {
	    set nv [expr {[set mtx($k)] - $min}]
	    set mtx($k) $nv
	}
    }
    set mtx(laa) $amino_acid_order

    if {$Centre} {
	set M {}
	foreach a $Laa {
	    set tmp {}
	    foreach b $Laa {
		lappend tmp [set mtx($a,$b)]
	    }
	    lappend M $tmp
	}
	set M [CentreMatrice $M]
	foreach a $Laa l $M {
	    foreach b $Laa c $l {
		set mtx($a,$b) $c
	    }
	}
    }

    return [array get mtx]
}


proc InitPAM35 {} {
    set pam "
Default symbol comparison table used by GAP for the comparison of protein sequences.  GAP uses the method of Needleman/Wunsch/Sellers to make alignments.

Dayhoff table (Schwartz, R. M. and Dayhoff, M. O. (1979) in Atlas of Protein Sequence and Structure, Dayhoff, M. O. Ed, pp. 353-358, National Biomedical Research Foundation, Washington D.C.) rescaled by dividing each value by the sum of its row and column, and normalizing to a mean of 0 and standard deviation of 1.0.  The value for FY (Phe-Tyr) = RW = 1.425.  Perfect matches are set to 3.5 and no matches on any row are better than perfect matches. 

Table used by Gribskov and Burgess NAR 14(16) 6745-6763


                     December 29, 1986  12:46

  A    B    C    D    E     F    G    H    I    K     L    M    N    P    Q     R    S    T    V    W     Y    Z  ..
 3.5  0.2  0.3  0.3  0.3  -0.5  0.7 -0.1  0.0  0.0  -0.1  0.0  0.2  0.5  0.2  -0.3  0.4  0.4  0.2 -0.8  -0.3  0.2 A
      1.1 -0.4  1.1  0.7  -0.7  0.6  0.4 -0.2  0.4  -0.5 -0.3  1.1  0.1  0.5   0.1  0.3  0.2 -0.2 -0.7  -0.3  0.6 B
           3.5 -0.5 -0.6  -0.1  0.2 -0.1  0.2 -0.6  -0.8 -0.6 -0.3  0.1 -0.6  -0.3  0.7  0.2  0.2 -1.2   1.0 -0.6 C
                3.5  1.0  -1.0  0.7  0.4 -0.2  0.3  -0.5 -0.4  0.7  0.1  0.7   0.0  0.2  0.2 -0.2 -1.1  -0.5  0.9 D
                     3.5  -0.7  0.5  0.4 -0.2  0.3  -0.3 -0.2  0.5  0.1  0.7   0.0  0.2  0.2 -0.2 -1.1  -0.5  1.1 E

                           3.5 -0.6 -0.1  0.7 -0.7   1.2  0.5 -0.5 -0.7 -0.8  -0.5 -0.3 -0.3  0.2  1.3   1.4 -0.7 F
                                3.5 -0.2 -0.3 -0.1  -0.5 -0.3  0.4  0.3  0.2  -0.3  0.6  0.4  0.2 -1.0  -0.7  0.3 G
                                     3.5 -0.3  0.1  -0.2 -0.3  0.5  0.2  0.7   0.5 -0.2 -0.1 -0.3 -0.1   0.3  0.5 H
                                          3.5 -0.2   0.8  0.6 -0.3 -0.2 -0.3  -0.3 -0.1  0.2  1.1 -0.5   0.1 -0.2 I
                                               3.5  -0.3  0.2  0.4  0.1  0.4   0.8  0.2  0.2 -0.2  0.1  -0.6  0.4 K

                                                     3.5  1.3 -0.4 -0.3 -0.1  -0.4 -0.4 -0.1  0.8  0.5   0.3 -0.2 L
                                                          3.5 -0.3 -0.2  0.0   0.2 -0.3  0.0  0.6 -0.3  -0.1 -0.1 M
                                                               3.5  0.0  0.4   0.1  0.3  0.2 -0.3 -0.3  -0.1  0.4 N
                                                                    3.5  0.3   0.3  0.4  0.3  0.1 -0.8  -0.8  0.2 P
                                                                         3.5   0.4 -0.1 -0.1 -0.2 -0.5  -0.6  1.1 Q

                                                                               3.5  0.1 -0.1 -0.3  0.2  -0.6  0.2 R
                                                                                    3.5  0.3 -0.1  0.3  -0.4  0.0 S
                                                                                         3.5  0.2 -0.6  -0.3  0.1 T
                                                                                              3.5 -0.8  -0.1 -0.2 V
                                                                                                   3.5   1.1 -0.8 W

                                                                                                         3.5 -0.6 Y
1.1 Z
    "

set pam [split $pam \n]
set header 0
set go 0
foreach l $pam {
    set l [string trim $l]
    if {$l eq ""} {
	continue
    }

    if {[string range $l end-1 end] eq "\.\."} {
	set go 1
	set laa [string range $l 0 end-2]
	regsub -all { +} $laa " " laa
	set laa [split $laa " "]
	set i 0
	continue
    }
    if {! $go} {
	continue
    }

    # lit scores
    regsub -all { +|\t} $l " " l
    set l [split $l " "]
    set a [lindex $laa $i]
    foreach b [lrange $laa $i end] v [lrange $l 0 end-1] {
	set mtx($a,$b) $v
	set mtx($b,$a) $v
    }
    incr i
}

set mtx(laa) [join $laa ""]

return [array get mtx]
}


proc InitPETMatrix {} {
    # The 250 PAM PET91 matrix (Jones et al., 1992)
    # LIT:1814076 PMID:1633570
    # Jones, D.T., Taylor, W.R. and Thornton, J.M.
    # The rapid generation of mutation data matrices from protein sequences
    # CABIOS 8, 275-282 (1992)
    # rows = ARNDCQEGHILKMFPSTWYV, cols = ARNDCQEGHILKMFPSTWYV
    
    set t "
    2.
    -1.,5.
    0.,0.,3.
    0.,-1.,2.,5.
    -1.,-1.,-1.,-3.,11.
    -1.,2.,0.,1.,-3.,5.
    -1.,0.,1.,4.,-4.,2.,5.
    1.,0.,0.,1.,-1.,-1.,0.,5.
    -2.,2.,1.,0.,0.,2.,0.,-2.,6.
    0.,-3.,-2.,-3.,-2.,-3.,-3.,-3.,-3.,4.
    -1.,-3.,-3.,-4.,-3.,-2.,-4.,-4.,-2.,2.,5.
    -1.,4.,1.,0.,-3.,2.,1.,-1.,1.,-3.,-3.,5.
    -1.,-2.,-2.,-3.,-2.,-2.,-3.,-3.,-2.,3.,3.,-2.,6.
    -3.,-4.,-3.,-5.,0.,-4.,-5.,-5.,0.,0.,2.,-5.,0.,8.
    1.,-1.,-1.,-2.,-2.,0.,-2.,-1.,0.,-2.,0.,-2.,-2.,-3.,6.
    1.,-1.,1.,0.,1.,-1.,-1.,1.,-1.,-1.,-2.,-1.,-1.,-2.,1.,2.
    2.,-1.,1.,-1.,-1.,-1.,-1.,-1.,-1.,1.,-1.,-1.,0.,-2.,1.,1.,2.
    -4.,0.,-5.,-5.,1.,-3.,-5.,-2.,-3.,-4.,-2.,-3.,-3.,-1.,-4.,-3.,-4.,15.
    -3.,-2.,-1.,-2.,2.,-2.,-4.,-4.,4.,-2.,-1.,-3.,-2.,5.,-3.,-1.,-3.,0.,9.
    1.,-3.,-2.,-2.,-2.,-3.,-2.,-2.,-3.,4.,2.,-3.,2.,0.,-1.,-1.,0.,-3.,-3.,4.
    "

    set lt [split $t "\n"]
    set aa "ARNDCQEGHILKMFPSTWYV"
    set laa [split $aa ""]
    set i 0
    foreach a $laa {
	set l [lindex $lt $i]
	set l [split $l ,]
	set j 0
	foreach b [lrange $laa 0 $i] {
	    set T($a,$b) [lindex $l $j]
	    set T($b,$a) [lindex $l $j]
	    incrj
	}
	incr i
    }
    
    set Lm [array get T]
    set Lm [AddBJToMatrix $Lm]
    
    return $Lm
}


proc DirichletMixtureData {} {
    set dataBrutes "
  1.90787e-01, 1.04790e+00, 8.51607e-01, 1.42468e+00, 1.65837e+00, 1.27624e-01, 7.17342e-01,
  1.32869e+00, 1.58841e+00, 4.76291e-01, 1.50793e-01, 3.46223e-01, 1.07498e+00, 1.22990e-01,
  2.43214e-01, 8.32888e-01, 1.61600e+00, 9.03840e-01, 1.81517e-01, 3.17127e-01, 2.71696e-01,
  2.31348e-01, 1.49669e+00, 9.26283e-01, 5.36734e-01, 5.35590e-01, 2.76149e-01, 6.50695e-01,
  8.51071e-01, 7.44779e-01, 5.23170e-01, 1.51316e+00, 2.41708e+00, 7.80437e-01, 6.87694e-01,
  1.07724e+00, 5.60151e-01, 8.95912e-01, 1.11477e+00, 3.86675e-01, 9.69174e-01, 1.79257e+00,
  6.36828e-02, 4.35462e-01, 6.92698e-02, 3.80381e-02, 2.76147e-02, 1.24846e-01, 7.62577e-02,
  3.95313e-02, 7.14402e-02, 4.93714e-02, 1.45257e+00, 4.17992e+00, 6.13128e-02, 6.70464e-01,
  7.67295e-01, 5.46339e-02, 7.08568e-02, 1.47081e-01, 9.45354e-02, 1.40703e-01, 9.54595e-01,
  1.20260e-01, 1.44133e+00, 1.94333e+00, 5.56915e-01, 1.04866e+00, 4.41589e-02, 1.38008e+00,
  2.65171e+00, 2.69416e-01, 3.37705e-01, 3.63554e-01, 7.12004e-01, 2.55697e+00, 2.02383e-01,
  9.94796e-02, 3.63374e-01, 9.12045e-01, 7.97208e-01, 6.82441e-06, 1.78230e-01, 5.47792e-01,
  6.28833e-02, 1.12917e+00, 7.32940e-02, 6.75998e-02, 4.22075e-02, 3.17997e-01, 6.16088e-02,
  7.12822e-02, 1.66381e-01, 4.35275e-02, 2.03149e+00, 1.37645e+00, 6.12778e-02, 2.74245e-01,
  3.16939e-01, 1.69192e-01, 1.99073e-01, 5.83574e-01, 4.79987e-02, 1.21036e-01, 3.12429e+00,
2.30917e-02, 3.38602e-01, 2.63820e+00, 2.91699e-01, 6.84881e-06, 6.60967e-02, 4.55701e-01,
4.47113e-02, 2.00108e-01, 2.77657e-01, 2.45482e-01, 4.98113e-01, 1.79164e+00, 1.41118e-01,
1.02420e-01, 9.91099e-02, 2.40487e-01, 2.97528e-01, 6.82441e-06, 1.99988e-01, 2.66838e-01,
2.54398e-02, 6.45122e-01, 1.51296e-01, 2.80755e-01, 2.44861e+00, 1.86722e-02, 7.12253e-01,
3.56545e+00, 2.28329e-01, 1.33064e-01, 8.05822e-02, 1.75863e-01, 4.72355e-01, 6.61411e-02,
6.27438e-02, 2.35140e-01, 4.16451e-01, 2.90239e-01, 6.82442e-06, 6.37813e-02, 1.70260e-01,
1.81905e-02, 2.69580e-03, 5.18381e-03, 3.64808e-03, 8.52051e-03, 6.78894e-06, 1.18796e-03,
4.83124e-03, 6.78119e-06, 4.04942e-06, 7.73177e-06, 3.62381e-03, 3.43071e-03, 9.05901e-04,
2.50302e-03, 6.84602e-06, 2.76818e-03, 2.44236e-03, 6.64933e-06, 2.95083e-03, 1.52711e-03,
4.36341e-02, 2.67702e+00, 4.66059e-02, 5.36256e-02, 1.61496e-02, 3.07979e-01, 5.53320e-02,
5.59059e-02, 7.64071e-01, 4.53289e-02, 1.77046e-01, 3.51216e-01, 4.21634e-02, 1.32101e-01,
1.20610e-01, 1.00687e-01, 7.49123e-01, 3.76924e-01, 2.03993e-02, 9.03913e-02, 5.32540e-01,
4.67005e-02, 3.27933e-01, 1.04451e-01, 2.39883e-01, 1.73800e-01, 3.48857e-02, 6.71135e-02,
1.01547e-01, 5.00419e+00, 5.61308e-02, 4.20194e-02, 6.82140e-02, 1.29979e-01, 3.12449e-02,
4.78230e-02, 9.78755e-02, 2.77191e-01, 9.45045e-02, 1.73248e-02, 4.47752e-02, 5.45999e-02,
2.74659e-02, 4.04781e-01, 1.34132e-01, 4.61109e-01, 2.07521e-01, 1.48804e-01, 1.24903e-01,
1.29000e-01, 2.24895e-01, 8.83638e-02, 1.48434e-01, 1.42950e-01, 1.33117e-01, 8.00954e-02,
6.14824e-02, 1.75370e-01, 1.76131e+00, 2.38531e+00, 1.24182e-02, 7.70201e-02, 3.54549e-01,
2.35271e-02, 2.09806e-06, 2.09611e-06, 2.09349e-06, 2.09395e-06, 1.51965e-02, 2.09525e-06,
2.09506e-06, 3.08171e-06, 2.09545e-06, 3.55392e+00, 1.79915e+00, 6.19279e-02, 2.32271e-01,
4.49120e-01, 2.09624e-06, 6.33349e-06, 8.48321e-02, 2.09599e-06, 1.77228e-01, 3.29717e+00,
1.90188e-02, 1.03006e-01, 7.26350e-02, 9.36077e-01, 2.60532e+00, 5.68496e-02, 6.45488e-02,
3.18932e-01, 2.44067e-01, 1.29950e-01, 4.57387e-02, 6.33750e-02, 1.04891e-01, 1.95064e-02,
2.28703e-02, 7.45474e-02, 4.29128e-01, 2.13524e-01, 8.70906e-03, 3.38116e-02, 5.98965e-02,
3.90740e-02, 5.45581e-01, 2.32418e-01, 1.46330e-01, 2.70351e-01, 4.74132e-02, 1.53661e-01,
3.23849e-01, 3.12641e-01, 7.51482e-02, 1.89273e-01, 3.27661e-01, 3.33386e-01, 5.14866e-02,
1.10750e-01, 4.65804e+00, 4.53472e-01, 3.11523e-01, 6.82219e-06, 8.56644e-02, 3.20962e-01,
3.15551e-02, 1.72477e-01, 1.70036e-01, 1.86367e-01, 1.25363e-01, 9.64611e-02, 1.30303e-01,
1.39411e-01, 1.89668e-01, 4.26400e-01, 6.97407e-02, 2.82296e-01, 8.95530e-02, 7.67090e-02,
9.29261e-01, 9.85695e-02, 1.87798e-01, 1.36169e-01, 3.96736e-01, 1.31186e+00, 1.20003e-01,
1.94012e-02, 1.50485e-01, 2.09957e-06, 2.09916e-06, 3.43319e-06, 6.54973e-02, 2.13697e-06,
2.09875e-06, 2.09628e-06, 2.09541e-06, 4.08937e-01, 8.01559e-01, 2.08249e-06, 1.64297e-01,
1.90252e+00, 3.77111e-02, 3.64121e-02, 5.88268e-02, 2.86392e-01, 1.10400e+00, 3.93563e-01,
1.92930e-03, 6.82604e-06, 1.80057e-01, 7.20143e-01, 7.00984e-06, 1.67036e-01, 4.53687e-01,
1.16956e-01, 1.78211e-01, 1.05145e+00, 7.58164e-06, 3.56887e-01, 1.08975e-01, 2.45596e-01,
6.82872e-06, 6.82541e-06, 6.82665e-06, 6.86221e-06, 6.82575e-06, 6.82650e-06, 8.09853e-06,
4.17487e-03, 3.18914e-02, 1.51802e-02, 2.51110e-02, 2.09471e-06, 6.01455e+00, 1.27434e-02,
2.09361e-06, 2.00737e-02, 2.09311e-06, 1.87376e-02, 3.35639e-02, 1.56161e-02, 1.21492e-02,
1.63082e-02, 2.18568e-02, 7.47796e-02, 2.70651e-02, 2.09217e-06, 2.09460e-06, 5.91846e-02,
3.79203e-03, 4.77257e-02, 6.57508e-02, 1.75686e-02, 6.82346e-06, 6.82267e-06, 6.82310e-06,
6.82411e-06, 4.06000e-02, 1.74947e-02, 7.10513e-02, 1.89537e-01, 2.77309e-02, 3.79048e-02,
2.93947e-01, 6.82394e-06, 5.29119e-02, 4.54005e-02, 3.17830e+00, 1.97322e-01, 6.25358e-02,
4.04424e-03, 2.09520e-06, 2.69173e-02, 6.98870e-02, 1.51420e-02, 2.09231e-06, 4.29689e-02,
2.09374e-06, 2.09214e-06, 9.35600e-01, 1.02272e-02, 2.09374e-06, 2.08998e-06, 2.08905e-06,
    5.66085e-03, 1.44082e-02, 3.08847e-02, 1.63193e-02, 2.08622e-06, 4.01371e-02, 1.45572e-02"

    set data [string map [list "\n" " " "," " "] $dataBrutes]
    regsub -all { +} [string trim $data] " " data
    set data [split $data " "]

    return $data
}


if {0} {
But: Est il possible de dÃ©finir dans un alignement multiple , le set de positions de l'alignement fonctionnellement importantes ?

1) benchmark :
--------------
Dans Pfam v26. (v27 est sorti en mars ...)
- prend Pfams qui ont reprÃ©sentants dans CSA (Catalytic Site Atlas) si 
- prend Pfam dont sÃ©quences ont un pattern Prosite
--> pour ces Pfam, si Nbr seq > 1000 , sample et prend 500 seq.
- Pour chaque Pfam , si il exists seq de PDB, rÃ©cupÃ¨re les rÃ©sidus d'interface.

Pour chaque Pfam, on a un set de rÃ©sidus :
- rÃ©sidus CSA
- rÃ©sidus Interface
- rÃ©sidus Prosite

et infos attachÃ©es :
- nbr seq,
- longueur,
- % identitÃ© moyen,
- ecart-type % identite

2) Calculs :
------------
Sur chaque Pfam, on fait calcul conservation en utilisant plusieurs mÃ©thodes :
- Dist : clustalx
- Kabat : frequences
- entrop1 : entropie + physicochimie , 
- Williamson : entropie + physicochimie
- Liu2 : basÃ© sur matrice
- RPCA : PCA sur blosum62 , prend les deux axes majeurs

Pour chaque mÃ©thode, on considÃ¨re des seuils Ã  partir desquels on considÃ¨re une colonne ou pas : 
si nbr.aa > Nseq * seuil -> bonne colonne
seuils :
- 0.005 (all columns)
- 0.1
- 0.25
- 0.5
- 0.7

Pour chaque mÃ©thode, pour chaque seuil, on clusterise les colonnes. On prend le cluster ayant la plus grande moyenne comme Ã©tant le groupe des rÃ©sidus importants.
Clustering methods :
- kmeans + dpc
- mixturemodels + aic
- hierar + secator

3) Analyse :
------------
Pour chaque Pfam, seuil, score, clustering, on a un set de residus prÃ©dits qu'on compare Ã  un set de rÃ©sidus "vrais positifs" (rÃ©sidus CSA+Interface+Prosite).
On calcule sensibilitÃ© et spÃ©cificitÃ© .

On considÃ¨re :
- tous alignements : 3513
- 0. Ã  30 % identite : 1513
- 30% Ã  50% identit : 1417
- 50% - 100% identitÃ© : 583

Dans ces cas, on regarde qui donne le meilleur sensibilite/specificite ("Best Of" dans fichier resultats)

anne knaus
03 88 37 67 19
mardi 20 mai
10h entrÃ©e Erasme, demander 
}


proc InitSolventArea {} {
    global pKa Surf SA

    #Residue Volume 	Surface Area 	Side Chain pKa
    set strSA "
A	88.6	115.	-999.
R	173.4	225.	~12
D	111.1	150.	4.5
N	114.1	160.	-999.
# C a pk entre 9.1 et 9.5 -> 9.3
C	108.5 	135.	9.3
E	138.4	190.	4.6
Q	143.8	180.	-999.
G	60.1	75.	-999.
H	153.2 	195.	6.2
I	166.7	175.	-999.
L	166.7	170.	-999.
K	168.6	200.	10.4
M	162.9	185.	-999.
F	189.9	210.	-999.
P	112.7	145.	-999.
S	89.0 	115.	-999.
T	116.1	140.	-999.
W	227.8 	255.	-999.
Y	193.6	230.	9.7
V	140.0	155.	-999.
#a-amino pKa = 6.8 - 7.9, a-carboxyl pKa = 3.5 - 4.3
    "
    
    set LSA [split $strSA \n]
    foreach l $LSA {
	set l [string trim $l]
	if {$l eq ""} {continue}
	if {[string index $l 0] eq "#"} {continue}

	set Lv [split $l "\t"]
	lassign $Lv aa surf area pka
	set SA($aa) $area
	set pKa($aa) $pka
	set Surf($aa) $surf
    }

    foreach aa [lsort [array names SA]] {
	#puts "SA($aa) >$SA($aa)<"
    }

    # References
    if {0} {
	References
	Volume:
	A.A. Zamyatin, Protein Volume in Solution, Prog. Biophys. Mol. Biol. 24(1972)107-123.
	Accessible surface area
	(calculated for the residue X in the tripeptide G-X-G)
	C. Chotia, The Nature of the Accessible and Buried Surfaces in Proteins, J. Mol. Biol., 105(1975)1-14.
	pKa:
	C. Tandford, Adv. Protein Chem. 17(1962)69-165.
    }

    return
}


proc MaxArea {} {
    # maximum solvent accessible area
    # Taken from wikipediia :
    # "Relative Accessible Surface Area"
    # 

    set asa "
A 	106
B 	160
C 	135
D 	163
E 	194
F 	197
G 	84
H 	184
I 	169
K 	205
L 	164
M 	188
N 	157
P 	136
Q 	198
R 	248
S 	130
T 	142
V 	142
W 	227
X 	180
Y 	222
Z 	196
"
    

    return
}


proc ListOfAllIDMappingBanks_hard {} {
    return [list ALLERGOME ARACHNOSERVER ARAPORT BIOCYC BIOGRID BIOMUTA CCDS CGD CHEMBL CHITARS CLAE COLLECTF COMPLEXPORTAL CONOSERVER CPTAC CRC64 DICTYBASE DIP DISPROT DMDM DNASU DRUGBANK ECHOBASE EGGNOG EMBL EMBL_CDS ENSEMBL ENSEMBLGENOME ENSEMBLGENOME_PRO ENSEMBLGENOME_TRS ENSEMBL_PRO ENSEMBL_TRS ESTHER EUHCVDB EUPATHDB FLYBASE GENECARDS GENEDB GENEID GENEREVIEWS GENETREE GENEWIKI GENE_NAME GENE_ORDEREDLOCUSNAME GENE_ORFNAME GENE_SYNONYM GENOMERNAI GI GLYCONNECT GUIDETOPHARMACOLOGY HGNC HOGENOM IDEAL KEGG KO LEGIOLIST LEPROMA MAIZEGDB MEROPS MGI MIM MINT NCBI_TAXID NEXTPROT OMA ORPHANET ORTHODB PATRIC PDB PEROXIBASE PHARMGKB PHI_BASE PLANTREACTOME POMBASE PROTEOMICSDB PSEUDOCAP REACTOME REBASE REFSEQ REFSEQ_NT RGD SGD STRING SWISSLIPIDS TAIR TCDB TREEFAM TUBERCULIST UCSC UNIPARC UNIPATHWAY UNIPROTKB_ID UNIREF100 UNIREF50 UNIREF90 VECTORBASE VGNC WBPARASITE WORLD_2DPAGE WORMBASE WORMBASE_PRO WORMBASE_TRS XENBASE ZFIN]
    
}

proc Matrix2C {} {
    set amino_acid_order "ABCDEFGHIKLMNPQRSTVWXYZ"
    set Laa [split $amino_acid_order ""]
    set naa [string length $amino_acid_order]

    set Lmat [InitClustalMatrix list]
    set Lmat "blosum62"
    
    set o [open "matrices.inc" w]

    # lookups aa <--> int
    #
    # aa -> int
    set alf "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    set Lalf [split $alf ""]
    set i -1
    set Lv {}
    foreach a $Lalf {
	if {$a in $Laa} {
	    incr i
	    set v $i
	} else {
	    set v -1
	}
	lappend Lv $v
    }
    puts $o "int aa2int\[[llength $Lalf]\] = \{[join $Lv ,]\};"
    puts $o ""
    
    # integer -> aa
    set Lv [lmap a $Laa {set x "'$a'"}]
    puts $o "int int2aa\[23\] = \{[join $Lv ,]\};"
    puts $o ""
    
    # Prototype
    puts $o "int **load_matrix(char *matName);"
    
    puts $o "int **load_matrix(char *matName)"
    puts $o "\{"
    # declaration of all matrices
    set Ldecl [lmap m $Lmat {set a "**$m"}]
    puts $o " int i, [join $Ldecl ", "]\;"
    
    # Build all matrices
    foreach mat $Lmat {
	# allocation
	puts $o "\n  $mat = (int **)ckalloc($naa*sizeof(int *))\;"
	puts $o "for (i=0; i<$naa; i++) \{"
	puts $o "     $mat\[i\] = (int *)ckalloc($naa*sizeof(int))\;"
	puts $o "\}"
	puts $o ""
	
	# fill matrix array
	array set T [InitClustalMatrix $mat 0 1]
	
	set Lvals {}
	set ia 0
	foreach a $Laa {
	    set Lkey [lsort [array names T "$a,*"]]
	    set Ligne {}
	    set ib 0
	    foreach k $Lkey {
		lappend Ligne "$mat\[$ia\]\[$ib\]=[set T($k)]"
		incr ib
	    }
	    puts $o "  [join $Ligne "\; "]\;"
	    puts $o ""
	    
	    incr ia
	}
	
	unset T
    }
    
    # matrices loader
    set Lm [lmap m $Lmat {set a "\"$m\""}]
    puts $o "  if (strcmp(matName,[lindex $Lm 0]) == 0) \{"
    puts $o "    return [lindex $Lmat 0]\;"
    foreach m [lrange $Lm 1 end] mat [lrange $Lmat 1 end] {
	puts $o "  \} else if (strcmp(matName,$m) == 0) \{"
	puts $o "    return $mat\;"
    }
    puts $o "  \}\;"
    puts $o "\}"
    puts $o ""
    
    close $o

    exit
}


proc mapping4js {} {
    set Lignes "I white magenta
    J white magenta
    L white magenta
    M white magenta
    V white magenta
    R white blue
    K white blue
    F white red
    Y white red
    W white red
    D white forestgreen
    B white forestgreen
    E white forestgreen
    Z black green1
    Q black green1
    P white black
    G black orange
    H black cyan
    N black cyan
    S white darkviolet
    T white darkviolet
    A white darkviolet
    U white darkviolet
    C white darkviolet
    X black dimgrey
    . black dimgrey
    0 black white
    1 black white
    2 black white
    3 black white
    4 black white
    5 black white
    6 black white
    7 black white
    8 black white
    9 black white
    Space white white"

    set Ll [split $Lignes \n]
    set Ljs {}
    foreach l $Ll {
	set l [string trim $l]
	lassign [split $l] a f b
	if {$a eq "."} {
	    set def "Gap"
	} else {
	    set def $a
	}
	lappend Ljs "'$def'" "'$a'" "'$f'" "'$b'"
    }
    puts "var mapping = \[[join $Ljs ,]\];"

    exit
}
























if {0} {
    set Ldbs [list ACC ID UPARC NF50 NF90 NF100 GENENAME EMBL_ID EMBL PIR UNIGENE_ID P_ENTREZGENEID P_GI P_REFSEQ_AC REFSEQ_NT_ID PDB_ID DISPROT_ID BIOGRID_ID DIP_ID MINT_ID STRING_ID CHEMBL_ID DRUGBANK_ID GUIDETOPHARMACOLOGY_ID SWISSLIPIDS_ID ALLERGOME_ID ESTHER_ID MEROPS_ID MYCOCLAP_ID PEROXIBASE_ID REBASE_ID TCDB_ID BIOMUTA_ID DMDM_ID WORLD_2DPAGE_ID DNASU_ID ENSEMBL_ID ENSEMBL_PRO_ID ENSEMBL_TRS_ID ENSEMBLGENOME_ID ENSEMBLGENOME_PRO_ID ENSEMBLGENOME_TRS_ID GENEDB_ID P_ENTREZGENEID KEGG_ID PATRIC_ID UCSC_ID VECTORBASE_ID WBPARASITE_ID ARACHNOSERVER_ID CCDS_ID CGD CONOSERVER_ID DICTYBASE_ID ECHOBASE_ID ECOGENE_ID EUHCVDB_ID EUPATHDB_ID FLYBASE_ID GENECARDS_ID H_INVDB_ID HGNC_ID HPA_ID LEGIOLIST_ID LEPROMA_ID MAIZEGDB_ID MIM_ID MGI_ID NEXTPROT_ID ORPHANET_ID PHARMGKB_ID POMBASE_ID PSEUDOCAP_ID RGD_ID SGD_ID TAIR_ID TUBERCULIST_ID WORMBASE_ID WORMBASE_TRS_ID WORMBASE_PRO_ID XENBASE_ID ZFIN_ID EGGNOG_ID GENETREE_ID HOGENOM_ID HOVERGEN_ID KO_ID OMA_ID ORTHODB_ID TREEFAM_ID BIOCYC_ID REACTOME_ID UNIPATHWAY_ID CLEANEX_ID COLLECTF_ID CHITARS_ID GENOMERNAI_ID GENEWIKI_ID NEXTBIO_ID]
}


proc LookupPDBQueryAttributes {} {
    global PDBQ
    
    set PDBQ(-resmin,att) "rcsb_entry_info.resolution_combined"
    set PDBQ(-resmin,ope) "less_or_equals"
    set PDBQ(-resmin,val) ""
    
    set PDBQ(-resmax,att) "rcsb_entry_info.resolution_combined"
    set PDBQ(-resmax,ope) "less_or_equals"
    set PDBQ(-resmax,val) ""
    
    set PDBQ(-ec,att) "rcsb_polymer_entity.rcsb_ec_lineage.id"
    set PDBQ(-ec,ope) "exact_match"
    set PDBQ(-ec,val) ""
    
    set PDBQ(-method,att) "exptl.method"
    set PDBQ(-method,ope) "exact_match"
    set PDBQ(-method,val) {"X-RAY DIFFRACTION" "NEUTRON DIFFRACTION" "SMALL ANGLE NETRON SCATTERING"}

    # search by release date
    set PDBQ(-date,att) "rcsb_accession_info.initial_release_date"
    set PDBQ(-date,ope) {"greater" "smaller"}
    set PDBQ(-date,val) ""

    set PDBQ(-organism,att) "rcsb_entity_source_organism.taxonomy_lineage.id"
    set PDBQ(-organism,ope) "exact_match"
    set PDBQ(-organism,val) ""

    # return types
    # - entry : return PDB IDs
    # - polymer_entity /
    # - non_polymer_entiry : PDN ID with entity ID : 1ABC_1
    # - polymer_instance : PDB  ID with chain ID : 1ABC.A
    # - assembly : PDB ID + assembly ID : 1ABC-<assembly ID>
    set PDBQ(-return,att) ""
    set PDBQ(-return,ope) ""
    set PDBQ(-return,val) {"entry" "chain" "molecule"}
    
    return
}


proc FileFormatExtensionsTable {} {
    set T(TFA) [list .fa .tfa .tfasta .fasta]
    set T(MSF) [list .msf .pileup]
    set T(ALN) [list .aln .clustal .clustalw]
    set T(RSF) [list .rsf]
    set T(XML) [list .xml .macsim]
    set T(ORD) [list .ord]
    
    return [array get T]
}


proc tmatx {} {
    set tmp [InitClustalMatrix blosum62 1 1]
    set Lv {}
    foreach {a b} $tmp {
	if {[string first "," $a] != -1} {
	    lappend Lv $a $b
	}
    }
    set Lv [lsort -real -stride 2 -index 1 $Lv]
    puts [lindex $Lv 1]
    puts [lindex $Lv end]

    exit
}

proc thydrom {} {
    global LNOrdali LSOrdali THydroAA TDesHydro

    array set THydroAA {}
    InitHydrophobicityAA4

    set n "Rcyto_Ence.cuni"
    set i [lsearch $LNOrdali $n]
    set s [lindex $LSOrdali $i]
    set sum 0.0
    set naa 0
    foreach a [split $s ""] {
	if {$a ne "."} {
	    set sum [expr {$sum + $THydroAA($a)}]
	    incr naa
	}
    }
    parray THydroAA
    puts ""
    puts "$n $i"
    puts "$TDesHydro($n) -> $sum"
    exit
}


proc prepdal {} {
    set Ll [LesLignesDuFichier panel.csv]
    foreach l [lrange $Ll 3 end] {
		 set Lv [split $l ","]
	set Ln [lindex $Lv 0]
	set b [lindex $Lv 3]
	if {[regexp -nocase {noir} $l]} {
	    set f black
	} else {
	    set f white
	}
	if {$Ln eq "P"} {
	    set f white
	}

	foreach a [split $Ln ""] {
	    lappend Ltxt "$a $f $b"
	}
    }
    set txt [join $Ltxt \n]
    puts "$txt"

    set Lmap [CreateMapping $txt]
    puts [join $Lmap \n]

    exit
}










