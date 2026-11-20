# Phase 4 : marches aléatoires à graine fixe. Chaque pas tire une action (changer d'instance, sélectionner,
# réaligner, séparateurs, ajouts, nouvelle instance, Overwrite, Delete, arbre, conservation, clustering,
# overview, objet 3D, sauvegarde et réouverture, Reload). Après chaque pas : erreurs Tcl et contrôles d'état
# de la sonde (phase 3). Au premier échec, la marche s'arrête et écrit la suite d'actions qui y mène.
# Usage :
#   tclsh8.6 test/phase4/marche.tcl N GRAINE PAS FICHIER SORTIE        marche aléatoire
#   tclsh8.6 test/phase4/marche.tcl N rejoue FICHIER_ACTIONS FICHIER SORTIE   rejoue une suite d'actions
lassign $argv N Graine NbPas Fichier Sortie
set argv [list $N]
source [file join [file dirname [file dirname [file normalize [info script]]]] phase3 commun.tcl]
set Donnees $env(HOME)/.cache/claude-ordalie-tests/donnees
set fo [open $Sortie w]; fconfigure $fo -buffering line
proc Log {s} {puts $s; puts $::fo $s}
proc Q {s} {W::ask $s}

# --- actions concrètes : {nom script ?délai?} -------------------------------------------
proc Choix {L} {lindex $L [expr {int(rand() * [llength $L])}]}
proc LignesSeqs {} {Q {set r {}; set y 0; foreach n $::LNOrdali {incr y; if {[string trim $n] ne ""} {lappend r $y}}; set r}}
proc LignesSeps {} {Q {set r {}; set y 0; foreach n $::LNOrdali {incr y; if {[string trim $n] eq "" && $y > 1 && $y < [llength $::LNOrdali]} {lappend r $y}}; set r}}
proc Selection {lignes} {
    set s {set ::PosInitNom 1.0}
    set premier 1
    foreach l $lignes {append s "; SelectNomSeq [expr {$premier ? "une" : "ctr"}] $l.0"; set premier 0}
    return $s
}
proc Tire {} {
    set macs [Q LesMacs]
    set cour [Q {MacCourant name}]
    set i1 [expr {[Q MacCourant] == 1}]
    set L {}
    # poids : une action apparaît plusieurs fois
    # instance modifiée : Ordalie demande Overwrite / Create a new one / Leave without saving / Cancel.
    # « Create a new one » ouvre la fenêtre du titre, que le banc ne remplit pas : Overwrite, ou Cancel
    # sur l'instance d'origine (M1)
    set rep [expr {$i1 ? 3 : 0}]
    foreach m $macs {if {$m ne $cour} {lappend L [list "instance $m" "probe::answer tk_dialog $rep; MiseAJourMac x [list $m]"]}}
    set seqs [LignesSeqs]
    for {set k 0} {$k < 3} {incr k} {
	set n [expr {1 + int(rand()*3)}]
	set sel {}; for {set j 0} {$j < $n} {incr j} {lappend sel [Choix $seqs]}
	lappend L [list "sélection [lsort -unique -integer $sel]" [Selection [lsort -unique -integer $sel]]]
    }
    if {[llength [Q {set ::NomSeqSel}]] >= 1} {lappend L {"réalignement de la sélection" ReAlignSeqs 600000}}
    if {[llength [Q {set ::NomSeqSel}]] == 1} {lappend L {"ajout d'un séparateur" AddSpaceSeq}}
    set seps [LignesSeps]
    if {$seps ne ""} {
	set y [Choix $seps]
	lappend L [list "retrait du séparateur $y" "[Selection [list $y]]; RemoveSpaceSeq"]
	lappend L {"retrait de tous les séparateurs" RemoveAllSeparators}
    }
    lappend L [list "ajout de séquences (fichier)" "AjouteSequenceOrPDB seqfile; set ::TAddS(SeqFileIn) $::Donnees/ajout.tfa; .was.fbut.ok invoke" 600000]
    set cif [Choix {AF-E9AEW4-F1-model_v6.cif AF-Q3KRD0-F1-model_v6.cif AF-Q9BW92-F1-model_v6.cif 1il2.cif 1il2.pdb}]
    lappend L [list "ajout de la structure $cif" "AjouteSequenceOrPDB pdbfile; set ::TAddS(StrucFileIn) $::Donnees/$cif; .was.fbut.ok invoke" 300000]
    set k [expr {int(rand()*1000)}]
    lappend L [list "nouvelle instance P$k" "SauveLeMac 1 P$k {marche $k}"]
    if {! $i1} {lappend L {"Overwrite" {SauveLeMac 0}}}
    if {! $i1 && [llength $macs] > 2} {lappend L {"suppression de l'instance" {probe::answer tk_dialog 0; DetruitInstance}}}
    lappend L {"arbre" {ChangeMode arbres; SelectionneToutesColonnes; CalculeUnArbre; ChangeMode feature} 300000}
    lappend L [list "conservation" "ChangeMode conservation; set ::Cons(Method) Threshold; set ::Cons(Title) m$k; LanceCalculConservation; SauveConservation; QuitteModeConservation \$::FrmBouton.cons" 300000]
    if {1} {lappend L {"clustering" {ChangeMode cluster; foreach k [array names ::Clus LCrit,*] {set ::Clus($k) 0}; set ::Clus(LCrit,length) 1; set ::Clus(Method) "hierarchic / secator"; NouveauClustering; ChangeMode feature} 300000}}
    lappend L {"overview" AfficheOverview}
    if {[Q {llength $::ListePDB}]} {
	set t [Choix {1 2 3 5 7}]
	set c [Choix {red blue couldefond green1}]
	lappend L [list "viewer, objet type $t $c" "VisualiseStructure; set m \[lindex \$::Liste3dMol 0\]; DefineNewObj \$m {}; set ::NwOj(Obj) o$k; foreach e \[array names ::NwOjR\] {lset ::NwOjR(\$e) 1 $t; lset ::NwOjR(\$e) 2 $c}; FinNewObj ok; QuitteViandox" 300000]
    }
    lappend L {"sauvegarde et réouverture" "SauveLAlignement ORD @TMP@/m.ord; FermeFichier nosave; OuvrirFichierAlignementDansOrdali Unk @TMP@/m.ord" 600000}
    lappend L {"Reload" ReLoadFichier 600000}
    return [Choix $L]
}

# --- un pas : action, puis contrôles ----------------------------------------------------
proc Pas {i a} {
    lassign $a nom script ms
    if {$ms eq ""} {set ms 120000}
    set script [string map [list @TMP@ $::Tmp] $script]
    set avant [expr {[string match "sauvegarde*" $nom] ? [Q {dict remove [::P3::Empreinte] invariants}] : ""}]
    set macs0 [Q LesMacs]
    # écrit avant l'action : si Ordalie se ferme, on sait laquelle
    puts $::fo "ACTION $i [list $nom]"
    set r [W::fire $script $ms]
    set etat [dict get $r state]
    set err ""
    if {$etat ne "done"} {set err "état $etat"}
    if {[dict exists $r code] && [dict get $r code] == 1} {set err [lindex [split [dict get $r errorInfo] \n] 0]}
    if {[dict exists $r bgerrors]} {set err "bgerror [lindex [split [lindex [dict get $r bgerrors] 0] \n] 0]"}
    # dialogue resté ouvert (action bloquée) : fermé avant les contrôles
    if {$etat eq "blocked"} {Q {foreach w {.was .nwoj .pss .legend} {catch {destroy $w}}; list}}
    set inv [expr {$err eq "" ? [Q ::P3::Invariants] : ""}]
    if {$err eq "" && $avant ne ""} {
	set apres [Q {::P3::Empreinte}]
	# modifications de M1 (alignement de référence) : la sauvegarde crée « Mn - Modified alignment »
	set nouvelle [expr {[dict get $apres instance] ni $macs0}]
	foreach k [dict keys $avant] {
	    if {[string match "arbre *" $k]} continue
	    if {$nouvelle && $k in {instance description}} continue
	    if {! [dict exists $apres $k] || [dict get $apres $k] ne [dict get $avant $k]} {lappend inv "AR $k change à la réouverture"}
	}
    }
    set res [expr {$err ne "" ? "ERREUR $err" : ($inv ne "" ? "INVARIANT [join $inv { ; }]" : "OK")}]
    Log "PAS $i [list $a] => $res"
    return [expr {$res eq "OK"}]
}

set Actions {}
Start $Fichier
Log "DEBUT graine $Graine fichier $Fichier"
if {[catch {
    if {$Graine eq "rejoue"} {
	set c [open $NbPas]; set Liste [read $c]; close $c
	set i 0
	foreach a $Liste {
	    incr i
	    lappend Actions $a
	    if {! [Pas $i $a]} {Log "ECHEC au pas $i"; break}
	}
    } else {
	expr {srand($Graine)}
	for {set i 1} {$i <= $NbPas} {incr i} {
	    set a [Tire]
	    lappend Actions $a
	    if {! [Pas $i $a]} {Log "ECHEC au pas $i"; break}
	}
    }
} m]} {
    # erreur du banc, ou Ordalie fermé brutalement (réponse vide de la sonde) : un échec aussi
    Log "SCRIPT $m"
    Log "ECHEC script"
}
Log "ACTIONS [list $Actions]"
catch Stop
close $fo
