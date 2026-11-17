proc QDrag {x y} {
    set W $::pgl(width)
    set H $::pgl(height)
    set lQuat [trackball \
	    [expr {(2.0*$::BQx - $W) / $W}] \
	    [expr {($H - 2.0*$::BQy) / $H}] \
	    [expr {(2.0*$x - $W) / $W}] \
	    [expr {($H - 2.0*$y) / $H}]]

    set ::BQx $x
    set ::BQy $y

    set ::cQuat [add_quats $lQuat $::cQuat]
    #update

    $::pgl(wogl) postredisplay

    return $lQuat
}


proc vzero {} {
  return [list 0.0 0.0 0.0]
}

proc vset {x y z} {
  return [list $x $y $z]
}

proc vsub {v1 v2} {
    foreach a $v1 b $v2 {
	lappend r [expr {$a-$b}]
    }
    
    return $r
}

proc vcross {v1 v2} {
    lassign $v1 a b c
    lassign $v2 d e f
    
    set x [expr {($b * $f) - ($c * $e)}]
    set y [expr {($c * $d) - ($a * $f)}]
    set z [expr {($a * $e) - ($b * $d)}]

    return [list $x $y $z]
}


proc vlength {v} {
    lassign $v x y z
    return [expr {sqrt($x*$x + $y*$y + $z*$z)}]
}

proc vscale {v div} {
    foreach x $v {
	lappend r [expr {$x*$div}]
    }
    return $r
}

proc vnormal {v} {
    return [vscale $v [expr {1.0/[vlength $v]}]]
}

proc vdot {v1 v2} {
    lassign $v1 a b c tmp
    lassign $v2 d e f tmp
    return [expr {$a*$d + $b*$e + $c*$f}]
}

proc vadd {v1 v2} {
    foreach x $v1 y $v2 {
	lappend r [expr {$x + $y}]
    }
    return $r
}


# Ok, simulate a track-ball.  
# Project the points onto the virtual
# trackball, 
# Then figure out the axis of rotation, which is the cross
# product of P1 P2 and O P1 (O is the center of the ball, 0,0,0)
# Note:  This is a deformed trackball-- is a trackball in the center,
# but is deformed into a hyperbolic sheet of rotation away from the
# center.  This particular function was chosen after trying out
# several variations.
#
# It is assumed that the arguments to this routine are in the range
# (-1.0 ... 1.0)

proc trackball {p1x p1y p2x p2y} {
    
    if {$p1x == $p2x && $p1y == $p2y} {
	set q [list 0.0 0.0 0.0 1.0]
        return $q
    }

    # First, figure out z-coordinates for projection of P1 and P2 to
    # deformed sphere
    set p1 [list $p1x $p1y [tb_project_to_sphere $p1x $p1y]]
    set p2 [list $p2x $p2y [tb_project_to_sphere $p2x $p2y]]

    # produit vectoriel
    set a [Vectoriel $p2 $p1]

    # rotation angle
    set d [vsub $p1 $p2]
    set t [expr {[vlength $d] / 2.0}]

    # Avoid problems with out-of-control values.
    if {$t >  1.0} {set t 1.0}
    if {$t < -1.0} {set t -1.0}
    set phi [expr {2.0 * asin($t)}]

    set q [axis_to_quat $a $phi]
    
    return $q
}

#  Given an axis and angle, compute quaternion.
proc axis_to_quat {a phi} {

    set a [vnormal $a]
    set q $a
    set q [vscale $q [expr {sin($phi/2.0)}]]
    lappend q [expr {cos($phi/2.0)}]

    return $q
}

# Project an x,y pair onto a sphere of radius r 
# OR a hyperbolic sheet
# if we are away from the center of the sphere.
proc tb_project_to_sphere {x y} {
    # !! r= 1.0 
    set d [expr {sqrt($x*$x + $y*$y)}]
    #inside sphere
    if {$d < 0.70710678118654752440} {
        set z [expr {sqrt(1. - $d*$d)}]
    } else {
        set t [expr {1.0 / 1.41421356237309504880}]
        set z [expr {$t*$t / $d}]
    }

    return $z
}


# Given two rotations, e1 and e2, 
# expressed as quaternion rotations,
# figure out the equivalent single rotation
# and stuff it into dest.
#
#This routine also normalizes the result every 
# RENORMCOUNT times it is
# called, to keep error from creeping in.
# NOTE: This routine is written so that q1 or q2 
# may be the same as dest (or each other).
#
#define RENORMCOUNT 97
#

proc add_quats {q1 q2} {
    set t1 [lrange $q1 0 2]
    set t1 [vscale $t1 [lindex $q2 3]]

    set t2 [lrange $q2 0 2]
    set t2 [vscale $t2 [lindex $q1 3]]

    set t3 [Vectoriel [lrange $q2 0 2] [lrange $q1 0 2]]
    set tf [vadd $t1 $t2]
    set tf [vadd $t3 $tf]
    lappend tf [expr {[lindex $q1 3] * [lindex $q2 3] - [vdot $q1 $q2]}]

    set dest $tf

    if {[incr ::qCount] > 97} {
        set ::qCount 0
        set dest [normalize_quat $dest]
    }

    return $dest
}

#Quaternions always obey:  a^2 + b^2 + c^2 + d^2 = 1.0
# If they don't add up to 1.0, dividing by their 
# magnitued will renormalize them.
#
#Note: See the following for more information 
# on quaternions:
#
# - Shoemake, K., Animating rotation with quaternion curves, Computer
#   Graphics 19, No 3 (Proc. SIGGRAPH'85), 245-254, 1985.
# - Pletinckx, D., Quaternion calculus as a basic tool in computer
#   graphics, The Visual Computer 5, 2-13, 1989.

proc normalize_quat {q} {
    lassign $q a b c d
    set mag [expr {$a*$a + $b*$b + $c*$c + $d*$d}]
    foreach v $q {
	lappend r [expr {$v/$mag}]
    }

    return $r
}


# Build a rotation matrix, given a quaternion rotation

proc build_rotmatrix {q} {
    lassign $q q0 q1 q2 q3

    set m00 [expr { 1.0 - 2.0 * ($q1 * $q1 + $q2 * $q2)}]
    set m01 [expr { 2.0 * ($q0 * $q1 - $q2 * $q3)}]
    set m02 [expr { 2.0 * ($q2 * $q0 + $q1 * $q3)}]
    set m03 0.0

    set m10 [expr { 2.0 * ($q0 * $q1 + $q2 * $q3)}]
    set m11 [expr { 1.0 - 2.0 * ($q2 * $q2 + $q0 * $q0)}]
    set m12 [expr { 2.0 * ($q1 * $q2 - $q0 * $q3)}]
    set m13 [expr { 0.0}]

    set m20 [expr { 2.0 * ($q2 * $q0 - $q1 * $q3)}]
    set m21 [expr { 2.0 * ($q1 * $q2 + $q0 * $q3)}]
    set m22 [expr { 1.0 - 2.0 * ($q1 * $q1 + $q0 * $q0)}]
    set m23 [expr { 0.0}]

    set m30 0.0
    set m31 0.0
    set m32 0.0
    set m33 1.0
    
    return [list $m00 $m01 $m02 $m03 $m10 $m11 $m12 $m13 $m20 $m21 $m22 $m23 $m30 $m31 $m32 $m33]
}



