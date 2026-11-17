# Edit > Preferences : chaque champ de chaque page est changé, OK, puis la valeur est vérifiée
#  - dans Defauts ; - dans la fenêtre rouverte ; - dans le fichier des préférences ; - relue par LitOrdalieDefauts
# dans une nouvelle session. Cancel ne change rien. Defaults remet les valeurs par défaut de la page.
# Usage : tclsh8.6 test/saisies/preferences_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
set Pages {General Sequences Conservation Editor "3D Display" Trees}
proc Ouvre {} {
    F "ouverture" AffichePreferences2 30000
    Q [list source $::Ici/champs.tcl]
}
proc Page {p} {
    Q "set i \[lsearch -exact {$::Pages} {$p}\]; .prf.lst selection clear 0 end; .prf.lst selection set \$i; event generate .prf.lst <<ListboxSelect>>; update"
}
# nouvelle valeur pour un champ
proc Autre {c val pos} {
    switch -glob $c {
	*Combobox {foreach v $pos {if {$v ne $val} {return $v}}; return $val}
	*Checkbutton {return [expr {$val eq [lindex $pos 0] ? [lindex $pos 1] : [lindex $pos 0]}]}
	*Spinbox - Entry - TEntry - Scale - TScale {
	    if {[string is integer -strict $val]} {return [expr {$val + 1}]}
	    if {[string is double -strict $val]} {return [expr {$val + 0.5}]}
	    return "${val}x"
	}
    }
    return $val
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set Fichier [Q FichierOrdalieDefauts]
    Ouvre
    set Attendu {}
    foreach p $Pages {
	Page $p
	set Lc [Q {::Champs::Liste .prf.frm}]
	set n 0
	# boutons radio : une valeur par variable
	set Radio {}
	foreach ch $Lc {
	    lassign $ch w c v val pos etat
	    if {$v eq "" || ! [string match "TmpDef(*" $v] || $etat eq "disabled"} continue
	    if {[string match *Radiobutton $c]} {
		if {$pos ne $val && ! [dict exists $Radio $v]} {dict set Radio $v $pos}
		continue
	    }
	    set nv [Autre $c $val $pos]
	    if {$nv eq $val} continue
	    Q [list set ::$v $nv]
	    dict set Attendu [string range $v 7 end-1] $nv
	    incr n
	}
	dict for {v nv} $Radio {
	    Q [list set ::$v $nv]
	    dict set Attendu [string range $v 7 end-1] $nv
	    incr n
	}
	V "page $p : champs changés" {$n > 0} "$n"
    }
    puts "     valeurs changées : $Attendu"
    set r [F "OK" {.prf.btn.cebon invoke} 30000]
    V "fenêtre fermée" {! [Q {winfo exists .prf}]}
    set faux {}
    dict for {k v} $Attendu {if {[Q "set ::Defauts($k)"] ne $v} {lappend faux "$k=[Q "set ::Defauts($k)"] (attendu $v)"}}
    V "Defauts : toutes les valeurs" {$faux eq ""} [join $faux "; "]
    # fenêtre rouverte : les champs montrent les nouvelles valeurs
    Ouvre
    set faux {}
    foreach p $Pages {
	Page $p
	foreach ch [Q {::Champs::Liste .prf.frm}] {
	    lassign $ch w c v val
	    if {[string match "TmpDef(*" $v]} {
		set k [string range $v 7 end-1]
		if {[dict exists $Attendu $k] && ! [string match *Radiobutton $c] && $val ne [dict get $Attendu $k]} {lappend faux "$p $k=$val"}
	    }
	}
    }
    V "fenêtre rouverte : nouvelles valeurs" {$faux eq ""} [join $faux "; "]
    # Cancel après changement : rien ne change
    set k [lindex [dict keys $Attendu] 0]
    Q "set ::TmpDef($k) annule_zz"
    F "Cancel" {.prf.btn.cancel invoke} 30000
    V "Cancel : $k inchangé" {[Q "set ::Defauts($k)"] eq [dict get $Attendu $k]} [Q "set ::Defauts($k)"]
    # fichier des préférences
    set c [open $Fichier]; set lu [read $c]; close $c
    set faux {}
    dict for {k v} $Attendu {
	if {$k eq "Mapping"} continue
	if {! [dict exists $lu $k] || [dict get $lu $k] ne $v} {lappend faux $k}
    }
    V "fichier $Fichier : toutes les valeurs" {$faux eq ""} [join $faux " "]
    file copy -force $Fichier $Tmp/prefs
    # Defaults : la page General revient aux valeurs par défaut
    Ouvre
    F "Defaults (page General)" {.prf.btn.defaut invoke} 30000
    lassign [Q ValeursDefautsPreferences] lDef
    set faux {}
    foreach k [Q {ClesPreferences General}] {
	if {[Q "set ::TmpDef($k)"] ne [dict get $lDef $k]} {lappend faux $k}
    }
    V "Defaults : page General remise" {$faux eq ""} [join $faux " "]
    F "Cancel" {.prf.btn.cancel invoke} 30000
    Inv "après Preferences"
    Stop
    # nouvelle session : relecture du fichier
    Start $Test/T_tutorial_maj.ord
    F "relecture" [list LitOrdalieDefauts $Tmp/prefs] 30000
    set faux {}
    dict for {k v} $Attendu {
	if {$k eq "Mapping"} continue
	if {[Q "set ::Defauts($k)"] ne $v} {lappend faux "$k=[Q "set ::Defauts($k)"]"}
    }
    V "nouvelle session : valeurs relues" {$faux eq ""} [join $faux "; "]
    F "Preferences après relecture" AffichePreferences2 30000
    F "OK" {.prf.btn.cebon invoke} 30000
    Inv "nouvelle session"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
