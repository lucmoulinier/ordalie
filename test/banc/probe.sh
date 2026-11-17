#!/bin/bash
# probe.sh N [-fire] [-wait ms] 'commande tcl'
N=$1; shift
exec /home/moumou/tcl/bin/tclsh8.6 "$(cd "$(dirname "$0")" && pwd)/client.tcl" $((4500+N)) "$@"
