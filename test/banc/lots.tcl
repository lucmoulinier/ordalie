# Définition des lots de l'audit (voir clordali/reports/LOTS.md)
#   items : préfixes des entrées de la barre de menus ; skip : préfixes exclus
#   base 1 : explorer les widgets de la vue principale ; bindings : liaisons souris/clavier
#   scenarios : {nom script} (@WORK@ = répertoire de travail de l'instance, @TEST@ = clordali/test)
set Selections(sel3) {
    {set ::PosInitNom 1.0; SelectNomSeq une 1.0}
    {SelectNomSeq ctr 2.0}
    {SelectNomSeq ctr 3.0}
}
set Lots [dict create]
set saveopen {}
foreach {fmt ext} {TFA tfa MSF msf XML xml ALN aln ORD ord} {
    lappend saveopen "save $fmt" "probe::answer tk_getSaveFile @WORK@/out.$ext; SauveLAlignement $fmt; list \[file exists @WORK@/out.$ext\] \[file size @WORK@/out.$ext\]"
}
foreach {fmt ext} {TFA tfa MSF msf XML xml ALN aln ORD ord} {
    lappend saveopen "reopen $fmt" "FermeFichier nosave; probe::answer tk_getOpenFile @WORK@/out.$ext; OuvrirFichierAlignementDansOrdali $fmt; list \[TypeAli\] \[llength \$::LNOrdali\] \[catch {LesMacs} m\] \$m"
}
lappend saveopen "reopen RSF (test)" "FermeFichier nosave; set f \[lindex \[glob -nocomplain @TEST@/*.rsf\] 0\]; if {\$f eq {}} {return {pas de fichier rsf dans test/}}; probe::answer tk_getOpenFile \$f; OuvrirFichierAlignementDansOrdali RSF; list \[TypeAli\] \[llength \$::LNOrdali\]"
lappend saveopen "save window TFA" "probe::answer tk_getSaveFile @WORK@/win.tfa; CreeLAlignementDeLaFenetre TFA; file exists @WORK@/win.tfa"
dict set Lots L01 [dict create items {{File >}} skip {{File > Quit}} scenarios $saveopen]
dict set Lots L02 [dict create items {{Edit >}}]
dict set Lots L03 [dict create items {{View >}}]
dict set Lots L04 [dict create items {{Sequences > Names} {Sequences > Retrieve} {Sequences > Edit Seq} {Sequences > Add} {Sequences > Export} {Sequences > Features Summary}}]
dict set Lots X04 [dict create items {{Sequences > Add}}]
dict set Lots L05 [dict create items {{Sequences > Identity}}]
dict set Lots L06 [dict create items {{Sequences > Search}}]
dict set Lots L07 [dict create items {{Sequences > Features Editor}}]
dict set Lots L08 [dict create items {{Alignment > Editor}}]
dict set Lots L09 [dict create items {{Alignment > Clustering}}]
dict set Lots L10 [dict create items {{Alignment > Conservation}}]
dict set Lots L11 [dict create items {{Alignment > Tree}}]
dict set Lots L12 [dict create items {{Alignment > Annotate}}]
dict set Lots L13 [dict create items {{Alignment > Re-align} {Alignment > Add sep} {Alignment > Remove} {Alignment > Overview} {Alignment > Barcode} {Alignment > Toggle}}]
set superpose {
    "Superposition complète" {
	proc ::SupDlg {} {
	    if {[winfo exists .pdbchooser]} {.pdbchooser.btn.selall invoke; update; .pdbchooser.btn.cebon invoke}
	    if {[winfo exists .pdbref]} {set ::chxmolref [lindex $::ListePDB 0]; update; .pdbref.btn.cebon invoke}
	    set ::SupId [after 300 SupDlg]
	}
	set ::SupId [after 300 SupDlg]
	unset -nocomplain ::SupRotTrans
	ChangeMode superpose
	$::FrmBouton.select.falcl.sal invoke
	$::FrmBouton.select.frmsst.fin invoke
	after cancel $::SupId
	array names ::SupRotTrans
    }
}
dict set Lots L14 [dict create items {{Structures >}} scenarios $superpose]
dict set Lots L15 [dict create items {{Help >}}]
dict set Lots L16 [dict create base 1 depth 2 scenarios {
    "New Instance" {set n0 [llength [LesMacs]]; SauveLeMac 1; list $n0 [llength [LesMacs]] [MacCourant name]}
    "Delete instance (confirmé)" {set n0 [LesMacs]; probe::answer tk_dialog 0; DetruitInstance; list [llength $n0] [llength [LesMacs]] [MacCourant name]}
    "Changer d'instance (toutes)" {set r {}; foreach m [LesMacs] {MiseAJourMac x $m; lappend r [MacCourant]}; set r}
}]
dict set Lots L17 [dict create bindings {NomNomSeq NomTextSeq}]
