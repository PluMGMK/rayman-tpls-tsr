#!/bin/bash -e
# Create a bin/cue pair for a complete CD image

# Remove existing files
test -e TPLSTSR4.bin && rm TPLSTSR4.bin
test -e TPLSTSR4.cue && rm TPLSTSR4.cue

# Ensure ISO is up-to-date before creating a BIN
./mkiso.sh

# Convert ISO to bin
poweriso convert TPLSTSR4.ISO -o "./CD/01. Data Track.bin" -y

# Convert WAV files to bin
# The WAV files are not included in the Git repo. If you want to make your own customized CD image, ensure you put all the tracks in the CD folder
for wav in ./CD/*.wav; do
	[ -e "$wav" ] || continue
	ffmpeg -y -i "$wav" -acodec pcm_s16le -f s16le -ac 2 -ar 44100 "${wav%.*}.bin"
done

rm "./CD/01. Data Track.cue" # there's no way of telling poweriso we don't want this
binmerge --outdir . "./CD/TPLSTSR4.cue" "TPLSTSR4"
sed '/INDEX 00/d' TPLSTSR4.cue > TPLSZULU.cue
