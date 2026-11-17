# Sonde de test GUI pour Ordalie : lancée comme script principal de wish.
#   env : ODIR (racine Ordalie), FIC (fichier ouvert au démarrage, facultatif),
#         GUI_PROBE_PORT (port du serveur), GUI_PROBE_DIR (répertoire de l'instance :
#         errors.log, caught.log, dialogs.log, dumps).
# Protocole : une ligne base64 par requête (script Tcl), une ligne base64 en réponse
# (dict status/result/errorInfo). Les actions qui peuvent bloquer passent par
# probe::fire (after idle), suivies par probe::status.

if {! [info exists ::env(ODIR)]} {set ::env(ODIR) /home/moumou/clordali}
set ::env(ORDALIDIR) $::env(ODIR)
set argv [expr {[info exists ::env(FIC)] && $::env(FIC) ne "" ? [list $::env(FIC)] : {}}]
fconfigure stdout -buffering line

namespace eval probe {
    variable Dir   $::env(GUI_PROBE_DIR)
    variable Port  $::env(GUI_PROBE_PORT)
    variable Act   ""            ;# action en cours (id)
    variable Nact  0
    variable Seen  [dict create] ;# erreurs attrapées déjà vues
    variable Answers [dict create] ;# réponses scriptées des dialogues
    variable Ready 0
}

proc probe::log {file msg} {
    variable Dir
    set f [open [file join $Dir $file] a]
    puts $f "[clock format [clock seconds] -format %T] \[$::probe::Act\] $msg"
    close $f
}

# --- erreurs ---------------------------------------------------------
proc probe::bgerr {msg opts} {
    set ei [expr {[dict exists $opts -errorinfo] ? [dict get $opts -errorinfo] : $msg}]
    probe::log errors.log "BGERROR $msg\n$ei\n----"
    if {$::probe::Act ne ""} {dict lappend ::probe::A($::probe::Act) bgerrors $msg}
}
proc bgerror {msg} {probe::bgerr $msg [list -errorinfo $::errorInfo]}

proc probe::errtrace {args} {
    variable Seen
    set msg [lindex [split $::errorInfo \n] 0]
    if {[dict exists $Seen $msg]} {return}
    set p {}
    for {set l [expr {[info level]-1}]} {$l > 0} {incr l -1} {
	lappend p [lindex [info level $l] 0]
    }
    dict set Seen $msg 1
    probe::log caught.log "$msg  <- [string range [join $p { < }] 0 300]"
}

# --- dialogues remplacés ---------------------------------------------
# probe::answer <dialogue> <valeur> : met une réponse en file d'attente
proc probe::answer {dlg val} {dict lappend ::probe::Answers $dlg $val; return}
proc probe::take {dlg default} {
    variable Answers
    if {[dict exists $Answers $dlg] && [llength [dict get $Answers $dlg]]} {
	set l [dict get $Answers $dlg]
	dict set Answers $dlg [lrange $l 1 end]
	return [lindex $l 0]
    }
    return $default
}
proc probe::dlg {name text rep} {
    regsub -all {\s+} $text " " text
    probe::log dialogs.log "$name «[string range $text 0 300]» -> $rep"
    if {$::probe::Act ne ""} {dict lappend ::probe::A($::probe::Act) dialogs "$name: [string range $text 0 120] -> $rep"}
    return $rep
}
proc probe::stubs {} {
    proc ::FaireLire {Message args} {probe::dlg FaireLire $Message ok; return}
    proc ::tk_dialog {w title text bitmap default args} {
	# défaut : -1 (fenêtre fermée = annuler)
	set r [probe::take tk_dialog [probe::auto_dialog $text $args]]
	probe::dlg tk_dialog "$title | $text | [join $args /]" $r
    }
    proc ::tk_messageBox {args} {
	set m [expr {[dict exists $args -message] ? [dict get $args -message] : $args}]
	set t [expr {[dict exists $args -type] ? [dict get $args -type] : "ok"}]
	set d [dict get {ok ok okcancel cancel yesno no yesnocancel cancel retrycancel cancel abortretryignore abort} $t]
	if {$::probe::Auto} {
	    set d [dict get {ok ok okcancel ok yesno yes yesnocancel yes retrycancel cancel abortretryignore ignore} $t]
	    if {$t eq "yesnocancel" && [regexp -nocase {not (been )?saved} $m]} {set d no}
	}
	probe::dlg tk_messageBox "$t | $m" [probe::take tk_messageBox $d]
    }
    proc ::tk_getOpenFile {args} {probe::dlg tk_getOpenFile $args [probe::take tk_getOpenFile [probe::auto_ouvre $args]]}
    proc ::tk_getSaveFile {args} {probe::dlg tk_getSaveFile $args [probe::take tk_getSaveFile [probe::auto_sauve $args]]}
    proc ::tk_chooseDirectory {args} {probe::dlg tk_chooseDirectory $args [probe::take tk_chooseDirectory [expr {$::probe::Auto ? $::probe::AutoWork : ""}]]}
    proc ::tk_chooseColor {args} {probe::dlg tk_chooseColor $args [probe::take tk_chooseColor [expr {$::probe::Auto ? "#ff0000" : ""}]]}
    proc ::Entre {{Defo ""}} {probe::dlg Entre $Defo [probe::take Entre [expr {$::probe::Auto && $Defo eq "" ? "test_ordalie" : $Defo}]]}
    proc ::ChoixParmi {Liste args} {probe::dlg ChoixParmi $Liste [probe::take ChoixParmi [expr {$::probe::Auto ? [lindex $Liste 0] : ""}]]}
    proc ::OuiOuNon {Message args} {probe::dlg OuiOuNon $Message [probe::take OuiOuNon $::probe::Auto]}
    # rien ne doit sortir de la machine de test ni la quitter
    proc ::exit {args} {probe::dlg exit $args ignored}
    foreach p {PrintSetup LanceDoc LogInBrowser} {
	if {[info commands ::$p] ne ""} {rename ::$p ::probe_orig_$p}
	proc ::$p {args} "probe::dlg $p \$args stubbed"
    }
}

# --- réponses automatiques et saisies (phase 2) ---------------------------------
# probe::auto 1 DONNEES WORK : les dialogues reçoivent une réponse valide au lieu d'être annulés
set ::probe::Auto 0
set ::probe::AutoData ""
set ::probe::AutoWork ""
set ::probe::AutoN 0
proc probe::auto {on data work} {
    set ::probe::Auto $on
    set ::probe::AutoData $data
    set ::probe::AutoWork $work
    return
}
proc probe::auto_dialog {text boutons} {
    if {! $::probe::Auto} {return -1}
    if {[regexp -nocase {not (been )?saved} $text]} {
	set i [lsearch -nocase $boutons no]
	return [expr {$i >= 0 ? $i : 1}]
    }
    return 0
}
proc probe::auto_ouvre {opts} {
    if {! $::probe::Auto} {return ""}
    set d $::probe::AutoData
    set t [string tolower $opts]
    if {[regexp {cif|pdb|structure} $t]} {
	set l [list 1il2.cif 1il2.pdb AF-E9AEW4-F1-model_v6.cif]
	return $d/[lindex $l [expr {[incr ::probe::AutoN] % 3}]]
    }
    if {[regexp {\.ord|ordalie} $t]} {return $d/T_tutorial_maj.ord}
    # fichier d'arbre (Load Tree file) : un vrai Newick, sinon la fenêtre de l'arbre n'est jamais explorée
    # (le dialogue ne dit pas qu'il attend un arbre : on regarde l'appelant)
    for {set i [info level]} {$i > 0} {incr i -1} {
	if {[lindex [info level $i] 0] in {LoadUnArbre ::LoadUnArbre}} {return $d/D_maj.ph}
    }
    if {[regexp {xml|macsim} $t]} {return $d/I_maj.xml}
    return $d/ajout.tfa
}
proc probe::auto_sauve {opts} {
    if {! $::probe::Auto} {return ""}
    set e txt
    if {[dict exists $opts -filetypes]} {
	regexp {\.([A-Za-z0-9]+)} [lindex [dict get $opts -filetypes] 0] -> e
    }
    return $::probe::AutoWork/sortie.$e
}
# texte qui décrit un champ : variable, chemin, libellé voisin, titre de la fenêtre
proc probe::libelle {w} {
    set p [winfo parent $w]
    set prec ""
    foreach c [winfo children $p] {
	if {$c eq $w} break
	if {[winfo class $c] in {Label TLabel}} {set prec [probe::opt $c -text]}
    }
    if {$prec eq ""} {set prec [probe::opt $p -text]}
    if {$prec eq "" && $p ne "."} {
	foreach c [winfo children [winfo parent $p]] {
	    if {$c eq $p} break
	    if {[winfo class $c] in {Label TLabel}} {set prec [probe::opt $c -text]}
	}
    }
    return $prec
}
# champs de saisie actifs et visibles, hors ceux de la liste Lexclus
proc probe::champs {Lexclus} {
    update idletasks
    set out {}
    set todo .
    while {[llength $todo]} {
	set w [lindex $todo 0]
	set todo [lrange $todo 1 end]
	if {! [winfo exists $w] || [string match *#* $w]} continue
	foreach ch [lsort [winfo children $w]] {lappend todo $ch}
	set c [winfo class $w]
	if {$c ni {Entry TEntry Spinbox TSpinbox Text} || ! [winfo ismapped $w] || $w in $Lexclus} continue
	if {[probe::opt $w -state] in {disabled readonly}} continue
	set top [winfo toplevel $w]
	if {$c eq "Text" && $top eq "."} continue
	set val [expr {$c eq "Text" ? [string trim [$w get 1.0 end]] : [$w get]}]
	set titre [expr {$top eq "." ? "" : [wm title $top]}]
	lappend out [dict create path $w class $c val $val var [probe::opt $w -textvariable] label [probe::libelle $w] titre $titre]
    }
    return $out
}
proc probe::ecrit {w val} {
    if {[winfo class $w] eq "Text"} {
	$w delete 1.0 end
	$w insert end $val
    } else {
	$w delete 0 end
	$w insert 0 $val
    }
}
# remplit les champs {chemin valeur ...}, puis fait les choix restés vides dans les fenêtres
# ouvertes hors de Ltops : liste sans sélection, liste déroulante vide, groupe de boutons radio
proc probe::remplit {valeurs Ltops} {
    foreach {w val} $valeurs {
	catch {if {[winfo exists $w]} {probe::ecrit $w $val}}
    }
    set todo {}
    foreach t [winfo children .] {
	if {[winfo toplevel $t] eq $t && $t ni $Ltops && [winfo ismapped $t]} {lappend todo $t}
    }
    array set vu {}
    while {[llength $todo]} {
	set w [lindex $todo 0]
	set todo [lrange $todo 1 end]
	if {! [winfo exists $w] || [string match *#* $w]} continue
	foreach ch [lsort [winfo children $w]] {lappend todo $ch}
	if {! [winfo ismapped $w] || [probe::opt $w -state] eq "disabled"} continue
	catch {
	    switch -- [winfo class $w] {
		Listbox {
		    if {[$w size] > 0 && [$w curselection] eq ""} {
			$w selection set 0
			event generate $w <<ListboxSelect>>
		    }
		}
		TCombobox {
		    if {[$w get] eq "" && [llength [$w cget -values]]} {
			$w set [lindex [$w cget -values] 0]
			event generate $w <<ComboboxSelected>>
		    }
		}
		Radiobutton - TRadiobutton {
		    set v [$w cget -variable]
		    if {$v ne "" && ! [info exists vu($v)]} {
			set vu($v) 1
			if {! [info exists ::$v] || [set ::$v] eq ""} {set ::$v [$w cget -value]}
		    }
		}
	    }
	}
    }
    return
}
# état du fichier ouvert : s'il change, l'explorateur repart d'une instance neuve
proc probe::empreinte {} {
    set l [list [TypeAli]]
    if {[TypeAli] eq "pasdali"} {return $l}
    catch {lappend l [LesMacs] [MacCourant name]}
    foreach v {LNOrdali ListePDB} {
	lappend l [expr {[info exists ::$v] ? [llength [set ::$v]] : -1}]
    }
    return $l
}

# --- actions -----------------------------------------------------------
# probe::fire script : lance script hors du handler socket, renvoie un id
proc probe::fire {script} {
    variable Nact
    set id a[incr Nact]
    set ::probe::A($id) [dict create state queued script $script tops0 [probe::tops] mode0 [probe::mode]]
    after idle [list probe::run $id]
    return $id
}
proc probe::run {id} {
    variable Act
    set prev $Act
    set Act $id
    dict set ::probe::A($id) state running
    dict set ::probe::A($id) t0 [clock milliseconds]
    set code [catch {uplevel #0 [dict get $::probe::A($id) script]} res opts]
    set Act $prev
    dict set ::probe::A($id) state done
    dict set ::probe::A($id) ms [expr {[clock milliseconds]-[dict get $::probe::A($id) t0]}]
    dict set ::probe::A($id) code $code
    dict set ::probe::A($id) result [string range $res 0 2000]
    if {$code == 1} {dict set ::probe::A($id) errorInfo [dict get $opts -errorinfo]}
    dict set ::probe::A($id) tops1 [probe::tops]
    dict set ::probe::A($id) mode1 [probe::mode]
}
# état d'une action ; si elle tourne encore, pile d'appels (elle est bloquée
# dans une boucle d'événements imbriquée : tkwait, vwait, update)
proc probe::status {id} {
    set d $::probe::A($id)
    if {[dict get $d state] eq "running"} {
	set st {}
	for {set i 1} {$i < [info frame]} {incr i} {
	    set f [info frame $i]
	    if {[dict exists $f proc]} {lappend st "[dict get $f proc]:[expr {[dict exists $f line] ? [dict get $f line] : {}}]"}
	}
	dict set d stack $st
	dict set d tops1 [probe::tops]
	dict set d grab [grab current]
    }
    return $d
}

# --- introspection -------------------------------------------------------
proc probe::mode {} {
    set m ?
    catch {set m [QuelMode]}
    return $m
}
proc probe::tops {} {
    set l [list .]
    foreach w [lsort [winfo children .]] {
	if {[winfo exists $w] && [winfo toplevel $w] eq $w && [winfo ismapped $w]} {
	    lappend l $w
	}
    }
    return $l
}
proc probe::opt {w o} {
    if {[catch {$w cget $o} v]} {return ""}
    return $v
}
# une ligne par widget : chemin, classe, puis options utiles non vides
proc probe::widgets {{root .} {all 0}} {
    update idletasks
    set out {}
    set todo [list $root]
    while {[llength $todo]} {
	set w [lindex $todo 0]
	set todo [lrange $todo 1 end]
	if {! [winfo exists $w] || [string match *#* $w]} continue
	set c [winfo class $w]
	set d [dict create path $w class $c mapped [winfo ismapped $w]]
	foreach o {-text -label -command -variable -textvariable -value -state -values -image} {
	    set v [probe::opt $w $o]
	    if {$v ne ""} {dict set d [string range $o 1 end] $v}
	}
	if {$c eq "Menu"} {dict set d entries [probe::menuentries $w]}
	if {$all || [dict exists $d command] || $c in {Menu Menubutton TCombobox Combobox Entry TEntry Scale Listbox Toplevel}} {
	    lappend out $d
	}
	foreach ch [lsort [winfo children $w]] {lappend todo $ch}
    }
    return $out
}
proc probe::menuentries {m} {
    set l {}
    set last [$m index end]
    if {$last eq "none"} {return $l}
    for {set i 0} {$i <= $last} {incr i} {
	set t [$m type $i]
	set e [dict create i $i type $t]
	if {$t ni {separator tearoff}} {
	    foreach o {-label -command -menu -variable -value -state -accelerator} {
		if {! [catch {$m entrycget $i $o} v] && $v ne ""} {dict set e [string range $o 1 end] $v}
	    }
	}
	lappend l $e
    }
    return $l
}
# JSON minimal pour les rapports
proc probe::json {v {type auto}} {
    if {[string is double -strict $v] && $type ne "str"} {return $v}
    return "\"[string map {\\ \\\\ \" \\\" \n \\n \t \\t \r \\r} $v]\""
}
proc probe::dump_tree {file {root .}} {
    set f [open $file w]
    puts $f "\["
    set sep ""
    foreach d [probe::widgets $root 1] {
	set parts {}
	dict for {k v} $d {
	    if {$k eq "entries"} {
		set es {}
		foreach e $v {
		    lappend es "{[join [lmap {a b} $e {expr {"[probe::json $a str]: [probe::json $b]"}}] ", "]}"
		}
		lappend parts "\"entries\": \[[join $es ", "]\]"
	    } else {
		lappend parts "[probe::json $k str]: [probe::json $v]"
	    }
	}
	puts -nonewline $f "$sep{[join $parts ", "]}"
	set sep ",\n"
    }
    puts $f "\n\]"
    close $f
    return $file
}

# --- serveur -------------------------------------------------------------
proc probe::accept {ch addr port} {
    fconfigure $ch -buffering line -translation lf -encoding utf-8
    fileevent $ch readable [list probe::req $ch]
}
proc probe::req {ch} {
    if {[catch {gets $ch line} n] || $n < 0} {
	if {[eof $ch]} {close $ch}
	return
    }
    if {$line eq ""} return
    set script [encoding convertfrom utf-8 [binary decode base64 $line]]
    set code [catch {uplevel #0 $script} res opts]
    set r [dict create status [expr {$code == 1 ? "error" : "ok"}] result $res]
    if {$code == 1} {dict set r errorInfo [dict get $opts -errorinfo]}
    puts $ch [binary encode base64 [encoding convertto utf-8 $r]]
}
proc probe::start {} {
    probe::stubs
    # fenêtre principale à la taille de l'écran Xvfb, pour les captures
    catch {wm geometry . 1580x1150+0+0; update}
    interp bgerror {} probe::bgerr
    trace add variable ::errorInfo write probe::errtrace
    socket -server probe::accept -myaddr 127.0.0.1 $probe::Port
    probe::cov_inventaire
    set ::probe::Ready 1
    probe::log errors.log "READY port $probe::Port"
    puts "PROBE READY $probe::Port"
}

# --- couverture des procédures (env GUI_PROBE_COV = fichier cumulatif) -----
# chaque procédure et méthode d'ordali_*.tcl note sa première exécution :
# <fichier> reçoit {nom action}, <fichier>.inv la liste {nom source}.
if {[info exists ::env(GUI_PROBE_COV)]} {
    set ::probe::CovF $::env(GUI_PROBE_COV)
    set ::probe::CovSrc [file normalize $::env(ODIR)/src]
    set ::probe::Inv [dict create]
    proc probe::couvert {nom} {
	set ::probe::Cov($nom) 1
	set f [open $::probe::CovF a]
	puts $f [list $nom $::probe::Act]
	close $f
    }
    proc probe::prefixe {nom} {return "if {!\[info exists ::probe::Cov($nom)\]} {::probe::couvert $nom};"}
    rename ::proc ::probe::proc_orig
    ::probe::proc_orig ::proc {nom largs corps} {
	set t [file tail [info script]]
	if {[string match ordali*.tcl $t] && [file dirname [file normalize [info script]]] eq $::probe::CovSrc && [regexp {^[\w:]+$} $nom]} {
	    set q $nom
	    if {! [string match ::* $q]} {
		set q [uplevel 1 {namespace current}]::$nom
	    }
	    set q [string trimleft $q :]
	    dict set ::probe::Inv $q $t
	    set corps [probe::prefixe $q]$corps
	}
	uplevel 1 [list ::probe::proc_orig $nom $largs $corps]
    }
    # méthodes de Structure : la classe est créée par SetupPDBObject
    ::probe::proc_orig probe::cov_methodes {} {
	if {[info commands ::Structure] eq ""} {return}
	set pub [info class methods Structure]
	foreach m [info class methods Structure -private] {
	    lassign [info class definition Structure $m] largs corps
	    set q Structure::$m
	    dict set ::probe::Inv $q ordali_StrucObj.tcl
	    oo::define Structure method $m $largs [probe::prefixe $q]$corps
	}
	if {[llength $pub]} {oo::define Structure export {*}$pub}
    }
    # écrit à l'ouverture, sans les procédures remplacées par la sonde
    ::probe::proc_orig probe::cov_inventaire {} {
	foreach n {FaireLire OuiOuNon Entre ChoixParmi PrintSetup LanceDoc LogInBrowser} {dict unset ::probe::Inv $n}
	set f [open $::probe::CovF.inv w]
	dict for {n t} $::probe::Inv {puts $f [list $n $t]}
	close $f
    }
} else {
    proc probe::cov_methodes {} {}
    proc probe::cov_inventaire {} {}
}

# démarrage : la sonde s'active quand LanceOrdali a fini (comme ctx.tcl)
proc probe::hook {args} {
    trace remove variable ::VariablesAuDepart write probe::hook
    if {[info commands SetupPDBObject] ne ""} {
	trace add execution SetupPDBObject leave {apply {args probe::cov_methodes}}
    }
    trace add execution LanceOrdali leave {apply {args {after 500 probe::start}}}
}
trace add variable ::VariablesAuDepart write probe::hook
# erreurs de démarrage
proc bgerror {msg} {probe::bgerr $msg [list -errorinfo $::errorInfo]}
uplevel #0 [list source $::env(ODIR)/src/ordali.tcl]
