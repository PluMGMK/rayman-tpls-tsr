@echo off
rem DOS-native build script for TPLS TSR
rem
rem Requirements:
rem - JWasm from https://www.japheth.de/JWasm.html ("Binary DOS" build)
rem - DOS32 3.5 beta (including DLINK tool) from https://hornet.org/cgi-bin/scene-search.cgi?search=AM
rem   - (Look for "/code/pmode/dos32b35.zip" on that page)

echo Assembling wrapper...
@jwasmr -mz tplswrap.asm

echo Assembling TSR...
@jwasmr -omf tplstsr3.asm

echo Linking TSR...
@dlink -S tplstsr3.obj
