# Outils de sonde pour les tests des fenêtres à saisie (chargé dans l'instance par W::ask source).
# ::Champs::Liste w : champs de saisie sous w, {chemin classe variable valeur valeurs_possibles}
namespace eval ::Champs {}
proc ::Champs::Liste {w} {
    set r {}
    set L [list $w]
    while {$L ne {}} {
	set L [lassign $L x]
	lappend L {*}[winfo children $x]
	set c [winfo class $x]
	set v ""
	switch $c {
	    Entry - TEntry - Spinbox - TSpinbox - TCombobox - Combobox {catch {set v [$x cget -textvariable]}}
	    Checkbutton - Radiobutton - TCheckbutton - TRadiobutton - Scale - TScale {catch {set v [$x cget -variable]}}
	    Text {}
	    default continue
	}
	set val ""
	if {$v ne ""} {catch {set val [set ::$v]}} elseif {$c eq "Text"} {set val [$x get 1.0 end-1c]}
	set pos ""
	switch $c {
	    TCombobox - Combobox - Spinbox - TSpinbox {catch {set pos [$x cget -values]}}
	    Radiobutton - TRadiobutton {catch {set pos [$x cget -value]}}
	    Checkbutton - TCheckbutton {catch {set pos [list [$x cget -onvalue] [$x cget -offvalue]]}}
	}
	set etat ""
	catch {set etat [$x cget -state]}
	lappend r [list $x $c $v $val $pos $etat]
    }
    return $r
}

# ::Champs::Pixel w y x : coordonnées (dans le widget Biotext w) du centre de la case ligne y, colonne x,
# après l'avoir rendue visible ; recherche avec « index @x,y », croissant en x et en y
proc ::Champs::Pixel {w y x} {
    $w see $y.$x
    update
    set W [winfo width $w]; set H [winfo height $w]
    # colonne : plus petit px donnant la colonne x
    set a 0; set b $W
    while {$a < $b} {
	set m [expr {($a+$b)/2}]
	lassign [split [$w index @$m,2] .] yy xx
	if {$xx < $x} {set a [expr {$m+1}]} else {set b $m}
    }
    set x0 $a
    set a $x0; set b $W
    while {$a < $b} {
	set m [expr {($a+$b)/2}]
	lassign [split [$w index @$m,2] .] yy xx
	if {$xx <= $x} {set a [expr {$m+1}]} else {set b $m}
    }
    set px [expr {($x0+$a-1)/2}]
    set a 0; set b $H
    while {$a < $b} {
	set m [expr {($a+$b)/2}]
	lassign [split [$w index @$px,$m] .] yy xx
	if {$yy < $y} {set a [expr {$m+1}]} else {set b $m}
    }
    set y0 $a
    set a $y0; set b $H
    while {$a < $b} {
	set m [expr {($a+$b)/2}]
	lassign [split [$w index @$px,$m] .] yy xx
	if {$yy <= $y} {set a [expr {$m+1}]} else {set b $m}
    }
    set py [expr {($y0+$a-1)/2}]
    if {[$w index @$px,$py] ne "$y.$x"} {error "case $y.$x non trouvée : [$w index @$px,$py]"}
    list $px $py
}
