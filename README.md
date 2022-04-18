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
|Requires `Music.dat` | Yes | Yes | No |
|Requires custom CD-ROM / Image | No | No | Yes |
|Includes extra MIDI tracks from PS1 | Yes | Yes | No |
|Can be used with custom Dosbox builds | No (unless you search for pointers and [compile TPLS yourself](https://github.com/Snaggly/Rayman1Dos-TPLS/blob/master/OffsetList.h)) | No (unless you apply the [patch](https://raymanpc.com/forum/viewtopic.php?f=89&t=28341) and compile Dosbox yourself) | Yes, no recompilation needed! |
|Can be used on Windows 3.x / 9x | No | No | Yes |
|Can be used on pure DOS | No | No | Yes, with a DPMI host|
|Rayman versions supported | All versions mentioned [here](https://github.com/RayCarrot/RayCarrot.RCP.Metro/blob/2e5ace35ba8d064dc7a592d9700aa311853b6deb/RayCarrot.RCP.Metro/Utilities/Games/Rayman%201/TPLS/TPLSRaymanVersion.cs) | All versions mentioned [here](https://github.com/RayCarrot/RayCarrot.RCP.Metro/blob/2e5ace35ba8d064dc7a592d9700aa311853b6deb/RayCarrot.RCP.Metro/Utilities/Games/Rayman%201/TPLS/TPLSRaymanVersion.cs) | v1.12 US and EU, v1.20 German and IT-SP-DU, v1.21 US – if you need another version added, please get in touch!|

## Installation and usage

### If using Dosbox with a configuration file

* Make sure your Rayman version is supported (see above table) – if not, please let me know and I'll see what I can do!
* Download and extract a release from the [releases page](https://github.com/PluMGMK/rayman-tpls-tsr/releases).
* Change the `IMGMOUNT` command in the `autoexec` section of your config file to mount the `tplstsr3.cue` file, rather than the game's original CD image.
* Replace the invocation of `RAYMAN.EXE` in the `autoexec` section with `TPLSWRAP.EXE`.
* Copy `TPLSTSR3.EXE` and `TPLSWRAP.EXE` from the release into the same folder as your `RAYMAN.EXE`.
* You will probably also need a DPMI host – download [CWSDPMI](http://sandmann.dotster.com/cwsdpmi/csdpmi7b.zip) and extract `CWSDPMI.EXE` into the same folder as the other two files.
* Run Dosbox with your new config file and enjoy TPLS!

### If on native DOS or Windows 3.x / 9x (having used Ubi Soft's installer to install _Rayman_)

* Make sure your Rayman version is supported (see above table) – if not, please let me know and I'll see what I can do!
* Download and extract a release from the [releases page](https://github.com/PluMGMK/rayman-tpls-tsr/releases).
* Use the `tplstsr3.cue` (or `tplstsr3.toc`) and `tplstsr3.bin` files to burn a CD-R – it should be possible to do this with `cdrdao` on Linux, or perhaps [ImgBurn](https://www.imgburn.com/) on Windows.
* Insert the new CD into your PC running DOS or Windows, and run `INSTALL.BAT`.
* If you're running pure DOS (no Windows 3.x / 9x or OS/2), and don't have a DPMI host (or don't know what that is), you will again probably need to download [CWSDPMI](http://sandmann.dotster.com/cwsdpmi/csdpmi7b.zip) and extract `CWSDPMI.EXE` into the same folder as `RAYMAN.EXE`.
* Run `C:\RAYMAN.BAT` and enjoy TPLS!

## Compilation

Linking the TSR requires DOS, so I've included a `BUILD.BAT` script that can do the whole job on DOS itself.

Prerequisites:
* A DOS build of JWasm. You can get this from [here](https://www.japheth.de/Download/JWasm/JWasm211bd.zip) (from [japheth.de](https://www.japheth.de/JWasm.html)).
* The `DLINK` command for the DOS32 DOS Extender by Adam Seychell. This is hard to come by, but I got it from [here](https://hornet.org/cgi-bin/scene-search.cgi?search=AM).
  * Look for "/code/pmode/dos32b35.zip" on that page.

## Why DOS32?

One might wonder why I'm using an obscure DOS extender whose author has disappeared, and which is so hard to find.
Well, the reason is that it's the only __documented__ and __working__ way I could find to make a Protected-Mode TSR.

In fact, this is why the source file is called `TPLSTSR3.ASM` – my _third_ attempt to make this settled on DOS32. The previous two attempts had been:

1. Create a standard Real-Mode TSR hooking `int 2Fh` directly.
2. Use the well-documented [DPMI Resident Service interface](http://www.delorie.com/djgpp/doc/dpmi/ch4.8.html) to create a Protected-Mode TSR, hooking `int 31h AX=0300h`.

The first attempt was quickly abandoned, since I realized there would be no good way to switch back to Protected Mode and find Rayman's data in memory.

The second attempt showed more promise, until I realized that despite the extensive _documentation_, nobody has actually _implemented_ this lovely Resident Service interface! Yes, really!
At least, I haven't been able to find any implementations, and I found a forum post somewhere, where someone else in my situation wondered if these functions were just theoretical…

So, I went with DOS32, since it has a documented and working TSR function, `int 31h AX=EE30h`.
In fact, with the experience gained writing this thing, I've come to realize that a normal DPMI client with plain old `int 21h AH=31h`
would probably work just as well, but we are where we are…
