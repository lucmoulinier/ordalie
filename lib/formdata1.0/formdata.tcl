#
#
#
# Taken from the Tcl wiki (wiki.tcl.tk)
# allow retrieving of http post with a file.
#
# Adapted by Luc Moulinier to accept a list or a file

package provide form-data 1.0
package require mime

source ../src/ordali_web.tcl

namespace eval form-data {}

proc form-data::compose {partv {type multipart/form-data}} {
    upvar 1 $partv parts
    
    set mime [mime::initialize -canonical $type -parts $parts]
    set packaged [mime::buildmessage $mime]
    foreach part $parts {
	mime::finalize $part
    }
    mime::finalize $mime
    
    return $packaged
}

proc form-data::add_binary {partv name filename value type} {
    upvar 1 $partv parts
    set disposition "form-data; name=\"${name}\"; filename=\"$filename\""
    lappend parts [mime::initialize -canonical $type \
	    -string $value \
	    -encoding binary \
	    -header [list Content-Disposition $disposition]]

    return
}

proc form-data::add_field {partv name value} {
    upvar 1 $partv parts

    set disposition "form-data; name=\"${name}\""
    lappend parts [mime::initialize \
	    -canonical text/plain \
	    -string $value \
	    -header [list Content-Disposition $disposition]]

    return
}

proc form-data::format {name filename value type args} {
    set parts {}
    foreach {n v} $args {
	add_field parts $n $v
    }
    add_binary parts $name $filename $value $type

    return [compose parts]
}


proc form-data::post {url field type file {params {}} {headers {}}} {

    # lm - 13/05/2013
    # check if we have a file or list
    if {[string is list -strict $file]} {
	set content $file
	set file tmp
    } else {
	# get contents of the file
	set fd [open $file r]
	fconfigure $fd -translation binary -encoding binary
	set content [read $fd]
	close $fd
    }
    
    # format the file and form
    set message [form-data::format $field [file tail $file] $content $type {*}$params]
 
    # parse the headers out of the message body 
    # because http get url wants them as a separate 
    # parameter
    set headerEnd [string first "\r\n\r\n" $message]
    incr headerEnd
    set bodystart [expr {$headerEnd + 3}]
    set headers_raw [string range $message 0 $headerEnd]
    set body [string range $message $bodystart end]
    set headers_raw [string map {"\r\n " " " "\r\n" "\n"} $headers_raw]
    regsub {  +} $headers_raw " " headers_raw
    
    foreach line [split $headers_raw "\n"] {
	regexp {^([^:]+): (.*)$} $line all label value
	lappend headers $label $value
    }
    
    # get the content-type
    array set ha $headers
    set content_type $ha(Content-Type)
    unset ha(Content-Type)
    set headers [array get ha]
    
    # POST it
    set Retour [HttpCopy $url "" $body -type $content_type -binary true -headers $headers]

    if {0} {
	set token [http::geturl $url \
		-type $content_type \
		-binary true \
		-headers $headers \
		-query $body]
	http::wait $token
    }

    return $Retour
    #return $token
}

