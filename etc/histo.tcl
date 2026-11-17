global ready
set ready 0
proc histogram {slist wid ht} { ;# render a histogram

    global ready
    array set scores $slist
    set nms [lsort -integer [array names scores]]

    catch {destroy .h} {}
    catch {destroy .b} {}
    canvas .h -width $wid -height $ht -bg beige
    pack .h
    set nbars [array size scores] ;#how many histogram bars
    set nax [expr {$nbars/10}] ;# axis spacing
    set hwid [expr {$wid / $nbars}]
    set i 0
    set hmax -9999999 ;# largest y value 
    set hmin  9999999 ;# smallest y value
    while {$i < $nbars} {
	set f $scores([lindex $nms $i])
	set hmax [expr {($f>$hmax) ? $f : $hmax}]
	set hmin [expr {($f<$hmin) ? $f : $hmin}]
	incr i
    }

    if {$hmax>$hmin} {
        set i 0
        set nay 100
        while {$nay<$hmax} {
	    set yp [expr $ht-0.75*$nay-20]
	    .h create line  0 $yp $wid $yp -fill red
	    incr nay 100
        }
        set nax 10
        while {$i<$nbars} {
	    set x [expr $hwid*$i]
	    set rhs [expr $x+$hwid/2]
	    set f [expr $ht-20-.75*$ht*$scores([lindex $nms $i])/$hmax]
	    .h create rectangle  $x [expr $ht-20] $rhs $f -fill gray
	    if {[expr $i>=$nax]} {
                .h create line  $x [expr $ht-20] $x 0 -fill red
		incr nax 10
	    }
	    incr i
	    incr x $hwid
        }
        update

	#        button .b  -text "Next" -command "incr ready" ;# when ready is changed, proceeds with commands
	#        pack .b
    }
}

Cal
