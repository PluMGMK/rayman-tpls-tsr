#!/usr/bin/python3
#mkmididat.py
# This file takes in FLACs from RayTunes and creates a DAT file
# with a header and lots of 10-kHz 16-bit signed mono PCM data!

from ffmpeg import FFmpeg
from sys import argv
import os.path

# Here are the files. The indices in this list are important,
# as they correspond to the hitpoints values for Ambient Starters.
input_files = [
        "58 - PS1 ~ Level Loading.flac",    # Index 0 only gets played at world load
        "62 - PS1 ~ Jungle Beat 1.flac",
        "63 - PS1 ~ Jungle Beat 2.flac",    # Unused? :/
        "64 - PS1 ~ Bongo Hills.flac",
        "57 - PS1 ~ Rayman's Theme.flac",
        "65 - PS1 ~ Mountain Beat 1.flac",
        "66 - PS1 ~ Mountain Beat 2.flac",
        "67 - PS1 ~ Mr Stone's Chase.flac",
        "69 - PS1 ~ Picture City Beat.flac",
        "70 - PS1 ~ Cave Bongos 1.flac",    # Unused? :/
        "71 - PS1 ~ Cave Bongos 2.flac",
        "72 - PS1 ~ Bad Rayman's Chase 1.flac",
        "73 - PS1 ~ Bad Rayman's Chase 2.flac",
        "61 - PS1 ~ Victory.flac",          # Special case - boss beaten
        ]

# Output file is AMBIENTS.DAT; The format is (in MASM notation):
#   numTracks   dd ?    ; how many tracks in the file
#   offTrack0   dd ?    ; offset of track 0
#   lenTrack0   dd ?    ; length of track 0
#   offTrack1   dd ?    ; offset of track 1
#   lenTrack1   dd ?    ; length of track 1
#   ...
#   offTrackN   dd ?    ; offset of track N
#   lenTrackN   dd ?    ; length of track N
#   pcmTrack0   db X dup (?)    ; 16-bit little-endian mono PCM data for track 0
#   pcmTrack1   db Y dup (?)    ; 16-bit little-endian mono PCM data for track 1
#   ...
#   pcmTrackN   db Z dup (?)    ; 16-bit little-endian mono PCM data for track N
output_file = "AMBIENTS.DAT"

input_dir = argv[-1]
if not os.path.isdir(input_dir):
    print("You need to specify the directory containing the FLAC files as the last argument!")
    exit(1)

# Use a list comprehension to convert all the files
pcm_data = [
        FFmpeg()
        .option("y")
        .input(os.path.join(input_dir,fn))
        .output(
            "pipe:1",   # Pipe the PCM data directly into the Python program
            acodec="pcm_s16le",
            f="s16le",  # Raw PCM data
            ac=1,       # Mono track
            ar=10000,   # Downsample to 10 kHz
            # Trim silence:
            af="silenceremove=start_periods=1:stop_periods=-1:start_threshold=-30dB:stop_threshold=-30dB:start_silence=2:stop_silence=2",
        ).execute()
        for fn in input_files
        ]

# Calculate the lengths
lengths = [len(pcm) for pcm in pcm_data]

# Figure out the position of the first track
total_tracks = len(lengths)
# Four bytes for the track count, and eight per track for the offset and length
first_offset = 4 + 8*total_tracks

# Now calculate the offsets
offsets = [first_offset]
for length in lengths[:-1]: # Leave off the last one since there is nothing after it!
    offsets.append(offsets[-1] + length)

# Write the data to the file - all little-endian since this is aimed at x86!
with open(output_file,"wb") as output:
    # Write the number of tracks
    output.write(total_tracks.to_bytes(4,'little'))
    # Write the offset and length of each track
    for offset,length in zip(offsets,lengths):
        output.write(offset.to_bytes(4,'little'))
        output.write(length.to_bytes(4,'little'))
    # We should be at the first offset now...
    if output.tell() != first_offset:
        print("WARNING: calculated offset of first track appears to be incorrect!")
    # Write the actual data
    for pcm in pcm_data:
        output.write(pcm)
    print(f"Wrote {output.tell()} bytes to {output_file} - Enjoy! :)")
