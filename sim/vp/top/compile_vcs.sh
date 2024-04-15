#!/bin/tcsh

vcs -full64 \
    +vpi \
    -Mupdate \
    +error+10 \
    +v2k \
    -timescale=1ns/100ps \
    +notimingcheck \
    +warn=all \
    +warn=noTFIPC \
    +warn=noWSUM \
    +define+FSDB_DUMP_DISABLE \
    -sverilog \
    -xprop=tmerge \
    -l vcs.log \
    -CFLAGS -std=c++11 \
    -f ./flist.f \
    -j96

#-debug_access+pp+fn+nomemcbk \
#-debug_region+cell+encrypt \
#-debug_pp \
#-rad -debug_acc+pp \
#-cm line+cond+tgl+fsm+branch+assert \