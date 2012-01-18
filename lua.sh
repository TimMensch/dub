#!/bin/sh
THISPATH=`dirname $0`
CYGPATH=$THISPATH
QCPATH=$THISPATH/../qc/tools

echo $THISPATH|grep -qv cygdrive
result=$?
if (( $result )) ; then
    THISPATH=`cygpath -w $THISPATH`
fi

P1=$1
shift
env LUA_PATH=bindings_path/\?.lua\;$THISPATH/lib/\?.lua LUA_CPATH=\;\;$QCPATH/host/this/clibs/?.dll\;$QCPATH/host/this/clibs/?.so $QCPATH/host/this/luajit $THISPATH/$P1 $*
