#!/bin/bash
# Ensure ISO is up-to-date before burning it to CD
./mkiso.sh

# The WAV files are not included in the Git repo. If you want to burn your own customized CD, ensure you have all these tracks available:
WAVDIR=$HOME/RaymanPS1_bis
cdrecord -data TPLSTSR4.ISO -audio $WAVDIR/RaymanPS1_02.wav $WAVDIR/RaymanPS1_03.wav $WAVDIR/RaymanPS1_04.wav $WAVDIR/RaymanPS1_05.wav $WAVDIR/RaymanPS1_06.wav $WAVDIR/RaymanPS1_07.wav $WAVDIR/RaymanPS1_08.wav $WAVDIR/RaymanPS1_09.wav $WAVDIR/RaymanPS1_10.wav $WAVDIR/RaymanPS1_11.wav $WAVDIR/RaymanPS1_12.wav $WAVDIR/RaymanPS1_13.wav $WAVDIR/RaymanPS1_14.wav $WAVDIR/RaymanPS1_15.wav $WAVDIR/RaymanPS1_16.wav $WAVDIR/RaymanPS1_17.wav $WAVDIR/RaymanPS1_18.wav $WAVDIR/RaymanPS1_19.wav $WAVDIR/RaymanPS1_20.wav $WAVDIR/RaymanPS1_21.wav $WAVDIR/RaymanPS1_22.wav $WAVDIR/RaymanPS1_23.wav $WAVDIR/RaymanPS1_24.wav $WAVDIR/RaymanPS1_25.wav $WAVDIR/RaymanPS1_26.wav $WAVDIR/RaymanPS1_27.wav $WAVDIR/RaymanPS1_28.wav $WAVDIR/RaymanPS1_29.wav $WAVDIR/RaymanPS1_30.wav $WAVDIR/RaymanPS1_31.wav $WAVDIR/RaymanPS1_32.wav $WAVDIR/RaymanPS1_33.wav $WAVDIR/RaymanPS1_34.wav $WAVDIR/RaymanPS1_35.wav $WAVDIR/RaymanPS1_36.wav $WAVDIR/RaymanPS1_37.wav $WAVDIR/RaymanPS1_38.wav $WAVDIR/RaymanPS1_39.wav $WAVDIR/RaymanPS1_40.wav $WAVDIR/RaymanPS1_41.wav $WAVDIR/RaymanPS1_42.wav $WAVDIR/RaymanPS1_43.wav $WAVDIR/RaymanPS1_44.wav $WAVDIR/RaymanPS1_45.wav $WAVDIR/RaymanPS1_46.wav $WAVDIR/RaymanPS1_47.wav $WAVDIR/RaymanPS1_48.wav $WAVDIR/RaymanPS1_49.wav $WAVDIR/RaymanPS1_50.wav $WAVDIR/RaymanPS1_51.wav $WAVDIR/RaymanPC_20.wav $WAVDIR/RaymanPC_21.wav $WAVDIR/RaymanPC_22.wav $WAVDIR/RaymanPC_JP_20.wav $WAVDIR/RaymanPC_CH_20.wav $WAVDIR/RaymanPC_23.wav $WAVDIR/RaymanPC_24.wav $WAVDIR/RaymanPC_26.wav $WAVDIR/RaymanPC_JP_21.wav $WAVDIR/RaymanPC_CH_21.wav || exit 1

echo To get BIN/CUEs for this new CD, you can run:
echo cdrdao read-cd --datafile tplstsr4.bin --driver generic-mmc:0x20000 --read-raw tplstsr4.toc
echo toc2cue tplstsr4.toc tplstsr4.cue
