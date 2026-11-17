# Test du format RSF désactivé : ni ouverture, ni écriture, code de lecture conservé.
# Usage : tclsh8.6 test/rsf_refus_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
fconfigure stdout -buffering line
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Refuse {r} {expr {[dict exists $r dialogs] && [string match "*RSF format*" [dict get $r dialogs]]}}

set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] rsf_refus_[pid]]
file mkdir $Tmp
set rsf $Tmp/a.rsf
set riche $Tmp/riche.txt
foreach f [list $rsf $riche] {
    set o [open $f w]; puts $o "!!RICH_SEQUENCE 1.0\n..\n{\nname  S1\nsequence\n  ACDEF\n}"; close $o
}
set tfa $Tmp/a_rsf.tfa
set o [open $tfa w]; puts $o ">s1\nACDEF\n>s2\nACDEF"; close $o

# ouverture
foreach {tag ty f} [list "extension .rsf" Unk $rsf "contenu RSF" Unk $riche "type RSF" RSF $riche] {
    Start
    set r [W::fire [list OuvrirFichierAlignementDansOrdali $ty $f] 15000]
    V "ouverture $tag : refusée" {[Refuse $r]} [expr {[dict exists $r dialogs] ? [dict get $r dialogs] : $r}]
    V "ouverture $tag : rien de chargé" {! [W::ask {info exists ::Sequences}]}
    V "ouverture $tag : pas d'erreur" {[dict get $r code] == 0}
    set ok [W::ask {expr {[winfo exists .wroom] ? 0 : 1}}]
    V "ouverture $tag : pas de fenêtre d'attente restante" {$ok}
    Stop
}
# ligne de commande : le message s'affiche, puis Ordalie démarre sans fichier
set pilote $Tmp/pilote.tcl
set o [open $pilote w]
puts $o {
    fconfigure stdout -buffering line
    set Racine $env(ODIR)
    set env(ORDALIDIR) $Racine
    set argv [list $env(FICRSF)]
    set argc 1
    proc Regarde {} {
	foreach w [winfo children .] {
	    if {[winfo class $w] in {Toplevel Dialog}} {
		foreach b [winfo children $w] {
		    foreach c [concat $b [winfo children $b]] {
			if {[winfo class $c] eq "Button"} {catch {puts "BOUTON [$c cget -text]"; after idle [list $c invoke]}}
		    }
		}
	    }
	}
	after 1000 Regarde
    }
    after 2000 Regarde
    after 20000 {
	puts "SEQUENCES [info exists ::Sequences]"
	puts "TYPE [TypeAli]"
	puts "TOPS [winfo exists .ordali]"
	exit 0
    }
    source $Racine/src/ordali.tcl
}
close $o
foreach {tag f} [list "cli extension .rsf" $rsf "cli contenu RSF" $riche] {
    set env(FICRSF) $f
    catch {exec /home/moumou/tcl/bin/wish8.6 $pilote </dev/null 2>@1} sortie
    V "$tag : rien de chargé" {[string match "*SEQUENCES 0*" $sortie]} [string range $sortie end-150 end]
    V "$tag : aucun type RSF retenu" {! [string match "*TYPE RSF*" $sortie]}
}
# un fichier normal s'ouvre toujours
Start
set r [W::fire [list OuvrirFichierAlignementDansOrdali Unk $tfa] 30000]
V "fasta : s'ouvre toujours" {[W::ask {info exists ::Sequences}]} $r
proc NbMenu {motif} {W::ask [string map [list MOTIF $motif] {
    set t 0
    foreach w [winfo children .menuBar] {
	foreach c [winfo children $w] {
	    if {[winfo class $c] ne "Menu"} continue
	    for {set i 0} {$i <= [$c index end]} {incr i} {
		catch {if {[string match MOTIF [$c entrycget $i -label]]} {incr t}}
	    }
	}
    }
    set t
}]}
V "menu : plus d'entrée RSF" {[NbMenu *RSF*] == 0 && [NbMenu *Clustal*] > 0} "[NbMenu *RSF*] [NbMenu *Clustal*]"
# écriture
foreach {tag cmd sortie} [list \
	"format RSF" [list SauveLAlignement RSF $Tmp/s1.txt] $Tmp/s1.txt \
	"nom .rsf"   [list SauveLAlignement TFA $Tmp/s2.rsf] $Tmp/s2.rsf] {
    set r [W::fire $cmd 15000]
    V "écriture $tag : refusée" {[Refuse $r]} $r
    V "écriture $tag : pas de fichier" {! [file exists $sortie]}
}
W::ask [list rename tk_getSaveFile tk_getSaveFile_vrai]
W::ask [list proc tk_getSaveFile {args} [list return $Tmp/s3.RSF]]
set r [W::fire {set ::Rep [DemandeEtSauveFichier tfa]} 15000]
V "dialogue de sauvegarde, nom .RSF : refusé" {[Refuse $r] && [W::ask {set ::Rep}] eq ""} $r
V "dialogue de sauvegarde : pas de fichier" {! [file exists $Tmp/s3.RSF]}
W::ask [list proc tk_getSaveFile {args} [list return $Tmp/s4.tfa]]
set r [W::fire [list SauveLAlignement TFA $Tmp/s4.tfa] 15000]
V "écriture fasta : marche toujours" {[file exists $Tmp/s4.tfa]} $r
V "code RSF conservé" {[W::ask {llength [info procs DecortiqueUnRSF]}] + [W::ask {llength [info procs DonneTabFeatureDuRsf]}] >= 1}
Stop
file delete -force $Tmp
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
