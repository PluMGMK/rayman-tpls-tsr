@echo off

echo Welcome to PluM's TPLS TSR installer!
echo The TSR itself is MIT-licensed, with source available on GitHub:
echo https://github.com/PluMGMK/rayman-tpls-tsr
echo This installer uses SED16, by Howard Helman and Walter Briscoe, of which
echo the full binary distribution is included in the SED16BIN folder.
echo I make no claim to copyright on this latter piece of software. Source code:
echo http://pement.org/sed/sed16src.zip

if not exist TPLSWRAP.EXE goto WRONGDIR
if not exist TPLSTSR3.EXE goto WRONGDIR
if not exist SED16BIN\SED.COM goto WRONGDIR

if not exist C:\RAYMAN.BAT goto NORAYMAN

find /I "tplswrap.exe" C:\RAYMAN.BAT > NUL
if not errorlevel 1 goto UPGRADE

find /I "rayman.exe" C:\RAYMAN.BAT > NUL
if errorlevel 1 goto NORAYMAN

rem Create a little batch file that sends us to the right directory
rem and saves our cwd for copying files...
sed16bin\sed "/rayman.exe/d" C:\RAYMAN.BAT > C:\TPLSTMP.BAT

move C:\RAYMAN.BAT C:\RAYMAN.BAK
sed16bin\sed "s/rayman.exe/tplswrap.exe/" C:\RAYMAN.BAK > C:\RAYMAN.BAT

goto COMMONINST

:UPGRADE
echo TPLS already seems to be installed. Performing an upgrade...
type C:\RAYMAN.BAT | find /I /V "tplswrap.exe" > C:\TPLSTMP.BAT

:COMMONINST
rem Now C:\TPLSTMP.BAT contains every line from C:\RAYMAN.BAT except the one
rem that actually launches Rayman - in other words, enough to get us to Rayman's
rem directory!
cd | sed16bin\sed "s/^/set olddir=/" >> C:\TPLSTMP.BAT
rem Now we've completed it, so it includes a final line "set olddir=<our cwd>"!

C:
call C:\TPLSTMP.BAT
rem Now our env is correct, so we can clean up...
del C:\TPLSTMP.BAT

copy %olddir%\TPLSWRAP.EXE .
copy %olddir%\TPLSTSR3.EXE .

echo TPLS installed! You can run C:\RAYMAN.BAT now!
goto END

:NORAYMAN
echo Rayman does not appear to be installed on this machine (at least not by
echo Ubi Soft's official installer).
echo If you know where RAYMAN.EXE is located, you can manually copy TPLSTSR3.EXE
echo and TPLSWRAP.EXE to that directory, and in future run TPLSWRAP.EXE instead
echo of RAYMAN.EXE.
echo If using Dosbox, you may need to update the "autoexec" section of your conf
echo file to make this change.
goto END

:WRONGDIR
echo Please run this file from the directory in which it came (which should also
echo contain TPLSWRAP.EXE, TPLSTSR3.EXE and the directory SED16BIN).

:END
