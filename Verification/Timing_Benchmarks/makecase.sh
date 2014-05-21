#!/bin/bash
size=$1
chid=$2
casename=$chid.fds
echo generating test case $casename
cat <<EOF > $casename
&HEAD CHID='$chid', TITLE='General purpose input file to test FDS timings, SVN $Revision: 19308 $' /

REM DO NOT EDIT the .fds input files directly.  When making changes:
REM 1. edit the template file, makecase.sh
REM 2. rerun the script makecases.sh
REM 3. commit updated test64...fds and test128...fds input files

&MESH IJK=$size,$size,$size, XB=0.0,1.0,0.0,1.0,0.0,1.0 /

&TIME T_END=1.0 /

&DUMP NFRAMES=2,DT_DEVC=0.1 /

&SPEC ID='METHANE' /
&SPEC ID='WATER VAPOR' /

&SURF ID='HOT', VEL=-0.1, TMP_FRONT=100., COLOR='RED' /

&VENT MB='XMIN', SURF_ID='OPEN' /
&VENT MB='XMAX', SURF_ID='OPEN' /
&VENT MB='YMIN', SURF_ID='OPEN' /
&VENT MB='YMAX', SURF_ID='OPEN' /
&VENT PBZ=0.0,   SURF_ID='HOT' /
&VENT MB='ZMAX', SURF_ID='OPEN' /

&DEVC XYZ=0.5,0.5,0.5, QUANTITY='WALL CLOCK TIME ITERATIONS', ID='clock time' /

&TAIL /
EOF
