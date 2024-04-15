#!/bin/tcsh

vcs -full64 \
    +vpi \
    -Mupdate \
    -debug_access+pp+fn+nomemcbk \
    -debug_region+cell+encrypt \
    +error+10 \
    +v2k \
    -timescale=1ns/100ps \
    +notimingcheck \
    +warn=all \
    +warn=noTFIPC \
    +warn=noWSUM \
    +define+FSDB_DUMP \
    -rad -debug_acc+pp \
    -sverilog \
    -xprop=tmerge \
    -l vcs.log \
    -cm line+cond+tgl+fsm+branch+assert \
    -f ./flist.f

if ($status != 0) then
  /bin/echo -e "\t@@@ RTL Compile FAILED"
  /bin/echo -e ""
  exit 0
endif

./simv +vcs+lic+wait -l ./simv.log -cm line+cond+tgl+fsm+branch+assert
urg -dir simv.vdb -dbname merge