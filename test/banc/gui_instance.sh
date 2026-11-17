#!/bin/bash
# gui_instance.sh start N [fichier] | stop N | shot N fichier.png | status N
# instance N : display :$((80+N)), port $((4500+N)), répertoire $BASE/instN
BASE=${GUI_BASE:-/home/moumou/.cache/claude-ordalie-tests/audit_gui}
ODIR=${ODIR:-/home/moumou/clordali}
H=$(cd "$(dirname "$0")" && pwd)
cmd=$1; N=$2
D=$BASE/inst$N; DISP=$((80+N)); PORT=$((4500+N))
case $cmd in
start)
    mkdir -p $D/home $D/work
    [ -f ~/.ordalierc ] && cp ~/.ordalierc $D/home/
    rm -f $D/errors.log $D/caught.log $D/dialogs.log $D/stdout.log
    if ! DISPLAY=localhost:$DISP xdpyinfo >/dev/null 2>&1; then
        Xvfb :$DISP -screen 0 1600x1200x24 +extension GLX -nolisten unix -listen tcp > $D/xvfb.log 2>&1 &
        echo $! > $D/xvfb.pid
        for i in $(seq 50); do DISPLAY=localhost:$DISP xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
    fi
    F=""
    if [ -n "$3" ]; then cp "$3" $D/work/; F=$D/work/$(basename "$3"); fi
    (cd $D/work && HOME=$D/home DISPLAY=localhost:$DISP GSCOPEDIR=${GSCOPEDIR:-/home/ripp/gscope} ODIR=$ODIR FIC=$F \
       GUI_PROBE_PORT=$PORT GUI_PROBE_DIR=$D \
       setsid /home/moumou/tcl/bin/wish8.6 $H/probe.tcl > $D/stdout.log 2>&1 & echo $! > $D/wish.pid)
    for i in $(seq 600); do grep -q "PROBE READY" $D/stdout.log 2>/dev/null && { echo "inst$N ready (port $PORT, display :$DISP)"; exit 0; }
        kill -0 $(cat $D/wish.pid) 2>/dev/null || { echo "inst$N died"; tail -20 $D/stdout.log; exit 1; }
        sleep 0.5; done
    echo "inst$N timeout"; exit 1 ;;
stop)
    [ -f $D/wish.pid ] && { pkill -P $(cat $D/wish.pid) 2>/dev/null; kill $(cat $D/wish.pid) 2>/dev/null; }
    [ -f $D/xvfb.pid ] && kill $(cat $D/xvfb.pid) 2>/dev/null
    rm -f $D/wish.pid $D/xvfb.pid; echo "inst$N stopped" ;;
shot)
    ffmpeg -y -loglevel error -f x11grab -video_size 1600x1200 -i localhost:$DISP -frames:v 1 "$3" && echo "$3" ;;
status)
    kill -0 $(cat $D/wish.pid 2>/dev/null) 2>/dev/null && echo "inst$N running" || echo "inst$N down" ;;
*) echo "usage: $0 start N [file] | stop N | shot N file | status N"; exit 1 ;;
esac
