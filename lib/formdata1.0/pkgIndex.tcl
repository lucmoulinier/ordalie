if {![package vsatisfies [package provide Tcl] 8.2]} {return}

package ifneeded form-data 1.0   [list source [file join $dir formdata.tcl]]

