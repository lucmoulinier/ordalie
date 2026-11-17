# Réduit LesProcsDeGscope.tcl aux procs utilisées par Ordalie (fermeture transitive)
# usage : tclsh reduit_gscope.tcl <ordalidir> <sortie> <rapport> ?racines_supp...?
#   <ordalidir>/src/LesProcsDeGscope.tcl : dump COMPLET de Gscope (ToutesLesProcsDeGscope)
#   racines : fichiers de ListOfOrdaliFiles (ordali_source.tcl), ordali.tcl, et les fichiers
#   supplémentaires donnés (etc/*.tcl, tests). Une proc du dump est gardée si son nom apparaît
#   dans le code gardé (hors commentaires) ; noms en minuscules ou de 3 caractères au plus :
#   seulement en position d'appel ; noms construits Prefixe$x / ${x}Suffixe : tous les candidats.
#   <rapport> : procs gardées et leur appelant ; <rapport>.supprimees : procs retirées.
#   Ensuite : python3 expurge.py <sortie> <sortie_expurgée> (retire les mots de passe).
lassign $argv OrdaliDir Sortie Rapport
set RacinesSupp [lrange $argv 3 end]

proc Lit {f} {
    set c [open $f r]
    fconfigure $c -encoding utf-8 -translation lf
    set t [read $c]
    close $c
    return $t
}

# --- découpage du dump en unités (commandes de premier niveau)
set Texte [Lit [file join $OrdaliDir src LesProcsDeGscope.tcl]]
set Unites {}
set cour ""
foreach ligne [split $Texte \n] {
    if {$cour eq "" && [string trim $ligne] eq ""} {
	lappend Unites [list blanc $ligne]
	continue
    }
    if {$cour eq ""} {set cour $ligne} else {append cour \n $ligne}
    if {[info complete "$cour\n"]} {
	lappend Unites [list cmd $cour]
	set cour ""
    }
}
if {$cour ne ""} {error "commande incomplète en fin de fichier"}

# --- procs du dump
set NbProc 0
array set Def {}
set Autres 0
foreach u $Unites {
    lassign $u type txt
    if {$type ne "cmd"} continue
    if {[catch {lindex $txt 0} w0] || $w0 ne "proc"} {incr Autres; continue}
    set nom [lindex $txt 1]
    set full "::[string trimleft $nom :]"
    lappend Def($full) $txt
    incr NbProc
}
puts "unités: [llength $Unites]  procs: $NbProc  noms: [array size Def]  autres cmds: $Autres"

# index : nom complet, nom sans :: initial, nom de queue -> nom complet
array set Idx {}
foreach full [array names Def] {
    lappend Idx($full) $full
    lappend Idx([string range $full 2 end]) $full
    lappend Idx([namespace tail $full]) $full
}
set TousNoms [lsort [array names Def]]

# --- procs définies par les fichiers Ordalie sourcés (elles masquent celles du dump)
set Src [file join $OrdaliDir src]
set Lsrc [Lit [file join $Src ordali_source.tcl]]
regexp {set ListOfOrdaliFiles \[list(.*?)\]} $Lsrc -> liste
set Fichiers {}
foreach f [string map {\\ " "} $liste] {
    if {[string index $f 0] eq "#"} continue
    if {[file exists [file join $Src $f]]} {lappend Fichiers [file join $Src $f]} else {puts "absent: $f"}
}
lappend Fichiers [file join $Src ordali.tcl] [file join $Src ordali_source.tcl]
array set Masque {}
set TexteRacines ""
foreach f $Fichiers {
    set t [Lit $f]
    append TexteRacines \n $t
    foreach {- n} [regexp -all -inline -line {^\s*proc\s+(\S+)} $t] {
	set Masque(::[string trimleft $n :]) 1
    }
}
# racines supplémentaires (etc, tests) : leurs propres procs ne désignent pas celles de Gscope
set RefsSupp {}
foreach f $RacinesSupp {
    set tf [Lit $f]
    set Locales {}
    foreach {- n} [regexp -all -inline -line {^\s*proc\s+(\S+)} $tf] {lappend Locales ::[string trimleft $n :]}
    lappend RacinesTextes [list $tf $Locales]
}
puts "fichiers racines: [llength $Fichiers] + [llength $RacinesSupp]  procs ordalie masquant le dump: [llength [array names Masque]]"

# --- extraction des références d'un texte
# texte des messages (puts, error, FaireLire, Espionne, -text, -message, -label, -title,
# -detail "...") : jamais exécuté, sauf les substitutions [ ... ] qu'on garde
proc SansMessages {txt} {
    set re {(?:\mputs(?:[ \t]+-nonewline)?(?:[ \t]+\$?[A-Za-z0-9_:]+)?|\merror|\mFaireLire|\mEspionne|-text|-message|-label|-title|-detail)[ \t]+"}
    set res ""
    set pos 0
    while {[regexp -indices -start $pos -- $re $txt m]} {
	lassign $m d f
	append res [string range $txt $pos $f]
	# parcours de la chaîne jusqu'au " fermant, en gardant les [ ... ] équilibrés
	set i [expr {$f + 1}]
	set n [string length $txt]
	set prof 0
	while {$i < $n} {
	    set c [string index $txt $i]
	    if {$c eq "\\"} {
		if {$prof > 0} {append res [string range $txt $i [expr {$i+1}]]}
		incr i 2
		continue
	    }
	    if {$prof == 0 && $c eq "\""} break
	    if {$c eq "\["} {incr prof}
	    if {$prof > 0} {append res $c}
	    if {$c eq "\]" && $prof > 0} {incr prof -1; if {$prof == 0} {append res " "}}
	    incr i
	}
	append res "\""
	set pos [expr {$i + 1}]
    }
    append res [string range $txt $pos end]
    return $res
}

proc Refs {txt} {
    global Idx TousNoms
    # lignes de commentaire ignorées
    regsub -all -line {^[ \t]*#.*$} $txt "" txt
    # texte des messages (jamais exécuté) ignoré
    set txt [SansMessages $txt]
    set R {}
    array set Cand {}
    foreach tok [regexp -all -inline -- {[^\s\[\]{}"$;\\()]+} $txt] {
	set t $tok
	if {[info exists Idx($t)]} {lappend Cand($t) {*}$Idx($t)}
	set t2 [string trimleft $t :]
	if {$t2 ne $t && [info exists Idx($t2)]} {lappend Cand($t) {*}$Idx($t2)}
    }
    foreach t [array names Cand] {
	set queue [namespace tail $t]
	if {[string length $queue] <= 3 || [string tolower $queue] eq $queue || [string toupper $queue] eq $queue} {
	    # nom faible : exige une position d'appel
	    set e [regsub -all {[][{}()*+?.^$|\\]} $t {\\&}]
	    set re [string cat {(?:^|[\[;\{"]|\m(?:list|eval|uplevel|catch|time|after\s+\S+|namespace\s+code|namespace\s+which(?:\s+-command)?|interp\s+alias\s+\S+\s+\S+\s+\S+)|-\w*command)[ \t]*} $e {(?=[\s\]\};"]|$)}]
	    if {![regexp -line -- $re $txt]} continue
	}
	lappend R {*}$Cand($t)
    }
    # noms construits : Prefixe$var ou Prefixe[...] , et $var/]Suffixe
    foreach {- pre} [regexp -all -inline -line -- {(?:^|[\[;\{]|\m(?:list|eval|uplevel|catch|time|after\s+\S+|namespace\s+code|namespace\s+which(?:\s+-command)?|interp\s+alias\s+\S+\s+\S+\s+\S+)|-\w*command)[ \t]*([A-Za-z_][A-Za-z0-9_:]{2,})(?=[$\[])} $txt] {
	lappend R {*}[lsearch -all -inline -glob $TousNoms "::$pre*"]
    }
    foreach {- suf} [regexp -all -inline -- {(?:\$\{[^\}]*\}|\$[A-Za-z0-9_:]+\([^)]*\)|\])([A-Za-z_][A-Za-z0-9_]{3,})} $txt] {
	lappend R {*}[lsearch -all -inline -glob $TousNoms "*$suf"]
    }
    return [lsort -unique $R]
}

# --- fermeture transitive
array set Garde {}
set File {}
set LesRacines [Refs $TexteRacines]
if {[info exists RacinesTextes]} {
    foreach rt $RacinesTextes {
	lassign $rt tf Locales
	foreach p [Refs $tf] {if {$p ni $Locales} {lappend LesRacines $p}}
    }
}
foreach p [lsort -unique $LesRacines] {
    if {[info exists Masque($p)]} continue
    if {![info exists Garde($p)]} {set Garde($p) racine; lappend File $p}
}
puts "racines directes: [llength $File]"
while {[llength $File]} {
    set p [lindex $File 0]
    set File [lrange $File 1 end]
    foreach corps $Def($p) {
	foreach q [Refs $corps] {
	    if {[info exists Masque($q)] || [info exists Garde($q)]} continue
	    set Garde($q) $p
	    lappend File $q
	}
    }
}
puts "procs gardées: [array size Garde] / [array size Def]"

# --- écriture
set out [open $Sortie w]
fconfigure $out -encoding utf-8 -translation lf
set NbEcrit 0
foreach u $Unites {
    lassign $u type txt
    if {$type eq "blanc"} {puts $out $txt; continue}
    if {![catch {lindex $txt 0} w0] && $w0 eq "proc"} {
	set full "::[string trimleft [lindex $txt 1] :]"
	if {![info exists Garde($full)]} continue
	incr NbEcrit
    } elseif {![catch {lindex $txt 0} w0] && $w0 eq "namespace" && [lindex $txt 2 0] eq "namespace" && [lindex $txt 2 1] in {import export}} {
	# import/export : gardé si l'origine est gardée
	set cible [lindex $txt 2 2]
	if {[lindex $txt 2 1] eq "export"} {set cible "[lindex $txt 1]::$cible"}
	set cible "::[string trimleft $cible :]"
	if {![info exists Garde($cible)]} continue
    }
    puts $out $txt
}
close $out
# enlève les lignes vides multiples
set t [Lit $Sortie]
regsub -all {\n{3,}} $t "\n\n" t
set out [open $Sortie w]; fconfigure $out -encoding utf-8 -translation lf; puts -nonewline $out $t; close $out

set r [open $Rapport w]
foreach p [lsort [array names Garde]] {puts $r "$p <- $Garde($p)"}
close $r
set r [open $Rapport.supprimees w]
foreach p $TousNoms {if {![info exists Garde($p)]} {puts $r "$p[expr {[info exists Masque($p)] ? { (masquée par ordalie)} : {}}]"}}
close $r
puts "écrites: $NbEcrit procs dans $Sortie"
