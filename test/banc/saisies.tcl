# Saisies de l'explorateur (phase 2) : table des valeurs valides et invalides par genre de champ,
# classement des messages. Actif avec GUI_SAISIES=1 ; sinon l'explorateur garde son comportement d'origine.
set Saisies [expr {[info exists env(GUI_SAISIES)] && $env(GUI_SAISIES)}]
set Donnees [expr {[info exists env(GUI_DONNEES)] ? $env(GUI_DONNEES) : "$env(HOME)/.cache/claude-ordalie-tests/donnees"}]
# accès réseau autorisés par exécution (lecture seule)
set Reseau [expr {[info exists env(GUI_RESEAU)] ? $env(GUI_RESEAU) : 2}]
set ReseauReste [dict create accessions $Reseau idstruct $Reseau]

# le budget est par genre : les ajouts par access ne privent pas les structures
proc prend_reseau {g} {
    if {[dict get $::ReseauReste $g] <= 0} {return 0}
    dict incr ::ReseauReste $g -1
    return 1
}
proc nom_champ {c} {
    foreach k {label var} {
	if {[string trim [dict get $c $k]] ne ""} {return [string trim [dict get $c $k]]}
    }
    return [lindex [split [dict get $c path] .] end]
}
# genre d'un champ, d'après sa variable, son chemin, son libellé et le titre de sa fenêtre
proc genre {c} {
    set t [string tolower "[dict get $c var] [dict get $c path] [dict get $c label] [dict get $c titre]"]
    foreach {g re} {
	accessions {uniprot|refseq|access|seqidin}
	fichier    {file|fichier|path}
	idstruct   {pdb|structure|struct}
	couleur    {colou?r}
	nombre     {thresh|cutoff|seuil|number|nbr|\ynb|size|width|height|score|factor|penal|gap|count|percent|%|window|weight|\ymin|\ymax|length}
	plage      {range|zone|interval|\yfrom\y|\yto\y|start|stop|debut}
	nom        {name|\ynom|title|label|obj|group|note|comment|desc}
	ec         {\yec\y|e\.c\.}
	sequence   {\ysequence\y|seqin}
    } {
	if {[regexp $re $t]} {return $g}
    }
    return texte
}
proc valeur_valide {c} {
    set d $::Donnees
    switch -- [genre $c] {
	accessions {return A0A3S7X901}
	idstruct   {return 1IL2}
	fichier {
	    set t [string tolower "[dict get $c var] [dict get $c path] [dict get $c label] [dict get $c titre]"]
	    return [expr {[regexp {pdb|struct|cif} $t] ? "$d/1il2.cif" : "$d/ajout.tfa"}]
	}
	couleur  {return red}
	ec       {return 6.1.1.12}
	nombre   {return 5}
	plage    {return 5}
	nom      {return test_ordalie}
	sequence {return MKVLAGIVTEQ}
	default  {return test}
    }
}
proc valeurs_invalides {c} {
    switch -- [genre $c] {
	accessions {return [list ZZZZZZ "a\{b"]}
	idstruct   {return [list NOTPDB "a\[b"]}
	fichier    {return [list /inexistant/x.tfa "a b\{c"]}
	couleur    {return [list pasunecouleur]}
	ec         {return [list 6.1 "a\{b"]}
	nombre     {return [list -1 abc 1e99]}
	plage      {return [list -5 x]}
	nom        {return [list "a b\{c" {[exit]}]}
	sequence   {return [list 123 "a\{b"]}
	default    {return [list "a\{b"]}
    }
}
proc est_validation {d} {
    expr {[dict exists $d text] && [dict exists $d command] &&
	  [regexp -nocase {^\s*(ok|apply|compute|add|run|go|load|fetch|retrieve|create|draw|validate|search)\s*$} [dict get $d text]]}
}
# valeurs des champs vides, pour une action sur le widget d. Un champ qui interroge le
# réseau n'est rempli que pour une validation, et dans la limite du budget.
proc valeurs_valides {champs d} {
    set vals {}
    set resume {}
    foreach c $champs {
	if {[dict get $c val] ne ""} continue
	if {[genre $c] in {accessions idstruct}} {
	    if {! [est_validation $d] || ! [prend_reseau [genre $c]]} continue
	}
	dict set vals [dict get $c path] [valeur_valide $c]
	lappend resume [genre $c]
    }
    return [list $vals $resume]
}
# une action qui ne produit qu'une consigne (« Please ... ») n'a pas atteint son code
proc classe_msg {res} {
    foreach x [dict get $res dialogs] {
	if {[regexp -nocase {^FaireLire: *(beware|please|select|no .* selected|you must|.* first *!|.* needs at least|give )} $x]} {return VALID}
    }
    return MSG
}
