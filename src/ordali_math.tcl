


# --- ordali_math.tcl
#
#


proc MinMax {liste} {
    if {[string is double [lindex $liste 0]]} {
	set l [lsort -real $liste]
    } else {
	set l [lsort -integer $liste]
    }

    return [list [lindex $l 0] [lindex $l end]]
}


proc K { x y } { set x }


proc shuffle4 { list } {
    set n [llength $list]
    while {$n > 0} {
	set j [expr {int(rand()*$n)}]
	lappend slist [lindex $list $j]
	incr n -1
	set temp [lindex $list $n]
	set list [lreplace [K $list [set list {}]] $j $j $temp]
    }

    return $slist
}


proc shuffle4_2lists { list1 list2 } {
    set n [llength $list1]
    while {$n > 0} {
	set j [expr {int(rand()*$n)}]
	lappend slist1 [lindex $list1 $j]
	lappend slist2 [lindex $list2 $j]
	incr n -1
	set temp1 [lindex $list1 $n]
	set temp2 [lindex $list2 $n]
	set list1 [lreplace [K $list1 [set list1 {}]] $j $j $temp1]
	set list2 [lreplace [K $list2 [set list2 {}]] $j $j $temp2]
    }

    return [list $slist1 $slist2]
}


proc ShuffleList {l {ret "list"}} {
    set n [llength $l]
    if {$n< 2} {
	return $l
    }
    
    set Li {}
    set nOK 0
    while {$nOK < $n} {
	set x [expr {int(rand() * $n)}]
	if {$x ni $Li && $x != $n} {
	    lappend Li $x
	    incr nOK
	}
    }

    # if ret = indices, return indices list,
    # otherwise return shuffled list
    if {$ret  eq "indices"} {
	return $Li
    }
    
    set Lnew {}
    foreach i $Li {
	lappend Lnew [lindex $l $i]
    }

    return $Lnew
}


    proc nist_pca {{X ""}} {
    package require La
    catch {namespace import ::La::*}

    if {$X eq ""} {
	set X {2 10 3 7 4 3 4 1 8 6 3 5 8 6 1 8 5 7 7 2 9 5 3 3 9 5 8 7 4 5 8 2 2}
    }

    set nlin [lindex $X 1]
    set Nobs $nlin
    set ncol [lindex $X 2]

    puts "Matrix of observation data X\[$nlin,$ncol\]"

    puts [show $X]
    puts {Compute column norms}
    mnorms_br X Xmeans Xsigmas
    puts "Means=[show $Xmeans]"
    puts "Sigmas=[show $Xsigmas %.6f]"
    puts "Normalize observation data creating Z\[$nlin,$ncol\]"
    puts [show [set Z [mnormalize $X $Xmeans $Xsigmas]] %10.6f]\n
    puts {Naive computation method that is sensitive to round-off error}
    puts {ZZ is (Ztranspose)(Z) }
    puts "ZZ=\n[show [set ZZ [mmult [transpose $Z] $Z]] %10.6f]"
    puts {the correlation matrix, R = (Zt)(Z)/(n-1)}
    puts "R=\n[show [set R [mscale $ZZ [expr {1/($Nobs-1)}]]] %8.4f]"
    puts {Continuing the naive example use R for the eigensolution}
    set V $R
    mevsvd_br V evals
    puts "eigenvalues=[show $evals %8.4f]"
    puts "eigenvectors:\n[show $V %8.4f]\n"
    puts "Good computation method- perform SVD of Z"
    
    #lm : on retourne eigenvalue et eigenvectors
    set Eval $evals
    set Evec $V

    set U $Z
    msvd_br U S V
    puts "Singular values, S=[show $S]"
    puts "square S and divide by (number of observations)-1 to get the eigenvalues"
    set SS [mprod $S $S]
    set evals [mscale $SS [expr {1.0/($Nobs - 1)}]]
    puts "eigenvalues=[show $evals %8.4f]"
    puts "eigenvectors:\n[show $V %8.4f]"
    puts "(the 3rd vector/column has inverted signs, thats ok the math still works)"
    puts "\nverify V x transpose = I"
    puts "As computed\n[show [mmult $V [transpose $V]] %20g]\n"
    puts "Rounded off\n[show [mround [mmult $V [transpose $V]]]]"
    #puts "Diagonal matrix of eigenvalues, L"
    #set L [mdiag $evals]
    #

    puts "\nsquare root of eigenvalues as a diagonal matrix"
    proc sqrt x { return [expr sqrt($x)] }
    set evals_sr [mat_unary_op $evals sqrt]
    set Lhalf [mdiag $evals_sr]
    puts [show $Lhalf %8.4f]

    puts "Factor Structure Matrix S"
    set S [mmult $V $Lhalf]
    puts [show $S %8.4f]\n
    set S2 [mrange $S 0 1]
    puts "Use first two eigenvalues\n[show $S2 %8.4f]"
    # Nash discusses better ways to compute this than multiplying SSt
    # the NIST method is sensitive to round-off error
    set S2S2 [mmult $S2 [transpose $S2]]
    puts "SSt for first two components, communality is the diagonal"
    puts [show $S2S2 %8.4f]\n


    # define reciprocal square root function
    proc recipsqrt x { return [expr 1.0/sqrt($x)] }
    # use it for Lrhalf calculation
    set Lrhalf [mdiag [mat_unary_op $evals recipsqrt]]

    set B [mmult $V $Lrhalf]
    puts "Factor score coefficients B Matrix:\n[show $B %12.4f]"

    puts "NIST shows B with a mistake, -.18 for -1.2 (-1.18 with a typo)"

    puts "\nWork with first normalized observation row"
    #    set z1 {2 3 0 0.065621795889 0.316227766017 -0.7481995314}
    set z1 "2 $ncol 0"
    for {set li 0} {$li < $ncol} {incr li} {
	lappend z1 [lindex $Z [expr $li + 3]]
    }
    puts [show $z1 %.4f]

    puts "compute the \"factor scores\" from multiplying by B"
    set t [mmult [transpose $z1] $B]
    puts [show $t %.4f]
    puts "NIST implies you might chart these"

    #set T2 [dotprod $t $t]
    #puts "Hotelling T2=[format %.4f $T2]"

    puts "Compute the scores using V, these are more familiar"
    set t [mmult [transpose $z1] $V]
    puts [show $t %.4f]
    puts "Calculate T2 from the scores, sum ti*ti/evi"

    set T2 [msum [transpose [mdiv [mprod $t $t] [transpose $evals]]]]
    puts "Hotelling T2=[format %.4f $T2]"

    puts "Fit z1 using first two principal components"
    set p [mrange $V 0 1]
    puts p=\n[show $p %10.4f]
    set t [mmult [transpose $z1] $p]
    set zhat [mmult $t [transpose $p]]
    puts "  z1=[show $z1 %10.6f]"
    puts "zhat=[show $zhat %10.6f]"
    set diffs [msub [transpose $z1] $zhat]
    puts "diff=[show $diffs %10.6f]"
    puts "Q statistic - distance from the model measurement for the first observation"
    set Q [dotprod $diffs $diffs]
    puts Q=[format %.4f $Q]
    puts "Some experts would compute a corrected Q that is larger since the
    observation was used in building the model.  The Q calculation just used
    properly applies to the analysis of new observations."
    set corr [expr 10.0/(10.0 - 2 -1)]  ;# N/(N - Ncomp - 1)
    puts "Corrected Q=[format %.4f [expr $Q * $corr]] (factor=[format %.4f $corr])"

    return [list $Eval $Evec]
}



proc PrepareHisto_VOIR_PLUS_LOIN {f} {

    if {[llength $f] == 1} {
	set lignes [LesLignesDuFichier $f]
	set L [lrange $lignes 2 end]
    } else {
	set L $f
    }
    
    foreach e $L {
	if {$e == -999.} {continue}
	regsub -all { +} $e " " e
	set Ln [split $e " "]
	lappend liste [lindex $Ln 1]
    }
    
    CreeHistogramme $liste 30
    
    return
}



proc FaitACP {} {
    
    global ListeScore
    
    set nlgn [llength $ListeScore]
    set ncol [llength [lindex $ListeScore 0]]
    set X "2 $nlgn $ncol"
    foreach l $ListeScore {
	foreach e $l {
	    lappend X $e
	}
    }
    EspionneL $X
    nist_pca $X
    exit
}



proc factorial2 {n} {
    
    #    n! = sqrt(2*pi)*n^(n+1/2)*e^-n
    return [expr {sqrt(2.*3.1415926)*pow($n,($n+0.5))*exp(-1.*$n)}]
}



proc factorial1 {n} {
    expr {$n>1?$n*[factorial1 [expr {$n-1}]]:1}
}



proc PrepareHisto {f} {
    
    set lignes [LesLignesDuFichier $f]
    set L [lrange $lignes 2 end]
    foreach e $L {
	if {$e == -999} {continue}
	set Ln [split $e "\t"]
	lappend liste [lindex $Ln 1]
    }
    
    CreeHistogramme $liste 50
    
    return
}


proc TraceHistogramme {LesX LesY {MinX ""} {MaxX ""} {MinY ""} {MaxY ""}} {

    set LesXTries [lsort -real $LesX]
    set LesYTries [lsort -real $LesX]
    if {$MinX eq ""} {
	set MinX [lindex $LesXTries 0]
    }
    if {$MaxX eq ""} {
	set MaxX [lindex $LesXTries end]
    }
    if {$MinY eq ""} {
	set MinY [lindex $LesYTries 0]
    }
    if {$MaxY eq ""} {
	set MaxY [lindex $LesYTries end]
    }
    
    return
}


proc CreeHistogrammeVal {liste N {min ""} {max ""}} {
    set Lt [lsort -increasing -real $liste]
    if {$min eq ""} {
	set min [lindex $Lt 0]
    }
    if {$max eq ""} {
	set max [lindex $Lt end]
    }
    set step [format %.3f [expr {double(($max - $min))/$N}]]

    #puts "min $min max $max"
    for {set i 0} {$i < $N} {incr i} {
	set d [expr {$min + $i * $step}]
	set f [expr {$d + $step}]
	set T($d) 0
	lappend Bornes $d
	foreach e $liste {
	    if {$e >= $d && $e < $f} {
		incr T($d)
	    }
	}
	#puts "$d $f $T($d)"
	lappend LesY [set T($d)]
    }

    return [list $Bornes $LesY [array get T]]
}


proc CreeHistogramme {liste N {sortie ""} {K ""} {color "white"} {tag ""} {min ""} {max ""} {step ""}} {
    
    if {$liste == {} } {return}
    
    lassign [CreehistogrammeVal $liste $N $min $max] Bornes LesY st
    array set T $sT

    if {$sortie eq "graph"} {
	set wdt [$K cget -width]
	set hgt [$K cget -height]
	set Ltag [lrepeat [llength $Bornes] $tag]
	return [Graphe $Bornes $LesY $K $color $wdt $hgt "" "" "" $Ltag]
    } else {
	return [array get T]
    }
}


proc Pi {} {
    return [expr {acos(-1.)}]
}



proc PiS2 {} {
    return [expr {acos(-1.)/2.}]
}



proc PiS4 {} {
    return [expr {acos(-1.)/4.}]
}



proc PiS8 {} {
    return [expr {acos(-1.)/8.}]
}


proc PiS16 {} {
    return [expr {acos(-1.)/16.}]
}


proc 2Pi {} {
    return [expr {2.*acos(-1.)}]
}


proc Coords2Angle {x y {epsilon 0.0001} } {
    
    if {abs($x) > $epsilon} {
	set theta [expr {atan($y / $x)}]
    } elseif {$y >= 0.0} {
	set theta [expr {[Pi] / 2.}]
    } else {
	set theta [expr {1.5 * [Pi]}]
    }
    
    if {$x < -$epsilon} {set theta [expr {[Pi] + $theta}]}
    while {$theta > [2Pi]} {set theta [expr {$theta-[2Pi]}]}
    while {$theta < 0.0} {set theta [expr {$theta+[2Pi]}]}
    
    return $theta
}


proc LissageParFenetre {Lx wdt} {

    if {! ($wdt % 2)} {
	FaireLire "Smoothing coefficient should be odd !"
	return
    }
    set w [expr {($wdt-1)/2}]
    
    set l [llength $Lx]
    for {set i 0} {$i < $l} {incr i} {
	set d [expr {$i - $w}]
	set f [expr {$i + $w}]
	set ax 0.0
	set n 0
	foreach x [lrange $Lx $d $f] {
	    set ax [expr {$ax + $x}]
	    incr n
	}
	set nx [expr {$ax/$n}]

	lappend newx $nx
    }

    return $newx
}


proc Derivee {l {s 2}} {
    # Attention !! Fct renvoie n-1 valeurs !!

    if {$s != 2 && $s != 3} {set s 3}
    if {$s == 2} {
	foreach v [lrange $l 0 end-1] w [lrange $l 1 end] {
	    set e [expr {$w-$v}]
	    lappend d $e
	}
    } else {
	foreach v [lrange $l 0 end-2] w [lrange $l 2 end] {
	    set e [expr {$w-$v}]
	    lappend d $e
	}
    }

    return $d
}


proc NormalisationZScore {Lvalues {Exclue -1234567890}} {
    set n [llength [lsort -unique $Lvalues]]
    if {$n == 0|| $n == 1} {
	# empty list or list of same value
	return $Lvalues
    }

    # Moyenne
    set sum 0.0
    set n 0
    foreach v $Lvalues {
	if {$Exclus != -1234567890 && $v!= $Exclue} {
	    set sum [expr {$sum + $v}]
	    incr n
	}
    }
    set mean [expr {$sum / double($n)}]

    # Écart-type
    set sum_sq 0.0
    foreach v $Lvalues {
	if {$Exclue != -1234567890 && $Exclue != $v} {
	    set sum_sq [expr {$sum_sq + ($v - $mean)**2}]
	}
    }
    set std [expr {sqrt($sum_sq / double($n))}]

    if {$std == 0} {
        puts "Écart-type nul : toutes les valeurs sont identiques"
	return $Lvalues
    }

    # Normalisation
    set result {}
    foreach v $Lvalues {
	if {$v != $Exclue} {
	    lappend result [expr {($v - $mean) / $std}]
	} else {
	    lappend result $v
	}
    }

    return $result
}


proc CoefficientCorrelation {lx ly} {
    # Ici lx et ly doivent etre de meme longueur
    if {[llength $lx] != [llength $ly]} {
	return ""
    }

    # Calcule moyenne de x et y, 
    # somme des x2 , y2
    # somme des xy
    #
    # coef.corr = cov(x,y)/(sigx*sigy)
    set sx 0.  ; set sy 0.
    set s2x 0. ; set s2y 0.
    set sxy 0.
    set N [llength $lx]
    foreach x $lx y $ly {
	set sx  [expr {$sx + $x}]
	set sy  [expr {$sy + $y}]
	set sxy [expr {$sxy + $x*$y}]
	set s2x [expr {$s2x + $x*$x}]
	set s2y [expr {$s2y + $y*$y}]
    }
    set mx [expr {$sx/$N}]
    set my [expr {$sy/$N}]
    set ex [expr {sqrt($s2x/$N-$mx*$mx)}]
    set ey [expr {sqrt($s2y/$N-$my*$my)}]

    if {$ex != 0.0 && $ey != 0.0} {
	set c [expr {($sxy/$N-$mx*$my)/($ex*$ey)}]
    } else {
	set c -999.
    }

    return $c
}


proc EcartType {l} {
    if {! [llength $l]} {
	return -1
    }

    set sd 0. ; set sx 0.0 ;  set s2x 0.
    set n [llength $l]
    foreach e $l {
	set sx [expr {$sx + $e}]
	set s2x [expr {$s2x+$e*$e}]
    }
    set mx [expr {$sx/$n}]
    set var [expr {$s2x/$n - $mx*$mx}]
    if {$var <= 0.0} {
	set ex 0.0
    } else {    
	set ex [expr {sqrt($var)}]
    }

    return $ex
}


proc Covariance {Lx Ly} {
    set Nx [llength $Lx]
    set Ny [llength $Ny]
    if {$Nx != $Ny} {
	FaireLire "Error ! List of different length !"
	return -1
    }	

    set mx 0.0 ; set my 0.0
    foreach x $Lx y $Ly {
	set mx [expr {$mx + $x}]
	set my [expr {$my + $y}]
    }
    set mx [expr {1.0 * $mx / $Nx}]
    set my [expr {1.0 * $my / $Ny}]
    set cov 0.0
    foreach x $Lx y $Ly {
	set cov [expr {($x - $mx)($y - $my)}]
    }
    set cov [expr {1.0 * $cov / $Nx}]

    return $cov
}


proc Variance {l} {
    if {! [llength $l]} {
	return -1
    }

    set sd 0. ; set sx 0.0 ;  set s2x 0.
    set n [llength $l]
    foreach e $l {
	set sx [expr {$sx + $e}]
	set s2x [expr {$s2x+$e*$e}]
    }
    set mx [expr {$sx/$n}]
    set var [expr {$s2x/$n - $mx*$mx}]

    return $var
}


proc Mean-Std {l} {
    if {[set n [llength $l]] == 0} {
	return
    }
    
    set m 0.0 ; set m2 0.0
    foreach e $l {
	set m  [expr {$m + $e}]
	set m2 [expr {$m2 + $e*$e}]
    }
    set m [expr {1.0 * $m/$n}]
    set m2 [expr {1.0 * $m2 / $n}]

    set var [expr {$m2 - $m*$m}]
    if {$var <= 0.0} {
	set sc 0.0
    } else {
	set sc [expr {sqrt($var)}]
    }

    if {0} {
    set var 0.0
    foreach e $l {
	set var [expr {$var + ($e-$m)**2}]
    }
    set var [expr {$var/($n-1)}]
    if {$var <= 0.} {
	set sc 0.
    } else {
	set sc [expr {sqrt($var)}]
    }
    }
    
    return [list $m $sc]
}


proc Moyenne {l} {
    set n [llength $l]
    set m 0.
    foreach e $l {
	set m [expr {$m + $e}]
    }
    return [expr {1.0*$m/$n}]
}


proc Ecorttype {l} {
    set m [Moyenne $l]
    set n [llength $l]
    set s2 0.
    foreach e $l {
	set s2 [expr {$s2+$e*$e}]
    }
    return [expr {sqrt($s2/$n -$m*$m)}]
}


proc CentreVecteur {V} {
    set m [Moyenne $V]
    set N {}
    foreach e $V {
	lappend N [expr {$e-$m}]
    }
    
    return $N
}


proc CentreMatrice {M} {
    # Matrice sous forme de liste de liste, 
    # une liste par ligne !!

    # Initialisation
    set nrows [llength $M]
    set ncols [llength [lindex $M 0]]
    for {set i 0} {$i < $ncols} {incr i} {
	set s$i 0.
    }

    # Calcule moyenne de chaque vecteur (colonne)
    foreach l $M {
	set i 0
	foreach e $l {
	    set s$i [expr {[set s$i]+$e}]
	    incr i
	}
    }

    for {set i 0} {$i < $ncols} {incr i} {
	set s$i [expr {[set s$i]/$nrows}]
    }

    # soustrait a chaque element d'un vectuer sa
    # moyenne correspondant
    set new {}
    foreach l $M {
	set i 0
	set lr {}
	foreach e $l {
	    lappend lr [expr {$e - [set s$i]}]
	    incr i
	}
	lappend new $lr
    }

    return $new
}


proc CentreReduitMatrice {M} {
    # Matrice sous forme de liste de liste, 
    # une liste par ligne !!

    # par colonne , soustrait moyenne et divise par 
    # ecart type de colonne

    # Initialisation
    set nrows [llength $M]
    set ncols [llength [lindex $M 0]]
    for {set i 0} {$i < $ncols} {incr i} {
	set s$i 0.
	set s2$i 0.
    }

    # Calcule moyenne de chaque vecteur (colonne)
    foreach l $M {
	set i 0
	foreach e $l {
	    set s$i [expr {[set s$i]+$e}]
	    set s2$i [expr {[set s2$i] + $e*$e}]
	    incr i
	}
    }
    for {set i 0} {$i < $ncols} {incr i} {
	set s$i [expr {[set s$i]/$nrows}]
	set e$i [expr {sqrt([set s2$i]/$nrows-[set s$i]**2)}]
    }

    # soustrait a chaque element d'un vectuer sa
    # moyenne correspondante, et divide par sigma
    set new {}
    foreach l $M {
	set i 0
	set lr {}
	foreach e $l {
	    lappend lr [expr {($e - [set s$i])/[set e$i]}]
	    incr i
	}
	lappend new $lr
    }

    return $new
}


proc MiseALEchelle {la lb} {
    # On met lb a l'echelle de la
    if {[llength $la] != [llength $lb]} {
	puts "lists of different length !!"
	return -1
    }

    set sxy 0.
    set sy2 0.
    foreach x1 $la x2 $lb {
	set sxy [expr {$sxy + $x1*$x2}]
	set sy2 [expr {$sy2 + $x2*$x2}]
    }
    set k [expr {$sxy/$sy2}]
    set nv {}
    foreach v $lb {
	lappend nv [expr {$v*$k}]
    }

    return $nv
}


proc SurfaceTriangle {a b c} {
    set p [expr {$a+$b+$c}]
    set 16s2 [expr {$p*($p-2.*$a)*($p-2.*$b)*($p-2.*$c)}]
    if {$16s2 <= 0.} {
	return 0.
    } else {
	return [expr {sqrt($16s2/16.)}]
    }
}


proc RotLuc {T A} {
    # pris dans tcl3d/rotations.tcl chez rR
    set c [expr {cos($T)}]
    set s [expr {sin($T)}]
    set u [expr {1.-$c}]

    set xx [expr {$x*$x*$u}]
    set yy [expr {$y*$y*$u}]
    set zz [expr {$z*$z*$u}]

    set xy [expr {$x*$y*$u}]
    set yz [expr {$y*$z*$u}]
    set xz [expr {$z*$x*$u}]

    set xs [expr {$x*$s}]
    set ys [expr {$y*$s}]
    set zs [expr {$z*$s}]

    set M [M_create \
	       [V_create [expr {$xx+$c }] [expr {$xy+$zs}] [expr $xz-$ys]] \
	       [V_create [expr $xy-$zs] [expr $yy+$c ] [expr $yz+$xs]] \
	       [V_create [expr $xz+$ys] [expr $yz-$xs] [expr $zz+$c ]] ]

    return
}


proc StandardiseTable {Ll} {
    set nl [llength $Ll]
    set dim [llength [lindex $Ll 0]]
    for {set i 0} {$i < $dim} {incr i} {
	set l$i [ExtraitListeDeListe $Ll $i]
	set l$i [Standardise [set l$i]]
    }

    set Lres {}
    for {set j 0} {$j < $nl} {incr j} {
	set Ltmp {}
	for {set i 0} {$i < $dim} {incr i} {
	    lappend Ltmp [lindex [set l$i] $j]
	}
	lappend Lres $Ltmp
    }

    return $Lres
}
	    

proc Centre {Liste} {
    set n [llength $Liste]
    if {$n == 0} {
	return {}
    }

    set m 0.0
    foreach x $Liste {
	set m [expr {$m + $x}]
    }
    set m [expr {1.0 * $m / $n}]
    set Lnew [lmap x $Liste {expr {$x - $m}}]

    return $Lnew
}


proc Standardise {l {Exclue -999.}} {
    set mo 0.0
    set m2 0.0
    set n 0
    foreach v $l {
	if {$v != $Exclue} {
	    set mo [expr {$mo + $v}]
	    set m2 [expr {$m2 + $v*$v}]
	    incr n
	}
    }
    if {$n == 0} {
	return $l
    }

    set mo [expr {1.*$mo/$n}]
    set m2 [expr {1.0*$m2/$n}]
    set var [expr {$m2 - ($mo*$mo)}]
    if {abs($var) < 1.0e-10} {
	puts "Achtung !! Var = $var proc standardise"
	set var 0.
	set ect 0.0
    } else {
	set ect [expr {sqrt($var)}]
    }

    set nl {}
    if {$ect != 0.0} {
	foreach v $l {
	    if {$v != $Exclue} {
		set nv [expr {($v - $mo)/$ect}]
		lappend nl $nv
	    } else {
		lappend nl $Exclue
	    }
	}
    } else {
	# std. dev. == 0. so just do data centrering
	foreach v $l {
	    if {$v != $Exclue} {
		set nv [expr {$v - $mo}]
		lappend nl $nv
	    } else {
		lappend nl $Exclue
	    }
	}
    }
    
    return $nl
}


proc ReScale {l {a 2} {b -1}} {
    # transforme selon :
    # newX = a * (x - min)/(max - min) + b
    #
    # si a= 2 b= -1 val entre -1 et 1
    # si a=1 b=0 val entre  0 et 1 

    set Lv [lsort -real $l]
    set min [lindex $Lv 0]
    set max [lindex $Lv end]
    set new {}

    foreach v $l {
	lappend new [expr {$a*($v-$min)/($max-$min) + $b}]
    }
    
    return $new
}

# Taken from :
# Visit http://www.johndcook.com/stand_alone_code.html for the source of this code and more like it.
#
# Note that the functions Gamma and LogGamma are mutually dependent.

proc gamma {x} {
    if {$x <= 0} {
        error "Invalid input" $x
    }
    
    # Split the function domain into three intervals:
    # (0, 0.001), [0.001, 12), and (12, infinity)

    ###########################################################################
    # First interval: (0, 0.001)
    #
    # For small x, 1/Gamma(x) has power series x + gamma x^2  - ...
    # So in this range, 1/Gamma(x) = x + gamma x^2 with error on the order of x^3.
    # The relative error over this interval is less than 6e-7.

    # Euler's gamma constant
    set gamma 0.577215664901532860606512090

    if {$x < 0.001} {
        return [expr {1.0/($x*(1.0 + $gamma*$x))}]
    }

    ###########################################################################
    # Second interval: [0.001, 12)

    if {$x < 12.0} {
        # The algorithm directly approximates gamma over (1,2) and uses
        # reduction identities to reduce other arguments to this interval.
        
        set y $x
        set n 0
        set arg_was_less_than_one [expr {$y < 1.0}]

        # Add or subtract integers as necessary to bring y into (1,2)
        # Will correct for this below
        if {$arg_was_less_than_one} {
            set y [expr {$y + 1.0}]
        } else {
            # will use n later
            set n [expr {entier($y) - 1}]
            set y [expr {$y - $n}]
        }

        # numerator coefficients for approximation over the interval (1,2)
        set p [list \
            -1.71618513886549492533811E+0 \
             2.47656508055759199108314E+1 \
            -3.79804256470945635097577E+2 \
             6.29331155312818442661052E+2 \
             8.66966202790413211295064E+2 \
            -3.14512729688483675254357E+4 \
            -3.61444134186911729807069E+4 \
             6.64561438202405440627855E+4 \
        ]

        # denominator coefficients for approximation over the interval (1,2)
        set q [list \
            -3.08402300119738975254353E+1 \
             3.15350626979604161529144E+2 \
            -1.01515636749021914166146E+3 \
            -3.10777167157231109440444E+3 \
             2.25381184209801510330112E+4 \
             4.75584627752788110767815E+3 \
            -1.34659959864969306392456E+5 \
            -1.15132259675553483497211E+5 \
        ]

        set num 0.0
        set den 1.0

        set z [expr {$y - 1}]
        for {set i 0} {$i < 8} {incr i} {
            set num [expr {($num + [lindex $p $i])*$z}]
            set den [expr {$den*$z + [lindex $q $i]}]
        }
        set result [expr {$num/$den + 1.0}]

        # Apply correction if argument was not initially in (1,2)
        if {$arg_was_less_than_one} {
            # Use identity gamma(z) = gamma(z+1)/z
            # The variable "result" now holds gamma of the original y + 1
            # Thus we use y-1 to get back the orginal y.
            set result [expr {$result / ($y-1.0)}]
        } else {
            # Use the identity gamma(z+n) = z*(z+1)* ... *(z+n-1)*gamma(z)
            for {set i 0} {$i < $n} {incr i} {
                set result [expr {$result * $y}]
                set y [expr {$y + 1}]
            }
        }

        return $result
    }

    ###########################################################################
    # Third interval: [12, infinity)

    if {$x > 171.624} {
        # Correct answer too large to display. 
        return 1.0/0 # float infinity
    }

    return [expr {exp([log_gamma $x])}]
}

proc log_gamma {x} {
    if {$x <= 0} {
        error "Invalid input"
    }

    if {$x < 12.0} {
        return [expr {log(abs([gamma $x]))}]
    }

    # Abramowitz and Stegun 6.1.41
    # Asymptotic series should be good to at least 11 or 12 figures
    # For error analysis, see Whittiker and Watson
    # A Course in Modern Analysis (1927), page 252

    set c [list \
         1.0/12.0 \
        -1.0/360.0 \
         1.0/1260.0 \
        -1.0/1680.0 \
         1.0/1188.0 \
        -691.0/360360.0 \
         1.0/156.0 \
        -3617.0/122400.0 \
    ]
    set z [expr {1.0/($x*$x)}]
    set sum [lindex $c 7]
    for {set i 6} {$i >= 0} {incr i -1} {
        set sum [expr $sum * $z]
        set sum [expr $sum + [lindex $c $i]]
    }
    set series [expr $sum/$x]

    set halfLogTwoPi 0.91893853320467274178032973640562
    set logGamma [expr {($x - 0.5)*log($x) - $x + $halfLogTwoPi + $series}]

    return $logGamma
}



if {0} {
293 ht pour 1500
350,43 ttc
100 ttc fred

980 ht imp / env / eti
428 ht timbres rapide
deux semaines
ericveit@actiondiff.com



}


proc LCnk {Ln k} {
    set n [llength $Ln]
    set x 0
    set Lr {}
    while {$x < $k} {
	set Ltmp $Lr
	foreach e $Ltmp {
	    set f [lindex $e end]
	    for {set i [expr {$f+1}]} {$i < $n} {incr i} {
		lappend Ltmp [list {*}$e $i]
	    }
	}
	for {set i 0} {$i < $n} {incr i} {
	    lappend Ltmp $i
	}
	set Lr $Ltmp
	
	incr x
    }
    set Lr [lsort -unique $Lr]

    set Ltot {}
    foreach e $Lr {
	if {[llength $e] == $k} {
	    lappend Ltot $e
	}
    }

    set Lres {}
    foreach e $Ltot {
	set tmp {}
	foreach i $e {
	    lappend tmp [lindex $Ln $i]
	}
	lappend Lres $tmp
    }

    return $Lres
}


proc tcnk {} {
    set o [LCnk [list 1 2 3 4 5] 3]
    puts [join $o]

    exit
}

proc tscrCEST_QUOI {} {
    set scr { set a [expr {3 + 5}]
	#puts $a
    }
    puts $scr
    append scr {
	set b [expr {10 + 2}]
	puts $b
    }
    puts $scr
    set o [eval $scr]
    puts $o
}


proc LCnk_choose {Lv Ln k} {
    set n [llength $Ln]
    foreach e $Lv {
	set x [lindex $e end]
	for {set i [expr {$x + 1}]} {$i < $n} {incr i} {
	    lappend Lr [list {*}$e $i]
	}
    }

}


proc GaussProbability {x mean stdev} {
    set exponent [expr {exp(-(pow($x-$mean,2)/(2*pow($stdev,2))))}]
    return [expr {(1 / (sqrt(2*acos(-1.)) * $stdev)) * $exponent}]
    
}

proc tgos {} {
    set s 0.0
    set step [expr {2./12.}]
    set max [GaussProbability 0.0 0.0 1.0]
    for {set i 0} {$i < 13} {incr i} {
	set v [expr {-1.0 + $i * $step}]
	set x [GaussProbability $v 0.0 1.0]
	puts [format "%2d %5.3f %5.3f %5.3f" $i $v $x [expr {$x/$max}]]
	set s [expr {$s+$x}]
    }
    puts "\ns= $s"
    exit
}


proc ComputeDistanceMatrix {} {
    global LNOrdali TDesPCI
    
    set Ld {}
    foreach n1 $LNOrdali {
	if {$n1 eq ""} {continue}
	set tmp {}
	foreach n2 $LNOrdali {
	    if {$n2 eq ""} {continue}
	    lappend tmp [expr {1.0 - [lindex [set TDesPCI($n1,$n2)] 0]}]
	}
	lappend Ld $tmp
    }
    
    return $Ld
}


proc GetWeightsFromEigen {Lvec} {
    set ok 0
    set Lw {}
    foreach vec $Lvec {
	if {[lindex $vec 0] < 0.0} {
	    set vec [lmap x $vec {expr {-1.0 * $x}}]
	}
	set sum [::tcl::mathop::+ {*}$vec]
	if {$sum > 0.0} {
	    set Lw $vec
	    break
	}
    }

    return $Lw
}


proc RunREigen {Ld} {
	# Compute Eigen decomposition of a SQUARE matrix !
    #
    # Returns
    # - the eigne values attaches to each component
    # - the eigen vectors of each component
    # - the data expressed in the components space
    #
    # ATTENTION :
    # if faut activer R par :
    # module load R/R-3.4.4
    #
    # Remember the matrix should be squared !!!

    package require Rtcl
    
    set   dim [llength [lindex $Ld 0]]
    set NbRow [llength $Ld]

    Rpipe "rm(list = ls())"

    Rpipe "data <- c([join [concat {*}$Ld] ,])"
    Rpipe "data <- matrix(data,nrow=$NbRow,byrow=T)"
    
    Rpipe "set.seed($::Defauts(RSeed))"
    Rpipe "res <- eigen(data)"

    set Lval [::rtcl::getvalue "res\$values"]
    #puts "\nEigen values :"
    #plist $Lval %6.3f
    set sum [::tcl::mathop::+ {*}$Lval]
    #puts "sum = $sum"
    
    #puts "\nEigen vectors :"
    set k 0
    set dimm1 [expr {$dim-1}]
    set Lvec {}
    set Ltmp [::rtcl::getvalue "res\$vectors"]
    while {$k < [llength $Ltmp]} {
	set vec [lrange $Ltmp $k $k+$dimm1]
	incr k $dim
	
	lappend Lvec $vec
	#puts -nonewline "v= "
	#plist $vec %6.3f
    }
    #puts ""
    
    return [list $Lval $Lvec]
}


proc RunRSVD {Ld} {
    # computes SVDA using R.
    #
    # Returns 3 list :
    # - the eigne values attaches to each component
    # - the eigen vectors of each component
    # - the data expressed in the components space
    # Activer R with :
    # module load R/R-3.6.1
    
    set   dim [llength [lindex $Ld 0]]
    set NbRow [llength $Ld]

    Rpipe "rm(list = ls())"

    Rpipe "data <- c([join [concat {*}$Ld] ,])"
    Rpipe "data <- matrix(data,nrow=$NbRow,byrow=T)"

    Rpipe "set.seed($::Defauts(RSeed))"
    Rpipe "pca  <- svd(data)"
    puts [Rpipe -verbose "pca"]
    puts [Rpipe -verbose "summary(pca)"]
    #puts "\nR PCA scales :"
    set Lval [::rtcl::getvalue "pca\$d"]
    #plist $Lval %7.4f
    #puts [format [string repeat "%7.4f " [llength [lindex $Ld 0]]] {*}$L]
    puts ""

     # eigen vectors
    set Ltmp [::rtcl::getvalue "pca\$v"]
    set Lvec {}
    for {set i 0} {$i < $dim} {incr i} {
	set vec {}
	for {set j 0} {$j < $dim} {incr j} {
	    lappend vec [lindex $Ltmp [expr {$i + $j*$dim}]]
	}
	lappend Lvec $vec
    }

    # eigen values
    # the sum of the eigenvalues equals the dimensionnality of the data.
    set Ltmp [::rtcl::getvalue "pca\$u"]
    set Lsum {}
    foreach e $Ltmp {
	lappend Lsum [expr {$e*$e}]
    }
    plist $Lsum %8.3f
    # data in components space
    set Ltmp [::rtcl::getvalue "pca\$u"]
    set dimm1 [expr {$dim - 1}]
    set Lx {}
    for {set i 0} {$i < [llength $Ltmp]} {incr i $dim} {
	lappend Lx [lrange $Ltmp $i $i+$dimm1]
    }

    return [list $Lval $Lvec $Lx]
}



proc RunRPCA {Ld} {
    # computes a PCA using R.
    #
    # Returns 3 list :
    # - the eigne values attaches to each component
    # - the eigen vectors of each component
    # - the data expressed in the components space
    # Activer R with :
    # module load R/R-3.6.1

    # IMPORTANT :
    # better than RunRPCA2 that uses R functionprincomp which makes spectral decomposition
    # and is less numerically accurate.
    
    set   dim [llength [lindex $Ld 0]]
    set NbRow [llength $Ld]

    Rpipe "rm(list = ls())"

    Rpipe "data <- c([join [concat {*}$Ld] ,])"
    Rpipe "data <- matrix(data,nrow=$NbRow,byrow=T)"

    Rpipe "set.seed($::Defauts(RSeed))"
    Rpipe "pca  <- prcomp(data, scale=F)"
    #Rpipe "pca  <- prcomp(data)"

     # eigen vectors
    set Ltmp [::rtcl::getvalue "pca\$rotation"]
    set Lvec {}
    set dimm1 [expr {$dim - 1}]
    for {set i 0} {$i < [llength $Ltmp]} {incr i $dim} {
	lappend Lvec [lrange $Ltmp $i $i+$dimm1]
    }

    # eigen values
    # the sum of the eigenvalues equals the dimensionnality of the data.
    set Ltmp [::rtcl::getvalue "pca\$sdev"]
    set Lval {}
    foreach e $Ltmp {
	lappend Lval [expr {$e*$e}]
    }

    # data in components space
    set Ltmp [::rtcl::getvalue "pca\$x"]
    set Lx {}
    for {set i 0} {$i < [llength $Ltmp]} {incr i $dim} {
	lappend Lx [lrange $Ltmp $i $i+$dimm1]
    }

    return [list $Lval $Lvec $Lx]
}

#lulu
proc RunRPCA2 {Ld} {
    # computes a PCA using R.
    #
    # Returns 3 lists :
    # - the eigne values attaches to each component
    # - the eigen vectors of each component
    # - the data expressed in the components space
    # Activate R with :
    # module load R/R-3.6.1
    
    set   dim [llength [lindex $Ld 0]]
    set NbRow [llength $Ld]

    Rpipe "rm(list = ls())"

    Rpipe "data <- c([join [concat {*}$Ld] ,])"
    Rpipe "data <- matrix(data,nrow=$NbRow,byrow=T)"

    if {! [info exists ::Defs(RSeed)]} {
	set ::Defs(RSeed) 101112
    }
    Rpipe "set.seed($::Defs(RSeed))"
    Rpipe "pca  <- princomp(data, cor = T, scores = T)"
    #Rpipe -verbose "str(pca)"

     # eigen vectors
    set Ltmp [::rtcl::getvalue "pca\$loadings"]
    set Lvec {}
    set dimm1 [expr {$dim - 1}]
    for {set i 0} {$i < [llength $Ltmp]} {incr i $dim} {
	lappend Lvec [lrange $Ltmp $i $i+$dimm1]
    }

    # eigen values
    # the sum of the eigenvalues equals the dimensionnality of the data.
    set Ltmp [::rtcl::getvalue "pca\$sdev"]
    set sum 0.
    set Lval {}
    foreach e $Ltmp {
	set v [expr {$e*$e}]
	lappend Lval $v
	set sum [expr {$sum + $v}]
    }
    puts "sum eigenvalues : $sum"

    # data in components space
    set Ltmp [::rtcl::getvalue "pca\$scores"]
    set Lx {}
    for {set i 0} {$i < [llength $Ltmp]} {incr i $dim} {
	lappend Lx [lrange $Ltmp $i $i+$dimm1]
    }

    return [list $Lval $Lvec $Lx]
}


proc RunTclPCA {Ldata} {
    #package require ::math::PCA

    set pca [::math::PCA::createPCA $Ldata]
    set Lval [$pca eigenvalues]
    set Lvec [$pca eigenvectors]
    set Lx   [$pca approximateOriginal]
    
    $pca destroy
    update

    return [list $Lval $Lvec $Lx]
}


proc Cnp {n p} {
    set sum 0
    for {set i $n} {$i > ($n - $p)} {incr i -1} {
	if {$i == $n} {
	    set sum $i
	} else {
	    set sum [expr {$sum * $i}]
	}
    }
    set sum [expr {$sum / [factorial1 $p]}]

    return $sum
}


proc prmcnp {n} {
    set sum 0
    for {set i 3} {$i < $n} {incr i} {
	incr sum [Cnp $n $i]
    }
    incr sum

    return $sum
}


proc Double2Fraction {dbl {eps 0.000001}} {
    for {set den 1} {$den<1024} {incr den} {
	set num [expr {round($dbl*$den)}]
	if {abs(double($num)/$den - $dbl) < $eps} {
	    break
	}
    }
    return [list $num $den]
}


proc d2f {} {
    puts [Double2Fraction 0.6666666666666]
    puts [Double2Fraction 1.3333333333333]
    exit
}

