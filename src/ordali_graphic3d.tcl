


proc CalculeRibbon {mol} {
    global RadMol
    global LesVecs

    DecortiqueUnPDB "${mol}.pdb"
    global PDB_[set mol]_AtmXYZ
    global PDB_[set mol]_NmrRes
    #    set ch [lindex [array names PDB_[set mol]_AtmXYZ] 0]
    set ch "A"

    set Lx [set PDB_[set mol]_AtmXYZ($ch)]
    foreach x $Lx {
	lassign $x n ca c o
	lappend Lca $ca
	lappend Lc $c
	lappend Lo $o
    }

    set LesVecs [CheminRibbon $Lca $Lc $Lo]

    return
}


proc CheminRibbon {type Lca Lcol {Lc {}} {Lo {}}} {
    # the smoothing (Lagrange, order 5) needs 5 residues : a shorter
    # segment has no ribbon (it failed, and left the structure db in
    # an open transaction). An empty result is skipped by the drawing.
    if {[llength $Lca] < 5} {
	return {}
    }
    if {$type eq "Nucleic"} {
	set Lca [Lissage3D $Lca]
	set nLcol [lrange $Lcol 0 1]
	for {set i 1} {$i < [llength $Lcol]-1} {incr i} {
	    lappend nLcol {*}[lrepeat 4 [lindex $Lcol $i]]
	}
	lappend nLcol [lindex $Lcol end]

	return [list $type $Lca $nLcol]
    }

    # ribbon de protein
    set LU $Lca
    set LV {}
    foreach ca1 $Lc ca2 $Lo  {
	set V [V_VV $ca2 - $ca1]
	set n [expr {1.0/[NormVec $V]}]
	set V [V_VS $V * $n]
	lappend LV $V
    }

    #GetRad $LU

    set len [llength $LV]
    set u0 [lindex $LV 0]
    lappend newv $u0
    foreach v [lrange $LV 1 end] {
	set norm [S_VV $u0 * $v]
	if {$norm < 0.0} {set v [V_SV -1. * $v]}
	set u0 $v
	lappend newv $v
    }
    set LV $newv

    # Lissage 3D par polynome Lagrange ordre 5
    set LNewU [Lissage3D $LU]
    set LNewV [Lissage3D $LV]

    # calcul des normales
    set L1 [lrange $LNewU 2 [expr {4*($len-1)}]]
    set L2 [lrange $LNewU 0 [expr {4*($len-1)-2}]]
    set LV [lrange $LNewV 1 [expr {4*($len-1)-1}]]
    foreach x1 $L1 x2 $L2 v $LV {
	set u0 [V_VV $x1 - $x2]
	set w [Vectoriel $u0 $v]
	set norm [NormVec2 $w]
	if {$norm > 0.001} {set norm [expr {1.0/sqrt($norm)}]}
	lappend Lw [V_SV $norm * $w]
    }

    # les extremites
    set Lw [linsert $Lw end [lindex $Lw end]]
    set Lw [linsert $Lw 0   [lindex $Lw 1]]

    set d1 0.7
    set d2 0.7

    set col1 [list 1.0 0.3 0.3]
    set col2 [list 1.0 0.3 0.3]
    set kstep 1

    # compute coordinates of points and of the normals
    #set f [open logpt w]
    set LesVecs {}
    for {set i 0} {$i < $len-1} {incr i} {
	set c1 [lindex $Lcol $i]
	set c2 [lindex $Lcol $i]
	for {set k [expr {4*$i}]} {$k < 4*($i+1)} {incr k} {
	    # couleurs
	    set mlt [expr {$k-4.*$i}]
	    # set c1 [V_VV $col1 + [V_VS [V_VS [V_VV $col2 - $col1] * 0.25] * $mlt]]
	    # set c2 [V_VV $col1 + [V_VS [V_VS [V_VV $col2 - $col1] * 0.25] * [expr {$mlt+1}]]]

	    # points
	    set d [expr {$d1 + ($d2-$d1)*0.25*$mlt}]
	    set uk [lindex $LNewU $k]
	    set up [lindex $LNewU $k+1]
	    set vk [lindex $LNewV $k]
	    set vp [lindex $LNewV $k+1]
	    set wk [lindex $Lw $k]
	    set wp [lindex $Lw $k+1]

	    set p1 [V_VV $uk - [V_SV $d * $vk]]
	    set p2 [V_VV $uk + [V_SV $d * $vk]]
	    set d [expr {$d1 + ($d2-$d1)*0.25*($k+1.-4.*$i)}]
	    set p3 [V_VV $up - [V_SV $d * $vp]]
	    set p4 [V_VV $up + [V_SV $d * $vp]]

	    set fmt "%d %s %6.2f %6.2f %6.2f"
	    if {$k % 2} {
		#lappend LesVecs $wk $c1 $p1 $wp $c2 $p3 $wk $c1 $p2
		#lappend LesVecs $wk $c1 $p2 $wp $c2 $p3 $wp $c2 $p4


		lappend LesVecs $wk $c1 $p1 $wp $c2 $p4 $wk $c1 $p2
		lappend LesVecs $wk $c1 $p1 $wp $c2 $p3 $wp $c2 $p4


		#puts $f [format $fmt $k A {*}$p1]
		#puts $f [format $fmt $k N {*}$wk]
		#puts $f [format $fmt $k B {*}$p4]
		#puts $f [format $fmt $k N {*}$wp]
		#puts $f [format $fmt $k C {*}$p2]
		#puts $f [format $fmt $k N {*}$wk]
		#puts $f [format $fmt $k D {*}$p1]
		#puts $f [format $fmt $k N {*}$wk]
		#puts $f [format $fmt $k E {*}$p3]
		#puts $f [format $fmt $k N {*}$wp]
		#puts $f [format $fmt $k F {*}$p4]
		#puts $f [format $fmt $k N {*}$wp]
		#puts ""
		#puts ""
	    } else {
		lappend LesVecs $wk $c1 $p1 $wp $c2 $p4 $wk $c1 $p2
		lappend LesVecs $wk $c1 $p1 $wp $c2 $p3 $wp $c2 $p4
		#puts $f [format $fmt $k A {*}$p1]
		#puts $f [format $fmt $k N {*}$wk]
		#puts $f [format $fmt $k B {*}$p4]
		#puts $f [format $fmt $k N {*}$wp]
		#puts $f [format $fmt $k C {*}$p2]
		#puts $f [format $fmt $k N {*}$wk]
		#puts $f [format $fmt $k D {*}$p1]
		#puts $f [format $fmt $k N {*}$wk]
		#puts $f [format $fmt $k E {*}$p3]
		#puts $f [format $fmt $k N {*}$wp]
		#puts $f [format $fmt $k F {*}$p4]
		#puts $f [format $fmt $k N {*}$wp]
		#puts ""
	    }
	}
	if {$i == 10000} {
	    set foo $f
	    set f stdout
	}
    }

    return [list $type $LesVecs]
}



proc Lissage3D l {
    # lissage par polynomes de Lagrange de ordre 5

    set n [llength $l]
    if {$n < 5} {return}

    set km [expr {4*($n-1)+1}]
    set cof [list 0.1 0.125 0.25 0.375 0.50 0.625 0.75 0.875 1.0 0.875 0.75 0.625 0.50 0.375 0.25 0.125]

    for {set k 0} {$k < $km} {incr k} {
	set xout($k) [list 0.0 0.0 0.0]
	set norms($k) 0.0
    }
    set xout([expr {$km-1}]) [lindex $l end]

    set C0 6144.0
    set C1 -1536.0
    set C2 1024.0

    set i 0
    set lx1 [lrange $l 0 end-4]
    set lx2 [lrange $l 1 end-3]
    set lx3 [lrange $l 2 end-2]
    set lx4 [lrange $l 3 end-1]
    set lx5 [lrange $l 4 end]
    foreach v1 $lx1 v2 $lx2 v3 $lx3 v4 $lx4 v5 $lx5 {
	for {set k 0} {$k < 16} {incr k} {
	    set kk0  "$k."
	    set kk4  [expr {$k - 4.0}]
	    set kk8  [expr {$k - 8.0}]
	    set kk12 [expr {$k - 12.0}]
	    set kk16 [expr {$k - 16.0}]

	    set c0 [expr {$kk4 * $kk8 * $kk12 * $kk16 / $C0}]
	    set c1 [expr {$kk0 * $kk8 * $kk12 * $kk16 / $C1}]
	    set c2 [expr {$kk0 * $kk4 * $kk12 * $kk16 / $C2}]
	    set c3 [expr {$kk0 * $kk4 * $kk8  * $kk16 / $C1}]
	    set c4 [expr {$kk0 * $kk4 * $kk8  * $kk12 / $C0}]

	    lassign $v1 x1 y1 z1
	    lassign $v2 x2 y2 z2
	    lassign $v3 x3 y3 z3
	    lassign $v4 x4 y4 z4
	    lassign $v5 x5 y5 z5

	    set qipk [expr {4*$i+$k}]
	    lassign [set xout($qipk)] xo yo zo
	    set lecof [lindex $cof $k]

	    set xo [expr {$xo + $lecof*($x1*$c0 + $x2*$c1 + $x3*$c2 + $x4*$c3 + $x5*$c4)}]
	    set yo [expr {$yo + $lecof*($y1*$c0 + $y2*$c1 + $y3*$c2 + $y4*$c3 + $y5*$c4)}]
	    set zo [expr {$zo + $lecof*($z1*$c0 + $z2*$c1 + $z3*$c2 + $z4*$c3 + $z5*$c4)}]

	    set xout($qipk)  [list $xo $yo $zo]
	    set norms($qipk) [expr {[set norms($qipk)] + $lecof}]
	}
	incr i
    }

    for {set k 0} {$k < $km-1} {incr k} {
	set xout($k) [V_VS [set xout($k)] / [set norms($k)]]
    }

    foreach k [lsort -integer [array names xout]] {
	lappend Lo [set xout($k)]
    }

    return $Lo
}


proc GetRad {l} {
    global RadMol xc yc zc pgl

    foreach a {xc yc zc xm ym zm xx yx zx} {
	set $a 0.0
    }
    foreach {a x} {xm 1. ym 1. zm 1. xx -1. yx -1.  zx -1.} {
	set $a [expr {$x*999.0}]
    }
    foreach e $l {
	lassign $e x y z
	foreach a {x y z} b {xm ym zm} c {xx yx zx} {
	    if {[set $a] < [set $b]} {set $b [set $a]}
	    if {[set $a] > [set $c]} {set $c [set $a]}
	}
    }

    foreach a {xc yc zc} b {xm ym zm} c {xx yx zx} {
	set $a [expr {0.5 * ([set $c] + [set $b])}]
    }

    set RadMol -999999.
    set RadMol [expr {sqrt(($xx-$xm)**2 + \
	    ($yx-$ym)**2 + \
	    ($zx-$zm)**2) \
	    / 2.}]
    if {0} {
	foreach {xt yt zt} [list $xm $ym $zm $xx $yx $zx] {
	    set d [expr {sqrt(($xt-$xc)*($xt-$xc) + \
		    ($yt-$yc)*($yt-$yc) + \
		    ($zt-$zc)*($zt-$zc))}]
	    if {$d > $RadMol} {set RadMol $d}
	}
    }

    set pgl(xMin) $xm
    set pgl(yMin) $ym
    set pgl(zMin) $zm
    set pgl(xMax) $xx
    set pgl(yMax) $yx
    set pgl(zMax) $zx
    set pgl(xc)   $xc
    set pgl(yc)   $yc
    set pgl(zc)   $zc

    if {0} {
	puts "radius : $RadMol"
	set fmt [format "Centre  : %6.2f %6.2f %6.2f" $pgl(xc) $pgl(yc) $pgl(zc)]
	puts "$fmt"
	set fmt [format "Minimum : %6.2f %6.2f %6.2f" $pgl(xMin) $pgl(yMin) $pgl(zMin)]
	puts "$fmt"
	set fmt [format "Maximum : %6.2f %6.2f %6.2f" $pgl(xMax) $pgl(yMax) $pgl(zMax)]
	puts "$fmt"
    }

    return $RadMol
}



proc ReadDict {} {
    global Tbond OrdEtcDir

    set Ll [LesLignesDuFichier [file join $OrdEtcDir "stereo_chem.odb"]]
    set YaRes 0
    foreach l $Ll {
	if {[regexp {^residue} $l]} {
	    set YaRes 1
	    regsub -all { +} $l " " l
	    set Lr [split $l " "]
	    set Res [lindex $Lr 1]
	    continue
	}
	if {[regexp {^-------} $l]} {
	    set YaRes 0
	    continue
	}
	if {$YaRes} {
	    if {[regexp {^bond_distance} $l]} {
		regsub -all { +} $l " " l
		set Lb [split $l " "]
		set a1 [lindex $Lb 1]
		set a2 [lindex $Lb 2]
		lappend Tbond($Res) [list $a1 $a2]
	    }
	}
    }

    return
}



proc RayonDeAtome {a} {
    if {! [string is integer $a]} {
	set a [string index [string trim $a] 0]
    }
    return [VdWDe $a]
}


proc CouleurDeAtome {a} {
    # $a is an atom name or an atomic number
    set a [string trim $a]
    if {! [string is integer -strict $a]} {
	set a [string index $a 0]
    }
    switch $a {
	"C"  {set col [list 1. 1. 0.]}
	"N"  {set col [list 0. 0. 1.]}
	"O"  {set col [list 1. 0. 0.]}
	"P"  {set col [list 1. 1. 0.]}
	"S"  {set col [list 0. 1. 0.]}
	"Se" {set col [list 0. 1. 0.]}
	"H"  {set col [list 1. 1. 1.]}
	"6"  {set col [list 1. 1. 0.]}
	"7"  {set col [list 0. 0. 1.]}
	"8"  {set col [list 1. 0. 0.]}
	"15"  {set col [list 1. 1. 0.]}
	"16"  {set col [list 0. 1. 0.]}
	"34"  {set col [list 0. 1. 0.]}
	"1" {set col [list 1. 1. 1.]}
	default {set col [list 1. 0. 0.]}
    }

    return $col
}


proc CalculeLabFil {pdbid} {
    global PDB_[set pdbid]_Labels
    global PDB_[set pdbid]_NomAtm
    global PDB_[set pdbid]_AtmXYZ
    global PDB_[set pdbid]_NomRes
    global PDB_[set pdbid]_NmrRes
    global TLabList

    set TLabList [glGenLists 1]
    glNewList $TLabList GL_COMPILE_AND_EXECUTE

    set Lch [lrange [array names PDB_[set pdbid]_NomAtm] 1 end]

    glInitNames
    glPushName 0

    set i 0
    foreach c $Lch {
	set LNat [set PDB_[set pdbid]_NomAtm($c)]
	set Lxyz [set PDB_[set pdbid]_AtmXYZ($c)]
	set LNom [set PDB_[set pdbid]_NomRes($c)]
	set LNmr [set PDB_[set pdbid]_NmrRes($c)]

	foreach Lx $Lxyz La $LNat ro $LNom rn $LNmr {
	    set r [string totitle [AutreCodeLuc $ro]]
	    foreach a $La x $Lx {
		incr i
		set a [string trim $a]
		set PDB_[set pdbid]_Labels($i) [list "$a $r ${c}${rn}" $x]
		lassign $x x1 y1 z1
		glLoadName $i
		glBegin GL_POINTS
		glVertex3f $x1 $y1 $z1
		#		glVertex3f {*}$x
		glEnd
	    }
	}
    }

    glEndList

    return
}



proc FilDeFerDe {liste pdbid} {
    global Tbond
    global PDB_[set pdbid]_AtmXYZ
    global PDB_[set pdbid]_NomAtm
    global PDB_[set pdbid]_NomRes

    #    set Lch [lrange [array names PDB_[set pdbid]_AtmXYZ] 1 end]
    set Lch "A"

    foreach c $Lch {
	set LNat [set PDB_[set pdbid]_NomAtm($c)]
	set LNrs [set PDB_[set pdbid]_NomRes($c)]
	set Lxyz [set PDB_[set pdbid]_AtmXYZ($c)]

	set first 1
	foreach Lx $Lxyz La $LNat r1 $LNrs {
	    set r [AutreCodeLuc $r1]

	    foreach a $La x $Lx {
		set Ar([string trim $a]) $x
	    }

	    foreach bd [set Tbond($r)] {
		lassign $bd a b 
		if {$a eq "C-" || $b eq "C-"} {continue}
		set col1 [CouleurDeAtome $a]
		set col2 [CouleurDeAtome $b]

		TraceLigne $liste [set Ar($a)] [set Ar($b)] $col1 $col2
	    }
	    if {$first} {
		set first 0
	    } else {
		TraceLigne $liste [set Ar(N)] $Cx [CouleurDeAtome "N"] [CouleurDeAtome "C"]
	    }
	    set Cx [set Ar(C)]

	    unset Ar
	}
    }

    return
}


proc FilDeFerDe2 {liste pdbid} {
    global Tbond
    global PDB_[set pdbid]_AtmXYZ
    global PDB_[set pdbid]_NomAtm
    global PDB_[set pdbid]_NomRes

    #    set Lch [lrange [array names PDB_[set pdbid]_AtmXYZ] 1 end]
    set Lch "A"

    foreach c $Lch {
	set LNat [set PDB_[set pdbid]_NomAtm($c)]
	set LNrs [set PDB_[set pdbid]_NomRes($c)]
	set Lxyz [set PDB_[set pdbid]_AtmXYZ($c)]

	set first 1
	set colN  [CouleurDeAtome "N"]
	set colCA [CouleurDeAtome "C"]
	set colC  ${colCA}
	set colO  [CouleurDeAtome "O"]
	foreach Lx $Lxyz La $LNat r1 $LNrs {
	    set r [AutreCodeLuc $r1]
	    # Trace N-CA CA-C C-O
	    TraceLigne $liste [lindex $Lx 0] [lindex $Lx 1] ${colN} ${colCA}
	    TraceLigne $liste [lindex $Lx 1] [lindex $Lx 2] ${colCA} ${colC}
	    TraceLigne $liste [lindex $Lx 2] [lindex $Lx 3] ${colC} ${colO}

	    if {$r ne "GLY"} {
		TraceLigne $liste [lindex $Lx 1] [lindex $Lx 4] ${colC} ${colC}
		if {$r ne "ALA"} {
		    set Lb1 [lrange $Lx 4 end-1]
		    set Ll1 [lrange $La 4 end-1]
		    set i 5
		    foreach a1 $Lb1 l1 $Ll1 {
			set Lb2 [lrange $Lx $i end]
			set Ll2 [lrange $La $i end]
			foreach a2 $Lb2 l2 $Ll2 {
			    if {[Dist2 $a1 $a2] <= 3.8025} {
				TraceLigne $liste $a1 $a2 [CouleurDeAtome $l1] [CouleurDeAtome $l2]
			    }
			}
			incr i
		    }
		}
	    }
	    if {$first} {
		set first 0
	    } else {
		TraceLigne $liste [lindex $Lx 0] $Cx ${colN} ${colC}
	    }
	    set Cx [lindex $Lx 2]
	}
    }

    return
}


proc SticksDe {liste pdbid} {
    global Tbond
    global PDB_[set pdbid]_AtmXYZ
    global PDB_[set pdbid]_NomAtm
    global PDB_[set pdbid]_NomRes

    set QObj [gluNewQuadric]
    gluQuadricDrawStyle $QObj GLU_FILL
    gluQuadricNormals   $QObj GLU_SMOOTH
    gluQuadricTexture   $QObj GL_TRUE

    set Lch [lrange [array names PDB_[set pdbid]_AtmXYZ] 1 end]

    foreach c $Lch {
	set LNat [set PDB_[set pdbid]_NomAtm($c)]
	set LNrs [set PDB_[set pdbid]_NomRes($c)]
	set Lxyz [set PDB_[set pdbid]_AtmXYZ($c)]

	foreach Lx $Lxyz La $LNat r1 $LNrs {
	    set r [AutreCodeLuc $r1]
	    set Lb [set Tbond($r)]

	    foreach a $La c $Lx {
		set Ar([string trim $a]) $c
	    }

	    foreach bd [set Tbond($r)] {
		lassign $bd a b 
		if {$a eq "C-" || $b eq "C-"} {continue}
		TraceCylindre $liste $QObj [set Ar($a)] [set Ar($b)]
	    }
	    unset Ar
	}
    }

    return
}


proc TraceAtomeIsole {qobj lx col ball} {
    lassign [lindex $lx 0] x y z
    set off 0.5
    foreach {a b c} {1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0} {
	set v1 [list \
		    [expr {$x + $a * $off}] \
		    [expr {$y + $b*$off}] \
		    [expr {$z + $c*$off}]]
	set v2 [list \
		    [expr {$x - $a*$off}] \
		    [expr {$y - $b*$off}] \
		    [expr {$z - $c*$off}]]
	TraceLigne "" $v1 $v2 $col $col
    }

    return
}


proc TraceLiaison {qobj la lb col1 col2 stick} {
    if {$stick} {
	#use_light
	TraceCylindre "" $qobj $la $lb $col1 $col2
    } else {
	#dont_use_light
	TraceLigne "" $la $lb $col1 $col2
    }

    return
}


proc TraceCylindre {liste QObj la lb col1 col2 {Rd1 0.1} {Rd2 0.1}} {

    lassign $la x1 y1 z1
    lassign $lb x2 y2 z2

    set vx [expr {$x2-$x1}]
    set vy [expr {$y2-$y1}]
    set vz [expr {$z2-$z1}]
    set lg [expr {sqrt($vx*$vx+$vy*$vy+$vz*$vz)}]
    if {$lg == 0.0} {
	puts "===> lg=0. la = $la lb = $lb"
	set lg 1.
    }
    set al [expr {acos($vz/$lg)*180./acos(-1.)}]
    if {$vz < 0.0} {set al [expr {-1.*$al}]}

    set rx [expr {-$vy*$vz}]
    set ry [expr {$vx*$vz}]
    set rz 0.

    glPushMatrix
    glTranslatef $x1 $y1 $z1
    glRotatef    $al $rx $ry 0.0
    gluCylinder  $QObj $Rd1 $Rd2 $lg 32 1
    glPopMatrix

    return
}


proc TraceLigne {liste la lb col1 col2} {

    lassign $la x1 y1 z1
    lassign $lb x2 y2 z2

    set vx [expr {($x2-$x1)/2.+$x1}]
    set vy [expr {($y2-$y1)/2.+$y1}]
    set vz [expr {($z2-$z1)/2.+$z1}]

    if {0} {
	puts "col1 $col1"
	puts "col2 $col2"
	puts " $x1 $y1 $z1"
	puts " $vx $vy $vz"
	puts " $x2 $y2 $z2\n"
    }
    
    #    glColor3f  {*}$col1
    nolight_color3fv $col1
    glLineWidth 1.0
    glBegin GL_LINES
    glNormal3f 0.0 0.0 0.0
    glVertex3f $x1 $y1 $z1
    glNormal3f 0.0 0.0 0.0
    glVertex3f $vx $vy $vz
    glEnd

    #    glColor3f  {*}$col2
    nolight_color3fv $col2
    glBegin GL_LINES
    glNormal3f 0.0 0.0 0.0
    glVertex3f $x2 $y2 $z2
    glNormal3f 0.0 0.0 0.0
    glVertex3f $vx $vy $vz
    glEnd

    return
}


proc CalculeStick {list mol} {

    ReadDict
    SticksDe $list $mol

    return
}


proc CalculeFilDeFer {list mol} {
    ReadDict
    dont_use_light
    FilDeFerDe2 $list $mol

    return
}


proc BenjiLaMalice {mode} {

    if { $mode == $::GL_SELECT } {
	global TLabList

	if {! [info exists TLabList]} {
	    global Cor

	    set TLabList [glGenLists 1]
	    glNewList $TLabList GL_COMPILE_AND_EXECUTE

	    set Cor(0) [list "Text P0" {0.0 0.0 0.0}]
	    glInitNames
	    glPushName 0

	    glLoadName 0
	    glBegin GL_POINTS
	    glVertex3f 0.0 0.0 0.0
	    glEnd

	    set Cor(2) [list "Text P2" {1.0 0.0 0.0}]
	    glLoadName 2
	    glBegin GL_POINTS
	    glVertex3f 1.0 0.0 0.0
	    glEnd

	    set Cor(4) [list "Text P4" {0.0 1.0 0.0}]
	    glLoadName 4
	    glBegin GL_POINTS
	    glVertex3f 0.0 1.0 0.0
	    glEnd

	    set Cor(6) [list "Text P6" {0.0 0.0 -1.0}]
	    glLoadName 6
	    glBegin GL_POINTS
	    glVertex3f 0.0 0.0 -1.0
	    glEnd

	    glEndList
	} else {
	    #	    puts "===> Call List !"
	    #	    glCallList $PickList
	}
    } else {
	glBegin GL_TRIANGLES

	glColor3f  1.0  0.0  0.0
	#	light_color3f  1.0  0.0  0.0
	glNormal3f 1.0  0.0  0.0
	glVertex3f 0.0  0.0  0.0

	#	light_color3f  0.0  1.0  0.0
	glColor3f  0.0  1.0  0.0
	glNormal3f 1.0  0.0  0.0
	glVertex3f 0.0  0.0  1.0

	#	light_color3f  0.0  0.0  1.0
	glColor3f  0.0  0.0  1.0
	glNormal3f 1.0  0.0  0.0
	glVertex3f 0.0  1.0  0.0

	if {0} {
	    glColor3f  1.0  1.0  1.0
	    glNormal3f 0.0  1.0  0.0
	    glVertex3f 0.0  0.0  0.0
	    glColor3f  0.0  0.0  1.0
	    glNormal3f 0.0  1.0  0.0
	    glVertex3f 1.0  0.0  0.0
	    glColor3f  1.0  0.0  0.0
	    glNormal3f 0.0  1.0  0.0
	    glVertex3f 0.0  0.0 -1.0

	    glColor3f  0.0  1.0  0.0
	    glVertex3f 0.0  1.0  0.0
	    glColor3f  0.0  0.0  1.0
	    glVertex3f 1.0  0.0  0.0
	    glColor3f  1.0  0.0  0.0
	    glVertex3f 0.0  0.0 -1.0

	    glColor3f  1.0  1.0  1.0
	    glVertex3f 0.0  0.0  0.0
	    glColor3f  0.0  0.0  1.0
	    glVertex3f 1.0  0.0  0.0
	    glColor3f  0.0  1.0  0.0
	    glVertex3f 0.0  1.0  0.0
	}
	glEnd
    }

    return
}


proc FillTheBox {aT i j k an} {
    upvar $aT T

    foreach v [set ::SpS($an)] {
	lassign $v a b c
	set T([expr {$i+$a}],[expr {$j+$b}],[expr {$k+$c}]) 1
    }

    return

    if {0} {
	foreach a {-1 0 1} {
	    foreach b {-1 0 1} {
		foreach c {-1 0 1} {
		    set T([expr {$i+$a}],[expr {$j+$b}],[expr {$k+$c}]) 5
		}
	    }
	}
    } else {
	foreach a {-1 0 1} {
	    set T([expr {$i+$a}],$j,$k) 5
	}
	foreach b {-1 0 1} {
	    set T($i,[expr {$j+$b}],$k) 5
	}
	foreach c {-1 0 1} {
	    set T($i,$j,[expr {$k+$c}]) 5
	}
    }

    return
}


proc Atomes2Grille {bbox Lc Lx Lan} {
    SampleVdW
    
    set Step [set ::Defauts(Sampling)]
    set Offset [expr {$::SpS(Offset)+1}]

    set OffX $Offset
    set OffY $Offset
    set OffZ $Offset
    puts "Step $Step"
    puts "Offset $Offset"

    lassign $bbox xm xx ym yx zm zx
    set xmi [expr {int($xm*$Step)-1}]
    set ymi [expr {int($ym*$Step)-1}]
    set zmi [expr {int($zm*$Step)-1}]
    set xxi [expr {int($xx*$Step)+1}]
    set yxi [expr {int($yx*$Step)+1}]
    set zxi [expr {int($zx*$Step)+1}]
    
    lassign $Lc xc yc zc
    set xci [expr {round($xc*$Step)}]
    set yci [expr {round($yc*$Step)}]
    set zci [expr {round($zc*$Step)}]

    # faut Offset sur chaque bord
    set resX [expr {int($xx-$xm+0.5)*$Step+1+2*$Offset}]
    set resY [expr {int($yx-$ym+0.5)*$Step+1+2*$Offset}]
    set resZ [expr {int($zx-$zm+0.5)*$Step+1+2*$Offset}]

    # Faut que la resolution de la grille soit un 
    # multiple de 3
    set k 4
    set Extra 0
    while {$resX % (1*$Step) || $resX % ($k*$Step) } {
	incr Extra
	set resX [expr {int($xx-$xm+0.5)*$Step+1+2*$OffX+$Extra}]
    }
    set Extra 0
    while {$resY % (1*$Step) || $resY % ($k*$Step) } {
	incr Extra
	set resY [expr {int($yx-$ym+0.5)*$Step+1+2*$OffY+$Extra}]
    }
    set Extra 0
    while {$resZ % (1*$Step) || $resZ % ($k*$Step) } {
	incr Extra
	set resZ [expr {int($zx-$zm+0.5)*$Step+1+2*$OffZ+$Extra}]
    }
    puts "\nresX $resX resY $resY resZ $resZ"

    for {set k 0} {$k < $resZ } {incr k} {
	for {set j 0} {$j < $resY } {incr j} {
	    for {set i 0} {$i < $resX } {incr i} {
		set T($i,$j,$k) 0
	    }
	}
    }

    set g [open coord w]
    foreach rx $Lx lna $Lan {
	foreach v $rx an $lna {
	    lassign $v x y z
	    puts $g [format " %8.3f %8.3f %8.3f" $x $y $z]
	    set x [expr {round($x-$xm)*$Step+1+$OffX}]
	    set y [expr {round($y-$ym)*$Step+1+$OffY}]
	    set z [expr {round($z-$zm)*$Step+1+$OffZ}]

	    FillTheBox T $x $y $z $an
	    #set T($x,$y,$z) 1.
	}
    }
    close $g
    puts "fill table T [llength [array names T]]"

    foreach e [array names T] {
	lassign [split $e ,] i j k
	if {($i < 0 || $i >= $resX) || ($j < 0 || $j >= $resY) || ($k < 0 || $k >= $resZ)} {puts $e}
    }

    set Lv [list]
    lappend Lv [list $resX $resY $resZ]
    
    #ExpandMask T $resX $resY $resZ
    #ExpandMask T $resX $resY $resZ
    #ExpandMask T $resX $resY $resZ
    #ExpandMask T $resX $resY $resZ
    #ContractMask T $resX $resY $resZ
    #ContractMask T $resX $resY $resZ
    #ContractMask T $resX $resY $resZ
    #ContractMask T $resX $resY $resZ
    #ExpandMask T $resX $resY $resZ
    #ExpandMask T $resX $resY $resZ
    #ContractMask T $resX $resY $resZ

    set f [open test w]
    #lappend Lv [list 8 8 8]
    puts ""
    for {set k 0} {$k < $resZ } {incr k} {
	for {set j 0} {$j < $resY } {incr j} {
	    for {set i 0} {$i < $resX } {incr i} {
		lappend Lp [set T($i,$j,$k)]
		puts -nonewline $f [set T($i,$j,$k)]
		if {[set T($i,$j,$k)] == 0} {
		    puts -nonewline "."
		} else {
		    puts -nonewline "O"
		}
	    }
	    puts ""
	}
	puts "\n"
    }
    close $f
    puts "$resX $resY $resZ"
    exit
    lappend Lv $Lp
    
    set Ltrg [mctcl $Lv]

    return $Ltrg
}


proc SampleVdW {} {
    global Chm SpS Defauts
    
    set Offset 0
    set cof [set Defauts(Sampling)]
    foreach e [array names Chm *,vdw] {
	if {[set Chm($e)] == 0} {continue}
	lassign [split $e ,] n tmp
	set r [expr {int([set Chm($e)]*$cof+0.5)}]
	for {set i -$r} {$i <= $r} {incr i} {
	    for {set j -$r} {$j <= $r} {incr j} {
		for {set k -$r} {$k <= $r} {incr k} {
		    if {($i*$i+$j*$j+$k*$k) <= $r*$r} {
			lappend SpS($n) [list $i $j $k]
			if {$i > $Offset} {set Offset $i}
			if {$j > $Offset} {set Offset $j}
			if {$k > $Offset} {set Offset $k}
		    }
		}
	    }
	}
    }

    set SpS(Offset) $Offset

    return
}


proc ExpandMask {aT rx ry rz} {
    upvar $aT T

    array set Q [array get T]

    # rajoute 1 rangee en -1 et au bord sup
    # en Z
    for {set i 0} {$i < $rx} {incr i} {
	for {set j 0} {$j < $ry} {incr j} {
	    set T($i,$j,$rz) 0
	    set T($i,$j,-1) 0
	}
    }
    # en Y
    for {set i 0} {$i < $rx} {incr i} {
	for {set k 0} {$k < $rz} {incr k} {
	    set T($i,$ry,$k) 0
	    set T($i,-1,$k) 0
	}
    }
    # en X
    for {set j 0} {$j < $ry} {incr j} {
	for {set k 0} {$k < $rz} {incr k} {
	    set T($rx,$j,$k) 0
	    set T(-1,$j,$k) 0
	}
    }

    
    for {set i 0} {$i < $rx} {incr i} {
	for {set j 0} {$j < $ry} {incr j} {
	    for {set k 0} {$k < $rz} {incr k} {
		set Q($i,$j,$k) [expr {[set T([expr {$i-1}],$j,$k)] || [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T([expr {$i+1}],$j,$k)] || [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,[expr {$j-1}],$k)] || [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,[expr {$j+1}],$k)] || [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,$j,[expr {$k-1}])] || [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,$j,[expr {$k+1}])] || [set Q($i,$j,$k)]}]
	    }
	}
    }

    unset T
    array set T [array get Q]

    return
}


proc ContractMask {aT rx ry rz} {
    upvar $aT T

    array set Q [array get T]

    # rajoute 1 rangee en -1 et au bord sup
    # en Z
    for {set i 0} {$i < $rx} {incr i} {
	for {set j 0} {$j < $ry} {incr j} {
	    set T($i,$j,$rz) 0
	    set T($i,$j,-1) 0
	}
    }
    # en Y
    for {set i 0} {$i < $rx} {incr i} {
	for {set k 0} {$k < $rz} {incr k} {
	    set T($i,$ry,$k) 0
	    set T($i,-1,$k) 0
	}
    }
    # en X
    for {set j 0} {$j < $ry} {incr j} {
	for {set k 0} {$k < $rz} {incr k} {
	    set T($rx,$j,$k) 0
	    set T(-1,$j,$k) 0
	}
    }

    
    for {set i 0} {$i < $rx} {incr i} {
	for {set j 0} {$j < $ry} {incr j} {
	    for {set k 0} {$k < $rz} {incr k} {
		set Q($i,$j,$k) [expr {[set T([expr {$i-1}],$j,$k)] && [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T([expr {$i+1}],$j,$k)] && [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,[expr {$j-1}],$k)] && [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,[expr {$j+1}],$k)] && [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,$j,[expr {$k-1}])] && [set Q($i,$j,$k)]}]
		set Q($i,$j,$k) [expr {[set T($i,$j,[expr {$k+1}])] && [set Q($i,$j,$k)]}]
	    }
	}
    }

    unset T
    array set T [array get Q]

    return
}


proc SortTriangles {Lt Ln} {
    foreach t $Lt {n1 n2 n3} $Ln {
	lassign $t v1 v2 v3
	set Ltn [list]
	foreach v {v1 v2 v3} n {n1 n2 n3} {
	    lappend Ltn [list [set $v] [set $n]]
	}
	set Ltn [lsort -index {0 2} -real $Ltn]
	lappend Lall $Ltn
    }
    set Lall [lsort -real -index {0 0 2} $Lall]
    
    set Lt [list] ; set Ln [list]
    foreach e $Lall {
	set Lt [list]
	foreach vn $e {
	    lassign $vn v n
	    lappend Lt $v
	    lappend Ln $n
	}
	lappend Ltri $Lt
    }
    
    return [list $Ltri $Ln]
}


proc DrawAtomsProtein {cp cyl QObj Lx La Ln} {
    # cp : draw main chain
    # cyl : draw as stick or line
    # QObj : quadric object for stick/ball

    set colCA [CouleurDeAtome "C"]
    set first 1
    if {$cp} {
	set colN  [CouleurDeAtome "N"]
	set colC  $colCA
	set colO  [CouleurDeAtome "O"]
    }
    foreach rx $Lx rn $La n $Ln {
	#if {! [EstUnBonResidu $rn]} {continue}
	
	# CA atoms alone 
	if {[llength $rx] == 1} {
	    set first 1

	    TraceAtomeIsole $QObj $rx $colCA 0

	    continue
	}
	
	set ACA [lindex $rx 1]
	if {$cp} {
	    set AN  [lindex $rx 0]
	    set AC  [lindex $rx 2]
	    set AO  [lindex $rx 3]
	    
	    # Trace N-CA CA-C C-O
	    TraceLiaison $QObj $AN $ACA ${colN} ${colCA} $cyl
	    TraceLiaison $QObj $ACA $AC ${colCA} ${colC} $cyl
	    TraceLiaison $QObj $AC $AO ${colC} ${colO} $cyl
	}
	
	if {[llength $rx] > 4} {
	    # CA - CB
	    TraceLiaison $QObj $ACA [lindex $rx 4] $colCA $colCA $cyl
	    if {$n eq "PRO"} {		
		TraceLiaison $QObj [lindex $rx 0] [lindex $rx end] [CouleurDeAtome " N  "] [CouleurDeAtome " C  "] $cyl
	    }
	    if {$n eq "ALA"} {continue}

	    set Lb1 [lrange $rx 4 end-1]
	    set Ll1 [lrange $rn 4 end-1]
	    # Dans certains PDB, il manque des 
	    # atomes. Ex, on a LYS et les atomes s'
	    # arretent a CB .... Dommage !
	    if {[llength $Lb1] > 1 && [llength $Ll1] > 1} {
		set i 5
		foreach a1 $Lb1 l1 $Ll1 {
		    set Lb2 [lrange $rx $i end]
		    set Ll2 [lrange $rn $i end]
		    foreach a2 $Lb2 l2 $Ll2 {
			if {[Dist2 $a1 $a2] <= 3.8025} {
			    TraceLiaison $QObj $a1 $a2 [CouleurDeAtome $l1] [CouleurDeAtome $l2] $cyl
			}
		    }
		    incr i
		}
	    }
	}
	if {$cp} {
	    if {$first} {
		set first 0
	    } else {
		# check for correct distance between
		# adjacent residues
		if {[Dist2 [lindex $rx 0] $Cx] <= 3.8025} {
		    TraceLiaison $QObj [lindex $rx 0] $Cx ${colN} ${colC} $cyl
		}
	    }
	    set Cx [lindex $rx 2]
	}
    }
    
    return
}


proc DrawAtomsNucleic {cp cyl QObj Lx La Ln} {
    # cp : draw main chain
    # cyl : draw as stick or line
    # QObj : quadric object for stick/ball

    # atoms order in PDB
    # 0P3 P OP1 OP2 O5' C5' C4' O4' C3' O3' C2' C1' 
    set colP [CouleurDeAtome "P"]
    set colN [CouleurDeAtome "N"]
    set colC [CouleurDeAtome "C"]
    set colO [CouleurDeAtome "O"]
    if {$cp} {set first 1} {set first 0}

    foreach rx $Lx rn $La n $Ln {
	if {" OP3"  in $rn} {set off 1} {set off 0}
	if {" O2''" in $rn} {set o2p 1} {set o2p 0}
	set of2 [expr {$off+$o2p}]
	
	if {$cp} {
	    if {$off && $o2p} {
		set Lcl [lassign $rx AOP3 AP AOP1 AOP2 AO5p AC5p AC4p AO4p AC3p AO3p AC2p AO2p AC1p]
	    } elseif {$off && ! $o2p} {
		set Lcl [lassign $rx AOP3 AP AOP1 AOP2 AO5p AC5p AC4p AO4p AC3p AO3p AC2p AC1p]
	    } elseif {! $off && $o2p} {
		set Lcl [lassign $rx AP AOP1 AOP2 AO5p AC5p AC4p AO4p AC3p AO3p AC2p AO2p AC1p]
	    } else {
		set Lcl [lassign $rx AP AOP1 AOP2 AO5p AC5p AC4p AO4p AC3p AO3p AC2p AC1p]
	    }
	} else {
	    set AP   [lindex $rx 0+$off]
	    set AC1p [lindex $rx 10+$of2]
	    # base atoms, after C1' (as the lassign above)
	    set Lcl  [lrange $rx 11+$of2 end]
	}

	if {$cp} {
	    # Trace P-OP1 P-OP2 P-O3P O3P-C3P ...
	    if {$off} {
		TraceLiaison $QObj $AP $AOP3 $colP $colO $cyl
	    }
	    
	    TraceLiaison $QObj $AP $AOP1 $colP $colO $cyl
	    TraceLiaison $QObj $AP $AOP2 $colP $colO $cyl
	    TraceLiaison $QObj $AP $AO5p $colP $colO $cyl
	    TraceLiaison $QObj $AO5p $AC5p $colO $colC $cyl
	    TraceLiaison $QObj $AC5p $AC4p $colC $colC $cyl
	    TraceLiaison $QObj $AC4p $AO4p $colC $colO $cyl
	    TraceLiaison $QObj $AO4p $AC1p $colO $colC $cyl
	    TraceLiaison $QObj $AC1p $AC2p $colC $colC $cyl
	    TraceLiaison $QObj $AC2p $AC3p $colC $colC $cyl
	    TraceLiaison $QObj $AC3p $AC4p $colC $colC $cyl
	    TraceLiaison $QObj $AC3p $AO3p $colC $colO $cyl
	    if {$o2p} {
		TraceLiaison $QObj $AC2p $AO2p $colC $colO $cyl
	    }
	} else {
	    TraceLiaison $QObj $AP $AC1p $colP $colC $cyl
	}
	if {[llength $rx] <= 11+$of2} {continue}

	# side chain
	# insert C1' first , as we can have 
	# PSU, purine or pyrimidine that connect C1'
	# in different ways
	# Dans certains PDB, il manque des 
	# atomes. On a LYS et les atomes s'
	# arretent a CB .... Dommage !
	set Lb1 [linsert $Lcl 0 $AC1p]
	set Ll1 [lrange $rn end-[expr {[llength $Lb1]-1}] end]
	
	if {[llength $Lb1] > 2 && [llength $Ll1] > 2} {
	    set i 1
	    foreach a1 [lrange $Lb1 0 end-1] l1 [lrange $Ll1 0 end-1] {
		set c1 [CouleurDeAtome $l1]

		set Lb2 [lrange $Lb1 $i end]
		set Ll2 [lrange $Ll1 $i end]
		foreach a2 $Lb2 l2 $Ll2 {
		    if {[Dist2 $a1 $a2] <= 3.8025} {
			TraceLiaison $QObj $a1 $a2 $c1 [CouleurDeAtome $l2] $cyl
		    }
		}
		incr i
	    }
	}
	if {$cp} {
	    if {$first} {
		set first 0
	    } else {
		TraceLiaison $QObj $AP $Cx $colP $colO $cyl
	    }
	    set Cx $AO3p
	}
    }

    return
}


proc DrawRibbonProtein {LesVecs} {

    #use_light
    set wr 0
    set zcol {0.2 0.2 1.0 1.0}

    foreach {n1 c1 v1 n2 c2 v2 n3 c3 v3} $LesVecs {
	glBegin GL_TRIANGLES
	glColor4f {*}$c1 1.0
	glNormal3fv $n1
	glVertex3fv $v1
	glNormal3fv $n2
	glVertex3fv $v2
	glNormal3fv $n3
	glVertex3fv $v3
	glEnd
    }

    return
}
	
	
proc DrawRibbonNucleic {Lpts Lcol} {
    
    puts "Lpts [llength $Lpts] [llength $Lcol]"
    #return
    set QObj [gluNewQuadric]
    gluQuadricDrawStyle $QObj GLU_FILL
    gluQuadricNormals   $QObj GLU_SMOOTH
    gluQuadricTexture   $QObj GL_TRUE

    set p0 [lindex $Lpts 0]
    set c0 [lindex $Lpts 0]
    set Rad 1.0
    foreach pt [lrange $Lpts 1 end] cl [lrange $Lcol 1 end] {
	TraceCylindre "" $QObj $p0 $pt $c0 $cl $Rad $Rad
	glPushMatrix
	glTranslatef {*}$p0
	glColor4fv $cl
	gluSphere $QObj 1.0 32 32
	glPopMatrix
	set p0 $pt
	set c0 $cl
    }
    glPushMatrix
    glTranslatef {*}$pt
    glColor4fv $cl
    gluSphere $QObj 1.0 32 32
    glPopMatrix

    gluDeleteQuadric $QObj

    return
}

