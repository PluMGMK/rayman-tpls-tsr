# rayman-tpls-tsr
This is a [TSR](https://en.wikipedia.org/wiki/Terminate_and_stay_resident_program), or "Terminate and Stay Resident Program" for DOS,
to implement "TPLS" (Per-Level Soundtrack) functionality for the PC version of _Rayman 1_. This functionality has previously been implemented
[here](https://github.com/Snaggly/Rayman1Dos-TPLS) and in [Rayman Plus](https://raymanpc.com/forum/viewtopic.php?f=89&t=25867),
and also as a [patch](https://raymanpc.com/forum/viewtopic.php?f=89&t=28341) applied to Dosbox. The Per-Level Soundtrack makes the soundtrack
of the PC version use multiple tracks per world, like on PS1 or Saturn, instead of repetitive medleys.

The unique feature of this latest implementation is that it runs natively inside DOS, alongside the _Rayman_ game itself.
This means that it can be used with any custom build of Dosbox, or indeed without Dosbox on an actual old gaming PC!

However, it also means that unlike the other implementations, a custom CD image is needed, or indeed a custom CD if running natively on an old PC.

## Advantages and limitations of different TPLS implementations

|Implementation |Memory-modifying TPLS (e.g. Rayman Plus) |TPLS built into Dosbox | TPLS as a TSR (i.e. this work) |
--- |--- | --- | ---
|Requires `dat` file | `Music.dat` | `Music.dat` | `AMBIENTS.DAT` (only for MIDI tracks) |
|Requires custom CD-ROM / Image | No | No | Yes |
|Includes extra MIDI tracks from PS1 | Yes | Yes | Yes! |
|Can be used with custom Dosbox builds | No (unless you search for pointers and [compile TPLS yourself](https://github.com/Snaggly/Rayman1Dos-TPLS/blob/master/OffsetList.h)) | No (unless you apply the [patch](https://raymanpc.com/forum/viewtopic.php?f=89&t=28341) and compile Dosbox yourself) | Yes, no recompilation needed! |
|Can be used on Windows 3.x / 9x | No | No | Yes |
|Can be used on pure DOS | No | No | Yes |
|Rayman versions supported | All versions mentioned [here](https://github.com/RayCarrot/RayCarrot.RCP.Metro/blob/2e5ace35ba8d064dc7a592d9700aa311853b6deb/RayCarrot.RCP.Metro/Utilities/Games/Rayman%201/TPLS/TPLSRaymanVersion.cs) | All versions mentioned [here](https://github.com/RayCarrot/RayCarrot.RCP.Metro/blob/2e5ace35ba8d064dc7a592d9700aa311853b6deb/RayCarrot.RCP.Metro/Utilities/Games/Rayman%201/TPLS/TPLSRaymanVersion.cs), plus v1.12 US UNPROTECTED | See below (basically every version we know about!) |

### Supported Rayman versions

These are all existing Rayman versions of which I am aware, and the TSR has been tested with each one to a certain extent. It "works" with all of them, but for some of them there may be some glitches that occur deeper in the game which I'm not aware of.

* "RAYMAN (US) v1.21"
* "RAYMAN (FR) v1.21"
* "RAYMAN (CH) v1.21"
* "RAYMAN (JP) v1.20"
* "RAYMAN (UK) v1.20"
* "RAYMAN (GERMAN) v1.20"
* "RAYMAN (IT-SP-DU) v1.20"
* "RAYMAN (US) v1.12" (both "UNPROTECTED" and normal version)
* "RAYMAN (EU) v1.12"
* "RAYMAN (EU) v1.10"
* "RAYMAN v1.00"

## Installation and usage

### If using Dosbox with a configuration file

* Make sure your Rayman version is supported (see above table) – if not, please let me know and I'll see what I can do!
* Download and extract a release from the [releases page](https://github.com/PluMGMK/rayman-tpls-tsr/releases).
* Change the `IMGMOUNT` command in the `autoexec` section of your config file to mount the `tplstsr3.cue` file, rather than the game's original CD image.
* Before the invocation of `RAYMAN.EXE` in the `autoexec` section, add `D:\TPLSTSR4.EXE` (where `D` is your CD drive letter).
* Run Dosbox with your new config file and enjoy TPLS!

### If on native DOS or Windows 3.x / 9x (having used Ubi Soft's installer to install _Rayman_)

* Make sure your Rayman version is supported (see above table) – if not, please let me know and I'll see what I can do!
* Download and extract a release from the [releases page](https://github.com/PluMGMK/rayman-tpls-tsr/releases).
* Use the `tplstsr4.cue` (or `tplstsr4.toc`) and `tplstsr4.bin` files to burn a CD-R – it should be possible to do this with `cdrdao` on Linux (**using the `--swap` option!**), or perhaps [ImgBurn](https://www.imgburn.com/) on Windows.
* Insert the new CD into your PC running DOS or Windows.
* Before running Rayman, run `D:\TPLSTSR4.EXE` (where `D` is your CD drive letter).
* Run `C:\RAYMAN.BAT` and enjoy TPLS!

## Compilation

`TPLSTSR4` (unlike the previous version) is a plain old `MZ` executable. However, because of the peculiar way I've used groups in the code, a lot of assemblers seem to miscalculate certain offsets. [JWasm](https://github.com/Baron-von-Riedesel/JWasm) v2.14 or greater will assemble the TSR correctly, and it can run on Windows, DOS or Linux.

```
jwasm -mz TPLSTSR4.ASM
```

It will warn about no stack being defined, but it should still produce a working `TPLSTSR4.EXE` in DOS `MZ` format.

## Ambient ("MIDI") tracks from PS1 version

In order for the game to play the ambient tracks, the file `AMBIENTS.DAT` needs to be present in the same folder that the TSR runs from (i.e. `TPLSTSR4.EXE` and `AMBIENTS.DAT` need to be in the same folder). This file is generated by `mkambdat.py`, which is a Python script that requires the [python-ffmpeg](https://pypi.org/project/python-ffmpeg/) module.

Currently it works by taking some of the 44.1-kHz 32-bit stereo FLAC files available in an archive on [RayTunes](https://raytunes.raymanpc.com), down-sampling them to 10-kHz 16-bit mono, and saving them as raw PCM data suitable for loading by the game itself. Given that the originals are MIDI, I suppose this doesn't really degrade the quality too badly…

## How does it work?

Unlike v1.x (using the DOS32 extender), since v2.0 this is a normal Real Mode TSR.
However, it still manages to inject 32-bit Protected Mode code into Rayman.
It does this by attaching a payload to whichever `HMIDRV.386` sound driver Rayman is using (this is why it won't work if Rayman's sound isn't configured), and saving it into a temporary file.
Rayman is then directed to open this temporary file instead of the original file when looking for its sound driver.

When Rayman loads the sound driver, it initially transfers control to the payload, which is able to communicate with the TSR's Real Mode stub.
The payload first sets up code and data segments for the actual sound driver, and then it sets up the hooks and overrides needed for TPLS itself.
It then transfers control to the actual sound driver, which is able to operate normally.

## Wishlist (possible future additions)

* Make the exit sign fanfare work in Candy Château (Currently it doesn't work because my code relies on the game entering a "frozen" state to hold Rayman in his pose until the fanfare finishes. For some reason, the game does not enter this "frozen" state in Candy Château, so my code wouldn't work in its current iteration.)
* More fine-grained configuration: perhaps command-line switches to choose whether or not to play the ambient tracks, or the exit sign fanfare, or the CD track for when Rayman dies.
 * Or perhaps even an in-game menu? (This would be **very** tricky though!)
* Option to replace the "popping" sound used for Tings with the "ting" sound from PS1
* [Not strictly related to the soundtrack, but would be nice] Fix the bugged curse stars in Candy Château so that they actually appear on Rayman like in the PS1 version. (The code for them does exist in the PC version, but – at least in _Rayman Designer_ – it only works when there are two curses at once, which never happens in the original game.)

I'm not promising at this point that any of these features will appear in a future version, but it's a possibility! :)
