#!/bin/tcsh

vcs -full64 \
    +vpi \
    -Mupdate \
    -debug_access+pp+fn+nomemcbk \
    -debug_region+cell+encrypt \
    -debug_pp \
    +error+10 \
    +v2k \
    -timescale=1ns/100ps \
    +notimingcheck \
    +warn=all \
    +warn=noTFIPC \
    +warn=noWSUM \
    -rad -debug_acc+pp \
    -sverilog \
    -xprop=tmerge \
    +noinline \
    -l vcs.log \
    -CFLAGS -std=c++11 \
    -f ./flist.f \
    -j16

if ($status != 0) then
  /bin/echo -e "\t@@@ RTL Compile FAILED"
  /bin/echo -e ""
  exit 0
endif

./simv +vcs+lic+wait -l ./simv.log