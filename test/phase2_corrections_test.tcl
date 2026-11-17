# Test des corrections E1 à E5 (bugs trouvés par la phase 2 de l'audit, 2026-11-06) :
# E1 nom d'objet 3D avec espace ou apostrophe, E2 instance d'un arbre chargé, E3 arbre Newick
# sans longueurs, E4 fichier qui n'est pas un arbre, E5 Print d'un canevas vide.
# Usage : tclsh8.6 test/phase2_corrections_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 7}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] phase2_[pid]]
file mkdir $Tmp
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {f} {
    exec $::P/gui_instance.sh start $::N $f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    W::ask {proc ::DernierArbre {} {
	set a {}
	foreach n [array names ::Abr Arbre,*] {lappend a [string range $n 6 end]}
	lindex [lsort -integer $a] end
    }}
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 120000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? $r : ""}]
    return $r
}
proc Dialogues {r} {expr {[dict exists $r dialogs] ? [dict get $r dialogs] : ""}}

set f [open $Tmp/ok.ph w]; puts $f {(a:0.1,b:0.2,(c:0.3,d:0.4):0.5);}; close $f
set f [open $Tmp/topo.ph w]; puts $f {(a,b,(c,d));}; close $f
set f [open $Tmp/pas_arbre.tfa w]; puts $f ">x\nMKTAYIAKQR\n>y\nMKTAYAKQRL"; close $f

if {[catch {
# --- E1 : noms d'objets 3D
puts "=== E1"
Start $Test/I_maj.xml
F "viewer" VisualiseStructure
for {set i 0} {$i < 100 && ! [W::ask {winfo exists .ordogl}]} {incr i} {after 200}
set mol [lindex [W::ask {lsort $::Liste3dMol}] 0]
foreach {nom attendu} [list "avec espace" obj_avec_espace "a b\{c" obj_a_b_c "it's" obj_it_s "ok_simple" obj_ok_simple] {
    W::ask [list DefineNewObj $mol ""]
    W::ask [list set ::NwOj(Obj) $nom]
    W::ask {update; list}
    F "objet <$nom>" {FinNewObj ok}
    V "objet <$nom> : fenêtre fermée" {! [W::ask {winfo exists .nwoj}]}
    V "objet <$nom> : créé sous le nom $attendu" {$attendu in [W::ask [list $mol _ListeObjets]]} [W::ask [list $mol _ListeObjets]]
    F "objet <$nom> : sauvegarde PDB ensuite" [list ::$mol save all all all 1 $Tmp/s.pdb]
}
V "nom invalide refusé par assignSelection, sans transaction ouverte" \
    {[W::ask [list catch [list ::$mol assignSelection "x y" {}]]] == 1 && [W::ask [list catch [list ::$mol save all all all 1 $Tmp/s2.pdb]]] == 0}
Stop

# --- E2 à E5 : arbres et Print
Start $Test/T_tutorial_maj.ord
puts "=== E2"
set n0 [W::ask {llength $::Abr(Liste)}]
F "chargement de D_maj.ph" [list LoadUnArbre $Test/D_maj.ph 1]
set A [W::ask DernierArbre]
V "E2 : instance de l'arbre définie" {[W::ask [list set ::Abr($A,Mac)]] eq [W::ask MacCourant]}
F "E2 : étiquettes des feuilles" [list ChangeLabelTree $A]
F "E2 : sauvegarde de l'ORD" [list ordfile::CreeLeORD $Tmp/arbre.ord]
F "E2 : fermeture" {FermeFichier nosave}
F "E2 : réouverture" [list OuvrirFichierAlignementDansOrdali Unk $Tmp/arbre.ord] 300000
V "E2 : l'arbre chargé est gardé dans l'ORD" {[W::ask {llength $::Abr(Liste)}] == $n0 + 1} "avant $n0, après [W::ask {set ::Abr(Liste)}]"

puts "=== E3"
foreach fic [list $Tmp/topo.ph $Tmp/ok.ph] {
    set t [file tail $fic]
    F "$t : chargement" [list LoadUnArbre $fic 1]
    set A [W::ask DernierArbre]
    set Lg [W::ask "set t \$::Abr(Arbre,$A); lmap n \[\$t nodes\] {\$t get \$n length}"]
    V "$t : longueurs numériques" {[llength [lmap l $Lg {expr {[string is double -strict $l] ? [continue] : $l}}]] == 0} $Lg
    V "$t : arbre dessiné" {[W::ask "llength \[.arbre$A.fc.c find all\]"] > 0}
    F "$t : radial" "\$::WOrdali(Tree,DenRad) invoke"
    F "$t : retour dendrogramme" "\$::WOrdali(Tree,DenRad) invoke"
    F "$t : Print" "PrintCanvas .arbre$A.fc.c png $Tmp/a.png"
}
set A [W::ask DernierArbre]
set Lg [lsort -real [W::ask "set t \$::Abr(Arbre,$A); lmap n \[\$t leaves\] {\$t get \$n length}"]]
V "ok.ph : longueurs du fichier gardées" {$Lg eq {0.1 0.2 0.3 0.4}} $Lg

puts "=== E4"
set avant [W::ask DernierArbre]
set r [F "fichier FASTA comme arbre" [list LoadUnArbre $Tmp/pas_arbre.tfa 1]]
V "E4 : message Newick" {[string match "*Newick*" [Dialogues $r]]} [Dialogues $r]
V "E4 : pas de nouvel arbre" {[W::ask DernierArbre] == $avant}

puts "=== E5"
F "Features Summary" FeatureSummary
set vide [expr {[W::ask {.fitsum.fc.c bbox all}] eq ""}]
puts "canevas du Features Summary vide : $vide"
W::ask {.fitsum.fc.c delete all}
set r [F "Print d'un canevas vide" "PrintCanvas .fitsum.fc.c png $Tmp/v.png"]
V "E5 : message" {[string match "*Nothing to print*" [Dialogues $r]]} [Dialogues $r]
Stop
} m]} {
    puts "FAIL script : $m"; incr Echecs
    catch Stop
}
file delete -force $Tmp
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
