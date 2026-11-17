# Phase 4 : réduit une marche en échec à une suite courte d'actions qui donne le même échec.
# Retire les actions une à une (de la première à l'avant-dernière) et garde le retrait si l'échec reste.
# Usage : tclsh8.6 test/phase4/reduit.tcl N JOURNAL_DE_MARCHE FICHIER SORTIE
lassign $argv N Journal Fichier Sortie
set Ici [file dirname [file normalize [info script]]]
set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] reduit_[pid]]
file mkdir $Tmp

# signature d'un échec : sa nature et son premier message, sans nombres
proc Signature {ligne} {
    if {! [regexp {=> (ERREUR|INVARIANT) (.*)$} $ligne -> k m] && ! [regexp {^(SCRIPT) (.*)$} $ligne -> k m]} {return ""}
    regsub -all {[0-9]+} [string range $m 0 80] N m
    return "$k $m"
}
proc Lire {f} {
    set c [open $f]; set L [split [read $c] \n]; close $c
    set actions {}; set sig ""
    foreach l $L {
	if {[string match "ACTIONS *" $l]} {set actions [lindex [string range $l 8 end] 0]}
	if {[set s [Signature $l]] ne ""} {set sig $s}
    }
    list $actions $sig
}
proc Rejoue {actions} {
    set f $::Tmp/actions.txt
    set c [open $f w]; puts $c $actions; close $c
    catch {exec timeout 3000 [info nameofexecutable] $::Ici/marche.tcl $::N rejoue $f $::Fichier $::Tmp/r.log >& $::Tmp/r.out}
    lindex [Lire $::Tmp/r.log] 1
}

lassign [Lire $Journal] Actions Cible
puts "échec visé : $Cible ([llength $Actions] actions)"
if {$Cible eq ""} {puts "pas d'échec dans $Journal"; exit 1}
set s [Rejoue $Actions]
if {$s ne $Cible} {puts "non reproduit en rejouant : <$s>"; set Actions {}}
set i 0
while {$i < [llength $Actions] - 1} {
    set essai [lreplace $Actions $i $i]
    if {[Rejoue $essai] eq $Cible} {
	set Actions $essai
	puts "  retiré, reste [llength $Actions]"
    } else {
	incr i
    }
}
set c [open $Sortie w]
puts $c "échec : $Cible"
puts $c "suite minimale ([llength $Actions] actions) :"
foreach a $Actions {puts $c "  [lindex $a 0]"}
puts $c "\nACTIONS [list $Actions]"
close $c
file delete -force $Tmp
puts "écrit $Sortie"
