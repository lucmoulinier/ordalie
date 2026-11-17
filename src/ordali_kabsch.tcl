

#
#
# --- ordali_kabsch.tcl
#
#



# Calcule le centroïde d'un ensemble de points
proc centroid {points} {
    set n [llength $points]
    set sum {0.0 0.0 0.0}
    foreach pt $points {
        foreach i {0 1 2} {
            lset sum $i [expr {[lindex $sum $i] + [lindex $pt $i]}]
        }
    }
    foreach i {0 1 2} {
        lset sum $i [expr {[lindex $sum $i] / $n}]
    }

    return $sum
}

# Soustrait un vecteur (centroïde) de chaque point
proc center_points {points centroid} {
    set centered {}
    foreach pt $points {
        set newpt {}
        foreach i {0 1 2} {
            lappend newpt [expr {[lindex $pt $i] - [lindex $centroid $i]}]
        }
        lappend centered $newpt
    }
    return $centered
}

# Calcule la matrice de covariance (3x3)
proc covariance_matrix {A B} {
    set H [list [list 0 0 0] [list 0 0 0] [list 0 0 0]]
    set n [llength $A]
    for {set k 0} {$k < $n} {incr k} {
        set a [lindex $A $k]
        set b [lindex $B $k]
        foreach i {0 1 2} {
            foreach j {0 1 2} {
                lset H $i $j [expr {[lindex $H $i $j] + [lindex $a $i]*[lindex $b $j]}]
            }
        }
    }

    return $H
}

# Produit matriciel 3x3 x 3x3
proc matmul3x3 {A B} {
    set result {}
    for {set i 0} {$i < 3} {incr i} {
        set row {}
        for {set j 0} {$j < 3} {incr j} {
            set sum 0.0
            for {set k 0} {$k < 3} {incr k} {
                set sum [expr {$sum + [lindex $A $i $k] * [lindex $B $k $j]}]
            }
            lappend row $sum
        }
        lappend result $row
    }

    return $result
}

# Transpose d'une matrice 3x3
proc transpose3x3 {M} {
    set T {}
    for {set i 0} {$i < 3} {incr i} {
        set row {}
        for {set j 0} {$j < 3} {incr j} {
            lappend row [lindex $M $j $i]
        }
        lappend T $row
    }

    return $T
}

# Déterminant d'une matrice 3x3
proc det3x3 {M} {
    lassign $M a b c
    lassign $a a1 a2 a3
    lassign $b b1 b2 b3
    lassign $c c1 c2 c3

    return [expr {$a1*($b2*$c3-$b3*$c2) - $a2*($b1*$c3-$b3*$c1) + $a3*($b1*$c2-$b2*$c1)}]
}

# Algorithme de Kabsch : superpose P (mobile) sur Q (référence).
# Renvoie {rmsd maxdev Rot Trans} (Rot, Trans : "array get")
# tels que x' = Rot.x + Trans
proc kabsch {Q P} {
    # Étape 1 : centrer les points
    set centroid_P [centroid $P]
    set centroid_Q [centroid $Q]

    set P_centered [center_points $P $centroid_P]
    set Q_centered [center_points $Q $centroid_Q]

    # Étape 2 : matrice de covariance
    set H [covariance_matrix $P_centered $Q_centered]

    # Étape 3 : SVD de H
    package require math::linearalgebra
    lassign [::math::linearalgebra::determineSVD $H] U S V
    
    # Étape 4 : calcul de R = V * U^T
    set Ut [transpose3x3 $U]
    set R [matmul3x3 $V $Ut]

    # correction de réflexion : si det(R) < 0, R est une rotation
    # impropre (miroir). On inverse le vecteur singulier associé à
    # la plus petite valeur singulière : R = V diag(1,1,-1) U^T
    if {[det3x3 $R] < 0.} {
	set imin 0
	foreach i {1 2} {
	    if {[lindex $S $i] < [lindex $S $imin]} {set imin $i}
	}
	foreach i {0 1 2} {
	    lset V $i $imin [expr {-1.0*[lindex $V $i $imin]}]
	}
	set R [matmul3x3 $V $Ut]
    }

    # apply rotation
    set Lp {}
    foreach pt $P_centered {
	set new [V_MV $R * $pt]
	set new [V_VV $new + $centroid_Q]
	lappend Lp $new
    }

    # calcul RMSD and max diviation
    set rms 0.0
    set maxD -1.
    foreach a $Lp b $Q {
	set d2 [Dist2 $a $b]
	set rms [expr {$rms + $d2}]
	if {$d2 > $maxD} {
	    set maxD $d2
	}
    }    
    set maxD [expr {sqrt($maxD)}]
    set rms [expr {sqrt($rms / [llength $P])}]

    # x' = R.(x - cP) + cQ = R.x + (cQ - R.cP)
    set Trans [V_VV $centroid_Q - [V_MV $R * $centroid_P]]
    lassign $Trans T(1) T(2) T(3)
    set i 1
    foreach row $R {
	lassign $row Rot($i,1) Rot($i,2) Rot($i,3)
	incr i
    }

    # return [list $R $centroid_P $centroid_Q]
    return [list $rms $maxD [array get Rot] [array get T]]
}

# Applique une matrice de rotation à un vecteur
proc rotate_point {R pt} {
    set result {}
    for {set i 0} {$i < 3} {incr i} {
        set sum 0.0
        for {set j 0} {$j < 3} {incr j} {
            set sum [expr {$sum + [lindex $R $i $j] * [lindex $pt $j]}]
        }
        lappend result $sum
    }

    return $result
}


# Exemple d'utilisation
proc kabsch_example {} {
    set A [list {1 0 0} {0 1 0} {0 0 1}]
    set B [list {0 1 0} {-1 0 0} {0 0 1}] ;# Rotation de 90° autour de z
    
    set result [kabsch $A $B]
    set R [lindex $result 0]
    set cA [lindex $result 1]
    set cB [lindex $result 2]
    
    puts "Matrice de rotation R:"
    puts $R
    exit
}


    
