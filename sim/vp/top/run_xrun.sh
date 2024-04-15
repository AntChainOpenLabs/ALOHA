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

xrun -64bit \
     -sv \
     -notimingcheck \
     -uvmaccess \
     -date \
     -dumpstack \
     -negdelay \
     -xprop C -XPELSA -xfile xfile.txt \
     -nowarn CUVWSP \
     -nowarn DSEMEL \
     -nowarn RNDXCELON \
     -nowarn DSEM2009 \
     -nowarn RNQUIE \
     -nowarn FUNTSK \
     -nowarn BIGWIX \
     -timescale 1ns/100ps \
     -l $8/xrun.log \
     -CFLAGS -std=c++11 \
     -f ./flist.f