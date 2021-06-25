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
	dos32_int21	df ?	; int 21h vector provided by DOS32
	raymanpsp	dw ?	; Rayman's PSP
	old_int21	df ?	; int 21h vector at the time of Rayman's running (i.e. PMODE/W's)
	callerpsp	dw ?	; our current caller's PSP
	old_gphandler	df ?
	rayman_cs	dw ?	; Rayman's code segment
	rayman_cs_asds	dw 0	; Rayman's code segment as a data segment, for poking!
	align 4

	saved_excvecs	df 20h dup (?)
	saved_intvecs	df 100h dup (?)

	NUM_HOOKS	equ 50	; more than we'll ever need, hopefully!
	hook_addxs	dd NUM_HOOKS dup (0)
	hook_origcode	dw NUM_HOOKS dup (0F5CDh)

	; Pointers to code in Rayman
	pInt31		dd ?
	pCreditsTrackNo	dd ?
	pLogoTrackNo	dd ?
	pMenuTrackNo	dd ?
	pGOverTrackNo	dd ?
	pIntroTrackNo	dd 0	; For multi-lang versions, intro/outtro track number is a
	pOuttroTrackNo	dd 0	;  fixed offset of the language ID - edit this fixed offset
	pPlayIntro	dd 0	; For single-lang versions, intro/outtro track number is fixed,
	pPlayOuttro	dd 0	;  so we inject our own code to calculate from the lang value
	pTrackTabDone	dd ?	; End of the track table population function
	pDoGrowingPlat	dd ?
	pMoskitoLock	dd ?	; Where Moskito locks the screen to begin the boss fight
	pMoskitoFast	dd ?	; Rayman's riding on a mosquito that starts moving fast
	pMoskitoSlow	dd ?	; Rayman's riding on a mosquito that stops moving fast
	pLevelStart1	dd ?	; Corresponds to "Now in level" in Dosbox TPLS
	pLevelStart2	dd ?
	pLevelEnd1	dd ?	; Corresponds to "No longer in level" in Dosbox TPLS
	pLevelEnd2	dd ?
	pExitSign1	dd ?	; Rayman reaches an exit sign, so a fanfare should play
	pExitSign2	dd ?
	pPerdu		dd ?	; Rayman is dead, so his death track should play
	pPlayTrack	dd ?	; Function in Rayman's code for playing a numbered CD audio track

	; Pointers to data in Rayman
	pRM_call_struct	dd ?
	pnum_world	dd ?
	pnum_level	dd ?
	ptrack_table	dd ?	; Pointer to level track assignment table (static)
	ptimeCd		dd ?
	pcdTime		dd ?	; How long has the track been playing? Set to zero to restart.
	prbook_table	dd ?	; Pointer to table of Redbook track info (populated @ runtime)
	prbook_lentable	dd ?
	prbook_tablefl	dd ?	; Pointer to flag indicating latter table is populated
	plowest_atrack	dd ?
	phighest_atrack	dd ?
	pcd_driveletter dd ?	; Pointer to Rayman's CD-ROM drive letter
	plang		dd ?

	; Track on-the-fly music tampering
	plen_to_restore	dd ?
	ptra_to_restore	dd ?
	len_to_restore	dd ?
	tra_to_restore	db 0
	music_dirty	db 0	; Have we messed with the music and need to restart it?

	rayman_banner	db 'R',1Eh,'A',1Eh,'Y',1Eh,'M',1Eh,'A',1Eh,'N',1Eh

	logfile_name	db "C:\TPLSICHK.LOG",0

	ENTETE_SIZE	equ 80	; number of columns in typical console - hardcoded into Rayman itself
	entete_buf	db ENTETE_SIZE dup (?)

	; DOS strings
	already		db "TPLS already resident. Aborting. You can just play Rayman.",13,10,"$"
	intro		db "Welcome to ",33o,"[35mP",33o,"[95ml",33o,"[35mu",33o,"[95mM",33o,"[35m'",33o,"[95ms",33o,"[37m TPLS TSR!",13,10,13,10
			db "Checking for DPMI...",13,10,"$"
	NODPMI_EXPLAIN	equ "In VCPI/raw mode, I can't guarantee continuity of int 31h from DOS32 to PMODE/W.",13,10,"$"
	nodpmi		db "DOS32 not using DPMI. Please run under a Win9x/3.x VDM or install a DPMI host.",13,10,NODPMI_EXPLAIN
	vcpimode	db "DOS32 using VCPI. Please use TPLSWRAP.EXE to make it use DPMI instead.",13,10,NODPMI_EXPLAIN
	dpmiok		db "DPMI available! Preparing to go resident...",13,10,"$"
	nogphandler	db "Couldn't install General Protection Fault handler.",13,10
			db "This means I can't stop Rayman crashing when it messes with the Debug Registers.",13,10
			db "Aborting...",13,10,"$"
	savingvecs	db "Saving exception and interrupt vectors...",13,10,"$"
	tsrok		db "Service installed - terminating successfully. You can play Rayman now!",13,10,"$"
	unkver		db 33o,"[35m","PluM says: Unknown Rayman version (see log file). Aborting...",33o,"[37m",13,10,"$"
	hookerr		db 33o,"[35m","PluM couldn't install their hook vector. Aborting...",33o,"[37m",13,10,"$"
	noextratracks	db 33o,"[35m","Warning: You are not using a custom CD image with intro/outtro tracks.",13,10
			db 	"Intro and/or outtro cutscenes may be silent!",33o,"[37m",13,10,"$"
	unhandled_gp	db 33o,"[35m","It's dead Jim. X(",33o,"[37m",13,10,"$"

	; Rayman version strings
	ray121us	db "RAYMAN (US) v1.21"
	ray120de	db "RAYMAN (GERMAN) v1.20"
	ray112eu	db "RAYMAN (EU) v1.12"

	; Files that Rayman may look for on the CD
	filechecked1	db ":\rayman\rayman.exe",0
	filechecked2	db ":\config.exe",0
	; It checks for these at the beginning of Allegro Presto,
	; and if they're not there, it's like "Thank you for playing Rayman."
	; A cross between Rayman 2's pirate head and THEdragon's creepypasta...
	filechecked3	db ":\rayman\intro.dat",0
	filechecked4	db ":\rayman\conclu.dat",0
	; What to open instead
	filetocheck	db "NUL",0	; can always be opened!

	; Some stuff for a Real-Mode installation checker
	align		4
	old_rmint2f	dd ?
	instch_callstr	rmcall <?>

entry:	; Welcome the user, hook int 31h and go resident
	; Check if TPLS is already installed
	mov	ax,0CE00h + 'T'
	mov	bl,'P'
	mov	cl,'L'
	mov	dl,'S'
	int	2Fh
	cmp	al,'P'
	jne	welcome
	cmp	bl,'l'
	jne	welcome
	cmp	cl,'u'
	jne	welcome
	cmp	dl,'M'
	mov	edx,offset already
	je	failure

welcome:
	mov	edx,offset intro
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h

	mov	ax,0EE00h	; check DOS32 version
	int	31h
	mov	ah,dl
	cmp	ah,4
	mov	edx,offset vcpimode
	je	failure

	cmp	ah,8
	mov	edx,offset nodpmi
	jne	failure

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
	mov	ax,cs
	test	ax,3
	; No need to catch GP violations in Ring0, since debug registers are fully accessible.
	jz	noneed_gphandler

	; Install GP handler to prevent crashes due to interference with debug registers.
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

noneed_gphandler:
	mov	ax,0204h	; get interrupt vector
	mov	bl,31h
	int	31h
	mov	dword ptr [old_int31],edx
	mov	word ptr [old_int31+4],cx

	inc	ax		; set interrupt vector
	mov	cx,cs
	mov	edx,offset new_int31
	int	31h

	mov	ax,0204h	; get interrupt vector
	mov	bl,21h
	int	31h
	mov	dword ptr [dos32_int21],edx
	mov	word ptr [dos32_int21+4],cx

	inc	ax		; set interrupt vector
	mov	cx,cs
	mov	edx,offset int21_exithack
	int	31h

	mov	bl,0F5h		; our custom hook vector
	mov	edx,offset hook_handler
	int	31h

	; Install a Real-Mode installation checker on int 2Fh
	mov	ax,0200h	; get rm interrupt vector
	mov	bl,2Fh
	int	31h
	mov	[old_rmint2f],edx
	mov	word ptr [old_rmint2f+2],cx

	mov	ax,0303h	; allocate rm callback
	push	cs
	pop	ds
	mov	esi,offset instcheck
	mov	edi,offset instch_callstr
	int	31h
	push	es
	pop	ds
	jc	skip_tplsinstcheck	; we've come too far to abort completely...

	mov	ax,0201h	; set rm interrupt vector
	mov	bl,2Fh
	int	31h

skip_tplsinstcheck:
	mov	edx,offset savingvecs
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h

	mov	ax,0202h	; get exception handler
	mov	bl,1Fh
	mov	edi,offset saved_excvecs + 6*1Fh

save_excvec_loop:
	int	31h
	jc	save_intvecs	; exceptions not supported by this host...
	mov	[edi],edx
	mov	[edi+4],cx
	sub	edi,6
	dec	bl
	jns	save_excvec_loop

save_intvecs:
	mov	ax,0204h	; get interrupt handler
	xor	bl,bl
	mov	edi,offset saved_intvecs
	
save_intvec_loop:
	int	31h
	mov	[edi],edx
	mov	[edi+4],cx
	add	edi,6
	inc	bl
	jnz	save_intvec_loop

	mov	edx,offset tsrok
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	int	21h
	mov	ax,0EE30h	; terminate and stay resident (DOS32 call)
	int	31h

failure:
	mov	ah,9		; display message
	int	21h
	mov	ax,4CFFh	; exit with -1 code
	int	21h

; ===== RESIDENT CODE =====

; ==========================
; == INSTALLATION CHECKER ==
; == (Call from Real Mode)==
; ==========================
instcheck:
	; Check for AH = CEh (an application-reserved function not on RBrown's list)
	; And AL:BL:CL:DL = "TPLS"
	cmp	word ptr [es:edi+rmcall._eax],0CE00h+'T'
	jne	instcheck_passthrough
	cmp	byte ptr [es:edi+rmcall._ebx],'P'
	jne	instcheck_passthrough
	cmp	byte ptr [es:edi+rmcall._ecx],'L'
	jne	instcheck_passthrough
	cmp	byte ptr [es:edi+rmcall._edx],'S'
	jne	instcheck_passthrough

	; Output is AL:BL:CL:DL = "PluM", all upper bytes zeroed
	mov	[es:edi+rmcall._eax],'P'
	mov	[es:edi+rmcall._ebx],'l'
	mov	[es:edi+rmcall._ecx],'u'
	mov	[es:edi+rmcall._edx],'M'

	; Simulate an iret
	add	[es:edi+rmcall._sp],6
	lodsd	; copy dword from rm stack @ DS:ESI to rm call struct's CS:IP field @ ES:EDI
	jmp	instcheck_setretaddr

instcheck_passthrough:
	; Resume Real Mode execution at old int 2F vector
	mov	eax,[cs:old_rmint2f]
instcheck_setretaddr:
	mov	dword ptr [es:edi+rmcall._ip],eax
	iretd



; ======================
; == INT 21H HANDLERS ==
; ======================

; This handler gets installed when we start. Its purpose is to make sure
; Rayman (or any other DPMI app) cleans up after itself when it exits.
; It also blanks `raymanpsp`, to make sure that all our setup code gets
; re-run if Rayman happens to be started again at the same segment.
int21_exithack:
	cmp	ah,4Ch		; exit
	je	do_exithack
	jmp	cs:dos32_int21	; simple passthrough

do_exithack:
	push	ds
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi

	; if this is Rayman, then we need to forget his PSP
	; so when he runs again, we'll re-do all our setup
	mov	ds,[cs:mydatasel]
	xor	bx,bx
	call	get_psp
	jne	exithack_notrayman
	mov	[raymanpsp],bx

	; forget Rayman's CS base and limit too!
	xchg	bx,[rayman_cs_asds]
	mov	ax,1		; free LDT selector
	int	31h

exithack_notrayman:
	; restore exception vectors...
	mov	ax,0203h	; set exception handler
	mov	bl,1Fh
	mov	esi,offset saved_excvecs + 6*1Fh

restore_excvec_loop:
	mov	edx,[esi]
	mov	cx,[esi+4]
	int	31h
	jc	restore_intvecs	; exceptions not supported by this host...
	sub	esi,6
	dec	bl
	jns	restore_excvec_loop

restore_intvecs:
	; restore interrupt vectors...
	mov	ax,0205h	; set interrupt handler
	xor	bl,bl
	mov	esi,offset saved_intvecs
	
restore_intvec_loop:
	mov	edx,[esi]
	mov	cx,[esi+4]
	int	31h
	add	esi,6
	inc	bl
	jnz	restore_intvec_loop

	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	pop	ds
	jmp	cs:dos32_int21


; This handler gets installed for certain Rayman versions to hook file I/O
; and circumvent CD checks. This is the straightforward one.
new_int21:
	cmp	ah,3Dh		; open
	je	new_int21_open
	jmp	cs:old_int21

new_int21_open:
	push	ebp
	lea	ebp,[esp+4]	; convenient pointer to stack frame
	push	ecx

	mov	cx,[cs:rayman_cs]
	cmp	cx,[ebp+4]
	je	open_fromrayman
	
	pop	ecx
	pop	ebp
	jmp	cs:old_int21

open_fromrayman:
	push	esi
	push	edi

	mov	esi,edx		; the file path
	mov	edi,[cs:pcd_driveletter]
	cmpsb			; is it looking for a file on the CD?
	je	open_oncd

	pop	edi
	pop	esi
	pop	ecx
	pop	ebp
	jmp	cs:old_int21

open_oncd:
	push	es
	mov	es,[cs:mydatasel]

	push	esi
	mov	edi,offset filechecked1
	mov	ecx,sizeof filechecked1
	repe	cmpsb
	pop	esi
	je	open_spooffile

	push	esi
	mov	edi,offset filechecked2
	mov	ecx,sizeof filechecked2
	repe	cmpsb
	pop	esi
	je	open_spooffile

	push	esi
	mov	edi,offset filechecked3
	mov	ecx,sizeof filechecked3
	repe	cmpsb
	pop	esi
	je	open_redirectlocal	; can't redirect to NUL since it also checks the size!

	push	esi
	mov	edi,offset filechecked4
	mov	ecx,sizeof filechecked4
	repe	cmpsb
	pop	esi
	je	open_redirectlocal	; can't redirect to NUL since it also checks the size!

	; it's none of the files to spoof
	pop	es
	pop	edi
	pop	esi
	pop	ecx
	pop	ebp
	jmp	cs:old_int21

open_spooffile:
	; before spoofing, make sure the CD is actually suitable
	mov	edi,[es:plowest_atrack]
	cmp	byte ptr [ds:edi],2
	ja	cd_ng		; too many data tracks

	mov	edi,[es:phighest_atrack]
	cmp	byte ptr [ds:edi],51
	jb	cd_ng		; not enough audio tracks

	cmp	byte ptr [ds:edi],57
	push	ds
	push	edx
	mov	ds,[es:mydatasel]
	jnb	cd_ok		; flags set by CMP above

	; It doesn't have the extra intro/outtro tracks - warn the user.
	mov	edx,offset noextratracks
	push	eax
	mov	ah,9		; print message - safe to do this under DOS32 (and PMODE/W for that matter!)
	pushfd
	call	cs:old_int21
	pop	eax

cd_ok:
	mov	edx,offset filetocheck
	pushfd
	call	cs:old_int21
	; set carry as appropriate in the return flags
	setc	cl
	mov	ch,byte ptr [ebp+8]
	and	ch,0FEh		; clear carry
	or	ch,cl		; set carry if necessary
	mov	byte ptr [ebp+8],ch

	; return
	pop	edx
	pop	ds
	pop	es
	pop	edi
	pop	esi
	pop	ecx
	pop	ebp
	iretd

cd_ng:
	mov	ax,3		; pretend path not found
	or	[ebp+8],1	; set carry
	; return
	pop	es
	pop	edi
	pop	esi
	pop	ecx
	pop	ebp
	iretd

open_redirectlocal:
	; Redirect attempt to load a file in "X:\rayman\" to cwd.
	; (Where X is the CD drive letter).
	push	edx
	add	edx,10		; "X:\rayman\" is 10 characters

	pushfd
	call	cs:old_int21
	; set carry as appropriate in the return flags
	setc	cl
	mov	ch,byte ptr [ebp+8]
	and	ch,0FEh		; clear carry
	or	ch,cl		; set carry if necessary
	mov	byte ptr [ebp+8],ch

	; return
	pop	edx
	pop	es
	pop	edi
	pop	esi
	pop	ecx
	pop	ebp
	iretd

; =====================
; == INT 31H HANDLER ==
; =====================
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

; =============================================================================
; SUBROUTINE to check if we've been called from Rayman('s initialization screen)
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

; ===========
; SUBROUTINE
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

; ============================================================
; SUBROUTINE to write unknown version information to a logfile
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

; ===========
; SUBROUTINE:
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
	movzx	edx,[rayman_cs]
	lsl	ecx,edx			; get original segment's limit
	mov	dx,cx
	shr	ecx,16
	int	31h

	pop	edx
	pop	ecx
	pop	ebx
	pop	eax

poketext_segpresent:
	push	es
	mov	es,[rayman_cs_asds]
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

; ===========
; SUBROUTINE:
; int set_hookpoint@<ecx>(void *addx@<edx>)
; Sets a hookpoint for *execution* at the given addx in Rayman's *code* segment.
set_hookpoint:
	push	eax

	xor	eax,eax
	call	hook_find		; find a null hookpoint

	mov	eax,offset hook_addxs
	mov	[eax+ecx*4],edx		; set the address

	pop	eax
	call	hook_activate		; activate the new hookpoint!
	ret

; ===========
; SUBROUTINE:
; void clear_hookpoint(int idx@<ecx>)
clear_hookpoint:
	call	hook_deactivate		; first, make sure it's inactive!
	push	eax

	mov	eax,offset hook_addxs
	mov	dword ptr [eax+ecx*4],0

	pop	eax
	ret

; ========================================================
; == Chunk of INT 31H HANDLER dealing with MSCDEX calls ==
; ========================================================
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

	; Check for version 1.20 German
	mov	esi,offset ray120de
	mov	edi,offset entete_buf
	mov	ecx,sizeof ray120de
	repe	cmpsb
	je	setup_ptrs_v120de

	; Check for version 1.12 Europe
	mov	esi,offset ray112eu
	mov	edi,offset entete_buf
	mov	ecx,sizeof ray112eu
	repe	cmpsb
	je	setup_ptrs_v112eu

	; TODO: Check for other versions (maybe)
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
	mov	[ptimeCd],esi		; @ 0x4FBC in the data section
	lea	esi,[edi-(54E38h-3D85Ch)]
	mov	[pcdTime],esi		; @ 0x3D85C in the data section
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
	lea	esi,[edi-(54E38h-3FA27h)]
	mov	[pcd_driveletter],esi	; @ 0x3FA27 in the data section

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
	lea	esi,[edi-(79B9Dh-6B1A0h)]
	mov	[pDoGrowingPlat],esi	; @ 0x6B1A0 in the text section
	lea	esi,[edi-(79B9Dh-43D35h)]
	mov	[pMoskitoLock],esi	; @ 0x43D35 in the text section
	lea	esi,[edi-(79B9Dh-4AE94h)]
	mov	[pMoskitoFast],esi	; @ 0x4AE94 in the text section
	lea	esi,[edi-(79B9Dh-4AEBDh)]
	mov	[pMoskitoSlow],esi	; @ 0x4AEBD in the text section
	lea	esi,[edi-(79B9Dh-70F0h)]
	mov	[pLevelStart1],esi	; @ 0x70F0 in the text section
	lea	esi,[edi-(79B9Dh-77F6h)]
	mov	[pLevelStart2],esi	; @ 0x77F6 in the text section
	lea	esi,[edi-(79B9Dh-7697h)]
	mov	[pLevelEnd1],esi	; @ 0x7697 in the text section
	lea	esi,[edi-(79B9Dh-7CA6h)]
	mov	[pLevelEnd2],esi	; @ 0x7CA6 in the text section
	lea	esi,[edi-(79B9Dh-5234Fh)]
	mov	[pExitSign1],esi	; @ 0x5234F in the text section
	lea	esi,[edi-(79B9Dh-524ACh)]
	mov	[pExitSign2],esi	; @ 0x524AC in the text section
	lea	esi,[edi-(79B9Dh-0CF8Eh)]
	mov	[pPerdu],esi		; @ 0xCF8E in the text section
	lea	esi,[edi-(79B9Dh-1A710h)]
	mov	[pPlayTrack],esi	; @ 0x1A710 in the text section

	jmp	common_tracktable_setup

setup_ptrs_v120de:
	mov	edi,[pRM_call_struct]	; @ 0x185EC8
	lea	esi,[edi-(185EC8h-17091Ch)]
	mov	[pnum_world],esi	; @ 0x17091C
	lea	esi,[edi-(185EC8h-17090Ch)]
	mov	[pnum_level],esi	; @ 0x17090C
	lea	esi,[edi-(185EC8h-135F0Bh)]
	mov	[ptrack_table],esi	; @ 0x135F0B
	lea	esi,[edi-(185EC8h-135F8Ch)]
	mov	[ptimeCd],esi		; @ 0x135F8C
	lea	esi,[edi-(185EC8h-16E8ECh)]
	mov	[pcdTime],esi		; @ 0x16E8EC
	lea	esi,[edi-(185EC8h-17F957h)]
	mov	[prbook_table],esi	; @ 0x17F957
	lea	esi,[edi-(185EC8h-17FAEBh)]
	mov	[prbook_lentable],esi	; @ 0x17FAEB
	lea	esi,[edi-(185EC8h-17FF8Eh)]
	mov	[prbook_tablefl],esi	; @ 0x17FF8E
	lea	esi,[edi-(185EC8h-17F951h)]
	mov	[plowest_atrack],esi	; @ 0x17F951
	lea	esi,[edi-(185EC8h-17F952h)]
	mov	[phighest_atrack],esi	; @ 0x17F952
	lea	esi,[edi-(185EC8h-170AB7h)]
	mov	[pcd_driveletter],esi	; @ 0x170AB7
	lea	esi,[edi-(185EC8h-170AC5h)]
	mov	[plang],esi		; @ 0x170AC5

	mov	edi,[pInt31]		; @ 0x880C9
	lea	esi,[edi-(880C9h-1AED8h)]
	mov	[pCreditsTrackNo],esi	; @ 0x1AED8
	lea	esi,[edi-(880C9h-1AF00h)]
	mov	[pLogoTrackNo],esi	; @ 0x1AF00
	lea	esi,[edi-(880C9h-1AF80h)]
	mov	[pMenuTrackNo],esi	; @ 0x1AF80
	lea	esi,[edi-(880C9h-1AFA8h)]
	mov	[pGOverTrackNo],esi	; @ 0x1AFA8
	lea	esi,[edi-(880C9h-16521h)]
	mov	[pPlayIntro],esi	; @ 0x16521
	lea	esi,[edi-(880C9h-33805h)]
	mov	[pPlayOuttro],esi	; @ 0x33805
	lea	esi,[edi-(880C9h-28848h)]
	mov	[pTrackTabDone],esi	; @ 0x28848
	lea	esi,[edi-(880C9h-79650h)]
	mov	[pDoGrowingPlat],esi	; @ 0x79650
	lea	esi,[edi-(880C9h-51D45h)]
	mov	[pMoskitoLock],esi	; @ 0x51D45
	lea	esi,[edi-(880C9h-58EA4h)]
	mov	[pMoskitoFast],esi	; @ 0x58EA4
	lea	esi,[edi-(880C9h-58ECDh)]
	mov	[pMoskitoSlow],esi	; @ 0x58ECD
	lea	esi,[edi-(880C9h-14FF0h)]
	mov	[pLevelStart1],esi	; @ 0x14FF0
	lea	esi,[edi-(880C9h-156F6h)]
	mov	[pLevelStart2],esi	; @ 0x156F6
	lea	esi,[edi-(880C9h-15597h)]
	mov	[pLevelEnd1],esi	; @ 0x15597
	lea	esi,[edi-(880C9h-15BA6h)]
	mov	[pLevelEnd2],esi	; @ 0x15BA6
	lea	esi,[edi-(880C9h-6035Fh)]
	mov	[pExitSign1],esi	; @ 0x6035F
	lea	esi,[edi-(880C9h-604BCh)]
	mov	[pExitSign2],esi	; @ 0x604BC
	lea	esi,[edi-(880C9h-1AF1Eh)]
	mov	[pPerdu],esi		; @ 0x1AF1E
	lea	esi,[edi-(880C9h-28660h)]
	mov	[pPlayTrack],esi	; @ 0x28660

	jmp	common_filespoof_setup

setup_ptrs_v112eu:
	mov	edi,[pRM_call_struct]	; @ 0x185D28
	lea	esi,[edi-(185D28h-170770h)]
	mov	[pnum_world],esi	; @ 0x170770
	lea	esi,[edi-(185D28h-17075Eh)]
	mov	[pnum_level],esi	; @ 0x17075E
	lea	esi,[edi-(185D28h-135EF3h)]
	mov	[ptrack_table],esi	; @ 0x135EF3
	lea	esi,[edi-(185D28h-135F74h)]
	mov	[ptimeCd],esi		; @ 0x135F74
	lea	esi,[edi-(185D28h-16E744h)]
	mov	[pcdTime],esi		; @ 0x16E744
	lea	esi,[edi-(185D28h-17F7B7h)]
	mov	[prbook_table],esi	; @ 0x17F7B7
	lea	esi,[edi-(185D28h-17F94Bh)]
	mov	[prbook_lentable],esi	; @ 0x17F94B
	lea	esi,[edi-(185D28h-17FDEEh)]
	mov	[prbook_tablefl],esi	; @ 0x17FDEE
	lea	esi,[edi-(185D28h-17F7B1h)]
	mov	[plowest_atrack],esi	; @ 0x17F7B1
	lea	esi,[edi-(185D28h-17F7B2h)]
	mov	[phighest_atrack],esi	; @ 0x17F7B2
	lea	esi,[edi-(185D28h-17090Bh)]
	mov	[pcd_driveletter],esi	; @ 0x17090B
	lea	esi,[edi-(185D28h-170918h)]
	mov	[plang],esi		; @ 0x170918

	mov	edi,[pInt31]		; @ 0x872CD
	lea	esi,[edi-(872CDh-1ADA8h)]
	mov	[pCreditsTrackNo],esi	; @ 0x1ADA8
	lea	esi,[edi-(872CDh-1ADD0h)]
	mov	[pLogoTrackNo],esi	; @ 0x1ADD0
	lea	esi,[edi-(872CDh-1AE50h)]
	mov	[pMenuTrackNo],esi	; @ 0x1AE50
	lea	esi,[edi-(872CDh-1AE78h)]
	mov	[pGOverTrackNo],esi	; @ 0x1AE78
	lea	esi,[edi-(872CDh-1651Eh)]
	mov	[pIntroTrackNo],esi	; @ 0x1651E
	lea	esi,[edi-(872CDh-33546h)]
	mov	[pOuttroTrackNo],esi	; @ 0x33546
	lea	esi,[edi-(872CDh-285C0h)]
	mov	[pTrackTabDone],esi	; @ 0x285C0
	lea	esi,[edi-(872CDh-789E0h)]
	mov	[pDoGrowingPlat],esi	; @ 0x789E0
	lea	esi,[edi-(872CDh-51105h)]
	mov	[pMoskitoLock],esi	; @ 0x51105
	lea	esi,[edi-(872CDh-58264h)]
	mov	[pMoskitoFast],esi	; @ 0x58264
	lea	esi,[edi-(872CDh-5828Dh)]
	mov	[pMoskitoSlow],esi	; @ 0x5828D
	lea	esi,[edi-(872CDh-14FE0h)]
	mov	[pLevelStart1],esi	; @ 0x14FE0
	lea	esi,[edi-(872CDh-156E6h)]
	mov	[pLevelStart2],esi	; @ 0x156E6
	lea	esi,[edi-(872CDh-15587h)]
	mov	[pLevelEnd1],esi	; @ 0x15587
	lea	esi,[edi-(872CDh-15B96h)]
	mov	[pLevelEnd2],esi	; @ 0x15B96
	lea	esi,[edi-(872CDh-5F71Fh)]
	mov	[pExitSign1],esi	; @ 0x5F71F
	lea	esi,[edi-(872CDh-5F87Ch)]
	mov	[pExitSign2],esi	; @ 0x5F87C
	lea	esi,[edi-(872CDh-1ADEEh)]
	mov	[pPerdu],esi		; @ 0x1ADEE
	lea	esi,[edi-(872CDh-283D8h)]
	mov	[pPlayTrack],esi	; @ 0x283D8

	jmp	common_filespoof_setup

	; TODO: Pointer setup code for other versions

common_filespoof_setup:
	push	eax
	push	ebx
	push	edx
	mov	ax,0204h	; get interrupt vector
	mov	bl,21h
	int	31h
	mov	dword ptr [old_int21],edx
	mov	word ptr [old_int21+4],cx

	inc	ax		; set interrupt vector
	mov	cx,cs
	mov	edx,offset new_int21
	int	31h
	pop	edx
	pop	ebx
	pop	eax

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
	mov	al,38			; Washing Machine from Space
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

	mov	edx,[pIntroTrackNo]
	test	edx,edx
	jz	no_introtrackno
	mov	al,52
	call	poketext

	mov	edx,[pOuttroTrackNo]
	test	edx,edx
	jz	no_introtrackno
	mov	al,55
	call	poketext

no_introtrackno:
	; Now set a hook so we can fill in the lengths of these tracks
	; once the game has read them from the CD!
	push	ecx
	mov	edx,[pTrackTabDone]
	call	set_hookpoint

	; General hooks
	mov	edx,[pLevelStart1]
	call	set_hookpoint
	mov	edx,[pLevelStart2]
	call	set_hookpoint
	mov	edx,[pLevelEnd1]
	call	set_hookpoint
	mov	edx,[pLevelEnd2]
	call	set_hookpoint

	; Hooks to react to things in the game
	mov	edx,[pDoGrowingPlat]
	call	set_hookpoint
	mov	edx,[pMoskitoLock]
	call	set_hookpoint
	mov	edx,[pMoskitoFast]
	call	set_hookpoint
	mov	edx,[pMoskitoSlow]
	call	set_hookpoint

	; Hooks to make the PC version use CD audio where it normally doesn't
	; (but other versions normally do)
	; Actually, screw the exit-sign one. Not only does the fanfare always get
	; cut off for an actual exit sign, but it also gets engaged for certain
	; non-exit-sign events (e.g. beating Mister Sax, using the WINMAP cheat, etc.)
	; mov	edx,[pExitSign1]
	; call	set_hookpoint
	; mov	edx,[pExitSign2]
	; call	set_hookpoint
	mov	edx,[pPerdu]
	call	set_hookpoint

	; Hooks to select the language-appropriate cutscene music
	mov	edx,[pPlayIntro]
	test	edx,edx
	jz	no_introhook
	call	set_hookpoint
	mov	edx,[pPlayOuttro]
	test	edx,edx
	jz	no_introhook
	call	set_hookpoint

no_introhook:
	pop	ecx			; we don't need the hookpoints' indices for now...
	pop	ebx
	pop	edx
	pop	eax
	pop	edi
	jmp	passthrough

skipinstcheck:
	; Reactivate all hookpoints.
	; NB: Because this happens here, we need to make sure int 2Fh
	; never gets called from within the hookpoint handler!
	push	ecx
	push	eax
	push	es
	push	edi
	mov	di,ds
	mov	es,di

	mov	edi,(offset hook_origcode)-4
	mov	ecx,NUM_HOOKS
	std
	xor	eax,eax
hook_reac_loop:
	scasd				; check if there is a hookpoint with this idx
	loope	hook_reac_loop		; this decrements ECX!
	je	hook_reac_done		; if ECX and [ES:EDI] are both zero, we're finished
	call	hook_activate		; the loope instruction has made this the right idx for here...
	inc	ecx			; cancel the effect of the loope instruction before next iteration
	loop	hook_reac_loop
hook_reac_done:
	cld

	pop	edi
	pop	es
	pop	eax
	pop	ecx

passthrough:
	pushfd				; Bloody UASM generates 16-bit instructions if I don't include the 'd'!
	call	old_int31		; doesn't matter that we've the wrong DS, since service 0300h doesn't use DS anyway
mscdex_retpoint:
	pop	ds
	iretd				; Bloody UASM generates 16-bit instructions if I don't include the 'd'!

; ===========
; SUBROUTINE:
; bool hook_active(int idx@<ecx>);
; ZF clear if hookpoint is active, set if inactive
hook_active:
	push	edx
	mov	edx,offset hook_origcode
	cmp	word ptr [edx+ecx*2],0F5CDh
	pop	edx
	ret

; ===========
; SUBROUTINE:
; int hook_find@<ecx>(void *addx@<eax>);
; Finds and returns the index of the *last* hookpoint in the list
; corresponding to the given addx.
; If none, returns -1
hook_find:
	push	es
	push	edi
	mov	di,ds
	mov	es,di

	mov	edi,(offset hook_origcode)-4
	mov	ecx,NUM_HOOKS
	std
	repne	scasd
	je	hook_found
	or	ecx,-1

hook_found:
	cld
	pop	edi
	pop	es
	ret

; ===========
; SUBROUTINE:
; ushort hook_swapcode@<eax>(int idx@<ecx>);
; Swaps the word at the idx-th hookpoint in the text section
; with the word stored in the table
hook_swapcode:
	push	ebx
	push	edx

	mov	edx,offset hook_origcode
	mov	ax,[edx+ecx*2]
	mov	edx,offset hook_addxs
	mov	edx,[edx+ecx*4]
	mov	ebx,2			; poke a word

	call	poketext

	mov	edx,offset hook_origcode
	mov	[edx+ecx*2],ax		; store the word we just replaced

	pop	edx
	pop	ebx
	ret

; ===========
; SUBROUTINE:
; void hook_activate(int idx@<ecx>);
; Activates the idx-th hookpoint if it's inactive.
hook_activate:
	call	hook_active
	jnz	hook_activate_retp
	push	eax
	call	hook_swapcode
	pop	eax
hook_activate_retp:
	ret

; ===========
; SUBROUTINE:
; void hook_deactivate(int idx@<ecx>);
; Dectivates the idx-th hookpoint if it's active.
hook_deactivate:
	call	hook_active
	jz	hook_activate_retp
	push	eax
	call	hook_swapcode
	pop	eax
	ret

; ===========
; SUBROUTINE:
; void __fastcall change_music(char newtrack);
; Changes the music track (and corresponding length) for the current level and plays
change_music:
	push	edx
	push	ecx
	push	ebx

	mov	ecx,[pnum_world]
	mov	edx,[pnum_level]
	movzx	ecx,word ptr [es:ecx]
	dec	ecx

	mov	ebx,ecx
	shl	ebx,4			; EBX = (num_world - 1) * 16
	lea	ebx,[ebx+ecx*4]		; EBX = (num_world - 1) * 20
	lea	ebx,[ebx+ecx*2]		; EBX = (num_world - 1) * 22
	add	bx,[es:edx]		; EBX = (num_world - 1) * 22 + num_level

	mov	edx,[ptrack_table]
	mov	cl,al
	lea	edx,[edx+ebx]
	xchg	[es:edx],cl
	mov	[tra_to_restore],cl
	mov	[ptra_to_restore],edx

	movzx	ecx,al
	shl	ecx,2
	add	ecx,[prbook_lentable]
	push	eax
	mov	eax,[es:ecx]		; get the length of this track in sectors
	mov	ecx,75
	xor	edx,edx
	add	eax,74			; round up
	div	ecx			; convert sectors to seconds by dividing by 75

	mov	edx,[ptimeCd]
	mov	ecx,eax
	lea	edx,[edx+ebx*4]
	xchg	[es:edx],ecx
	mov	[len_to_restore],ecx
	mov	[plen_to_restore],edx

	; restart the CD music
	xor	ecx,ecx
	mov	eax,[pcdTime]
	mov	[es:eax],ecx

	pop	eax
	pop	ebx
	pop	ecx
	pop	edx
	ret

; =================================================
; == HANDLER for our hooking mechanism on int F5 ==
; =================================================
hook_handler:
	sub	dword ptr [esp],2	; rewind to before the int 0F5h instruction
	push	ebp
	lea	ebp,[esp+4]		; convenient pointer to stack frame
	push	ds			; this pushes a dword on the stack??
	mov	ds,[cs:mydatasel]	; our own data are of interest now!

	push	eax
	push	ecx
	mov	eax,[ebp]		; the return addx
	call	hook_find
	call	hook_deactivate

	cmp	eax,[pTrackTabDone]
	je	rbook_table_populated

	cmp	eax,[pLevelStart1]
	je	now_in_level
	cmp	eax,[pLevelStart2]
	je	now_in_level

	cmp	eax,[pLevelEnd1]
	je	no_longer_in_level
	cmp	eax,[pLevelEnd2]
	je	no_longer_in_level

	cmp	eax,[pDoGrowingPlat]
	je	plant_growing
	cmp	eax,[pMoskitoLock]
	je	moskito_fight
	cmp	eax,[pMoskitoFast]
	je	moskito_ride_speedup
	cmp	eax,[pMoskitoSlow]
	je	no_longer_in_level	; restore default music

	cmp	eax,[pExitSign1]
	je	yay_fanfare
	cmp	eax,[pExitSign2]
	je	yay_fanfare
	cmp	eax,[pPerdu]
	je	snif_dead

	cmp	eax,[pPlayIntro]
	je	cutscene
	cmp	eax,[pPlayOuttro]
	je	cutscene

	; Dunno what hookpoint that was then...
hook_retpoint:
	pop	ecx
	pop	eax
	pop	ds
	pop	ebp
	iretd

; Rayman has just populated its Redbook track tables.
; This means we can stop watching the flag, and
; that we can determine the lengths of the tracks.
rbook_table_populated:
	call	clear_hookpoint	; no need for this hookpoint anymore!

	push	esi
	push	edi
	push	edx
	push	ebx

	mov	esi,[ptrack_table]
	mov	edi,[ptimeCd]
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
	jmp	hook_retpoint

; Entering a level - restart the music if it's been tampered with...
now_in_level:
	xor	ecx,ecx
	cmp	[music_dirty],cl
	jz	hook_retpoint

	; It's been tampered with - reset
	mov	eax,[pcdTime]
	mov	[es:eax],ecx
	mov	[music_dirty],cl
	jmp	hook_retpoint

; Leaving a level - restore the default music track if needed, and mark as dirty.
no_longer_in_level:
	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jz	hook_retpoint

	; It's been tampered with - reset
	cmp	eax,[pMoskitoSlow]
	jne	delayed_reset

	; Immediately set cdTime to zero to signal the game to play the restored track
	mov	eax,[pcdTime]
	mov	[es:eax],ecx
	jmp	reset_decided

delayed_reset:
	mov	[music_dirty],1		; set dirty flag so the restored track will play on level reentry

reset_decided:
	xchg	[tra_to_restore],cl
	mov	eax,[ptra_to_restore]
	mov	[es:eax],cl		; restore the default track number

	mov	ecx,[len_to_restore]
	mov	eax,[plen_to_restore]
	mov	[es:eax],ecx		; restore the default track length

	jmp	hook_retpoint

; Rayman's planted a seed - we should switch the music to Suspense if it's not already.
; No need to check the world/level, since there's only one level in the whole game where this happens...
plant_growing:
	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jnz	hook_retpoint		; music already changed

	mov	al,10			; Suspense - The Flood
	call	change_music
	jmp	hook_retpoint

; A mosquito fight is about to begin so the screen has been locked
moskito_fight:
	mov	ecx,[pnum_level]
	cmp	word ptr [es:ecx],6
	jne	hook_retpoint		; it's not Anguish Lagoon

	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jnz	hook_retpoint		; music already changed

	mov	al,7			; Bzzit Attacks
	call	change_music
	jmp	hook_retpoint

; Rayman's riding a mosquito, who has just started going really fast - switch the music to "Hold on Tight!" if it's not already.
; No need to check the world/level, since there's only one level in the whole game where this happens...
moskito_ride_speedup:
	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jnz	hook_retpoint		; music already changed

	mov	al,6			; Hold on Tight!
	call	change_music
	jmp	hook_retpoint

; Rayman's reached the exit sign! Play a CD audio track to celebrate, like the PS1 and Saturn versions.
; TODO: Do we really want this? It's a nice idea in principle, but the game seems to stop the audio 
; before it has a chance to finish... We could probably do more hooks to stop that...
yay_fanfare:
	; Check whether we're returning to the same or lower privilege level
	mov	ax,cs
	mov	cx,[ebp+4]
	arpl	ax,cx

	; Before we diverge our paths, save a new return address in ECX.
	; These "exit sign" hookpoints occur at a call (5bytes) to a null sub, which can be skipped over.
	mov	ecx,[ebp]
	lea	ecx,[ecx+5]

	; We actually want to return directly to Rayman's function to play a CD audio track,
	; and invoke it with track 29 (Rayman's victory fanfare).
	mov	eax,[pPlayTrack]
	mov	[ebp],eax
	mov	eax,29			; Yeah!
	mov	[music_dirty],80h	; set fanfare flag
	jz	fanfare_privileged	; ZF set/cleared by ARPL above

	; OK, Rayman's at the same privilege level as us, so there's only one stack to worry about
	mov	[ebp+8],ecx		; replace EFLAGS with new return address - now this is a RETF frame instead of IRET!
	pop	ecx
	add	esp,4			; skip EAX on the stack (it's set to our track number!)
	pop	ds
	pop	ebp
	retf

fanfare_privileged:
	; Returning to an outer privilege level, which means we're on a different stack.
	sub	dword ptr [ebp+0Ch],4	; create a RETN frame on user-mode stack (user SS:ESP are at SS:EBP+0Ch)
	lds	ebp,[ebp+0Ch]
	mov	[ds:ebp],ecx		; put our new return address into this new stack frame

	; Now return by the usual route, but make sure EAX is set to our track number
	mov	[esp+4],eax
	jmp	hook_retpoint

; Rayman is dead :( Play a CD audio track, like the PS1 and Saturn versions
snif_dead:
	; We want to return directly to Rayman's function to play a CD audio track,
	; and invoke it with track 30 (Rayman's death cries).
	; Unlike for the fanfare, there's no need to mess with stacks.
	; This is because we're replacing a JMP instruction that hops straight into
	; "PlayTchatchVignette", and we're just redirecting to the CD audio function.
	mov	eax,[pPlayTrack]
	mov	[ebp],eax
	mov	dword ptr [esp+4],30	; EAX --> Perdu
	mov	[music_dirty],1		; set dirty flag to restart level music when Rayman respawns
	jmp	hook_retpoint

; Single-lang game version is about to play a cutscene - select the right music
cutscene:
	mov	ecx,[plang]
	mov	bl,[es:ecx]		; BL contains the track number passed to the cutscene function
	add	bl,52			; first intro track on custom CD image

	cmp	eax,[pPlayOuttro]
	jne	hook_retpoint
	add	bl,3			; add three more to get outtro track
	jmp	hook_retpoint

; == GP VIOLATION HANDLER ==
; Prevent interference with Debug Registers.
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
