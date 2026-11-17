

proc CleanHTML {data} {
set data [RemoveHTMLComment $data]
set data [RemoveHTMLStyle $data]
set data [RemoveHTMLJavascript $data]
set data [RemoveHTMLSVG $data]

return $data
}


proc RemoveHTMLComment {txt} {
# remove comments in HTML string
set id [string first "<!--" $txt]
while {$id > -1} {
set if [string first "-->" $txt $id+4]
set txt "[string range $txt 0 $id-1][string range $txt $if+3 end]"
set id [string first "<!--" $txt]
}
regsub -all "><" $txt ">\n<" txt

return $txt
}


proc RemoveHTMLJavascript {txt} {
# Remove Javascript scripts in HTML text
set txt [RemoveHTMLBalise script $txt]

return $txt
}


proc RemoveHTMLSVG {txt} {
# Remove SVG graphics from HTML
set txt [RemoveHTMLBalise svg $txt]

return $txt
}


proc RemoveHTMLStyle {txt} {
# Remove CSS style scripts in HTML text
set txt [RemoveHTMLBalise style $txt]

return $txt
}


proc RemoveHTMLBalise {balise txt} {
if {[string index $balise 0] eq "<"} {
set balise [string range $balise 1 end]
}
set baliseOn  "<$balise"
set baliseOff "</$balise>"
set lenBalOn  [string length $baliseOn]
set lenBalOff [string length $baliseOff]

set id [string first $baliseOn $txt]
while {$id > -1} {
set if [string first $baliseOff $txt $id+$lenBalOn]
set txt "[string range $txt 0 $id-1][string range $txt $if+$lenBalOff end]"
set id [string first $baliseOn $txt]
}
regsub -all "><" $txt ">\n<" txt

return $txt
}
