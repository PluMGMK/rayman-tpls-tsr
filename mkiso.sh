#!/bin/bash
# Create an ISO image for release, ensuring that its contents are up-to-date

# First make sure the built EXEs are up-to-date
jwasm -mz TPLSTSR4.ASM
jwasm -mz FIXWLDS.ASM

# Now create the ISO
# Set the abstract, biblio and copyright, even though (for now) the TSR spoofs them anyway
# Use level 1 to ensure maximal compatibility with DOS!
mkisofs -v -abstract RAYMAN -biblio RAYMAN -copyright RAYMAN -V RAYMAN -iso-level 1 -o TPLSTSR4.ISO {TPLSTSR4,FIXWLDS}.{ASM,EXE} LICENSE README.md *.sh
