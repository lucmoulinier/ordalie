##################################################################
#
# Cyclic Redundancy Check (CRC) in Tcl
#
# Version : 0.2 (October 8, 2006)
#
#   Author : Eric Hassold
#    Email : hassold@evolane.com
#  Company : Evolane
#      Web : http://www.evolane.com
#
##################################################################

namespace eval crc {
    variable crc

    set crc(ready) 0
    set crc(ctxid) 0
}

proc crc::Init {} {
    variable crc

    if {$crc(ready)} {
	return
    }

    # Common polynomials for supported CRC
    variable poly

    set poly(crc5-usb) {5 2 0}
    set poly(smbus)    {8 2 1 0}
    set poly(crc15)    {15 14 10 8 7 4 3 0}
    set poly(crc16)    {16 15 2 0}
    set poly(ccitt)    {16 12 5 0}
    set poly(crc24)    {24 23 18 17 14 11 10 7 6 5 4 3 1 0}
    set poly(crc32)    {32 26 23 22 16 12 11 10 8 7 5 4 2 1 0}
    set poly(crc32c)   {32 28 27 26 25 23 22 20 19 18 14 13 11 10 9 8 6 0}
    # CRC-64-ISO
    set poly(crc64)    {64 4 3 1 0}
    # CRC-64-ECMA-182
    set poly(ecma)  {
	64 62 57 55 54 53 52 47 46 45 40 39 38 37 35 33
	32 31 29 27 24 23 22 21 19 17 13 12 10 9 7 4 1 0
    }

    # For each polynomial (and reflection option), a CRC table is
    # generated once, and saved in memory
    variable crctable
    array set crctable {}
}

# Generic helper for Bit reflection
proc crc::reflect {val {nbbits 32}} {
    set r [expr {($val >> $nbbits) << $nbbits}]

    for {set i 0} {$i < $nbbits} {incr i} {
	if {$val & (1<<$i)} {
	    set r [expr {$r | (1<<(($nbbits-1)-$i))}]
	}
    }

    return $r
}

# Create CRC lookup table from polynomial exponents
proc crc::CRCTable {poly {reflectin 0}} {
    set width [lindex $poly 0]

    # Convert list of exponents into a polynomial mask
    if {$width<=32} {
	set polymask 0
	foreach b $poly {
	    if {$b==32} {
		continue
	    }
	    set polymask [expr {int($polymask | (1<<$b))}]
	}

	set msbmask [expr {int(1 << ($width - 1))}]
	set mask [expr {int(($msbmask-1)<<1 | 1)}]
	set shiftmask [expr {int($mask ^ $msbmask)}]
    } elseif {$width == 64} {
	set polymask [expr {wide(0)}]
	foreach b $poly {
	    if {$b==64} {
		continue
	    }
	    set polymask [expr {wide($polymask | wide(1<<$b))}]
	}

	set msbmask [expr {wide(1 << ($width - 1))}]
	set mask [expr {wide(($msbmask-1)<<1 | 1)}]
	set shiftmask [expr {wide($mask ^ $msbmask)}]
    } else {
	error "invalid width"
    }

    set tablewidth 8

    set tbl {}
    for {set i 0} {$i < (1<<$tablewidth)} {incr i} {
	if {$reflectin} {
	    set r [reflect $i $tablewidth]
	} else {
	    set r $i
	}

	if {$width<=32} {
	    set r [expr { int($r) << ($width - $tablewidth)}]
	} else {
	    set r [expr {wide($r) << ($width - $tablewidth)}]
	}

	for {set k 0} {$k < 8} {incr k} {
	    if {$r & $msbmask} {
		set r [expr {(($r & $shiftmask) << 1) ^ $polymask}]
	    } else {
		set r [expr {($r & $shiftmask) << 1}]
	    }
	}
	if {$reflectin} {
	    set r [reflect $r $width]
	}

	if {$width<=32} {
	    lappend tbl [expr {int($r & $mask)}]
	} else {
	    lappend tbl [expr {wide($r & $mask)}]
	}
    }

    return $tbl
}

# API for evolane::transform
proc crc::Create {this args} {
    upvar \#0 $this ctx

    variable crctable
    variable poly

    # Init package
    Init

    # Create table
    set codec $ctx(codec)
    switch -exact -- $codec {
	"crc64" {
	    # ISO 3309
	    set polyname  crc64
	    set seed      0
	    set reflect   1
	    set xor       0
	}
	"crc32" {
	    set polyname  crc32
	    set seed      0xffffffff
	    set reflect   1
	    set xor       0xffffffff
	}
	"crc16" {
	    set polyname  crc16
	    set seed      0
	    set reflect   1
	    set xor       0
	}
	"crc16-usb" {
	    set polyname  crc16
	    set seed      0xffff
	    set reflect   1
	    set xor       0xffff
	}
	"ccitt" {
	    set polyname  ccitt
	    set seed      0xffff
	    set reflect   0
	    set xor       0
	}
	"xmodem" {
	    set polyname  ccitt
	    set seed      0
	    set reflect   0
	    set xor       0
	}
	"hdlc" {
	    # Used in X.25 and for the HDLC 2-byte FCS.
	    set polyname  ccitt
	    set seed      0xffff
	    set reflect   1
	    set xor       0xffff
	}
	"smbus" {
	    # Used in ATM HEC and SMBus
	    set polyname  smbus
	    set seed      0
	    set reflect   0
	    set xor       0
	}
	"crc24" {
	    set polyname  crc24
	    set seed      0xb704ce
	    set reflect   0
	    set xor       0
	}
	"crc15" {
	    # Used in CAN (Controller Area Network) protocols
	    set polyname  crc15
	    set seed      0
	    set reflect   0
	    set xor       0
	}
	"crc32c" {
	    # Used in iSCSI (RFC-3385)
	    set polyname  crc32c
	    set seed      0xffffffff
	    set reflect   1
	    set xor       0xffffffff
	}
	"crc5-usb" {
	    # Used in USB Token and Start-Of-Frame packets
	    set polyname  crc5-usb
	    set seed      0x1f
	    set reflect   1
	    set xor       0x1f
	}
	default {
	    error "Unsupported CRC mode \"$ctx(codec)\""
	}
    }

    # Generate table if it doesn't already exist
    if {![info exists crctable($codec)]} {
	set crctable($codec) [CRCTable $poly($polyname) $reflect]
    }

    # Fill context members
    set ctx(format)    {c}
    set ctx(crctable)  $codec

    set ctx(width)      [lindex $poly($polyname) 0]
    set ctx(reflectin)  $reflect
    set ctx(reflectout) $reflect

    if {$ctx(width)<=32} {
	set ctx(seed)      [expr {int($seed)}]
	set ctx(xor)       [expr {int($xor)}]
    } else {
	set ctx(seed)      [expr {wide($seed)}]
	set ctx(xor)       [expr {wide($xor)}]
    }

    if {$ctx(width) <= 32} {
	set msbmask [expr {int(1 << ($ctx(width) - 1))}]
	set mask [expr {int(($msbmask-1)<<1 | 1)}]
    } elseif {$ctx(width) == 64} {
	set msbmask [expr {wide(1 << ($ctx(width) - 1))}]
	set mask [expr {wide(($msbmask-1)<<1 | 1)}]
    } else {
	error "unsupported width"
    }

    if {!$ctx(reflectin)} {
	if {$ctx(width) <= 32} {
	    set smask [expr {int(($mask << 8) & $mask)}]
	} else {
	    set smask [expr {wide(($mask << 8) & $mask)}]
	}
    } else {
	if {$ctx(width) <= 32} {
	    set smask [expr {int((1<<($ctx(width)-8))-1)}]
	} else {
	    set smask [expr {wide((1<<($ctx(width)-8))-1)}]
	}
    }

    set ctx(msbmask) $msbmask
    set ctx(mask)    $mask
    set ctx(smask)   $smask

    return
}

proc crc::Process {this bytes} {
    upvar \#0 $this ctx

    variable crctable

    set mask $ctx(mask)
    set smask $ctx(smask)

    set rot    [expr {$ctx(width) - 8}]

    set crc $ctx(seed)
    set tbl [set crctable($ctx(crctable))]

    if {!$ctx(reflectin)} {
	foreach b $bytes {
	    set ndx [expr {(($crc >> $rot) ^ $b) & 0xff}]
	    set lkp [lindex $tbl $ndx]
	    set crc [expr {($lkp ^ (($crc << 8) & $smask)) & $mask}]
	}
    } else {
	foreach b $bytes {
	    set ndx [expr {($crc ^ $b) & 0xff}]
	    set lkp [lindex $tbl $ndx]
	    set crc [expr {($lkp ^ (($crc >> 8) & $smask)) & $mask}]
	}
    }

    if {$ctx(width)<=32} {
	set ctx(seed) [expr {int($crc)}]
    } else {
	set ctx(seed) [expr {wide($crc)}]
    }

    return
}

proc crc::Close {this} {
    upvar \#0 $this ctx

    set s $ctx(seed)
    if {$ctx(reflectout)} {
	# set s [reflect $s $ctx(width)]
    }
    if {$ctx(xor) != 0} {
	set s [expr {$s ^ $ctx(xor)}]
    }

    return $s
}

# Standalone version
# This CRC code is designed to be used as a codec module for
# evolane::transform package. However, one may use this simplified
# API, with no external dependencies
proc crc::crc {method buffer} {
    variable crc

    set this "[namespace current]::ctx[incr crc(ctxid)]"
    upvar \#0 $this ctx

    set ctx(codec) $method
    Create $this
    set width $ctx(width)

    binary scan $buffer c* bytes
    Process $this $bytes
    set r [Close $this]

    unset $this
    
    set xlen [expr {($width+3)/4}]
    if {$xlen>8} {
	set result [format "%0${xlen}lx" $r]
    } else {
	set result [format "%0${xlen}x" $r]
    }
    return $result 
}

proc crc::crc32 {buffer} {
    return [crc crc32 $buffer]
}

proc crc::crc64 {buffer} {
    return [string toupper [crc crc64 $buffer]]
}




























