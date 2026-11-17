# File > Print : formats (png, jpeg, ps), papier (A4 paysage / portrait, illimité), zone (tout, fenêtre,
# sélection). Lignes et colonnes retenues comparées à l'alignement ; nombre de pages ; chaque fichier est
# une image lisible ou un PostScript ; rien à imprimer (sélection vide) : message.
# Usage : tclsh8.6 test/saisies/print_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Imprime {base reglages} {
    Q {PrintSetup defauts}
    foreach {k v} $reglages {Q [list set ::PrmPrt($k) $v]}
    Q [list probe::answer tk_getSaveFile $base]
    set r [W::fire BonPrintOrdali 600000]
    # pages : sur le disque (le résultat renvoyé par la sonde est tronqué)
    list [expr {[Err $r] ? [dict get $r errorInfo] : ""}] [Dialogues $r] [lsort [glob -nocomplain [file rootname $base].*.*]]
}
proc Lisible {f} {
    if {[string match *.ps $f]} {set c [open $f]; set t [read $c 4]; close $c; return [expr {$t eq "%!PS"}]}
    Q "set i \[image create photo -file [list $f]\]; set r \[expr {\[image width \$i\] > 100 && \[image height \$i\] > 100}\]; image delete \$i; set r"
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set nseq [Q {llength [lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : 1}}]}]
    set lg [Q LongueurDeLAlignement]
    foreach {tag reglages} {
	png_all   {Format png Area all Papier A4 Orientation landscape}
	ps_all    {Format ps Area all Papier A4 Orientation portrait}
	jpeg_ill  {Format jpeg Area all Papier unlimited}
	png_fen   {Format png Area window Papier A4 Orientation landscape}
    } {
	lassign [Imprime $Tmp/$tag.x $reglages] err msg fichiers
	V "$tag : sans erreur" {$err eq ""} [string range $err 0 300]
	V "$tag : pages écrites ([llength $fichiers])" {[llength $fichiers] > 0 && [lsearch -not [lmap f $fichiers {file exists $f}] 1] < 0} $fichiers
	V "$tag : fichiers lisibles" {[lsearch [lmap f $fichiers {Lisible $f}] 0] < 0}
	set LS [Q {set ::PrmPrt(LSeqs)}]; set LN [Q {set ::PrmPrt(LNOri)}]
	set nn [llength [lsearch -all -not $LN ""]]
	switch -glob $tag {
	    *_all - *_ill {
		V "$tag : toutes les séquences ($nseq) et colonnes ($lg)" {$nn == $nseq && [Q {set ::PrmPrt(LgSeqs)}] == $lg} "$nn [Q {set ::PrmPrt(LgSeqs)}]"
	    }
	    *_fen {
		# lignes et colonnes visibles
		set vis [Q {
		    lassign [split [$::NomTextSeq index @0,0] .] y1 x1
		    lassign [split [$::NomTextSeq index @[expr {[winfo width $::NomTextSeq]-1}],[expr {[winfo height $::NomTextSeq]-1}]] .] y2 x2
		    list [llength [lmap n [lrange $::LNOrdali $y1-1 $y2-1] {expr {[string trim $n] eq "" ? [continue] : 1}}]] [expr {$x2-$x1+1}]
		}]
		lassign $vis nv lv
		V "$tag : séquences visibles ($nv)" {abs($nn - $nv) <= 1} "$nn"
		V "$tag : colonnes visibles ($lv)" {abs([Q {set ::PrmPrt(LgSeqs)}] - $lv) <= 2} [Q {set ::PrmPrt(LgSeqs)}]
	    }
	}
	# chaque séquence imprimée = tranche de l'alignement
	set xD [Q {set ::PrmPrt(xD)}]; set lgp [Q {set ::PrmPrt(LgSeqs)}]
	set faux 0
	foreach n $LN s $LS {if {$n ne "" && $s ne [string range [Q "set ::Sequences([string trim $n])"] $xD [expr {$xD+$lgp-1}]]} {incr faux}}
	V "$tag : séquences imprimées = alignement" {$faux == 0} $faux
    }
    # A4 : plusieurs pages, illimité : une seule
    lassign [Imprime $Tmp/u.x {Format png Area all Papier unlimited}] err msg f1
    V "illimité : une page" {[llength $f1] == 1} [llength $f1]
    # sélection
    Q {set ::PosInitNom 1.0}
    W::fire {SelectNomSeq une 3.0} 20000
    W::fire {SelectNomSeq ctr 5.0} 20000
    Q {set ::ZoneSelect {{100 199}}}
    lassign [Imprime $Tmp/s.x {Format png Area selected Papier unlimited}] err msg fs
    V "sélection : 2 séquences, colonnes 100-199" {[llength [lsearch -all -not [Q {set ::PrmPrt(LNOri)}] ""]] == 2 && [Q {set ::PrmPrt(LgSeqs)}] == 100 && [Q {set ::PrmPrt(xD)}] == 100} "[Q {set ::PrmPrt(LNOri)}] [Q {set ::PrmPrt(LgSeqs)}]"
    Q {set ::NomSeqSel {}; set ::ZoneSelect {}}
    lassign [Imprime $Tmp/v.x {Format png Area selected}] err msg fv
    V "sélection vide : message" {[string match "*Nothing is selected*" $msg]} $msg
    V "sélection vide : pas de fichier" {$fv eq ""}
    Inv "après Print"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
