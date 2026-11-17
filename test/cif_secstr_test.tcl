# Test des structures secondaires lues dans un CIF : modèles AlphaFold (HELX_RH_AL_P, STRN...)
# et PDB (1il2.cif comparé à 1il2.pdb).
# Usage : tclsh8.6 test/cif_secstr_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    # {type élément -> nombre} des éléments lus
    W::ask {proc ::Compte {mol chn} {
	set T [dict create]
	foreach e [$mol _SSBrut $chn] {
	    DecortiqueSS $e Elmt c d f r
	    dict incr T $Elmt
	}
	lsort -stride 2 $T
    }}
    W::ask {oo::define Structure method _SSBrut {chn} {
	my variable SecStrRaw
	return $SecStrRaw($chn)
    }
    oo::define Structure export _SSBrut}
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 240000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? [dict get $r errorInfo] : ""}]
}
proc Ajoute {f} {
    W::fire {AjouteSequenceOrPDB pdbfile} 5000
    W::ask [list set ::TAddS(StrucFileIn) $::Test/$f]
    F "ajout $f" {.was.fbut.ok invoke}
}
# nombre de lignes de la séquence couvertes par le tag
proc NbTag {t nom} {W::ask [string map [list @T $t @N $nom] {
    set l [expr {[lsearch -exact $::LNOrdali @N]+1}]
    llength [lmap x [$::NomTextSeq tag ranges @T] {if {[lindex [split $x .] 0] == $l} {set x} else continue}]
}]}

Start $Test/D_maj.xml
W::ask {set ::Defauts(AffSS) 1}
Ajoute AF-Q9BW92-F1-model_v6.cif
set c [W::ask {Compte Q9BW92 A}]
puts "Q9BW92 : $c"
foreach {t n} {Alpha 22 3_10 7 polyP 7 Sheet 44 Turn 37} {
    V "Q9BW92 : $n $t" {[dict exists $c $t] && [dict get $c $t] == $n} $c
}
F "affichage" {set ::Defauts(AffSS) 0; ToggleSecStr}
V "Q9BW92_A : hélices affichées" {[NbTag Hel Q9BW92_A] == 2*(22+7)} [NbTag Hel Q9BW92_A]
V "Q9BW92_A : feuillets affichés" {[NbTag She Q9BW92_A] == 2*44} [NbTag She Q9BW92_A]
V "Q9BW92_A : coudes affichés" {[NbTag Tur Q9BW92_A] == 2*37} [NbTag Tur Q9BW92_A]
V "SSBin : hélices" {[string first 1 [W::ask {Q9BW92 SSBin helix A}]] >= 0}
V "SSBin : feuillets" {[string first 1 [W::ask {Q9BW92 SSBin sheet A}]] >= 0}
Stop

# 1il2 : même structure en CIF et en PDB
Start $Test/D_maj.xml
Ajoute 1il2.pdb
set Pdb [W::ask {Compte 1IL2 A}]
set Lp [W::ask {join [lsort [lmap e [1IL2 _SSBrut A] {DecortiqueSS $e E c d f r; list $E [string trim $d] [string trim $f]}]] ,}]
Stop
Start $Test/D_maj.xml
Ajoute 1il2.cif
set Cif [W::ask {Compte 1IL2 A}]
set Lc [W::ask {join [lsort [lmap e [1IL2 _SSBrut A] {DecortiqueSS $e E c d f r; list $E [string trim $d] [string trim $f]}]] ,}]
Stop
puts "1il2 PDB : $Pdb"
puts "1il2 CIF : $Cif"
V "1il2 : mêmes types et nombres en CIF et en PDB" {$Pdb eq $Cif} "$Pdb / $Cif"
V "1il2 : mêmes éléments en CIF et en PDB" {$Lp eq $Lc}
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
