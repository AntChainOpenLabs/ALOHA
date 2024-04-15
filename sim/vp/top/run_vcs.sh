#!/bin/tcsh

setenv ISRAM_FILE $1
setenv SPM_FILE $2
setenv TDB_PATH $3
setenv SRC0_PTR $4
setenv SRC1_PTR $5
setenv RSLT_PTR $6
setenv KSK_PTR $7
setenv STEP $8
setenv RUN_PATH $9

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
    +define+FSDB_DUMP_DISABLE \
    -rad -debug_acc+pp \
    -sverilog \
    -xprop=tmerge \
    +noinline \
    -l vcs.log \
    -cm line+cond+tgl+fsm+branch+assert \
    -CFLAGS -std=c++11 \
    -f ./flist.f \
    -j16 \
    +vcs+lic+wait \
    -Xkeyopt=rtopt

if ($status != 0) then
  /bin/echo -e "\t@@@ RTL Compile FAILED"
  /bin/echo -e ""
  exit 0
endif

./simv +vcs+lic+wait -l ./simv.log -cm line+cond+tgl+fsm+branch+assert
urg -dir simv.vdb -dbname merge