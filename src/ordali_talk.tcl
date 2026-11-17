


#
# ordali_talk.tcl
#
# routine for tcl TextTo-Speech
#

proc TclTalkInit {{lang "fr"}} {
    global TclTalk
    
    set TclTalk(PID) 0
    set TclTalk(Pause) 0
    switch -- $::tcl_platform(os) {
	"Linux" {
	    set cmd espeak
	    switch -- $lang {
		"fr" {set voice "-v fr"}
		"en" {set voice "-v en"}
	    }
	}
	"Darwin" {
	    set cmd "say"
	    switch -- $lang {
		"fr" {set voice "-v Audrey"}
		"en" {set voice "-v Victoria"}
	    }
	}
	"windows" {
	}
    }
    set TclTalk(cmd) "$cmd $voice"
    
    # if this is a re-init, keep the text
    if {! [info exists TclTalk(Text)]} {
	set TclTalk(Text) ""
    }
    
    return 
}    


proc TclTalk {{what "NoArg"}} {
    global TclTalk
    
    TclTalkKill
    if {! $TclTalk(Pause)} {
	if {$what eq "NoArg"} {
	    # Repeat last text
	    set what $TclTalk(Text)
	} else {
	    set what [string map {"\n" " " "\"" "'" "\[" "\\\[" "\]" "\\\]" "\$" "\\\$" "\"" ""} $what]
	    set TclTalk(Text) $what
	}
	
	set lacmd "$TclTalk(cmd) \"$what\""
	set TclTalk(PID) [eval exec $lacmd &]
    }
    
    return
}


proc TclTalkKill {} {
    switch -- $::tcl_platform(os) {
	"Linux" {
	    killespeak
	    if {0} {
		set user $::env(USER)
		set Lpid [exec ps -ef | grep espeak | grep "$user"]
		set Lpid [split $Lpid \n]
		foreach p $Lpid {
		    regsub -all { +} [string trim $p] " " p
		    if {[string first "$user" $p] == -1} {
			continue
		    }
		    set p [lindex [split $p] 1]
		    catch {kill -9 $p}
		}
	    }
	}
    }
    set ::TclTalk(PID) 0
    
    return
}


proc ChangeLanguage {lang} {
    # first kill everything
    TclTalkKill
    
    # Now initialize with new lang
    set ::Language $lang
    TclTalkInit $lang

    # Re-speak the last stuff
    puts "\nTalk : $::Language"
    puts "Talk : >$::TclTalk(Text)<"
    TclTalk
    
    return
}


proc killespeak {} {
    set Lp [exec ps -ef | grep espeak | grep moumou]
    set Lp [split $Lp \n]
    foreach p $Lp {
	set p [string trim $p]
	if {[string first "moumou" $p] != 0} {
	    continue
	}
	regsub -all { +} $p " " p
	set pid [lindex [split $p] 1]
	catch {exec kill -9 $pid}
    }

    return
}


