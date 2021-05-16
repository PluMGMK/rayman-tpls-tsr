; PluM's TPLS TSR - DOS32 version - third time's a charm!

; MIT License
; 
; Copyright (c) 2021 PluMGMK
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

; Build instructions:
; - Assemble on any OS of your choice using MASM or compatible, to OMF format
;  - E.g. `uasm -omf tplstsr3.asm`
; - Link *on DOS* using DLINK, from Adam Seychell's DOS32 3.5 beta distribution
;  - E.g. `DLINK -S TPLSTSR3.O`
;  - This distribution is hard enough to come by - I found it here:
;   - https://hornet.org/cgi-bin/scene-search.cgi?search=AM
;   - (Look for "/code/pmode/dos32b35.zip" on that page)

.386
.MODEL  FLAT
.STACK 
.CODE

rmcall STRUCT
	_edi	dd ?
	_esi	dd ?
	_ebp	dd ?
	res	dd ?
	_ebx	dd ?
	_edx	dd ?
	_ecx	dd ?
	_eax	dd ?
	flags	dw ?
	_es	dw ?
	_ds	dw ?
	_fs	dw ?
	_gs	dw ?
	_ip	dw ?
	_cs	dw ?
	_sp	dw ?
	_ss	dw ?
rmcall ENDS

exception_stackframe STRUCT
	int_retaddx	df ?	; DPMI host's internal addx - NO TOUCHY!
	_aln1		dw ?	; alignment padding
	errcode		dd ?
	act_retaddx	df ?	; The actual return addx
	_aln2		dw ?	; alignment padding (again)
	eflags		dd ?
	ss_esp		df ?
	_aln3		dw ?	; alignment padding
exception_stackframe ENDS

	old_int31	df ?
	mydatasel	dw ?	; A selector to access our local data
	raymanpsp	dw ?	; Rayman's PSP
	old_gphandler	df ?
	callerpsp	dw ?	; our current caller's PSP
	rayman_cs	dw ?	; Rayman's code segment
	rayman_cs_asds	dw 0	; Rayman's code segment as a data segment, for poking!

	NUM_BKPTS	equ 50	; more than we'll ever need, hopefully!
	bkpt_addxs	dd NUM_BKPTS dup (0)
	bkpt_origcode	dw NUM_BKPTS dup (0F5CDh)

	; Pointers to code in Rayman
	pInt31		dd ?
	pCreditsTrackNo	dd ?
	pLogoTrackNo	dd ?
	pMenuTrackNo	dd ?
	pGOverTrackNo	dd ?
	pTrackTabDone	dd ?	; End of the track table population function

	; Pointers to data in Rayman
	pRM_call_struct	dd ?
	pnum_world	dd ?
	pnum_level	dd ?
	ptrack_table	dd ?	; Pointer to level track assignment table (static)
	ptrack_lentable	dd ?
	prbook_table	dd ?	; Pointer to table of Redbook track info (populated @ runtime)
	prbook_lentable	dd ?
	prbook_tablefl	dd ?	; Pointer to flag indicating latter table is populated
	plowest_atrack	dd ?
	phighest_atrack	dd ?

	rayman_banner	db 'R',1Eh,'A',1Eh,'Y',1Eh,'M',1Eh,'A',1Eh,'N',1Eh

	logfile_name	db "C:\TPLSICHK.LOG",0

	ENTETE_SIZE	equ 80	; number of columns in typical console - hardcoded into Rayman itself
	entete_buf	db ENTETE_SIZE dup (?)

	; DOS strings
	intro		db "Welcome to ",33o,"[35mP",33o,"[95ml",33o,"[35mu",33o,"[95mM",33o,"[35m'",33o,"[95ms",33o,"[37m TPLS TSR!",13,10,13,10
			db "Checking for DPMI...",13,10,"$"
	nodpmi		db "DOS32 not using DPMI. Please run under Windows or install a DPMI host.",13,10
			db "If a VCPI provider is running, you may need to disable it.",13,10
			db "In VCPI/raw mode, I can't guarantee continuity of int 31h from DOS32 to PMODE/W.",13,10,"$"
	tooprivileged	db "DOS32 is using DPMI, but in Ring 0.",13,10
			db "This means I can't stop Rayman interfering with the Debug Registers.",13,10
			db "Please use a Ring-3 DPMI host instead.",13,10,"$"
	dpmiok		db "DPMI available! Preparing to go resident...",13,10,"$"
	nogphandler	db "Couldn't install General Protection Fault handler.",13,10
			db "This means I can't stop Rayman interfering with the Debug Registers.",13,10
			db "Aborting...",13,10,"$"
	tsrok		db "Service installed - terminating successfully. You can play Rayman now!",13,10,"$"
	unkver		db 33o,"[35m","PluM says: Unknown Rayman version (see log file). Aborting...",33o,"[37m",13,10,"$"
	bkpterr		db 33o,"[35m","PluM couldn't install their breakpoint handler. Aborting...",33o,"[37m",13,10,"$"
	unhandled_gp	db 33o,"[35m","It's dead Jim. X(",33o,"[37m",13,10,"$"

	; Rayman version strings
	ray121us	db "RAYMAN (US) v1.21"

entry:	; Welcome the user, hook int 31h and go resident
	mov	edx,offset intro
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h

	mov	ax,0EE00h	; check DOS32 version
	int	31h
	cmp	dl,8
	mov	edx,offset nodpmi
	jne	failure

	mov	ax,cs
	test	ax,3
	mov	edx,offset tooprivileged
	jz	failure

	mov	edx,offset dpmiok
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h
	mov	[mydatasel],ds	; save our local data segment selector for use when our interrupt is invoked

	; Check if the DPMI host has a breakpoint handler installed.
	; If not, install a dummy one to prevent Rayman's leftover debugging code from crashing rudely.
	mov	ax,0202h	; get exception handler
	mov	bl,3		; breakpoint
	int	31h
	test	cx,cx
	jnz	install_gphandler

	mov	ax,0203h	; set exception handler
	mov	cx,cs		; this code segment
	mov	edx,offset dummy_handler
	int	31h

install_gphandler:
	; Install GP handler to prevent interference with debug registers.
	mov	ax,0202h	; get exception handler
	mov	bl,0Dh		; GP violation
	int	31h
	mov	dword ptr [old_gphandler],edx
	mov	word ptr [old_gphandler+4],cx

	mov	ax,0203h	; set exception handler
	mov	cx,cs		; this code segment
	mov	edx,offset gp_handler
	int	31h
	mov	edx,offset nogphandler
	jc	failure
	
	mov	ax,0204h	; get interrupt vector
	mov	bl,31h
	int	31h
	mov	dword ptr [old_int31],edx
	mov	word ptr [old_int31+4],cx

	inc	ax		; set interrupt vector
	mov	cx,cs
	mov	edx,offset new_int31
	int	31h

	mov	bl,0F5h		; our custom breakpoint vector
	mov	edx,offset bkpt_handler
	int	31h

	mov	edx,offset tsrok
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h
	mov	ax,0ee30h
	int	31h

failure:
	mov	ah,9		; display message
	int	21h
	mov	ax,4CFFh	; exit with -1 code
	int	21h

; Resident code:

new_int31:
	cmp	ax,0300h
	je	sim_rm_int
	jmp	cs:old_int31
	
sim_rm_int:
	cmp	bl,2Fh
	je	sim_rm_int2F
	jmp	cs:old_int31

sim_rm_int2F:
	cmp	byte ptr [es:edi+rmcall._eax+1],15h	; Real-Mode AH = 15h?
	je	sim_rm_mscdex
	jmp	cs:old_int31

get_psp:
	; Output: ZF set if it's Rayman, clear otherwise
	push	eax
	push	ebx
	mov	ah,62h
	int	21h

	cmp	bx,[raymanpsp]
	mov	[callerpsp],bx

	pop	ebx
	pop	eax
	ret

check_is_rayman:
	; Output: ZF set if called from Rayman, clear otherwise
	push	es
	push	edi
	push	esi
	push	eax
	push	ebx

	mov	ax,2		; convert RM segment to PM data selector
	mov	bx,0B800h	; Video BIOS text buffer
	int	31h
	jc	raycheck_nonzero; Silently fail, assume it's not Rayman
	mov	es,ax
	xor	edi,edi		; We're interested in the very beginning of this segment.

	mov	esi,offset rayman_banner
	cld
	cmpsd
	jnz	raycheck_retpoint
	cmpsd
	jnz	raycheck_retpoint
	cmpsd
	jnz	raycheck_retpoint

	mov	bx,[callerpsp]
	mov	[raymanpsp],bx
	jmp	raycheck_retpoint

raycheck_nonzero:
	or	esp,esp		; Guaranteed to clear ZF

raycheck_retpoint:
	pop	ebx
	pop	eax
	pop	esi
	pop	edi
	pop	es
	ret

read_entete:
	; Read the UbiSoft banner at the top of the console,
	; called the "EnTete" in their code.
	push	es
	push	ds
	push	esi
	push	edi
	push	ecx
	push	ebx
	push	eax

	mov	ax,ds
	mov	es,ax
	mov	edi,offset entete_buf

	mov	ax,2		; convert RM segment to PM data selector
	mov	bx,0B800h	; Video BIOS text buffer
	int	31h
	jc	trash
	mov	ds,ax
	xor	esi,esi		; We're interested in the very beginning of this segment.

	mov	ecx,ENTETE_SIZE
transfer_loop:
	lodsw	; Load the character and control byte
	stosb	; Just store the character
	loop	transfer_loop

entete_retpoint:
	pop	eax
	pop	ebx
	pop	ecx
	pop	edi
	pop	esi
	pop	ds
	pop	es
	ret

trash:
	; Fill the buffer with spaces to avoid having to explain ourselves...
	mov	eax,20202020h
	mov	ecx,ENTETE_SIZE SHR 2
	rep	stosd
	jmp	entete_retpoint

write_to_logfile:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi

	; Apparently PMODE/W doesn't provide service 6Ch :(
	; mov	ax,6C00h		; extended open/create
	; ; Read/write + Full sharing access + Do not call int 24h + Flush each write
	; mov	bx,2+(1 SHL 6)+(1 SHL 0Dh)+(1 SHL 0Eh) 
	; xor	cx,cx			; no special file attributes
	; mov	dx,1+(1 SHL 4)		; Open if exists + Create if it doesn't
	; mov	esi,offset logfile_name

	; Let's use 3Dh instead, but the file has to exist first...
	; Open file + Read/write + Full sharing access
	mov	ax,3D42h
	xor	cx,cx			; no special file attributes
	mov	edx,offset logfile_name
	int	21h
	jc	logfile_retpoint		; fail silently

	mov	ebx,eax
	mov	ax,4202h		; seek from end
	xor	ecx,ecx			; 0 from end - i.e. the end itself
	xor	edx,edx
	int	21h

	mov	ah,40h			; write to file
	mov	ecx,ENTETE_SIZE
	mov	edx,offset entete_buf
	int	21h

	; Next, figure out where this version of Rayman keeps its Real-Mode call structure
	push	es
	push	edi
	mov	edx,[pRM_call_struct]
	mov	es,[mydatasel]
	mov	edi,offset entete_buf	; reuse this buffer...
	mov	ah,'x'
	mov	al,'0'
	cld
	stosw				; start the hex number with the familiar "0x"

	mov	ecx,8
	add	edi,ecx
	dec	edi
	mov	word ptr [edi],0A0Dh	; terminate the line with 13,10 (little endian!)

	std				; work backwards
hex_to_asc:	
	mov	al,dl
	and	al,0Fh			; lower nibble
	cmp	al,0Ah			; is it a letter or number?
	jb	not_asc
	add	al,'A'-'0'-0Ah
not_asc:
	add	al,'0'
	stosb
	shr	edx,4			; move onto next nibble
	loop	hex_to_asc

	cld
	pop	edi
	pop	es

	mov	ah,40h			; write to file
	mov	ecx,12			; enough for "0x", eight nibbles, and CRLF
	mov	edx,offset entete_buf
	int	21h

	mov	ah,3Eh			; close the logfile
	int	21h

logfile_retpoint:
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

; int __fastcall poketext(int data, void *addx, unsigned char size)
; Inserts a byte/word/dword (depending on "size") into Rayman's code segment
; at the given addx, and returns what was there before.
poketext:
	cmp	[rayman_cs_asds],0
	jnz	poketext_segpresent

	push	eax
	push	ebx
	push	ecx
	push	edx

	; Create a data selector
	xor	ax,ax			; allocate LDT selector
	mov	cx,1			; we only need one...
	int	31h
	mov	[rayman_cs_asds],ax

	; Get the base of Rayman's code segment
	mov	ax,6			; get segment base addx
	mov	bx,[rayman_cs]
	int	31h			; sets CX:DX

	mov	ax,7			; set segment base addx - uses CX:DX
	mov	bx,[rayman_cs_asds]
	int	31h

	mov	ax,8			; set segment limit
	mov	cx,0FFFFh		; 4 GB limit
	mov	dx,cx			; set lower 12 bits to page-align (??)
	int	31h

	pop	edx
	pop	ecx
	pop	ebx
	pop	eax

poketext_segpresent:
	push	es
	; mov	es,[rayman_cs_asds]
	bt	ebx,0			; single byte?
	jnc	poketext_notbyte
	xchg	al,[es:edx]
	jmp	poketext_retpoint

poketext_notbyte:
	bt	ebx,1			; word?
	jnc	poketext_notword
	xchg	ax,[es:edx]
	jmp	poketext_retpoint

poketext_notword:
	xchg	eax,[es:edx]		; default to dword (we are 32-bit after all!)
poketext_retpoint:
	pop	es
	ret

; int set_breakpoint@<ecx>(void *addx@<edx>)
; Sets a breakpoint for *execution* at the given addx in Rayman's *code* segment.
set_breakpoint:
	push	eax

	xor	eax,eax
	call	bkpt_find		; find a null breakpoint

	mov	eax,offset bkpt_addxs
	mov	[eax+ecx*4],edx		; set the address

	pop	eax
	call	bkpt_activate		; activate the new breakpoint!
	ret

; void clear_breakpoint(int idx@<ecx>)
clear_breakpoint:
	call	bkpt_deactivate		; first, make sure it's inactive!
	push	eax

	mov	eax,offset bkpt_addxs
	mov	dword ptr [eax+ecx*4],0

	pop	eax
	ret

sim_rm_mscdex:
	push	ds			; this pushes a dword on the stack??
	mov	ds,[cs:mydatasel]	; our own data are of interest now!

	call	get_psp
	je	skipinstcheck		; if we already recognize Rayman's PSP

	; Is it an installation check?
	cmp	byte ptr [es:edi+rmcall._eax],0	; AL = 0?
	jne	passthrough
	cmp	word ptr [es:edi+rmcall._ebx],0	; BX = 0?
	jne	passthrough

	; OK, this could be a new application checking for MSCDEX
	; Is it Rayman?
	call	check_is_rayman
	jne	passthrough

	; Yes it's Raaaaaaaaaaaaaaaaaaaaaaaaaaaayyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyman...
	mov	[pRM_call_struct],edi	; this is the address of the RM call structure
	mov	edi,[esp+4]		; stack: Saved DS (4b!), then return address (4b)
	sub	edi,2			; subtract 2b to get back to beginning of int 31h instruction
	mov	[pInt31],edi
	mov	di,[esp+8]		; Rayman's code segment should be here
	call	read_entete
	mov	[rayman_cs],di
	mov	edi,[pRM_call_struct]	; in case we forget to do this later!

rayman_vercheck:
	; Next, check the Rayman version
	push	edi
	push	ecx
	push	esi
	push	es
	mov	cx,ds
	mov	es,cx

	; Check for version 1.21 US
	mov	esi,offset ray121us
	mov	edi,offset entete_buf
	mov	ecx,sizeof ray121us
	repe	cmpsb
	je	setup_ptrs_v121us

	; TODO: Check for other versions
	push	edx
	mov	edx,offset unkver
	mov	ah,9			; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h
	call	write_to_logfile
	
	pop	edx
	pop	es
	pop	esi
	pop	ecx
	pop	edi
	jmp	mscdex_retpoint		; return without calling MSCDEX function so Rayman thinks it's not installed

setup_ptrs_v121us:
	mov	edi,[pRM_call_struct]	; @ 0x54E38 in the data section
	lea	esi,[edi-(54E38h-3F88Ch)]
	mov	[pnum_world],esi	; @ 0x3F88C in the data section
	lea	esi,[edi-(54E38h-3F87Ch)]
	mov	[pnum_level],esi	; @ 0x3F87C in the data section
	lea	esi,[edi-(54E38h-4F3Bh)]
	mov	[ptrack_table],esi	; @ 0x4F3B in the data section
	lea	esi,[edi-(54E38h-4FBCh)]
	mov	[ptrack_lentable],esi	; @ 0x4FBC in the data section
	lea	esi,[edi-(54E38h-4E8C7h)]
	mov	[prbook_table],esi	; @ 0x4E8C7 in the data section
	lea	esi,[edi-(54E38h-4EA5Bh)]
	mov	[prbook_lentable],esi	; @ 0x4EA5B in the data section
	lea	esi,[edi-(54E38h-4EEFEh)]
	mov	[prbook_tablefl],esi	; @ 0x4EEFE in the data section
	lea	esi,[edi-(54E38h-4E8C1h)]
	mov	[plowest_atrack],esi	; @ 0x4E8C1 in the data section
	lea	esi,[edi-(54E38h-4E8C1h)]
	mov	[phighest_atrack],esi	; @ 0x4E8C2 in the data section

	mov	edi,[pInt31]		; @ 0x79B9D in the text section
	lea	esi,[edi-(79B9Dh-0CF48h)]
	mov	[pCreditsTrackNo],esi	; @ 0xCF48 in the text section
	lea	esi,[edi-(79B9Dh-0CF70h)]
	mov	[pLogoTrackNo],esi	; @ 0xCF70 in the text section
	lea	esi,[edi-(79B9Dh-0CFF0h)]
	mov	[pMenuTrackNo],esi	; @ 0xCFF0 in the text section
	lea	esi,[edi-(79B9Dh-0D018h)]
	mov	[pGOverTrackNo],esi	; @ 0xD018 in the text section
	lea	esi,[edi-(79B9Dh-1A8F8h)]
	mov	[pTrackTabDone],esi	; @ 0x1A8F8 in the text section

	; TODO: Pointer setup code for other versions

common_tracktable_setup:
	; Restore registers from before the version check
	pop	es
	pop	esi
	pop	ecx
	; Except EDI since we'll use it again immediately

	push	eax
	mov	edi,[ptrack_table]

	; JUNGLE
	inc	edi			; skip level 0, which doesn't exist
	; For now, assume no data track.
	; This will be fixed up when the game populates its Redbook track table
	mov	al,3			; First Steps
	stosb
	mov	al,8			; Lost in the Woods
	stosb
	mov	al,31			; Betilla the Fairy
	stosb
	mov	al,4			; Deep Forest
	stosb
	mov	al,3			; First Steps
	stosb
	mov	al,8			; Lost in the Woods
	stosb
	mov	al,5			; Flight of the Mosquito
	stosb
	mov	al,31			; Betilla the Fairy
	stosb
	mov	al,8			; Lost in the Woods
	stosb
	mov	al,4			; Deep Forest
	stosb
	stosb				; two levels in a row with same track
	mov	al,3			; First Steps
	stosb
	mov	al,8			; Lost in the Woods
	stosb
	mov	al,32			; Suspense
	stosb
	mov	al,5			; Flight of the Mosquito
	stosb
	mov	al,9			; Moskito's Rage
	stosb
	mov	al,31			; Betilla the Fairy
	stosb
	mov	al,34			; The Magician's Challenge
	; Five levels with same track - four bonus levels + breakout
	stosb
	stosb
	stosb
	stosb
	stosb

	; MUSIC
	mov	al,16			; Harmony
	stosb
	mov	al,14			; Bongo Bridge
	stosb
	mov	al,15			; The Band Awakens
	stosb
	mov	al,23			; Storm in Band Land
	stosb
	mov	al,14			; Bongo Bridge
	stosb
	mov	al,19			; The Red Drummers
	stosb
	mov	al,17			; Fear of Heights
	stosb
	mov	al,16			; Harmony
	stosb
	mov	al,17			; Fear of Heights
	stosb
	mov	al,18			; Blazing Brass
	stosb
	mov	al,31			; Betilla the Fairy
	stosb
	mov	al,12			; Mysterious Gongs
	stosb
	mov	al,21			; Meditating Monks
	stosb
	mov	al,18			; Blazing Brass
	stosb
	mov	al,20			; The Saxophone's Song
	stosb
	stosb				; two levels in a row with same track
	mov	al,34			; The Magician's Challenge
	; Two bonus levels
	stosb
	stosb
	add	edi,4			; skip levels 19-22, which don't exist

	; MOUNTAIN
	mov	al,28			; Night on Blue Mountain
	stosb
	stosb				; two levels in a row with same track
	mov	al,25			; Rocking up the Mountains
	stosb
	mov	al,26			; Peaceful Peaks
	stosb
	mov	al,28			; Night on Blue Mountain
	stosb
	mov	al,25			; Rocking up the Mountains
	stosb
	mov	al,32			; Suspense
	stosb
	mov	al,11			; Flooded Mountains
	stosb
	mov	al,24			; Watch your step!
	stosb
	mov	al,27			; Ruler of the Mountains
	stosb
	mov	al,31			; Betilla the Fairy
	stosb
	mov	al,34			; The Magician's Challenge
	; Two bonus levels
	stosb
	stosb
	add	edi,9			; skip levels 14-22, which don't exist

	; IMAGE
	mov	al,40			; The Inky Sea
	stosb
	mov	al,36			; Picture Perfect
	stosb
	mov	al,39			; Quiet!
	stosb
	mov	al,37			; Space Mama's Play
	stosb
	mov	al,36			; Picture Perfect
	stosb
	mov	al,35			; Painted Pentathlon
	stosb
	mov	al,39			; Quiet!
	stosb
	mov	al,35			; Painted Pentathlon
	stosb
	mov	al,23			; Storm in Band Land
	stosb
	mov	al,32			; Suspense
	stosb
	mov	al,39			; Washing Machine from Space
	stosb
	mov	al,34			; The Magician's Challenge
	; Two bonus levels
	stosb
	stosb
	add	edi,9			; skip levels 14-22, which don't exist

	; CAVE
	mov	al,43			; Lurking in the Darkness
	stosb
	mov	al,42			; Deep in the Caves
	stosb
	mov	al,44			; Party at Joe's
	stosb
	mov	al,46			; Alone in the Dark
	stosb
	mov	al,42			; Deep in the Caves
	stosb
	mov	al,46			; Alone in the Dark
	stosb
	mov	al,42			; Deep in the Caves
	stosb
	mov	al,44			; Party at Joe's
	stosb
	mov	al,41			; Entering the Cavern
	stosb
	mov	al,45			; Never Wake a Sleeping Scorpion
	stosb
	stosb				; two levels in a row with same track
	mov	al,34			; The Magician's Challenge
	; Two bonus levels
	stosb
	stosb
	add	edi,9			; skip levels 14-22, which don't exist

	; CAKE
	mov	al,47			; Creepy Clowns
	stosb
	mov	al,49			; Candy Party
	stosb
	mov	al,48			; The Cake is a Lie
	stosb
	mov	al,13			; Cloak of Darkness
	stosb
	add	edi,14			; skip levels 5-18 (!), which don't exist

	; MISC
	push	edx
	push	ebx

	mov	ebx,1			; poking single bytes
	mov	al,2			; Ubi Soft Presents
	mov	edx,[pLogoTrackNo]
	call	poketext

	mov	al,33			; World Map
	mov	edx,[pMenuTrackNo]
	call	poketext

	mov	al,44			; Party at Joe's
	mov	edx,[pCreditsTrackNo]
	call	poketext

	mov	al,50			; End of the Line
	mov	edx,[pGOverTrackNo]
	call	poketext

	; Now set a breakpoint so we can fill in the lengths of these tracks
	; once the game has read them from the CD!
	mov	edx,[pTrackTabDone]
	push	ecx
	call	set_breakpoint

	pop	ecx			; we don't need the BP's idx for now...
	pop	ebx
	pop	edx
	pop	eax
	pop	edi
	jmp	passthrough

skipinstcheck:
	; TODO:
	; - Reactivate inactive breakpoints 
	; - Set breakpoints for things like:
	;  - The mosquito's attack in Anguish Lagoon
	;  - Planting a seed in the Swamps
	;  - etc...

passthrough:
	pushfd				; Bloody UASM generates 16-bit instructions if I don't include the 'd'!
	call	old_int31		; doesn't matter that we've the wrong DS, since service 0300h doesn't use DS anyway
mscdex_retpoint:
	pop	ds
	iretd				; Bloody UASM generates 16-bit instructions if I don't include the 'd'!

; bool bkpt_active(int idx@<ecx>);
; ZF clear if breakpoint is active, set if inactive
bkpt_active:
	push	edx
	mov	edx,offset bkpt_origcode
	cmp	word ptr [edx+ecx*2],0F5CDh
	pop	edx
	ret

; int bkpt_find@<ecx>(void *addx@<eax>);
; Finds and returns the index of the *last* breakpoint in the list
; corresponding to the given addx.
; If none, returns -1
bkpt_find:
	push	es
	push	edi
	mov	di,ds
	mov	es,di

	mov	edi,(offset bkpt_origcode)-4
	mov	ecx,NUM_BKPTS
	std
	repne	scasd
	je	bkpt_found
	cld

	or	ecx,-1

bkpt_found:
	pop	edi
	pop	es
	ret

; ushort bkpt_swapcode@<eax>(int idx@<ecx>);
; Swaps the word at the idx-th breakpoint in the text section
; with the word stored in the table
bkpt_swapcode:
	push	ebx
	push	edx

	mov	edx,offset bkpt_origcode
	mov	ax,[edx+ecx*2]
	mov	edx,offset bkpt_addxs
	mov	edx,[edx+ecx*4]
	mov	ebx,2			; poke a word

	call	poketext

	mov	edx,offset bkpt_origcode
	mov	[edx+ecx*2],ax		; store the word we just replaced

	pop	edx
	pop	ebx
	ret

; void bkpt_activate(int idx@<ecx>);
; Activates the idx-th breakpoint if it's inactive.
bkpt_activate:
	call	bkpt_active
	jnz	bkpt_activate_retp
	push	eax
	call	bkpt_swapcode
	pop	eax
bkpt_activate_retp:
	ret

; void bkpt_deactivate(int idx@<ecx>);
; Dectivates the idx-th breakpoint if it's active.
bkpt_deactivate:
	call	bkpt_active
	jz	bkpt_activate_retp
	push	eax
	call	bkpt_swapcode
	pop	eax
	ret

; Handler for our *custom* breakpoint mechanism on int F5
bkpt_handler:
	sub	dword ptr [esp],2	; rewind to before the int 0F5h instruction
	push	ebp
	lea	ebp,[esp+4]		; convenient pointer to stack frame
	push	ds			; this pushes a dword on the stack??
	mov	ds,[cs:mydatasel]	; our own data are of interest now!

	push	eax
	push	ecx
	mov	eax,[ebp]		; the return addx
	call	bkpt_find
	call	bkpt_deactivate

	cmp	eax,[pTrackTabDone]
	je	rbook_table_populated
	; Dunno what breakpoint that was then...

bkpt_retpoint:
	pop	ecx
	pop	eax
	pop	ds
	pop	ebp
	iretd

; Rayman has just populated its Redbook track tables.
; This means we can stop watching the flag, and
; that we can determine the lengths of the tracks.
rbook_table_populated:
	call	clear_breakpoint	; no need for this breakpoint anymore!

	push	esi
	push	edi
	push	edx
	push	ebx

	mov	esi,[ptrack_table]
	mov	edi,[ptrack_lentable]
	mov	edx,[prbook_lentable]
	mov	ecx,129			; length of the track table (for some reason)
	mov	ebx,[plowest_atrack]

	; Set DS to Rayman's so we can use lods as well as stos
	mov	ax,es
	mov	ds,ax
	cld

	; mov	bl,[ebx]
	; dec	bl			; zero-indexed track number of first audio track

tracklen_loop:
	; add	[edi],bl		; correct each table entry for data track
	xor	eax,eax
	lodsb				; load the track index into EAX
	mov	eax,[edx+eax*4]		; the EAXth entry of the Redbook length table

	push	edx
	push	ecx
	mov	ecx,75
	xor	edx,edx
	add	eax,74			; round up
	div	ecx			; convert sectors to seconds by dividing by 75
	pop	ecx
	pop	edx

	stosd				; store the length in seconds into the length table
	loop	tracklen_loop

	pop	ebx
	pop	edx
	pop	edi
	pop	esi
	jmp	bkpt_retpoint

; General Protection Fault handler. Prevent interference with Debug Registers.
; (And hence crashes when using more conservative DPMI hosts!)
gp_handler:
	push	ebp
	lea	ebp,[esp+4]		; convenient pointer to stack frame

	push	ds
	push	esi
	push	eax
	lds	esi,[ss:ebp+exception_stackframe.act_retaddx]
	cld
	lodsw

	cmp	ax,210Fh
	je	gp_readdbg
	cmp	ax,230Fh
	je	gp_resumenext		; trying to write a DR? Dat's niiiiice!

	pop	eax
	pop	esi
	pop	ds
	pop	ebp

	cmp	word ptr [cs:old_gphandler+4],0
	je	gp_failure		; no old handler to jump to!
	jmp	cs:old_gphandler

gp_readdbg:
	; Pretend the DRs are all empty, no matter what.
	; This will prevent Rayman from unceremoniously exiting when the user presses ESC.
	; (It doesn't even reset the video mode!)
	lodsb				; get the ModR/M byte
	and	eax,7			; get the dest register
	shl	eax,2			; multiply by 4 to get an offset into the following code
	add	eax,offset gp_xortable
	jmp	eax

gp_xortable:
	; Each xor/jmp pair is four bytes, so this forms a nice table
	xor	eax,eax
	jmp	short gp_seteax
	xor	ecx,ecx
	jmp	short gp_resumenext
	xor	edx,edx
	jmp	short gp_resumenext
	xor	ebx,ebx
	jmp	short gp_resumenext
	xor	esp,esp
	jmp	short gp_resumenext
	xor	ebp,ebp
	jmp	short gp_setebp
	xor	esi,esi
	jmp	short gp_setesi
	xor	edi,edi
	jmp	short gp_resumenext

gp_setesi:
	mov	[esp+4],esi
	jmp	short gp_resumenext
gp_setebp:
	mov	[esp+0Ch],ebp
	jmp	short gp_resumenext
gp_seteax:
	mov	[esp],eax
gp_resumenext:
	; Move execution onto the next instruction (three bytes later)
	add	dword ptr [ss:ebp+exception_stackframe.act_retaddx],3
	pop	eax
	pop	esi
	pop	ds
	pop	ebp
dummy_handler:
	retf

gp_failure:
	; Things are bad...
	mov	dword ptr [esp+exception_stackframe.act_retaddx],offset its_dead_jim
	mov	word ptr [esp+exception_stackframe.act_retaddx+4],cs
	retf

its_dead_jim:
	mov	ax,3	; switch to VGA text mode
	int	10h

	mov	ds,[cs:mydatasel]
	mov	edx,offset unhandled_gp
	jmp	failure

END entry
