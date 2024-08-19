; PluM's TPLS TSR - hybrid SOS-hooking version

; MIT License
; 
; Copyright (c) 2022, 2023 PluMGMK
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

.386
.MODEL  LARGE

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

IOCTLRW	struc			; IOCTL read/write request
	bLen	db ?		; 3 for read, 12 for write
	bUnit	db ?
	bCmd	db ?
	wStatus	dw ?
	_resd	dq ?
	_resd1	db ?		; media descriptor byte = 0 for MSCDEX
	wBufOff	dw ?
	wBufSeg	dw ?
	wCount	dw ?
	_resd2	dw ?		; starting sector number = 0 for MSCDEX
	_resd3	dd ?		; volume ID = 0 for MSCDEX
IOCTLRW	ends

PlayReq	struc
	bLen	db ?
	bUnit	db ?
	bCmd	db ?
	wStatus	dw ?
	_resd	dq ?
	bAMode	db ?		; addressing mode (RedBook / High Sierra)
	dwStart	dd ?		; first sector
	dwSectors dd ?
PlayReq	ends

AudioDiscInfo	struc
	function	db ?
	first_audtrack	db ?
	last_audtrack	db ?
	addr_leadout	dd ?
AudioDiscInfo	ends

AudioTrackInfo	struc
	function	db ?
	track_number	db ?
	starting_point	dd ?
	ctrl_info	db ?
AudioTrackInfo	ends

_SOS_DRV_FILEHEADER struc
	szName          db 32 dup(?)
	wDrivers        dd ?
	lOffset         dd ?
	lFileSize       dd ?
_SOS_DRV_FILEHEADER ends

_SOS_DRV_DRIVERHEADER struc
	szName          db 32 dup(?)
	lNextDriver     dd ?
	wSize           dd ?
	wDeviceID       dd ?
	wExtenderType   dd ?
_SOS_DRV_DRIVERHEADER ends

_SOS_START_SAMPLE struc
	lpSamplePtr		df ?
				dw ? ; padding
	dwSampleSize		dd ?
	wLoopCount		dw ?
				dw ? ; padding
	wChannel		dw ?
				dw ? ; padding
	wVolume			dw ?
				dw ? ; padding
	wSampleID		dw ?
				dw ? ; padding
	lpCallback		df ?
				dw ? ; padding
	wSamplePort		dw ?
				dw ? ; padding
	wSampleFlags		dw ?
				dw ? ; padding
	dwSampleByteLength	dd ?
	dwSampleLoopPoint	dd ?
	dwSampleLoopLength	dd ?
	dwSamplePitchAdd	dd ?
	wSamplePitchFraction	dw ?
				dw ? ; padding
	wSamplePanLocation	dw ?
				dw ? ; padding
	wSamplePanSpeed		dw ?
				dw ? ; padding
	wSamplePanDirection	dw ?
				dw ? ; padding
	wSamplePanStart		dw ?
				dw ? ; padding
	wSamplePanEnd		dw ?
				dw ? ; padding
	wSampleDelayBytes	dw ?
				dw ? ; padding
	wSampleDelayRepeat	dw ?
				dw ? ; padding
	dwSampleADPCMPredicted	dd ?
	wSampleADPCMIndex	dw ?
				dw ? ; padding
	wSampleRootNoteMIDI	dw ?
				dw ? ; padding
				dd ? ; padding
				dd ? ; padding
				dd ? ; padding
_SOS_START_SAMPLE ends

; values for wSampleFlags
_STEREOTOMONO	equ 10h
_TRANSLATE8TO16	equ 20h
_STAGE_LOOP	equ 40h
_TRANSLATE16TO8	equ 80h
_VOLUME		equ 100h
_PANNING	equ 200h
_PITCH_SHIFT	equ 400h
_CONTINUE_BLOCK	equ 800h
_PENDING_RELEASE equ 1000h
_FIRST_TIME	equ 2000h
_LOOPING	equ 4000h
_ACTIVE		equ 8000h

; structures specific to Rayman 1:
Rayman_LevelInfo struc
	pObjBase	dd ? ; pointer to an array of game objects
	wObjCount	dw ? ; how many objects?
Rayman_LevelInfo ends

; Based on https://github.com/BinarySerializer/BinarySerializer.Ray1/blob/6fb1b1142256877f3d5a74f0742a1a34b4f64b61/src/BinarySerializer.Ray1/DataTypes/Object/ObjData.cs
Rayman_ObjData struc
	SpritesPointer		dd ?
	AnimationsPointer	dd ?
	ImageBufferPointer	dd ?
	ETAPointer		dd ?
	RuntimeCommandsPointer	dd ?
	RuntimeLabelOffsetsPointer dd ?
	CommandContexts		dd ?
				dd ?
	IsLinked		dd ?
	IsActive		dd ?
	XPosition		dd ?
	YPosition		dd ?
	ActiveFlag		dd ?
	Index			dw ?
	ScreenXPosition		dw ?
	ScreenYPosition		dw ?
				dw ?
	InitialXPosition	dw ?
	InitialYPosition	dw ?
	SpeedX			dw ?
	SpeedY			dw ?
	SpritesCount		dw ?
	CurrentCommandOffset	dw ?
	CommandsCount		dw ?
				dw ?
	FollowY			dw ?
	FollowX			dw ?
	CMD_Arg1		dw ?
				dw ?
	RaymanDistance		dw ?
	IFramesTimer		dw ?
	TestBlockIndex		dw ?
	Scale			dw ?
	TypeZDC			dw ?
	ActiveTimer		dw ?
	ObjType			dw ?
	BlockTypes		db 5 dup(?)
				db ? ; padding
	OffBX			db ?
	OffBY			db ?
	RuntimeCurrentAnimIndex	db ?
	RuntimeCurrentAnimFrame	db ?
	SubEtat			db ?
	Etat			db ?
	InitialSubEtat		db ?
	InitialEtat		db ?
	CurrentCommand		db ?
	GravityValue1		db ?
	GravityValue2		db ?
	ChangeAnimationMode	db ?
	OffHY			db ?
	FollowSprite		db ?
	HitPoints		db ?
	InitialHitPoints	db ?
	InitFlag		db ?
	HitSprite		db ?
	DetectZone		db ?
	DetectZoneFlag		db ?
	CommandContextDepth	db ?
				db ?
	DisplayPrio		db ?
	Timer			db ?
	AnimationsCount		db ?
	PC_Flags		dw ?
				db ? ; padding
Rayman_ObjData ends
.errnz	size Rayman_ObjData - 84h

; values for ObjType
TYPE_BALLE1	equ 13	; a shot bullet ("always" object which we can replace)
TYPE_SPLASH	equ 19	; a splash ("always" object which we can replace)
TYPE_AUDIOSTART	equ 30	; starts a "MIDI" track - we hook it to make it work
TYPE_STONECHIP	equ 79	; lava ball piece ("always" object which we can replace)
TYPE_EXPLOSION	equ 83	; dust effect ("always" object which we can hopefully replace)
TYPE_POING	equ 94	; Rayman's fist (we use it to find PNG.ETA/DES pointers)
TYPE_BNOTE	equ 102	; teeny bad notes from Mister Sax's bombs ("always" object which we can replace)
TYPE_BB1_PLAT	equ 115	; a cloud created by Mister Stone's spark attack ("always" object which we can replace)
TYPE_NOVA2	equ 143	; item collected ("always" object which we can hopefully replace)
TYPE_PIEDS_RAYMAN equ 206 ; Rayman's feet (vestige of handstand move, unused in final game)

; our own struct:
InjectableAmbientStarter struc
	; level where it's injected:
	bWorld		db ?
	bLevel		db ?
	; location to inject it:
	wXPos		dw ?
	wYPos		dw ?
	; hitpoints (i.e. index of track to play)
	bHitPoints	db ?
	; which object type we can replace (this can be a byte since
	; Rayman 1 only uses types >255 for the Breakout game)
	bTypeToReplace	db ?
InjectableAmbientStarter ends

debug_bell	macro
	mov	ah,2	; write character
	mov	dl,7	; bell
	int	21h
endm

debug_bell_saveregs macro
	push	ax
	push	dx
	debug_bell
	pop	dx
	pop	ax
endm

; Real/VM86-Mode code, resident in Conventional Memory
stubdos	segment use16
sos_devid	dd 999		; default (invalid) value used by Rayman

LOGOTRACK	equ 12		; Ubi Soft logo track on original CD
LOGOTRACK_REDIR	equ 2		; Ubi Soft logo track on TPLS CD
logotrack_start	dd 0
logotrack_len	dd ?
logotrack_wrong	dd ?
MENUTRACK	equ 19		; menu track on original CD
MENUTRACK_REDIR	equ 33		; menu track on TPLS CD
menutrack_start	dd 0
menutrack_len	dd ?
menutrack_wrong	dd ?

FIRSTINTROTRACK	equ 53		; first intro track on TPLS CD (minus US intro)
NUMINTROTRACKS	equ 5		; English, French, German, Japanese, Chinese
FIRSTOUTROTRACK	equ FIRSTINTROTRACK + NUMINTROTRACKS

old_int21	label dword
old_int21_off	dw ?
old_int21_seg	dw ?

old_int2f	label dword
old_int2f_off	dw ?
old_int2f_seg	dw ?

callback2payload label dword
callback_off	dw ?
callback_seg	dw ?

; file headers for copying between original and spoofed HMIDRV files
hmidrv_hdr	_SOS_DRV_FILEHEADER <{?}>
hmidrv_drvhdr	_SOS_DRV_DRIVERHEADER <{?}>

; buffer for copying actual driver code
?LOG_BUFSIZE	equ 10	; 1 kiB should be plenty...
BUFSIZE		equ 1 SHL ?LOG_BUFSIZE
hmidrv_buffer	db BUFSIZE dup (?)

; Bit 0 = Payload in EMS
; Bit 1 = HMIDRV.386 redirect active
; Bit 2 = Other file redirects active (for DRM)
; Bit 3 = Payload active
; Bit 4 = Hookpoints dirty
; Bit 5 = EMS state saved
; Bit 6 = Running on Win9x
; Bit 7 = Spoof Copyright / Abstract / Bibliographic Filenames
; Bit 8 = Next Audio Disc Info Request should return spoofed data
; Bit 9 = Win9x int 31h handler should return immediately after calling RM int 2Fh
; Bit A = US Rayman version running
statusword	dw 0

emshdl		dw 0
pageframe	dw 0

first_cddrv	db 0
endof_cddrv	db 0
suitable_cddrv	db 0

hmidrv		db "hmidrv.386",0
fakehmidrv	db "tplsdrv.386",0

raycfg		db "rayman.cfg",0
ray1wld		db "pcmap\ray1.wld",0

; Files that Rayman may look for on the CD
raymanexe	db "\rayman\rayman.exe",0
configexe	db "\config.exe",0
; It checks for these at the beginning of Allegro Presto,
; and if they're not there, it's like "Thank you for playing Rayman."
; A cross between Rayman 2's pirate head and THEdragon's creepypasta...
introdat	db "\rayman\intro.dat",0
concludat	db "\rayman\conclu.dat",0
; What to open instead
fake_exes	db "NUL",0	; can always be opened!

rayman_banner	db 'R',1Eh,'A',1Eh,'Y',1Eh,'M',1Eh,'A',1Eh,'N',1Eh

; Warning / error messages
emserr		db 33o,"[35m","EMS error occurred. Unable to proceed with payload injection...",33o,"[37m",13,10,"$"
noextratracks	db 33o,"[35m","Warning: CD in drive "
noextratracks_letter db ?,": does not have intro/outtro tracks.",13,10
		db "Intro and/or outtro cutscenes may be silent!",33o,"[37m",13,10,"$"
wrongvolumelabel db 33o,"[35m","CD in drive "
wrongvolumelabel_letter db ?,": does not have volume label 'RAYMAN', not using.",13,10
		db "Note that this only matters for Rayman v1.00 and v1.10, so you can rectify this",13,10
		db "by playing a newer version, or by using the latest TPLS CD image (which should",13,10
		db "be correctly labelled).",33o,"[37m",13,10,"$"
badbioschecksums db 33o,"[35m","Your BIOS and/or Video BIOS checksum(s) do not match what is in RAY1.WLD,",13,10
		db "which means that the game will think it is being played on a different",13,10
		db "machine to the one it was originally installed on, and not work properly!",13,10
		db "To fix this, cd into the PCMAP folder and run FIXWLDS.EXE (comes with the TSR).",33o,"[37m",13,10,"$"
toomanydatatracks db 33o,"[35m","CD in drive "
toomanydatatracks_letter db ?,": has too many data tracks, not using.",33o,"[37m",13,10,"$"
notenoughaudiotracks db 33o,"[35m","CD in drive "
notenoughaudiotracks_letter db ?,": hasn't enough audio tracks, not using.",33o,"[37m",13,10,"$"
unkver		db 33o,"[35m","Unknown Rayman version. Not proceeding with payload injection...",33o,"[37m",13,10,"$"
payload_fail	db 33o,"[35m","Payload injection failed - could not read valid driver spec from config file,",13,10
		db "or could not find the driver in HMIDRV.386, or could not create TPLSDRV.386",33o,"[37m",13,10,"$"

; Rayman version strings
ray121us	db "RAYMAN (US) v1.21"
ray121fr	db "RAYMAN (FR) v1.21"
ray121ch	db "RAYMAN (CH) v1.21"
ray120jp	db "RAYMAN (JP) v1.20"
ray120uk	db "RAYMAN (UK) v1.20"
ray120de	db "RAYMAN (GERMAN) v1.20"
ray120itspdu	db "RAYMAN (IT-SP-DU) v1.20"
ray112us	db "RAYMAN (US) v1.12"
ray112eu	db "RAYMAN (EU) v1.12"
ray110eu	db "RAYMAN (EU) v1.10"
ray100		db "RAYMAN v1.00"

unprotected	db "(C) 1994-1995 UBI STUDIOS (UNPROTECTED), FRANCE"

; This is the audio disc info that Rayman v1.00 and v1.10 expect to get!
spoof_info	AudioDiscInfo<0Ah,1,25,?>

; Check if we've been called from Rayman's initialization screen
; CF set if yes, clear if no
chk_is_rayman	proc near	uses ds si es di
	push	cs
	pop	ds
	assume	ds:stub

	mov	si,0B800h	; Video BIOS text buffer
	mov	es,si

	mov	si,offset rayman_banner
	xor	di,di
	cld
	cmpsd
	jne	@@not_rayman
	cmpsd
	jne	@@not_rayman
	cmpsd
	jne	@@not_rayman

	; If we got this far, it's Rayman!
	stc
	ret

@@not_rayman:
	clc
	ret
	assume	ds:nothing
chk_is_rayman	endp

; Check if what's written at the top of the screen matches CX chars @ ES:DI
; If CX is negative, we check backwards from the right instead
; CF set if yes, clear if no
chk_entete	proc near	uses ax cx ds si es di
	mov	si,0B800h	; Video BIOS text buffer
	mov	ds,si

	test	cx,cx
	js	@@rtl

	xor	si,si
	cld
	jmp	@F
@@rtl:
	mov	si,0A0h-2	; Screen is 0x50 chars wide = 0xA0 bytes
	std
	neg	cx

@@:
	lodsw
	scasb
	loope	@B
	jne	@@no_match

	; If we got this far, it's a match!
	stc
	ret

@@no_match:
	clc
	ret
chk_entete	endp

; Map our payload into the page frame
; Returns status in CF, map location in AX
map_payload_seg	proc far	uses bx dx
	mov	ax,4400h; map logical page into first physical page
	xor	bx,bx	; first and only logical page in our handle
	mov	dx,cs:[emshdl]
	int	67h
	test	ah,ah
	jnz	@@failure

	mov	ax,cs:[pageframe]
	clc
	ret

@@failure:
	stc
	ret
map_payload_seg	endp

; Get the payload segment into GS
; CF set if an EMS error occurred
get_payload_seg	proc near	uses ax
	bt	cs:[statusword],0
	jc	@F

	mov	ax,payload
@@success:
	mov	gs,ax
	; CF should be clear here due to BT above, or JNC below
	ret

@@:
	bts	cs:[statusword],5
	jc	@F	; state already saved

	mov	ah,47h	; save page map
	push	dx
	mov	dx,cs:[emshdl]
	int	67h
	pop	dx
	test	ah,ah
	jz	@F

	btr	cs:[statusword],5	; sets CF
	ret

@@:
	call	map_payload_seg
	jnc	@@success

	call	restore_ems
	btr	cs:[statusword],5	; sets CF
	ret
get_payload_seg	endp

; restore the EMS state
; CF set according to status
restore_ems	proc near	uses ax dx
	mov	ah,48h	; restore page map
	mov	dx,cs:[emshdl]
	int	67h
	test	ah,ah	; clears CF
	jz	@F
	stc
@@:
	ret
restore_ems	endp

; Takes RedBook M:S:F address in EDX and returns HSG sector in EDX
redbook2hsg	proc near	uses ebx ecx
	mov	ebx,edx
	shr	ebx,10h	; EDX = minutes
	imul	ebx,ebx,60
	movzx	ecx,dh	; seconds
	add	ebx,ecx
	imul	ebx,ebx,75
	movzx	ecx,dl	; frames
	lea	edx,[ecx+ebx-150]
	ret
redbook2hsg	endp

; Assumes the correct drive number is in CX!
setup_music_redirect proc near	uses ax es bx edx edi
	mov	ax,1510h	; send driver request
	sub	sp,((size IOCTLRW) + 1) AND (NOT 1)
	mov	bx,sp
	push	ss
	pop	es		; ES:BX --> buffer on stack
	assume	es:nothing

	push	bp
	sub	sp,((size AudioTrackInfo) + 1) AND (NOT 1)
	mov	bp,sp

	mov	es:[bx.IOCTLRW.bLen],size IOCTLRW
	mov	es:[bx.IOCTLRW.bUnit],0
	mov	es:[bx.IOCTLRW.bCmd],3		; IOCTL read
	mov	es:[bx.IOCTLRW.wBufSeg],ss
	mov	es:[bx.IOCTLRW.wBufOff],bp	; another stack buffer
	mov	es:[bx.IOCTLRW.wCount],size AudioTrackInfo

	mov	[bp.AudioTrackInfo.function],0Bh; audio track info
	mov	[bp.AudioTrackInfo.track_number],LOGOTRACK
	call	do_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[logotrack_wrong],edx

	mov	[bp.AudioTrackInfo.track_number],LOGOTRACK_REDIR
	call	do_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[logotrack_start],edx
	call	redbook2hsg
	mov	edi,edx

	mov	[bp.AudioTrackInfo.track_number],LOGOTRACK_REDIR+1
	call	do_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	call	redbook2hsg
	sub	edx,edi
	mov	cs:[logotrack_len],edx

	mov	[bp.AudioTrackInfo.track_number],MENUTRACK
	call	do_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[menutrack_wrong],edx

	mov	[bp.AudioTrackInfo.track_number],MENUTRACK_REDIR
	call	do_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[menutrack_start],edx
	call	redbook2hsg
	mov	edi,edx

	mov	[bp.AudioTrackInfo.track_number],MENUTRACK_REDIR+1
	call	do_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	call	redbook2hsg
	sub	edx,edi
	mov	cs:[menutrack_len],edx

	add	sp,((size AudioTrackInfo) + 1) AND (NOT 1)
	pop	bp
	add	sp,((size IOCTLRW) + 1) AND (NOT 1)
	ret
setup_music_redirect endp

; Helper function for setup_music_redirect:
; This calls through to the real MSCDEX handler.
; In normal DOS, this is further up the interrupt chain, so we do a far call.
; In Windows 9x, it's a protected mode handler, so we have to invoke the interrupt again.
do_int2f	proc near
	bt	cs:[statusword],6	; Windows 9x
	jc	@F

	pushf
	call	old_int2f
	ret

@@:
	clc	; since, for AX=1510h, "Windows95 sets CF if CX isn't a
		; CD-ROM drive but leaves CF unchanged if the drive is
		; in fact a CD-ROM" (I can confirm this is also true for 98,
		; so it is probably also true for Me.)
	int	2Fh
	ret
do_int2f	endp

; Check if a PlayReq in ES:BX is pointing at an incorrect track for logo / menu music, and redirect
chk_music_redirect proc near	uses eax
	cmp	cs:[logotrack_start],0
	jnz	@F
	call	setup_music_redirect

@@:
	cmp	es:[bx.PlayReq.bAMode],1
	jne	@@retpoint	; Rayman only uses Redbook

	mov	eax,es:[bx.PlayReq.dwStart]
	cmp	eax,cs:[logotrack_wrong]
	jne	@F

	mov	eax,cs:[logotrack_start]
	mov	es:[bx.PlayReq.dwStart],eax
	mov	eax,cs:[logotrack_len]
	mov	es:[bx.PlayReq.dwSectors],eax
	jmp	@@retpoint

@@:
	cmp	eax,cs:[menutrack_wrong]
	jne	@@retpoint

	mov	eax,cs:[menutrack_start]
	mov	es:[bx.PlayReq.dwStart],eax
	mov	eax,cs:[menutrack_len]
	mov	es:[bx.PlayReq.dwSectors],eax

@@retpoint:
	ret
chk_music_redirect endp

setup_payload	proc near	uses gs ds dx es edi eax cx bx si
	call	get_payload_seg
	mov	dx,offset emserr
	jc	@@earlyfail
	assume	gs:payload

	; clean out the pointers in case there's anything stale from a previous run
	xor	eax,eax
	push	gs
	pop	es
	assume	es:payload

	mov	edi,offset psosDRVInit_ret + 4
	mov	cx,(end_textptrs - (psosDRVInit_ret + 4)) SHR 2
	rep	stosd

	mov	edi,offset psos_InitStruct + 4
	mov	cx,(end_dataptrs - (psos_InitStruct + 4)) SHR 2
	rep	stosd

	push	cs
	pop	es
	push	cs
	pop	ds
	assume	ds:stub,es:stub

	mov	di,offset ray121us
	mov	cx,sizeof ray121us
	call	chk_entete
	jc	@@setup_ptrs_v121us

	mov	di,offset ray121fr
	mov	cx,sizeof ray121fr
	call	chk_entete
	jc	@@setup_ptrs_v121fr

	mov	di,offset ray121ch
	mov	cx,sizeof ray121ch
	call	chk_entete
	jc	@@setup_ptrs_v121ch

	mov	di,offset ray112us
	mov	cx,sizeof ray112us
	call	chk_entete
	jc	@@setup_ptrs_v112us

	mov	di,offset ray120jp
	mov	cx,sizeof ray120jp
	call	chk_entete
	jc	@@setup_ptrs_v120jp

	mov	di,offset ray120uk
	mov	cx,sizeof ray120uk
	call	chk_entete
	jc	@@setup_ptrs_v120uk

	mov	di,offset ray120de
	mov	cx,sizeof ray120de
	call	chk_entete
	jc	@@setup_ptrs_v120de

	mov	di,offset ray112eu
	mov	cx,sizeof ray112eu
	call	chk_entete
	jc	@@setup_ptrs_v112eu

	mov	di,offset ray110eu
	mov	cx,sizeof ray110eu
	call	chk_entete
	jc	@@setup_ptrs_v110eu

	mov	di,offset ray100
	mov	cx,sizeof ray100
	call	chk_entete
	jc	@@setup_ptrs_v100

	mov	di,offset ray120itspdu
	mov	cx,sizeof ray120itspdu
	call	chk_entete
	jc	@@setup_ptrs_v120itspdu

	mov	dx,offset unkver
@@earlyfail:
	mov	ah,9	; write to stdout
	pushf
	call	old_int21

	stc
	jmp	@@retpoint

@@setup_ptrs_v121us:
	bts	cs:[statusword],0Ah			; indicate US version

	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x6664 in this version
	mov	gs:[pnum_world],(3F88Ch-6664h)		; @ 0x3F88C in the data section
	mov	gs:[pnum_level],(3F87Ch-6664h)		; @ 0x3F87C in the data section
	mov	gs:[ptrack_table],(4F3Bh-6664h)		; @ 0x4F3B in the data section
	mov	gs:[ptimeCd],(4FBCh-6664h)		; @ 0x4FBC in the data section
	mov	gs:[pcdTime],(3D85Ch-6664h)		; @ 0x3D85C in the data section
	; mov	gs:[prbook_table],(4E8C7h-6664h)	; @ 0x4E8C7 in the data section
	mov	gs:[prbook_lentable],(4EA5Bh-6664h)	; @ 0x4EA5B in the data section
	; mov	gs:[prbook_tablefl],(4EEFEh-6664h)	; @ 0x4EEFE in the data section
	; mov	gs:[plowest_atrack],(4E8C1h-6664h)	; @ 0x4E8C1 in the data section
	; mov	gs:[phighest_atrack],(4E8C2h-6664h)	; @ 0x4E8C2 in the data section
	; mov	gs:[pcd_driveletter],(3FA27h-6664h)	; @ 0x3FA27 in the data section
	mov	gs:[plang],(3FA35h-6664h)		; @ 0x3FA35 in the data section
	mov	gs:[pdwDETDriverIndex],(50B78h-6664h)	; @ 0x50B78 in the data section
	mov	gs:[plevel],(3CDF0h-6664h)		; @ 0x3CDF0 in the data section
	mov	gs:[pflagCDPlay],(7F78h-6664h)		; @ 0x7F78 in the data section

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x73D6D in this version
	mov	gs:[pCreditsTrackNo],(0CF48h-73D6Dh)	; @ 0xCF48 in the text section
	mov	gs:[pLogoTrackNo],(0CF70h-73D6Dh)	; @ 0xCF70 in the text section
	mov	gs:[pMenuTrackNo],(0CFF0h-73D6Dh)	; @ 0xCFF0 in the text section
	mov	gs:[pGOverTrackNo],(0D018h-73D6Dh)	; @ 0xD018 in the text section
	mov	gs:[pPlayIntro],(8594h-73D6Dh)		; @ 0x8594 in the text section
	mov	gs:[pPlayOuttro],(258B5h-73D6Dh)	; @ 0x258B5 in the text section
	mov	gs:[pDoGrowingPlat],(6B1A0h-73D6Dh)	; @ 0x6B1A0 in the text section
	mov	gs:[pMoskitoLock],(43D35h-73D6Dh)	; @ 0x43D35 in the text section
	mov	gs:[pMoskitoFast],(4AE94h-73D6Dh)	; @ 0x4AE94 in the text section
	mov	gs:[pMoskitoSlow],(4AEBDh-73D6Dh)	; @ 0x4AEBD in the text section
	mov	gs:[pLevelStart1],(70F0h-73D6Dh)	; @ 0x70F0 in the text section
	mov	gs:[pLevelStart2],(77F6h-73D6Dh)	; @ 0x77F6 in the text section
	mov	gs:[pLevelEnd1],(7697h-73D6Dh)		; @ 0x7697 in the text section
	mov	gs:[pLevelEnd2],(7CA6h-73D6Dh)		; @ 0x7CA6 in the text section
	mov	gs:[pExitSign1],(52228h-73D6Dh)		; @ 0x52228 in the text section
	mov	gs:[pExitSign2],(524ACh-73D6Dh)		; @ 0x524AC in the text section
	mov	gs:[pPerdu],(0CF8Eh-73D6Dh)		; @ 0xCF8E in the text section
	mov	gs:[pPlayTrack],(1A710h-73D6Dh)		; @ 0x1A710 in the text section
	mov	gs:[pCutsceneRead],(2A55Ch-73D6Dh)	; @ 0x2A55C in the text section
	mov	gs:[pConvenientRetF],(71330h-73D6Dh)	; @ 0x71330 in the text section
	mov	gs:[psosDIGIStart],(743F7h-73D6Dh)	; @ 0x743F7 in the text section
	mov	gs:[psosDIGIStop],(74A10h-73D6Dh)	; @ 0x74A10 in the text section
	mov	gs:[pStartVignette],(26E60h-73D6Dh)	; @ 0x26E60 in the text section
	mov	gs:[pObjectsLoaded],(36054h-73D6Dh)	; @ 0x36054 in the text section
	mov	gs:[pManageSndEvent],(61C00h-73D6Dh)	; @ 0x61C00 in the text section
	mov	gs:[pStartCDbbdead],(628DFh-73D6Dh)	; @ 0x628DF in the text section
	mov	gs:[pStopCD],(0D028h-73D6Dh)		; @ 0xD028 in the text section
	mov	gs:[pStartFreezeSnd],(63164h-73D6Dh)	; @ 0x63164 in the text section
	mov	gs:[pStopFreezeSnd],(63178h-73D6Dh)	; @ 0x63178 in the text section
	mov	gs:[pExitSignEOA1],(5238Fh-73D6Dh)	; @ 0x5238F in the text section
	mov	gs:[pExitSignEOA2],(523E2h-73D6Dh)	; @ 0x523E2 in the text section
	mov	gs:[pExitSignEOA3],(524E5h-73D6Dh)	; @ 0x524E5 in the text section
	mov	gs:[pDoAnimFrozen],(4B6A5h-73D6Dh)	; @ 0x4B6A5 in the text section

	jmp	@@payload_fixedup

@@setup_ptrs_v121fr:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137664 in this version
	mov	gs:[pnum_world],(17088Ch-137664h)	; @ 0x17088C
	mov	gs:[pnum_level],(17087Ch-137664h)	; @ 0x17087C
	mov	gs:[ptrack_table],(135F3Bh-137664h)	; @ 0x135F3B
	mov	gs:[ptimeCd],(135FBCh-137664h)		; @ 0x135FBC
	mov	gs:[pcdTime],(16E85Ch-137664h)		; @ 0x16E85C
	; mov	gs:[prbook_table],(17F8C7h-137664h)	; @ 0x17F8C7
	mov	gs:[prbook_lentable],(17FA5Bh-137664h)	; @ 0x17FA5B
	; mov	gs:[prbook_tablefl],(17FEFEh-137664h)	; @ 0x18011E
	; mov	gs:[plowest_atrack],(17F8C1h-137664h)	; @ 0x17F8C1
	; mov	gs:[phighest_atrack],(17F8C2h-137664h)	; @ 0x17F8C2
	; mov	gs:[pcd_driveletter],(170A27h-137664h)	; @ 0x170A27
	mov	gs:[plang],(170A35h-137664h)		; @ 0x170A35
	mov	gs:[pdwDETDriverIndex],(181B78h-137664h); @ 0x181B78
	mov	gs:[plevel],(16DDF0h-137664h)		; @ 0x16DDF0
	mov	gs:[pflagCDPlay],(138F78h-137664h)	; @ 0x138F78

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81D8D in this version
	mov	gs:[pCreditsTrackNo],(1AF48h-81D8Dh)	; @ 0x1AF48
	mov	gs:[pLogoTrackNo],(1AF70h-81D8Dh)	; @ 0x1AF70
	mov	gs:[pMenuTrackNo],(1AFF0h-81D8Dh)	; @ 0x1AFF0
	mov	gs:[pGOverTrackNo],(1B018h-81D8Dh)	; @ 0x1B018
	mov	gs:[pPlayIntro],(16594h-81D8Dh)		; @ 0x16594
	mov	gs:[pPlayOuttro],(338B5h-81D8Dh)	; @ 0x33805
	mov	gs:[pDoGrowingPlat],(791C0h-81D8Dh)	; @ 0x791C0
	mov	gs:[pMoskitoLock],(51D55h-81D8Dh)	; @ 0x51D55
	mov	gs:[pMoskitoFast],(58EB4h-81D8Dh)	; @ 0x58EB4
	mov	gs:[pMoskitoSlow],(58EDDh-81D8Dh)	; @ 0x58EDD
	mov	gs:[pLevelStart1],(150F0h-81D8Dh)	; @ 0x150F0
	mov	gs:[pLevelStart2],(157F6h-81D8Dh)	; @ 0x157F6
	mov	gs:[pLevelEnd1],(15697h-81D8Dh)		; @ 0x15697
	mov	gs:[pLevelEnd2],(15CA6h-81D8Dh)		; @ 0x15CA6
	mov	gs:[pExitSign1],(60248h-81D8Dh)		; @ 0x60248
	mov	gs:[pExitSign2],(604CCh-81D8Dh)		; @ 0x604CC
	mov	gs:[pPerdu],(1AF8Eh-81D8Dh)		; @ 0x1AF8E
	mov	gs:[pPlayTrack],(28710h-81D8Dh)		; @ 0x28710
	mov	gs:[pConvenientRetF],(7F350h-81D8Dh)	; @ 0x7F350
	mov	gs:[psosDIGIStart],(82417h-81D8Dh)	; @ 0x82417
	mov	gs:[psosDIGIStop],(82A30h-81D8Dh)	; @ 0x82A30
	mov	gs:[pStartVignette],(34E60h-81D8Dh)	; @ 0x34E60
	mov	gs:[pObjectsLoaded],(44064h-81D8Dh)	; @ 0x44064
	mov	gs:[pManageSndEvent],(6FC20h-81D8Dh)	; @ 0x6FC20
	mov	gs:[pStartCDbbdead],(708FFh-81D8Dh)	; @ 0x708FF
	mov	gs:[pStopCD],(1B028h-81D8Dh)		; @ 0x1B028
	mov	gs:[pStartFreezeSnd],(71184h-81D8Dh)	; @ 0x71184
	mov	gs:[pStopFreezeSnd],(71198h-81D8Dh)	; @ 0x71198
	mov	gs:[pExitSignEOA1],(603AFh-81D8Dh)	; @ 0x603AF
	mov	gs:[pExitSignEOA2],(60402h-81D8Dh)	; @ 0x60402
	mov	gs:[pExitSignEOA3],(60505h-81D8Dh)	; @ 0x60505
	mov	gs:[pDoAnimFrozen],(596C5h-81D8Dh)	; @ 0x596C5

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v121ch:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137694 in this version
	mov	gs:[pnum_world],(170AA4h-137694h)	; @ 0x170AA4
	mov	gs:[pnum_level],(170A94h-137694h)	; @ 0x170A94
	mov	gs:[ptrack_table],(135F3Bh-137694h)	; @ 0x135F3B
	mov	gs:[ptimeCd],(135FBCh-137694h)		; @ 0x135FBC
	mov	gs:[pcdTime],(16EA74h-137694h)		; @ 0x16EA74
	; mov	gs:[prbook_table],(17FAE7h-137694h)	; @ 0x17FAE7
	mov	gs:[prbook_lentable],(17FC7Bh-137694h)	; @ 0x17FC7B
	; mov	gs:[prbook_tablefl],(18011Eh-137694h)	; @ 0x18011E
	; mov	gs:[plowest_atrack],(17FAE1h-137694h)	; @ 0x17FAE1
	; mov	gs:[phighest_atrack],(17FAE2h-137694h)	; @ 0x17FAE2
	; mov	gs:[pcd_driveletter],(170C3Fh-137694h)	; @ 0x170C3F
	mov	gs:[plang],(170C4Eh-137694h)		; @ 0x170C4E
	mov	gs:[pdwDETDriverIndex],(181D98h-137694h); @ 0x181D98
	mov	gs:[plevel],(16DFF0h-137694h)		; @ 0x16DFF0
	mov	gs:[pflagCDPlay],(138FA8h-137694h)	; @ 0x138FA8

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x8169D in this version
	mov	gs:[pCreditsTrackNo],(1AF48h-8169Dh)	; @ 0x1AF48
	mov	gs:[pLogoTrackNo],(1AF70h-8169Dh)	; @ 0x1AF70
	mov	gs:[pMenuTrackNo],(1AFF0h-8169Dh)	; @ 0x1AFF0
	mov	gs:[pGOverTrackNo],(1B018h-8169Dh)	; @ 0x1B018
	mov	gs:[pPlayIntro],(16594h-8169Dh)		; @ 0x16594
	mov	gs:[pPlayOuttro],(336BDh-8169Dh)	; @ 0x336BD
	mov	gs:[pDoGrowingPlat],(78AD0h-8169Dh)	; @ 0x78AD0
	mov	gs:[pMoskitoLock],(51D45h-8169Dh)	; @ 0x51D45
	mov	gs:[pMoskitoFast],(58EA4h-8169Dh)	; @ 0x58EA4
	mov	gs:[pMoskitoSlow],(58ECDh-8169Dh)	; @ 0x58ECD
	mov	gs:[pLevelStart1],(150F0h-8169Dh)	; @ 0x150F0
	mov	gs:[pLevelStart2],(157F6h-8169Dh)	; @ 0x157F6
	mov	gs:[pLevelEnd1],(15697h-8169Dh)		; @ 0x15697
	mov	gs:[pLevelEnd2],(15CA6h-8169Dh)		; @ 0x15CA6
	mov	gs:[pExitSign1],(6023Dh-8169Dh)		; @ 0x6023D
	mov	gs:[pExitSign2],(604BCh-8169Dh)		; @ 0x604BC
	mov	gs:[pPerdu],(1AF8Eh-8169Dh)		; @ 0x1AF8E
	mov	gs:[pPlayTrack],(28710h-8169Dh)		; @ 0x28710
	mov	gs:[pConvenientRetF],(7EC60h-8169Dh)	; @ 0x7EC60
	mov	gs:[psosDIGIStart],(81D27h-8169Dh)	; @ 0x81D27
	mov	gs:[psosDIGIStop],(82340h-8169Dh)	; @ 0x82340
	mov	gs:[pStartVignette],(34C70h-8169Dh)	; @ 0x34C70
	mov	gs:[pObjectsLoaded],(43E54h-8169Dh)	; @ 0x43E54
	mov	gs:[pManageSndEvent],(6F530h-8169Dh)	; @ 0x6F530
	mov	gs:[pStartCDbbdead],(7020Fh-8169Dh)	; @ 0x7020F
	mov	gs:[pStopCD],(1B028h-8169Dh)		; @ 0x1B028
	mov	gs:[pStartFreezeSnd],(70A94h-8169Dh)	; @ 0x70A94
	mov	gs:[pStopFreezeSnd],(70AA8h-8169Dh)	; @ 0x70AA8
	mov	gs:[pExitSignEOA1],(6039Fh-8169Dh)	; @ 0x6039F
	mov	gs:[pExitSignEOA2],(603F2h-8169Dh)	; @ 0x603F2
	mov	gs:[pExitSignEOA3],(604F5h-8169Dh)	; @ 0x604F5
	mov	gs:[pDoAnimFrozen],(596B5h-8169Dh)	; @ 0x596B5

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v120itspdu:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(17091Ch-137634h)	; @ 0x17091C
	mov	gs:[pnum_level],(17090Ch-137634h)	; @ 0x17090C
	mov	gs:[ptrack_table],(135F0Bh-137634h)	; @ 0x135F0B
	mov	gs:[ptimeCd],(135F8Ch-137634h)		; @ 0x135F8C
	mov	gs:[pcdTime],(16E8ECh-137634h)		; @ 0x16E8EC
	; mov	gs:[prbook_table],(17F957h-137634h)	; @ 0x17F957
	mov	gs:[prbook_lentable],(17FAEBh-137634h)	; @ 0x17FAEB
	; mov	gs:[prbook_tablefl],(17FF8Eh-137634h)	; @ 0x17FF8E
	; mov	gs:[plowest_atrack],(17F951h-137634h)	; @ 0x17F951
	; mov	gs:[phighest_atrack],(17F952h-137634h)	; @ 0x17F952
	; mov	gs:[pcd_driveletter],(170AB7h-137634h)	; @ 0x170AB7
	mov	gs:[plang],(170AC5h-137634h)		; @ 0x170AC5

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x821FF in this version
	mov	gs:[pCreditsTrackNo],(1AED8h-821FFh)	; @ 0x1AED8
	mov	gs:[pLogoTrackNo],(1AF00h-821FFh)	; @ 0x1AF00
	mov	gs:[pMenuTrackNo],(1AF80h-821FFh)	; @ 0x1AF80
	mov	gs:[pGOverTrackNo],(1AFA8h-821FFh)	; @ 0x1AFA8
	mov	gs:[pPlayIntro],(16521h-821FFh)		; @ 0x16521
	mov	gs:[pPlayOuttro],(33805h-821FFh)	; @ 0x33805
	mov	gs:[pDoGrowingPlat],(79640h-821FFh)	; @ 0x79640
	mov	gs:[pMoskitoLock],(51D35h-821FFh)	; @ 0x51D35
	mov	gs:[pMoskitoFast],(58E94h-821FFh)	; @ 0x58E94
	mov	gs:[pMoskitoSlow],(58EBDh-821FFh)	; @ 0x58EBD
	mov	gs:[pLevelStart1],(14FF0h-821FFh)	; @ 0x14FF0
	mov	gs:[pLevelStart2],(156F6h-821FFh)	; @ 0x156F6
	mov	gs:[pLevelEnd1],(15597h-821FFh)		; @ 0x15597
	mov	gs:[pLevelEnd2],(15BA6h-821FFh)		; @ 0x15BA6
	mov	gs:[pExitSign1],(6034Fh-821FFh)		; @ 0x6034F
	mov	gs:[pExitSign2],(604ACh-821FFh)		; @ 0x604AC
	mov	gs:[pPerdu],(1AF1Eh-821FFh)		; @ 0x1AF1E
	mov	gs:[pPlayTrack],(28660h-821FFh)		; @ 0x28660

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v120jp:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(17091Ch-137634h)	; @ 0x17091C
	mov	gs:[pnum_level],(17090Ch-137634h)	; @ 0x17090C
	mov	gs:[ptrack_table],(135EFFh-137634h)	; @ 0x135EFF
	mov	gs:[ptimeCd],(135F80h-137634h)		; @ 0x135F80
	mov	gs:[pcdTime],(16E8ECh-137634h)		; @ 0x16E8EC
	; mov	gs:[prbook_table],(17F957h-137634h)	; @ 0x17F957
	mov	gs:[prbook_lentable],(17FAEBh-137634h)	; @ 0x17FAEB
	; mov	gs:[prbook_tablefl],(17FF8Eh-137634h)	; @ 0x17FF8E
	; mov	gs:[plowest_atrack],(17F951h-137634h)	; @ 0x17F951
	; mov	gs:[phighest_atrack],(17F952h-137634h)	; @ 0x17F952
	; mov	gs:[pcd_driveletter],(170AB7h-137634h)	; @ 0x170AB7
	mov	gs:[plang],(170AC5h-137634h)		; @ 0x170AC5

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81EB9 in this version
	mov	gs:[pCreditsTrackNo],(1AEC8h-81EB9h)	; @ 0x1AEC8
	mov	gs:[pLogoTrackNo],(1AEF0h-81EB9h)	; @ 0x1AEF0
	mov	gs:[pMenuTrackNo],(1AF70h-81EB9h)	; @ 0x1AF70
	mov	gs:[pGOverTrackNo],(1AF98h-81EB9h)	; @ 0x1AF98
	mov	gs:[pPlayIntro],(16511h-81EB9h)		; @ 0x16511
	mov	gs:[pPlayOuttro],(33B3Dh-81EB9h)	; @ 0x33B3D
	mov	gs:[pDoGrowingPlat],(792B0h-81EB9h)	; @ 0x792B0
	mov	gs:[pMoskitoLock],(52225h-81EB9h)	; @ 0x52225
	mov	gs:[pMoskitoFast],(59384h-81EB9h)	; @ 0x59384
	mov	gs:[pMoskitoSlow],(593ADh-81EB9h)	; @ 0x593AD
	mov	gs:[pLevelStart1],(14FD0h-81EB9h)	; @ 0x14FD0
	mov	gs:[pLevelStart2],(156E6h-81EB9h)	; @ 0x156E6
	mov	gs:[pLevelEnd1],(15587h-81EB9h)		; @ 0x15587
	mov	gs:[pLevelEnd2],(15B96h-81EB9h)		; @ 0x15B96
	mov	gs:[pExitSign1],(6083Fh-81EB9h)		; @ 0x6083F
	mov	gs:[pExitSign2],(6099Ch-81EB9h)		; @ 0x6099C
	mov	gs:[pPerdu],(1AF0Eh-81EB9h)		; @ 0x1AF0E
	mov	gs:[pPlayTrack],(28650h-81EB9h)		; @ 0x28650

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v120uk:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(17091Ch-137634h)	; @ 0x17091C
	mov	gs:[pnum_level],(17090Ch-137634h)	; @ 0x17090C
	mov	gs:[ptrack_table],(135F0Bh-137634h)	; @ 0x135F0B
	mov	gs:[ptimeCd],(135F8Ch-137634h)		; @ 0x135F8C
	mov	gs:[pcdTime],(16E8ECh-137634h)		; @ 0x16E8EC
	; mov	gs:[prbook_table],(17F957h-137634h)	; @ 0x17F957
	mov	gs:[prbook_lentable],(17FAEBh-137634h)	; @ 0x17FAEB
	; mov	gs:[prbook_tablefl],(17FF8Eh-137634h)	; @ 0x17FF8E
	; mov	gs:[plowest_atrack],(17F951h-137634h)	; @ 0x17F951
	; mov	gs:[phighest_atrack],(17F952h-137634h)	; @ 0x17F952
	; mov	gs:[pcd_driveletter],(170AB7h-137634h)	; @ 0x170AB7
	mov	gs:[plang],(170AC5h-137634h)		; @ 0x170AC5

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x821FF in this version
	mov	gs:[pCreditsTrackNo],(1AED8h-821FFh)	; @ 0x1AED8
	mov	gs:[pLogoTrackNo],(1AF00h-821FFh)	; @ 0x1AF00
	mov	gs:[pMenuTrackNo],(1AF80h-821FFh)	; @ 0x1AF80
	mov	gs:[pGOverTrackNo],(1AFA8h-821FFh)	; @ 0x1AFA8
	mov	gs:[pPlayIntro],(16521h-821FFh)		; @ 0x16521
	mov	gs:[pPlayOuttro],(33805h-821FFh)	; @ 0x33805
	; displacements are same as German for these four:
	mov	gs:[pDoGrowingPlat],(79650h-8220Fh)	; @ 0x79640
	mov	gs:[pMoskitoLock],(51D45h-8220Fh)	; @ 0x51D35
	mov	gs:[pMoskitoFast],(58EA4h-8220Fh)	; @ 0x58E94
	mov	gs:[pMoskitoSlow],(58ECDh-8220Fh)	; @ 0x58EBD
	; these four are different:
	mov	gs:[pLevelStart1],(14FF0h-821FFh)	; @ 0x14FF0
	mov	gs:[pLevelStart2],(156F6h-821FFh)	; @ 0x156F6
	mov	gs:[pLevelEnd1],(15597h-821FFh)		; @ 0x15597
	mov	gs:[pLevelEnd2],(15BA6h-821FFh)		; @ 0x15BA6
	; displacements are same as German for these two:
	mov	gs:[pExitSign1],(6035Fh-8220Fh)		; @ 0x6034F
	mov	gs:[pExitSign2],(604BCh-8220Fh)		; @ 0x604AC
	; these two are different:
	mov	gs:[pPerdu],(1AF1Eh-821FFh)		; @ 0x1AF1E
	mov	gs:[pPlayTrack],(28660h-821FFh)		; @ 0x28660

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v120de:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(17091Ch-137634h)	; @ 0x17091C
	mov	gs:[pnum_level],(17090Ch-137634h)	; @ 0x17090C
	mov	gs:[ptrack_table],(135F0Bh-137634h)	; @ 0x135F0B
	mov	gs:[ptimeCd],(135F8Ch-137634h)		; @ 0x135F8C
	mov	gs:[pcdTime],(16E8ECh-137634h)		; @ 0x16E8EC
	; mov	gs:[prbook_table],(17F957h-137634h)	; @ 0x17F957
	mov	gs:[prbook_lentable],(17FAEBh-137634h)	; @ 0x17FAEB
	; mov	gs:[prbook_tablefl],(17FF8Eh-137634h)	; @ 0x17FF8E
	; mov	gs:[plowest_atrack],(17F951h-137634h)	; @ 0x17F951
	; mov	gs:[phighest_atrack],(17F952h-137634h)	; @ 0x17F952
	; mov	gs:[pcd_driveletter],(170AB7h-137634h)	; @ 0x170AB7
	mov	gs:[plang],(170AC5h-137634h)		; @ 0x170AC5

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x8220F in this version
	mov	gs:[pCreditsTrackNo],(1AED8h-8220Fh)	; @ 0x1AED8
	mov	gs:[pLogoTrackNo],(1AF00h-8220Fh)	; @ 0x1AF00
	mov	gs:[pMenuTrackNo],(1AF80h-8220Fh)	; @ 0x1AF80
	mov	gs:[pGOverTrackNo],(1AFA8h-8220Fh)	; @ 0x1AFA8
	mov	gs:[pPlayIntro],(16521h-8220Fh)		; @ 0x16521
	mov	gs:[pPlayOuttro],(33805h-8220Fh)	; @ 0x33805
	mov	gs:[pDoGrowingPlat],(79650h-8220Fh)	; @ 0x79650
	mov	gs:[pMoskitoLock],(51D45h-8220Fh)	; @ 0x51D45
	mov	gs:[pMoskitoFast],(58EA4h-8220Fh)	; @ 0x58EA4
	mov	gs:[pMoskitoSlow],(58ECDh-8220Fh)	; @ 0x58ECD
	mov	gs:[pLevelStart1],(14FF0h-8220Fh)	; @ 0x14FF0
	mov	gs:[pLevelStart2],(156F6h-8220Fh)	; @ 0x156F6
	mov	gs:[pLevelEnd1],(15597h-8220Fh)		; @ 0x15597
	mov	gs:[pLevelEnd2],(15BA6h-8220Fh)		; @ 0x15BA6
	mov	gs:[pExitSign1],(6035Fh-8220Fh)		; @ 0x6035F
	mov	gs:[pExitSign2],(604BCh-8220Fh)		; @ 0x604BC
	mov	gs:[pPerdu],(1AF1Eh-8220Fh)		; @ 0x1AF1E
	mov	gs:[pPlayTrack],(28660h-8220Fh)		; @ 0x28660

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v112us:
	bts	cs:[statusword],0Ah			; indicate US version

	mov	di,offset unprotected + sizeof unprotected - 1
	mov	cx,-(sizeof unprotected)
	call	chk_entete
	jc	@@setup_ptrs_v112us_unprotected

	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(170780h-137634h)	; @ 0x170780
	mov	gs:[pnum_level],(17076Eh-137634h)	; @ 0x17076E
	mov	gs:[ptrack_table],(135EF3h-137634h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137634h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E754h-137634h)		; @ 0x16E754
	; mov	gs:[prbook_table],(17F7C7h-137634h)	; @ 0x17F7C7
	mov	gs:[prbook_lentable],(19595Bh-137634h)	; @ 0x19595B
	; mov	gs:[prbook_tablefl],(17FDFEh-137634h)	; @ 0x17FDFE
	; mov	gs:[plowest_atrack],(17F7C1h-137634h)	; @ 0x17F7C1
	; mov	gs:[phighest_atrack],(17F7C2h-137634h)	; @ 0x17F7C2
	; mov	gs:[pcd_driveletter],(17091Bh-137634h)	; @ 0x17091B
	mov	gs:[plang],(170928h-137634h)		; @ 0x170928

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81CA8 in this version
	mov	gs:[pCreditsTrackNo],(1ADA8h-81CA8h)	; @ 0x1ADA8
	mov	gs:[pLogoTrackNo],(1ADD0h-81CA8h)	; @ 0x1ADD0
	mov	gs:[pMenuTrackNo],(1AE50h-81CA8h)	; @ 0x1AE50
	mov	gs:[pGOverTrackNo],(1AE78h-81CA8h)	; @ 0x1AE78
	mov	gs:[pPlayIntro],(1652Bh-81CA8h)		; @ 0x1652B
	mov	gs:[pPlayOuttro],(33557h-81CA8h)	; @ 0x33557
	mov	gs:[pDoGrowingPlat],(79180h-81CA8h)	; @ 0x79180
	mov	gs:[pMoskitoLock],(518A5h-81CA8h)	; @ 0x518A5
	mov	gs:[pMoskitoFast],(58A04h-81CA8h)	; @ 0x58A04
	mov	gs:[pMoskitoSlow],(58A2Dh-81CA8h)	; @ 0x58A2D
	mov	gs:[pLevelStart1],(14FE0h-81CA8h)	; @ 0x14FE0
	mov	gs:[pLevelStart2],(156E6h-81CA8h)	; @ 0x156E6
	mov	gs:[pLevelEnd1],(15587h-81CA8h)		; @ 0x15587
	mov	gs:[pLevelEnd2],(15B96h-81CA8h)		; @ 0x15B96
	mov	gs:[pExitSign1],(5FEBFh-81CA8h)		; @ 0x5FEBF
	mov	gs:[pExitSign2],(6001Ch-81CA8h)		; @ 0x6001C
	mov	gs:[pPerdu],(1ADEEh-81CA8h)		; @ 0x1ADEE
	mov	gs:[pPlayTrack],(283D8h-81CA8h)		; @ 0x283D8

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v112us_unprotected:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(170520h-137634h)	; @ 0x170520
	mov	gs:[pnum_level],(17050Eh-137634h)	; @ 0x17050E
	mov	gs:[ptrack_table],(135EF3h-137634h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137634h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E4F4h-137634h)		; @ 0x16E4F4
	; mov	gs:[prbook_table],(17F667h-137634h)	; @ 0x17F667
	mov	gs:[prbook_lentable],(17F7FBh-137634h)	; @ 0x17F7FB
	; mov	gs:[prbook_tablefl],(17FB9Bh-137634h)	; @ 0x17FB9B
	; mov	gs:[plowest_atrack],(17F661h-137634h)	; @ 0x17F661
	; mov	gs:[phighest_atrack],(17F662h-137634h)	; @ 0x17F662
	; mov	gs:[pcd_driveletter],(1706BBh-137634h)	; @ 0x1706BB
	mov	gs:[plang],(1706C8h-137634h)		; @ 0x1706C8

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81216 in this version
	mov	gs:[pCreditsTrackNo],(1AC78h-81216h)	; @ 0x1AC78
	mov	gs:[pLogoTrackNo],(1ACA0h-81216h)	; @ 0x1ACA0
	mov	gs:[pMenuTrackNo],(1AD20h-81216h)	; @ 0x1AD20
	mov	gs:[pGOverTrackNo],(1AD48h-81216h)	; @ 0x1AD48
	mov	gs:[pPlayIntro],(163F5h-81216h)		; @ 0x163F5
	mov	gs:[pPlayOuttro],(333F7h-81216h)	; @ 0x333F7
	mov	gs:[pDoGrowingPlat],(786E0h-81216h)	; @ 0x786E0
	mov	gs:[pMoskitoLock],(51715h-81216h)	; @ 0x51715
	mov	gs:[pMoskitoFast],(58874h-81216h)	; @ 0x58874
	mov	gs:[pMoskitoSlow],(5889Dh-81216h)	; @ 0x5889D
	mov	gs:[pLevelStart1],(14FE0h-81216h)	; @ 0x14FE0
	mov	gs:[pLevelStart2],(156DAh-81216h)	; @ 0x156DA
	mov	gs:[pLevelEnd1],(1557Bh-81216h)		; @ 0x1557B
	mov	gs:[pLevelEnd2],(15B7Eh-81216h)		; @ 0x15B7E
	mov	gs:[pExitSign1],(5FD2Fh-81216h)		; @ 0x5FD2F
	mov	gs:[pExitSign2],(5FE8Ch-81216h)		; @ 0x5FE8C
	mov	gs:[pPerdu],(1ACBEh-81216h)		; @ 0x1ACBE
	mov	gs:[pPlayTrack],(282C4h-81216h)		; @ 0x282C4

	jmp	@@payload_fixedup

@@setup_ptrs_v112eu:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137624 in this version
	mov	gs:[pnum_world],(170770h-137624h)	; @ 0x170770
	mov	gs:[pnum_level],(17075Eh-137624h)	; @ 0x17075E
	mov	gs:[ptrack_table],(135EF3h-137624h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137624h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E744h-137624h)		; @ 0x16E744
	; mov	gs:[prbook_table],(17F7B7h-137624h)	; @ 0x17F7B7
	mov	gs:[prbook_lentable],(17F94Bh-137624h)	; @ 0x17F94B
	; mov	gs:[prbook_tablefl],(17FDEEh-137624h)	; @ 0x17FDEE
	; mov	gs:[plowest_atrack],(17F7B1h-137624h)	; @ 0x17F7B1
	; mov	gs:[phighest_atrack],(17F7B2h-137624h)	; @ 0x17F7B2
	; mov	gs:[pcd_driveletter],(17090Bh-137624h)	; @ 0x17090B
	mov	gs:[plang],(170918h-137624h)		; @ 0x170918

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81508 in this version
	mov	gs:[pCreditsTrackNo],(1ADA8h-81508h)	; @ 0x1ADA8
	mov	gs:[pLogoTrackNo],(1ADD0h-81508h)	; @ 0x1ADD0
	mov	gs:[pMenuTrackNo],(1AE50h-81508h)	; @ 0x1AE50
	mov	gs:[pGOverTrackNo],(1AE78h-81508h)	; @ 0x1AE78
	mov	gs:[pPlayIntro],(1652Bh-81508h)		; @ 0x1652B
	mov	gs:[pPlayOuttro],(33557h-81508h)	; @ 0x33557
	mov	gs:[pDoGrowingPlat],(789E0h-81508h)	; @ 0x789E0
	mov	gs:[pMoskitoLock],(51105h-81508h)	; @ 0x51105
	mov	gs:[pMoskitoFast],(58264h-81508h)	; @ 0x58264
	mov	gs:[pMoskitoSlow],(5828Dh-81508h)	; @ 0x5828D
	mov	gs:[pLevelStart1],(14FE0h-81508h)	; @ 0x14FE0
	mov	gs:[pLevelStart2],(156E6h-81508h)	; @ 0x156E6
	mov	gs:[pLevelEnd1],(15587h-81508h)		; @ 0x15587
	mov	gs:[pLevelEnd2],(15B96h-81508h)		; @ 0x15B96
	mov	gs:[pExitSign1],(5F71Fh-81508h)		; @ 0x5F71F
	mov	gs:[pExitSign2],(5F87Ch-81508h)		; @ 0x5F87C
	mov	gs:[pPerdu],(1ADEEh-81508h)		; @ 0x1ADEE
	mov	gs:[pPlayTrack],(283D8h-81508h)		; @ 0x283D8

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	jmp	@@payload_fixedup

@@setup_ptrs_v110eu:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137624 in this version
	mov	gs:[pnum_world],(170720h-137624h)	; @ 0x170720
	mov	gs:[pnum_level],(17070Eh-137624h)	; @ 0x17070E
	mov	gs:[ptrack_table],(135EF3h-137624h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137624h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E6F4h-137624h)		; @ 0x16E6F4
	; mov	gs:[prbook_table],(17F767h-137624h)	; @ 0x17F767
	mov	gs:[prbook_lentable],(17F8FBh-137624h)	; @ 0x17F8FB
	; mov	gs:[prbook_tablefl],(17FD9Eh-137624h)	; @ 0x17FD9E
	; mov	gs:[plowest_atrack],(17F761h-137624h)	; @ 0x17F761
	; mov	gs:[phighest_atrack],(17F762h-137624h)	; @ 0x17F762
	; mov	gs:[pcd_driveletter],(1708BBh-137624h)	; @ 0x1708BB
	mov	gs:[plang],(1708C8h-137624h)		; @ 0x1708C8

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81678 in this version
	mov	gs:[pCreditsTrackNo],(1ADD8h-81678h)	; @ 0x1ADD8
	mov	gs:[pLogoTrackNo],(1AE00h-81678h)	; @ 0x1AE00
	mov	gs:[pMenuTrackNo],(1AE80h-81678h)	; @ 0x1AE80
	mov	gs:[pGOverTrackNo],(1AEA8h-81678h)	; @ 0x1AEA8
	mov	gs:[pPlayIntro],(1655Fh-81678h)		; @ 0x1655F
	mov	gs:[pPlayOuttro],(33557h-81678h)	; @ 0x33557
	mov	gs:[pDoGrowingPlat],(78B50h-81678h)	; @ 0x78B50
	mov	gs:[pMoskitoLock],(510B5h-81678h)	; @ 0x510B5
	mov	gs:[pMoskitoFast],(58214h-81678h)	; @ 0x58214
	mov	gs:[pMoskitoSlow],(5823Dh-81678h)	; @ 0x5823D
	mov	gs:[pLevelStart1],(15050h-81678h)	; @ 0x15050
	mov	gs:[pLevelStart2],(15756h-81678h)	; @ 0x15756
	mov	gs:[pLevelEnd1],(155F7h-81678h)		; @ 0x155F7
	mov	gs:[pLevelEnd2],(15C06h-81678h)		; @ 0x15C06
	mov	gs:[pExitSign1],(5F6CFh-81678h)		; @ 0x5F6CF
	mov	gs:[pExitSign2],(5F82Ch-81678h)		; @ 0x5F82C
	mov	gs:[pPerdu],(1AE1Eh-81678h)		; @ 0x1AE1E
	mov	gs:[pPlayTrack],(28408h-81678h)		; @ 0x28408

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	; And another involving the metadata!
	bts	cs:[statusword],7
	; And it expects a very specific length of data on the CD...
	mov	cs:[spoof_info.addr_leadout],401D18h
	jmp	@@payload_fixedup

@@setup_ptrs_v100:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137584 in this version
	mov	gs:[pnum_world],(170282h-137584h)	; @ 0x170282
	mov	gs:[pnum_level],(170270h-137584h)	; @ 0x170270
	mov	gs:[ptrack_table],(135EF3h-137584h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137584h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E2ACh-137584h)		; @ 0x16E2AC
	; mov	gs:[prbook_table],(17F3C7h-137584h)	; @ 0x17F3C7
	mov	gs:[prbook_lentable],(17F55Bh-137584h)	; @ 0x17F55B
	; mov	gs:[prbook_tablefl],(17F8FCh-137584h)	; @ 0x17F8FC
	; mov	gs:[plowest_atrack],(17F3C1h-137584h)	; @ 0x17F3C1
	; mov	gs:[phighest_atrack],(17F3C2h-137584h)	; @ 0x17F3C2
	; mov	gs:[pcd_driveletter],(170419h-137584h)	; @ 0x170419
	mov	gs:[plang],(170428h-137584h)		; @ 0x170428

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81548 in this version
	mov	gs:[pCreditsTrackNo],(1AB7Ch-81548h)	; @ 0x1AB7C
	mov	gs:[pLogoTrackNo],(1ABA4h-81548h)	; @ 0x1ABA4
	mov	gs:[pMenuTrackNo],(1AC24h-81548h)	; @ 0x1AC24
	mov	gs:[pGOverTrackNo],(1AC4Ch-81548h)	; @ 0x1AC4C
	mov	gs:[pPlayIntro],(1639Fh-81548h)		; @ 0x1639F
	mov	gs:[pPlayOuttro],(339A3h-81548h)	; @ 0x339A3
	mov	gs:[pDoGrowingPlat],(78AC0h-81548h)	; @ 0x78AC0
	mov	gs:[pMoskitoLock],(51105h-81548h)	; @ 0x51105
	mov	gs:[pMoskitoFast],(58250h-81548h)	; @ 0x58250
	mov	gs:[pMoskitoSlow],(58279h-81548h)	; @ 0x58279
	mov	gs:[pLevelStart1],(15058h-81548h)	; @ 0x15058
	mov	gs:[pLevelStart2],(1571Bh-81548h)	; @ 0x1571B
	mov	gs:[pLevelEnd1],(155BDh-81548h)		; @ 0x155BD
	mov	gs:[pLevelEnd2],(15B9Ch-81548h)		; @ 0x15B9C
	mov	gs:[pExitSign1],(5F58Fh-81548h)		; @ 0x5F58F
	mov	gs:[pExitSign2],(5F6ECh-81548h)		; @ 0x5F6EC
	mov	gs:[pPerdu],(1ABC2h-81548h)		; @ 0x1ABC2
	mov	gs:[pPlayTrack],(28868h-81548h)		; @ 0x28868

	; This version has DRM that involves checking files on the CD
	bts	cs:[statusword],2
	; And another involving the metadata!
	bts	cs:[statusword],7
	; And it expects a very specific length of data on the CD...
	mov	cs:[spoof_info.addr_leadout],401E19h

@@payload_fixedup:
	; Next we need to open up Rayman's config file and get the driver ID
	mov	ax,3D00h	; OPEN read-only
	mov	dx,offset raycfg
	pushf
	call	old_int21
	jc	@@failed
	mov	bx,ax

	mov	ax,4200h	; LSEEK from beginning
	xor	cx,cx
	mov	dx,11h		; DeviceID in config file
	pushf
	call	old_int21
	jc	@@failed_fileopen

	mov	ah,3Fh		; READ
	mov	cx,4
	mov	dx,offset sos_devid
	pushf
	call	old_int21
	jc	@@failed_fileopen

	mov	ah,3Eh		; CLOSE
	pushf
	call	old_int21

	; Now the really fun part...
	; We need to open HMIDRV.386 and extract the corresponding driver!
	mov	ax,3D00h	; OPEN read-only
	mov	dx,offset hmidrv
	pushf
	call	old_int21
	jc	@@failed
	mov	bx,ax

	mov	ah,3Fh		; READ
	mov	cx,sizeof hmidrv_hdr
	mov	dx,offset hmidrv_hdr
	pushf
	call	old_int21
	jc	@@failed_fileopen

@@drvhdr_loop:
	mov	ah,3Fh		; READ
	mov	cx,sizeof hmidrv_drvhdr
	mov	dx,offset hmidrv_drvhdr
	pushf
	call	old_int21
	jc	@@failed_fileopen

	mov	edi,[sos_devid]
	cmp	edi,[hmidrv_drvhdr.wDeviceID]
	jne	@F

	bt	word ptr [hmidrv_drvhdr.wExtenderType],0Fh	; RATIONAL
	jc	@@found_driver

@@:
	mov	ax,4201h	; LSEEK from current position
	mov	cx,word ptr [hmidrv_drvhdr.wSize+2]
	mov	dx,word ptr [hmidrv_drvhdr.wSize]
	pushf
	call	old_int21
	jc	@@failed_fileopen

	dec	[hmidrv_hdr.wDrivers]
	jnz	@@drvhdr_loop
	jmp	@@failed_fileopen

@@found_driver:
	; we have a suitable driver in HMIDRV.386
	mov	edi,[hmidrv_drvhdr.wSize]

	; now copy it into a fake file...
	mov	ah,3Ch		; CREAT
	xor	cx,cx		; no attributes
	mov	dx,offset fakehmidrv
	pushf
	call	old_int21
	jc	@@failed_fileopen
	mov	si,ax

	xchg	si,bx		; we're looking at the fake file...
	mov	ah,40h		; WRITE
	mov	cx,sizeof hmidrv_hdr
	mov	dx,offset hmidrv_hdr
	; only one driver in this new file
	mov	[hmidrv_hdr.wDrivers],1
	pushf
	call	old_int21
	jc	@@failed_twofilesopen

	mov	ah,40h		; WRITE
	mov	cx,sizeof hmidrv_drvhdr
	mov	dx,offset hmidrv_drvhdr
	; we're adding a chunk!
	add	[hmidrv_drvhdr.wSize],offset end_of_payload
	pushf
	call	old_int21
	jc	@@failed_twofilesopen

	push	ds
	push	gs
	pop	ds
	assume	ds:payload
	mov	ah,40h		; WRITE
	mov	ecx,offset end_of_payload
	xor	dx,dx
	pushf
	call	old_int21
	pop	ds
	assume	ds:stub
	jc	@@failed_twofilesopen

	mov	cx,di
	and	cx,(BUFSIZE-1)
	shr	edi,?LOG_BUFSIZE
	.if	cx
	   inc	edi		; include the first chunk <1 kiB!
	.else
	   mov	cx,BUFSIZE	; no extra <1-kiB chunk...
	.endif

@@:
	xchg	bx,si		; back to the original file
	mov	ah,3Fh		; READ
	mov	dx,offset hmidrv_buffer
	pushf
	call	old_int21
	jc	@@failed_twofilesopen

	xchg	bx,si		; fake file again!
	mov	cx,ax
	mov	ah,40h		; WRITE
	pushf
	call	old_int21
	jc	@@failed_twofilesopen

	mov	cx,BUFSIZE
	dec	edi
	jnz	@B

	; should be OK from here!
	mov	ah,3Eh		; CLOSE
	pushf
	call	old_int21

	mov	bx,si
	mov	ah,3Eh		; CLOSE
	pushf
	call	old_int21

	clc
@@retpoint:
	pushf	; save CF state
	btr	cs:[statusword],5
	jnc	@F
	call	restore_ems
@@:
	popf
	ret

@@failed_twofilesopen:
	mov	ah,3Eh		; CLOSE
	pushf
	call	old_int21
	mov	bx,si
@@failed_fileopen:
	mov	ah,3Eh		; CLOSE
	pushf
	call	old_int21
@@failed:
	mov	ah,9
	mov	dx,offset payload_fail
	pushf
	call	old_int21
	btr	[statusword],2	; unset any DRM redirections we may have set
	stc
	jmp	@@retpoint

	assume	gs:nothing,es:nothing,ds:nothing
setup_payload	endp

; Check if the CD drive letter in AL contains a TPLS-suitable CD
; Sets CF if not suitable, clears if suitable
chk_suitablecd	proc near	uses ds ax cx es bx dx
	push	cs
	pop	ds
	assume	ds:stub

	cmp	al,[suitable_cddrv]
	jne	@F
	clc
	ret

@@:
	mov	dl,al
	sub	al,'a'		; convert letter to number
	movzx	cx,al

	mov	ax,1510h	; send driver request
	sub	sp,((size IOCTLRW) + 1) AND (NOT 1)
	mov	bx,sp
	push	ss
	pop	es		; ES:BX --> buffer on stack
	assume	es:nothing

	push	bp
	sub	sp,((size AudioDiscInfo) + 1) AND (NOT 1)
	mov	bp,sp

	mov	es:[bx.IOCTLRW.bLen],size IOCTLRW
	mov	es:[bx.IOCTLRW.bUnit],0
	mov	es:[bx.IOCTLRW.bCmd],3		; IOCTL read
	mov	es:[bx.IOCTLRW.wBufSeg],ss
	mov	es:[bx.IOCTLRW.wBufOff],bp	; another stack buffer
	mov	es:[bx.IOCTLRW.wCount],size AudioDiscInfo
	mov	[bp.AudioDiscInfo.function],0Ah	; audio disc info

	call	do_int2f
	jc	@@cleanupstack

	bt	es:[bx.IOCTLRW.wStatus],0Fh	; error?
	jc	@@cleanupstack

	cmp	[bp.AudioDiscInfo.first_audtrack],1
	ja	@@toomanydatatracks
	cmp	[bp.AudioDiscInfo.last_audtrack],51
	jb	@@notenoughaudiotracks
	cmp	[bp.AudioDiscInfo.last_audtrack],61
	jnb	@F

	mov	[noextratracks_letter],dl
	sub	[noextratracks_letter],20h	; make uppercase!
	mov	dx,offset noextratracks
	mov	ah,9	; write to stdout
	pushf
	call	old_int21

@@:
	bt	[statusword],7			; extra DRM?
	jnc	@F

	; Rayman v1.00 and v1.10 have extra DRMs, which we won't bypass,
	; but we will make them more upfront, and explain how the user
	; can rectify the situation.
	call	chk_vollabel
	jc	@@wrongvolumelabel

	call	chk_biossums
	jc	@@badbioschecksums

@@:
	mov	[suitable_cddrv],dl
	clc

@@cleanupstack:
	setc	al	; remember carry flag!
	add	sp,((size AudioDiscInfo) + 1) AND (NOT 1)
	pop	bp
	add	sp,((size IOCTLRW) + 1) AND (NOT 1)
	rcr	al,1	; restore carry
	ret

@@wrongvolumelabel:
	mov	[wrongvolumelabel_letter],dl
	sub	[wrongvolumelabel_letter],20h	; make uppercase!
	mov	dx,offset wrongvolumelabel
	jmp	@F
@@badbioschecksums:
	mov	dx,offset badbioschecksums
	jmp	@F
@@toomanydatatracks:
	mov	[toomanydatatracks_letter],dl
	sub	[toomanydatatracks_letter],20h	; make uppercase!
	mov	dx,offset toomanydatatracks
	jmp	@F
@@notenoughaudiotracks:
	mov	[notenoughaudiotracks_letter],dl
	sub	[notenoughaudiotracks_letter],20h; make uppercase!
	mov	dx,offset notenoughaudiotracks
@@:
	mov	ah,9	; write to stdout
	pushf
	call	old_int21
	stc
	jmp	@@cleanupstack

	assume	ds:nothing
chk_suitablecd	endp

; Takes drive letter in DL
; Returns with Carry set if volume label is not "RAYMAN"
chk_vollabel	proc near	uses eax es bx cx ds dx
	movzx	eax,dl
	or	eax,('\' SHL 10h) + (':' SHL 8)
	push	eax		; Now SS:[SP] = "X:\",0

	mov	ax,4E00h	; FINDFIRST
	mov	cx,8		; volume label attribute
	push	ss
	pop	ds
	assume	ds:nothing
	mov	dx,sp		; drive letter on stack
	pushf
	call	old_int21
	add	sp,4		; clean it up

	mov	ah,2Fh		; get DTA
	pushf
	call	old_int21
	assume	es:nothing

	; ASCIZ volume label is now at ES:[BX+1Eh]
	cmp	dword ptr es:[bx+1Eh], "MYAR"
	jne	@@bad
	cmp	word ptr es:[bx+1Eh+4],"NA"
	jne	@@bad
	cmp	byte ptr es:[bx+1Eh+6],0
	jne	@@bad
	; Successful comparison will have cleared CF for us
@@:
	ret

@@bad:
	stc
	ret
chk_vollabel	endp

; Checks if the BIOS and VBIOS checksums in the WLD files match the current PC
; Returns with Carry set if they don't match
chk_biossums	proc near	uses bp ax bx cx dx es si di
	assume	ds:stub	; called from within chk_suitablecd

	xor	bp,bp		; place a zero on the stack,
	push	bp		; to be overwritten with checksums
	mov	bp,sp

	mov	ax,3D00h	; OPEN read-only
	mov	dx,offset ray1wld
	pushf
	call	old_int21
	jc	@@done

	mov	bx,ax
	mov	ax,4200h	; LSEEK from beginning of file
	xor	cx,cx
	mov	dx,5		; seek to position 5 (checksums)
	pushf
	call	old_int21
	jc	@F

	mov	ah,3Fh		; READ
	mov	cx,2		; two checksums
	push	ds
	push	ss
	pop	ds		; read them onto the stack
	assume	ds:nothing
	mov	dx,bp
	pushf
	call	old_int21
	pop	ds
	assume	ds:stub

@@:
	mov	ah,3Eh		; CLOSE
	pushf
	call	old_int21

	mov	ax,0F000h	; BIOS ROM
	xor	di,di
@@nextrom:
	mov	es,ax
	xor	si,si
	mov	cx,1000h	; check the first page
@@:
	lods	byte ptr es:[si]
	sub	[bp+di],al
	loop	@B
	jz	@F

	stc	; no match
	jmp	@@done
@@:
	mov	ax,0C000h	; Video BIOS ROM
	inc	di
	cmp	di,2
	jb	@@nextrom
	; If JB is not taken, that means CF is clear, so we return success

@@done:
	lea	sp,[bp+2]
	ret
chk_biossums	endp

tpls_int21	proc
	assume	ds:nothing,es:nothing

	test	cs:[statusword],46h	; Win9x and/or redirects
	jnz	@F	; redirect(s) active!
	jmp	cs:old_int21

@@:
	cmp	ah,3Dh	; OPEN
	je	@F
	cmp	ah,4Ch	; EXIT
	je	@@exit
	jmp	cs:old_int21

@@:
	push	es
	push	si
	push	di
	push	cx
	push	ax

	push	cs
	pop	es
	assume	es:stub
	mov	si,dx
	cld

	bt	cs:[statusword],1
	jnc	@@nothmidrv
	mov	di,offset hmidrv
	mov	cx,sizeof hmidrv
	push	si
@@:
	lodsb
	.if	al >= 'A' && al <= 'Z'
	   or	al,20h	; make sure it's lowercase
	.endif
	scasb
	loope	@B
	pop	si
	jne	@@nothmidrv

	mov	si,offset fakehmidrv
	jmp	@@callthrough

@@nothmidrv:
	bt	cs:[statusword],2
	jnc	@@notcdredir

	lodsw
	cmp	ah,':'	; on a different drive?
	jne	@@passthrough
	or	al,20h	; ensure lowercase!
	cmp	al,cs:[first_cddrv]
	jb	@@passthrough
	cmp	al,cs:[endof_cddrv]
	jnb	@@passthrough

	; OK, we're opening a file from a CD. Check if we need to redirect.
	mov	di,offset raymanexe
	mov	cx,sizeof raymanexe
	push	si
	repe	cmpsb
	pop	si
	jne	@F

	call	chk_suitablecd
	mov	si,offset fake_exes
	jnc	@@callthrough
	jmp	@@passthrough

@@:
	mov	di,offset configexe
	mov	cx,sizeof configexe
	push	si
	repe	cmpsb
	pop	si
	jne	@F

	call	chk_suitablecd
	mov	si,offset fake_exes
	jnc	@@callthrough
	jmp	@@passthrough

@@:
	mov	di,offset introdat
	mov	cx,sizeof introdat
	push	si
	repe	cmpsb
	pop	si
	je	@@redir_local

	mov	di,offset concludat
	mov	cx,sizeof concludat
	push	si
	repe	cmpsb
	pop	si
	je	@@redir_local

@@notcdredir:
	bt	cs:[statusword],6	; Windows 9x
	jnc	@@passthrough
	call	openredir_9x

@@passthrough:
	pop	ax
	pop	cx
	pop	di
	pop	si
	pop	es
	jmp	cs:old_int21

@@callthrough:
	pop	ax
	pop	cx
	push	ds
	push	dx

	mov	dx,si
	push	cs
	pop	ds
	assume	ds:stub
	pushf
	call	old_int21

	pop	dx
	pop	ds
	jmp	@@return_setc

@@redir_local:
	; Redirect attempt to load a file in "X:\rayman\" to cwd.
	; (Where X is the CD drive letter).
	pop	ax
	pop	cx
	push	dx
	add	dx,10		; "X:\rayman\" is 10 characters
	pushf
	call	cs:old_int21
	pop	dx

@@return_setc:
	pop	di
	pop	si
	pop	es

	jc	@F
	btr	word ptr [esp+4], 0	; clear CF
	iret

@@:
	bts	word ptr [esp+4], 0	; set CF
	iret

@@exit:
	; Reset everything when Rayman exits
	test	cs:[statusword],not 1
	jz	@F

	push	ds
	push	ax
	push	dx

	push	cs
	pop	ds
	assume	ds:stub

	; Bit 0 means using EMS, which doesn't change across Rayman runs.
	; Likewise for Bit 6, meaning running on Windows 9x.
	; Other bits reset for a new run.
	and	[statusword],41h
	; Reset this too, to make sure we go through whatever rigmarole
	; is needed if another version is launched in the same session!
	mov	[suitable_cddrv],0

	mov	dx,offset fakehmidrv
	mov	ah,41h	; UNLINK
	pushf
	call	old_int21

	pop	dx
	pop	ax
	pop	ds
	assume	ds:nothing
@@:
	jmp	cs:old_int21
tpls_int21	endp

tpls_int2f	proc
	assume	ds:nothing,es:nothing

	cmp	ax,0CE00h+'T'
	jne	@F
	cmp	bl,'P'
	jne	@F
	cmp	cl,'L'
	jne	@F
	cmp	dl,'S'
	jne	@F

	; Output is AL:BL:CL:DL = "PluM", all upper bytes zeroed
	mov	eax,'P'
	mov	ebx,'l'
	mov	ecx,'u'
	mov	edx,'M'
	iret

@@:
	cmp	ah,15h	; MSCDEX call?
	jne	@@uncond_passthrough
	bt	cs:[statusword],3	; payload active?
	jnc	@F

	btr	cs:[statusword],4	; need to run the callback?
	jnc	@@passthrough
	bt	cs:[statusword],6	; on Win9x, this code should be unreachable
	jc	@@passthrough		; but test for it just in case...
	
	; the payload sets this when it activates
	jmp	cs:callback2payload
	; and the callback itself will send us to old_int2f when it's done

@@:
	; We don't have a PM companion, need to handle everything in RM
	bt	cs:[statusword],1	; redirects active?
	jnc	@@mscdex_noredir

	bt	cs:[statusword],7	; spoofing active?
	jnc	@F

	; GET COPYRIGHT / ABSTRACT / BIBLIOGRAPHIC DOC FILENAME
	.if	(al >= 2) && (al <= 4)
	   ; Write "RAYMAN" in the buffer
	   mov	dword ptr es:[bx], "MYAR"
	   mov	word ptr es:[bx+4],"NA"
	   mov	byte ptr es:[bx+6],0

	   ; in a moment, Rayman will also check the audio info
	   bts	cs:[statusword],8	; so have the right answer ready!
	   jmp	@@return_success
	.endif

@@:
	cmp	al,10h		; send driver request
	jne	@@passthrough

	bt	cs:[statusword],8	; spoofing needed?
	jnc	@F

	.if	es:[bx.IOCTLRW.bCmd] == 3; IOCTL INPUT
	   cmp	es:[bx.IOCTLRW.wCount],size AudioDiscInfo
	   jb	@@passthrough	; bad request, let MSCDEX deal with it

	   push	es
	   push	di
	   les	di,dword ptr es:[bx.IOCTLRW.wBufOff]
	   cmp	byte ptr es:[di],0Ah	; Audio Disc Info
	   je	@@audinfo

	   pop	di
	   pop	es
	   jmp	@@passthrough
	.endif

@@:
	cmp	es:[bx.IOCTLRW.bCmd],84h; PLAY AUDIO
	jne	@@passthrough

	call	chk_music_redirect
	jmp	cs:old_int2f

@@mscdex_noredir:
	; Redirects not active, time to check if we should activate them
	test	al,al
	jnz	@@passthrough
	test	bx,bx
	jnz	@@passthrough

	; installation check - see if it's Rayman that's calling us
	call	chk_is_rayman
	jnc	@@passthrough

	call	setup_payload
	jc	@@passthrough

	; activate redirects if successful
	bts	cs:[statusword],1

@@passthrough:
	bt	cs:[statusword],6	; Windows 9x
	jc	@F
@@uncond_passthrough:
	jmp	cs:old_int2f

@@:
	iret	; go straight back to the hooked int 31h

@@audinfo:
	; clear this bit so the next request won't be spoofed!
	btr	cs:[statusword],8

	push	si
	lea	si,spoof_info
	; move seven bytes = 4+2+1
	movsd	es:[di],cs:[si]
	movsw	es:[di],cs:[si]
	movsb	es:[di],cs:[si]

	pop	si
	pop	di
	pop	es

@@return_success:
	; if we're on Win9x, signal to the int 31h handler that it should IRET immediately
	bt	cs:[statusword],6
	jnc	@F
	bts	cs:[statusword],9

@@:
	; return with CF clear
	push	bp
	mov	bp,sp
	btr	word ptr [bp+6],0	; Flags = BP+6 since we've got the pushed BP
	pop	bp
	iret
tpls_int2f	endp
stubdos	ends

; Protected-Mode code, injected into the sound driver at the first possible opportunity
; Kept in Conventional or Expanded Memory before injection
payload	segment use32
; Make sure it fits on an EMS page...
.errnz ((end_of_payload-$) gt 4000h)

	; FS error to avoid accidentally poking the sound driver...
	assume	fs:error,ds:nothing,es:nothing,gs:nothing

	cmp	al,1
	je	@@uninit

	cmp	cs:[RealDrv_CS],0
	jnz	@F
	call	setup_selectors
@@:
	push	ds
	push	edi
	mov	ds,cs:[mydatasel]
	assume	ds:payload

	; init code
	push	gs
	call	get_stub_seg
	jc	@@stubseg_failure
	assume	gs:stub
	; turn off HMIDRV.386 redirect as the real file may need to be opened for the timer driver!
	btr	gs:[statusword],1

	test	al,al	; init function?
	jnz	@@passthrough
	bts	gs:[statusword],3

	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi

	push	es
	push	ds
	mov	ax,35F5h; get interrupt vector
	int	21h
	mov	[old_intF5_off],ebx
	mov	[old_intF5_seg],es

	; install our hook function
	mov	ax,25F5h; set interrupt vector
	push	cs
	pop	ds
	mov	edx,offset hook_handler
	int	21h

	; On Win9x, we don't allocate an RM callback, but just let the int 31h handler call the payload directly
	bt	gs:[statusword],6
	jc	@F

	mov	ax,303h	; allocate RM callback
	mov	esi,offset callback_fromstub
	pop	es	; get saved DS from stack
	mov	edi,offset callback_RMCS
	int	31h
	mov	gs:[callback_off],dx
	mov	gs:[callback_seg],cx

	push	es	; restore DS on stack to what it was
	jmp	@@callback_done

@@:
	mov	gs:[payload_cs],cs

@@callback_done:
	pop	ds
	pop	es

	lgs	edi,[ebp-24h]	; points at return addx of driver immediately below sosDRVInit's stack frame
	assume	gs:nothing
	mov	[rayman_cs],gs
	mov	edi,[ebp+4]	; return addx of sosDRVInit itself
	call	fixup_textptrs

	lgs	edi,[ebp+0C8h]	; lpInitStruct on stack frames in Rayman's SOS interface code
	mov	[rayman_ds],gs
	call	fixup_dataptrs

	mov	ax,6	; get base addx
	mov	bx,cs:[rayman_cs]
	int	31h
	mov	di,cx
	shl	edi,10h
	mov	di,dx

	mov	ax,6	; get base addx
	mov	bx,cs:[rayman_ds]
	int	31h
	shl	ecx,10h
	mov	cx,dx
	mov	ax,bx
	cmp	ecx,edi
	je	@F	; no need for alias

	mov	ax,0Ah	; create alias
	mov	bx,cs:[rayman_cs]
	int	31h

@@:
	mov	[rayman_cs_asds],ax

	; Read in the "MIDI" track data
	lea	edx,midi_file_name
	call	read_ambient_file
	jc	@F
	mov	[midi_file_seg],ax
	mov	[midi_file_hdl],esi
	mov	[midi_file_size],ecx
@@:

	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax

	call	setup_tracknos
	; we can setup lengths from here because (unlike TPLSTSR3)
	; this function only runs when Rayman is setting up sound
	; (i.e. long after the CD init code is over and done with)
	call	setup_tracklens
	call	setup_hooks

@@passthrough:
	pop	gs
	pop	edi
	pop	ds
	assume	ds:nothing
	; FS should be OK here
	jmp	cs:lpRealDrv

@@stubseg_failure:
	mov	edx,offset stubseg_error
	call	bailout

@@uninit:
	cmp	cs:[RealDrv_CS],0
	jz	@F

	; FS should be OK, since RealDrv_CS isn't zero
	; (i.e. setup_selectors has been called)
	call	cs:lpRealDrv	; let the driver uninit itself
	call	free_selectors

@@:
	push	gs
	push	ds
	push	fs
	pop	ds	; make sure DS is OK for get_stub_seg
	call	get_stub_seg
	pop	ds
	jc	@F
	assume	gs:stub
	btr	gs:[statusword],3
	bts	gs:[statusword],1
@@:
	pop	gs
	assume	gs:nothing
	retf

; Subroutines from here are called from within init code
; which has a good DS setup.
assume	ds:payload

; Takes a pointer to the sosDRVInit retpoint in EDI and fixes up
; all our pointers to Rayman's text section accordingly
fixup_textptrs	proc near	uses esi
	; get the delta between the current fixup and anything previously applied
	; (in case init gets called more than once for any bizarre reason)
	sub	edi,[psosDRVInit_ret]
	add	[psosDRVInit_ret],edi
	mov	esi,offset psosDRVInit_ret + 4
	.while	esi < end_textptrs
	   cmp	dword ptr [esi],0
	   jz	@F	; don't fixup null ptrs!
	   add	[esi],edi
@@:
	   add	esi,4
	.endw
	ret
fixup_textptrs	endp

; Takes a pointer to the InitStruct in EDI and fixes up all our pointers to Rayman's data section accordingly
fixup_dataptrs	proc near	uses esi
	; get the delta between the current fixup and anything previously applied
	; (in case init gets called more than once for any bizarre reason)
	sub	edi,[psos_InitStruct]
	mov	esi,offset psos_InitStruct + 4
	.while	esi < end_dataptrs
	   add	[esi],edi
	   add	esi,4
	.endw
	ret
fixup_dataptrs	endp

; write all the correct TPLS track numbers into the level track table
; and into the logo / menu / etc. code
setup_tracknos	proc near	uses es eax ebx edx
	mov	es,[rayman_ds]
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

@@:
	ret
setup_tracknos	endp

; write all the correct TPLS track lengths into the level track length table,
; assuming setup_tracknos has already been called
setup_tracklens	proc near	uses es edi esi edx ecx ebx eax ebp
	mov	es,[rayman_ds]
	mov	esi,[ptrack_table]
	mov	edi,[ptimeCd]
	mov	ebp,[prbook_lentable]
	mov	ecx,129			; length of the track table (for some reason)

	cld

@@tracklen_loop:
	xor	eax,eax
	lodsb	es:[esi]		; load the track index into EAX
	mov	eax,es:[ebp+eax*4]	; the EAXth entry of the Redbook length table

	mov	ebx,75
	xor	edx,edx
	add	eax,74			; round up
	div	ebx			; convert sectors to seconds by dividing by 75

	stosd				; store the length in seconds into the length table
	loop	@@tracklen_loop

	ret
setup_tracklens	endp

; insert all the hooks we need into Rayman's text
setup_hooks	proc near	uses ecx edx
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
	mov	edx,[pExitSign1]
	call	set_hookpoint
	mov	edx,[pExitSign2]
	call	set_hookpoint
	mov	edx,[pPerdu]
	call	set_hookpoint

	; Hooks to delay level transition until fanfare CD audio has fully played out
	mov	edx,[pExitSignEOA1]
	call	set_hookpoint
	mov	edx,[pExitSignEOA2]
	call	set_hookpoint
	mov	edx,[pExitSignEOA3]
	call	set_hookpoint
	mov	edx,[pDoAnimFrozen]
	call	set_hookpoint

	; Hooks to select the language-appropriate cutscene music
	mov	edx,[pPlayIntro]
	test	edx,edx
	jz	@F
	call	set_hookpoint
	mov	edx,[pPlayOuttro]
	test	edx,edx
	jz	@F
	call	set_hookpoint

@@:	; Hook to fix the stupid _dos_read wrapper that crashes the game
	mov	edx,[pCutsceneRead]
	test	edx,edx
	jz	@F
	call	set_hookpoint

@@:	; Hooks to enable "MIDI" tracks (if available)
	cmp	[midi_file_seg],0
	jz	@F
	mov	edx,[pStartVignette]
	call	set_hookpoint
	mov	edx,[pObjectsLoaded]
	call	set_hookpoint
	mov	edx,[pManageSndEvent]
	call	set_hookpoint
	mov	edx,[pStartCDbbdead]
	call	set_hookpoint
	mov	edx,[pStartFreezeSnd]
	call	set_hookpoint
	mov	edx,[pStopFreezeSnd]
	call	set_hookpoint

@@:
	ret
setup_hooks	endp

; Get the stub segment into GS
; CF clear on success, set on failure
; Sets it up if it isn't already there - in this case, DS must point to payload!
get_stub_seg	proc near	uses ax ebx ecx edx
	mov	ax,cs:[stub_selector]
	test	ax,ax		; clears CF
	jnz	@@ok

	mov	ax,2		; segment to selector
	mov	bx,stub
	int	31h
	jnc	@F

	; if there aren't any Real-Mode selectors left, try the hard way
	xor	ax,ax	; alloc selectors
	mov	cx,1	; just one
	int	31h
	jc	@@retpoint

	movzx	edx,bx	; stub segment
	movzx	ebx,ax
	mov	ax,7	; set base addx
	shl	edx,4	; convert to linear addx
	mov	ecx,edx
	shr	ecx,10h
	int	31h
	jc	@@retpoint

	mov	ax,8		; set limit
	xor	cx,cx
	or	dx,-1		; full 16-bit segment
	int	31h
	jc	@@retpoint

	lar	ecx,ebx
	stc
	jnz	@@retpoint

	shr	ecx,8
	mov	ax,9		; set rights
	int	31h
	jc	@@retpoint

	mov	ax,bx
@@:
	; This is where DS must point to payload!
	mov	[stub_selector],ax
@@ok:
	mov	gs,ax
@@retpoint:
	ret
get_stub_seg	endp

setup_selectors	proc near	uses eax ebx ecx edx ds esi
	; When we come in here, FS is freshly setup by Rayman
	; to point *at us*, so we can use it. We'll be moving
	; it shortly though!
	assume	fs:payload,ds:nothing

	mov	esi,cs
	mov	ax,0Ah		; create alias
	mov	bx,si
	int	31h
	jc	@@no_selectors_badds
	mov	fs:[mydatasel],ax

	mov	ds,ax
	assume	ds:payload

	xor	ax,ax	; alloc selectors
	mov	cx,1	; do CS first
	int	31h
	jc	@@no_selectors
	mov	[RealDrv_CS],ax

	mov	ax,6	; get base addx
	;mov	bx,si
	int	31h
	jc	@@no_selectors
	mov	eax,offset end_of_payload
	mov	ebx,eax
	shr	ebx,10h
	add	dx,ax
	adc	cx,bx

	mov	ax,7	; set base addx
	mov	bx,[RealDrv_CS]
	int	31h
	jc	@@no_selectors

	; set Rayman-provided FS to point to the sound driver!
	mov	ax,7	; set base addx
	mov	bx,fs
	int	31h
	jc	@@no_selectors

	; reload it
	mov	fs,bx
	; now it points at the driver, which we don't screw with!
	assume	fs:error

	lsl	edx,esi
	sub	edx,offset end_of_payload
	mov	ecx,edx
	shr	ecx,10h

	mov	ax,8		; set limit
	int	31h
	jc	@@no_selectors

	mov	ax,8		; set limit
	mov	bx,[RealDrv_CS]
	int	31h
	jc	@@no_selectors

	lar	ecx,esi
	jnz	@@no_selectors

	shr	ecx,8
	mov	ax,9		; set rights
	int	31h
	jc	@@no_selectors

	ret

@@no_selectors_badds:
	assume	fs:payload
	push	fs
	pop	ds
@@no_selectors:
	assume	fs:error
	mov	edx,offset outofselectors
	call	bailout
setup_selectors	endp

free_selectors	proc near	uses ax bx ecx edx esi
	mov	ax,1	; free selector
	xor	bx,bx
	xchg	bx,[RealDrv_CS]
	int	31h

	mov	esi,cs
	mov	ax,6	; get base addx
	mov	bx,si
	int	31h

	; set Rayman-provided FS to point back to us!
	mov	ax,7	; set base addx
	mov	bx,fs
	int	31h

	lsl	edx,esi
	sub	edx,offset end_of_payload
	mov	ecx,edx
	shr	ecx,10h

	mov	ax,8		; set limit
	int	31h

	ret
free_selectors	endp

; Play the ALth audio track in the "MIDI" file
play_ambient_track	proc near	uses es
	pushad
	; Convert byte track index to dword
	cbw
	cwde

	mov	es,[midi_file_seg]
	assume	es:nothing
	; Clamp within the tracks available (count is at ES:4)
	cmp	eax,es:[4]
	jb	@F
	mov	eax,es:[4]
	dec	eax
@@:
	; Set ESI to offset and EDX to length
	mov	esi,es:[eax*8+8]
	mov	edx,es:[eax*8+0Ch]

	; Already playing this track?
	cmp	[midi_cur_track],eax
	je	@F
	; Remember which track we're playing
	mov	[midi_cur_track],eax

	sub	esp,size _SOS_START_SAMPLE
	push	ss
	pop	es
	mov	edi,esp

	mov	ecx,(size _SOS_START_SAMPLE) SHR 2
	xor	eax,eax
	rep	stosd

	; Use #3, since Rayman uses #2 (and Designer also uses #1)
	mov	[esp]._SOS_START_SAMPLE.wSampleID,3
	; Play the *mono* PCM data across both channels
	mov	[esp]._SOS_START_SAMPLE.wChannel,2
	; Max volume
	mov	[esp]._SOS_START_SAMPLE.wVolume,7FFFh

	; Point at the data
	mov	dword ptr [esp]._SOS_START_SAMPLE.lpSamplePtr,esi
	mov	cx,[midi_file_seg]
	mov	word ptr [esp+4]._SOS_START_SAMPLE.lpSamplePtr,cx
	; Set the length
	mov	[esp]._SOS_START_SAMPLE.dwSampleSize,edx

	; Make it loop
	mov	[esp]._SOS_START_SAMPLE.wSampleFlags, _STAGE_LOOP+_LOOPING
	; Loop the full thing, from the beginning!
	mov	[esp]._SOS_START_SAMPLE.dwSampleLoopLength,edx
	mov	[esp]._SOS_START_SAMPLE.dwSampleLoopPoint,eax
	; Loop forever
	mov	[esp]._SOS_START_SAMPLE.wLoopCount,-1

	; Call the function
	mov	ecx,ss		; segment of lpStartSample
	mov	ebx,esp		; offset of lpStartSample
	mov	eax,[pdwDETDriverIndex]
	mov	es,[rayman_ds]
	mov	eax,es:[eax]	; int drvindex

	call	sosDIGIStartSample
	mov	[midi_sample_idx],eax

	add	esp,size _SOS_START_SAMPLE
@@:
	popad
	ret
play_ambient_track	endp

stop_ambient_track	proc near
	mov	ecx,[midi_sample_idx]
	test	cx,cx
	js	@F	; skip if negative

	pushad
	mov	edx,ecx	; int sample
	mov	eax,[pdwDETDriverIndex]
	mov	eax,es:[eax]
	call	sosDIGIStopSample
	popad

@@:
	xor	ecx,ecx
	dec	ecx
	; Set these to -1 to indicate no ambient playing anymore
	mov	[midi_sample_idx],ecx
	mov	[midi_cur_track],ecx
	ret
stop_ambient_track	endp

assume	ds:nothing

; Call a "near" function in Rayman (offset in EDI) from within the payload.
; This code is pretty evil tbh, but we're just using it to interact with the sound system.
call_code_in_rayman	proc near
	push	ds
	push	es
	; Make sure the segments are sane...
	mov	ds,[rayman_ds]
	mov	es,[rayman_ds]

	; Create a RETF frame so the called function will return here
	push	cs
	push	offset @F
	; Create a RETN frame so the near function will return to a RETF trampoline
	push	[pConvenientRetF]
	; Create a RETF frame so we can "return" to the desired code in Rayman
	push	dword ptr [rayman_cs]
	push	edi
	; "Return" to Rayman's code
	retf
@@:
	; OK, Rayman's code should have returned to us now - return to our (near) caller
	pop	es
	pop	ds
	ret
call_code_in_rayman	endp

; int sosDIGIStartSample@<eax>(int drvidx@<eax>, _SOS_START_SAMPLE far *lpStartSample@<cx:ebx>);
; This is a wrapper function that calls through to the actual sosDIGIStartSample in Rayman's code
sosDIGIStartSample	proc near
	mov	edi,[psosDIGIStart]
	jmp	call_code_in_rayman
sosDIGIStartSample	endp

; int __fastcall sosDIGIStopSample(int drvidx, int sample);
; This is a wrapper function that calls through to the actual sosDIGIStopSample in Rayman's code
sosDIGIStopSample	proc near
	mov	edi,[psosDIGIStop]
	jmp	call_code_in_rayman
sosDIGIStopSample	endp

; Open an audio file (name in DS:EDX), allocate a buffer, read it in,
; and return:
; * CF clear on success, set on failure
; * Selector for audio data in AX
; * Memory block handle in ESI
; * Size in ECX
read_ambient_file	proc near	uses edx ebp ds bx di
	mov	ax,3D00h	; OPEN read-only
	int	21h
	jnc	@F
	ret
@@:
	mov	bx,ax
	mov	ax,4202h	; LSEEK from end
	xor	cx,cx
	mov	dx,cx
	int	21h

	; Now the filesize is in DX:AX --> save in EBP...
	mov	bp,dx
	shl	ebp,10h
	mov	bp,ax
	; and allocate this much memory
	xchg	bx,dx		; keep the file handle in DX!
	mov	cx,ax
	mov	ax,501h		; allocate Protected Mode memory
	int	31h
	xchg	bx,dx		; file handle back into BX
	jc	@@close_and_ret

	; Now the address is in DX:CX, and the handle in SI:DI
	shl	esi,10h
	mov	si,di		; get the full handle value into ESI
	; Next we need to create a selector to point at this memory
	mov	di,cx		; save lower half of linear address
	xor	ax,ax		; alloc selectors
	mov	cx,1		; just the one
	int	31h
	jc	@@free_and_fail

	; Selector is now in AX - need to set its base to DX:DI...
	mov	cx,dx
	mov	dx,di
	mov	di,bx		; save file handle in DI
	mov	bx,ax		; get selector into BX
	mov	ax,7		; set base address
	int	31h
	jc	@@free_selector_and_fail

	; ... and its size to EBP
	mov	ax,8		; set limit
	dec	ebp		; limit = size-1
	mov	dx,bp
	ror	ebp,10h
	mov	cx,bp
	ror	ebp,10h
	inc	ebp		; restore the size
	test	cx,cx
	jz	@F
	or	dx,0FFFh	; round up to nearest page!
@@:	int	31h
	jc	@@free_selector_and_fail

	; Go back to the beginning of the file...
	mov	ds,bx		; prepare to read into our new selector
	mov	ax,4200h	; LSEEK from beginning
	mov	bx,di		; file handle was saved in DI
	xor	ecx,ecx
	mov	edx,ecx
	int	21h

	; ... and now we can read it into the segment!
	mov	ah,3Fh		; READ
	mov	ecx,ebp		; count
	; EDX is already zero from above (read to beginning of segment)
	int	21h

	mov	ecx,ds:[0]	; Get the signature for verification
	mov	bx,ds		; BX needs to be selector if we fail
	mov	ds,dx		; zero DS in case we fail
	jc	@@free_selector_and_fail

	; Check the signature...
	cmp	ecx,'T' + ('P' SHL 8) + ('L' SHL 10h) + ('S' SHL 18h)
	; If they are equal, it also keeps CF clear
	jne	@@free_selector_and_fail

	; We're done!
	xchg	bx,di		; get file handle in BX so we can close it

@@close_and_ret:
	setc	cl		; remember carry flag!
	mov	ah,3Eh		; CLOSE
	int	21h
	rcr	cl,1		; restore carry

	jc	@F
	mov	ax,di		; get selector into AX for return
	mov	ecx,ebp		; get size into ECX for return
@@:
	ret

; Free the selector and fail the function call
@@free_selector_and_fail:
	mov	ax,1		; free selector
	int	31h
	; File handle was saved in DI, get it back into BX
	mov	bx,di
; Free the memory and fail the function call
@@free_and_fail:
	; Memory handle should be in ESI, get it into SI:DI
	mov	di,si
	shr	esi,10h
	mov	ax,502h		; free Protected Mode memory
	int	31h
	; Indicate failure:
	stc
	jmp	@@close_and_ret
read_ambient_file	endp

; We're screwed - print a message (in EDX)
; and pull down the entire program
bailout		proc near
	mov	ax,3	; switch to VGA text mode
	int	10h

	mov	ah,9	; write to stdout
	int	21h

	mov	ax,4CFFh; EXIT with status FFh
	int	21h
bailout		endp

align	4
lpRealDrv	label fword
		dd 0
RealDrv_CS	dw 0
mydatasel	dw ?

NUM_HOOKS	equ 50	; more than we'll ever need, hopefully!
hook_addxs	dd NUM_HOOKS dup (0)
hook_origcode	dw NUM_HOOKS dup (0F5CDh)
cur_trig_hook	dw -1

; Pointers to code in Rayman
psosDRVInit_ret	dd 0
pCreditsTrackNo	dd ?
pLogoTrackNo	dd ?
pMenuTrackNo	dd ?
pGOverTrackNo	dd ?
pPlayIntro	dd 0	; For single-lang versions, intro/outtro track number is fixed,
pPlayOuttro	dd 0	;  so we inject our own code to calculate from the lang value
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
pCutsceneRead	dd 0	; A wrapper function for _dos_read which is broken in v1.21 US
pConvenientRetF	dd ?	; Finds a convenient RETF, steps outta the shade, says something like...
psosDIGIStart	dd ?	; Function in Rayman's code to play a sound sample
psosDIGIStop	dd ?	; Function in Rayman's code to stop a sound sample
pStartVignette	dd ?	; Game shows "loading" vignette, we start playing the drums!
pObjectsLoaded	dd ?	; Objects have all been loaded from a LEV file, and fixed up
pManageSndEvent	dd ?	; Null function associated with "Ambient Starter" collision
pStartCDbbdead	dd ?	; Call to "start_cd_rap" from "PlaySnd", when a boss is defeated
pStopCD		dd ?	; Function in Rayman's code to stop CD audio and reset the timer
pStartFreezeSnd	dd ?	; Function in Rayman's code to freeze sound when game is paused
pStopFreezeSnd	dd ?	; Function in Rayman's code to unfreeze sound when game is resumed
pExitSignEOA1	dd ?	; Exit sign code is checking if Rayman's animation has finished:
pExitSignEOA2	dd ?	;; We need it to believe the answer is "NO" at least until our CD
pExitSignEOA3	dd ?	;; audio is finished playing!
pDoAnimFrozen	dd ?	; Call to "DO_ANIM" on Rayman while game is otherwise frozen on exit sign
end_textptrs:

; Pointers to data in Rayman
psos_InitStruct	dd 0
pnum_world	dd ?
pnum_level	dd ?
ptrack_table	dd ?	; Pointer to level track assignment table (static)
ptimeCd		dd ?
pcdTime		dd ?	; How long has the track been playing? Set to zero to restart.
;prbook_table	dd ?	; Pointer to table of Redbook track info (populated @ runtime)
prbook_lentable	dd ?
;prbook_tablefl	dd ?	; Pointer to flag indicating latter table is populated
;plowest_atrack	dd ?
;phighest_atrack	dd ?
;pcd_driveletter dd ?	; Pointer to Rayman's CD-ROM drive letter
plang		dd ?
pdwDETDriverIndex dd ?	; Pointer to Rayman's SOS driver index
plevel		dd ?	; Pointer to level info
pflagCDPlay	dd ?	; Frame counter from when CD track ends to when it starts again (four frames)
end_dataptrs:

; Track on-the-fly music tampering
plen_to_restore	dd ?
ptra_to_restore	dd ?
len_to_restore	dd ?
tra_to_restore	db 0
music_dirty	db 0	; Have we messed with the music and need to restart it?

align	2
stub_selector	dw 0
rayman_cs	dw ?	; Rayman's code segment
rayman_cs_asds	dw 0	; Rayman's code segment as a data segment, for poking!
rayman_ds	dw ?

align	4
callback_RMCS	rmcall <?>

old_intF5	label fword
old_intF5_off	dd ?
old_intF5_seg	dw ?

; Ambient Starters to inject
injection_table:
	; Pink Plant Woods part 2: we can replace one BALLE1 which leaves four spare for the one hunter in the map...
	InjectableAmbientStarter<1,2,991,375,1,TYPE_BALLE1>

	; Bongo Hills part 4: we can replace BNOTE because (thankfully!) there are loads of them, and Mister Sax isn't in the map
	InjectableAmbientStarter<2,4,1310,288,3,TYPE_BNOTE>
	InjectableAmbientStarter<2,4,2663,355,0,TYPE_BNOTE>
	InjectableAmbientStarter<2,4,236,546,3,TYPE_BNOTE>
	InjectableAmbientStarter<2,4,2834,686,4,TYPE_BNOTE>
	InjectableAmbientStarter<2,4,1674,790,0,TYPE_BNOTE>
	InjectableAmbientStarter<2,4,2736,829,4,TYPE_BNOTE>

	; Twilight Gulch part 1: we can replace BB1_PLAT because Mister Stone isn't in the map
	InjectableAmbientStarter<3,1,83,15,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,1,540,93,5,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,1,1496,114,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,1,1915,133,6,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,1,372,316,0,TYPE_BB1_PLAT>
	; No BB1_PLATs left, so steal one each of these four, and hope there aren't any noticeable consequences...
	InjectableAmbientStarter<3,1,2121,341,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<3,1,2056,431,0,TYPE_BALLE1>
	InjectableAmbientStarter<3,1,2153,504,5,TYPE_NOVA2>
	InjectableAmbientStarter<3,1,520,581,6,TYPE_STONECHIP>

	; Twilight Gulch part 2: we can replace BB1_PLAT because Mister Stone doesn't throw those in this map
	InjectableAmbientStarter<3,2,4665,507,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,2,1953,621,7,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,2,5593,772,7,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,2,6876,773,0,TYPE_BB1_PLAT>

	; Hard Rocks part 3: we can replace BB1_PLAT because Mister Stone isn't in the map
	InjectableAmbientStarter<3,5,802,34,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,5,0,383,5,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,5,429,383,6,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,5,275,713,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,5,135,833,0,TYPE_BB1_PLAT>
	; No BB1_PLATs left, so steal one each of these five, and hope there aren't any noticeable consequences...
	InjectableAmbientStarter<3,5,513,1223,5,TYPE_EXPLOSION>
	InjectableAmbientStarter<3,5,749,2091,0,TYPE_BALLE1>
	InjectableAmbientStarter<3,5,812,2090,0,TYPE_NOVA2>
	InjectableAmbientStarter<3,5,874,2090,0,TYPE_STONECHIP>
	InjectableAmbientStarter<3,5,939,2298,6,TYPE_PIEDS_RAYMAN>

	; Mister Stone's Peaks part 4: we can replace BB1_PLAT because Mister Stone isn't in the map
	InjectableAmbientStarter<3,9,3630,146,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,9,5073,259,6,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,9,7133,534,0,TYPE_BB1_PLAT>
	InjectableAmbientStarter<3,9,2850,809,6,TYPE_BB1_PLAT>

	; Eraser Plains part 1: I think we can replace EXPLOSION because, although there are loads of them, I can't think of anything in this map that actually uses them...
	InjectableAmbientStarter<4,1,840,14,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,1,1640,107,8,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,1,3102,160,8,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,1,830,249,8,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,1,827,319,8,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,1,2382,304,0,TYPE_EXPLOSION>

	; Space Mama's Crater part 2: I think we can replace EXPLOSION because, although there are loads of them, I can't think of anything in this map that actually uses them...
	InjectableAmbientStarter<4,9,3968,3,8,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,2017,117,8,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,3251,156,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,3372,188,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,3250,232,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,3371,255,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,4368,309,0,TYPE_EXPLOSION>
	InjectableAmbientStarter<4,9,4637,382,0,TYPE_EXPLOSION>
	; No EXPLOSIONs left, so steal the unused "Rayman's feet" object
	InjectableAmbientStarter<4,9,3520,508,8,TYPE_PIEDS_RAYMAN>

	; Eat At Joe's part 4: steal two (of five) NOVA2s, and the unused "Rayman's feet" object
	InjectableAmbientStarter<5,6,974,121,10,TYPE_PIEDS_RAYMAN>
	InjectableAmbientStarter<5,6,46,468,0,TYPE_NOVA2>
	InjectableAmbientStarter<5,6,1225,450,10,TYPE_NOVA2>

	; Mister Dark's Dare part 2: we can replace SPLASH because there is no water in the map
	; Note that there are ten Ambient Starters in this map in the PS1 version, but mercifully, five of them also exist in the PC version!
	; This means we only need to inject five more:
	InjectableAmbientStarter<6,2,5064,192,0,TYPE_SPLASH>
	InjectableAmbientStarter<6,2,5595,288,12,TYPE_SPLASH>
	InjectableAmbientStarter<6,2,5596,363,12,TYPE_SPLASH>
	InjectableAmbientStarter<6,2,2045,397,11,TYPE_SPLASH>
	InjectableAmbientStarter<6,2,5491,397,12,TYPE_SPLASH>
end_injection_table:

midi_file_seg	dw 0	; Selector pointing at "MIDI" track data
midi_file_hdl	dd ?	; Memory block handle for that segment
midi_file_size	dd ?	; Size of that memory block
midi_sample_idx	dd -1	; Sample index of currently-playing "MIDI" track
midi_cur_track	dd -1	; Which "MIDI" track is currently playing
; Filename for "MIDI" track data - TODO: find it in same dir as TSR EXE
midi_file_name	db "AMBIENTS.DAT",0

; Error messages
outofselectors	db 33o,"[35m","Error setting up selector(s).",13,10
		db "Payload cannot init real sound driver.",33o,"[37m",13,10,"$"
stubseg_error	db 33o,"[35m","Error setting up selector.",13,10
		db "Payload cannot communicate with Real-Mode stub.",33o,"[37m",13,10,"$"

assume	ds:nothing,es:nothing,fs:nothing,gs:nothing

callback_fromstub proc
	; Reactivate all hookpoints.
	; NB: Because this happens here, we need to make sure int 2Fh
	; never gets called from within the hookpoint handler!
	mov	ds,cs:[mydatasel]
	assume	ds:payload

	movzx	ecx,[cur_trig_hook]
	call	hook_activate
	mov	[cur_trig_hook],-1

	call	get_stub_seg
	assume	gs:stub
	; send it back to the int 2F handler
	mov	eax,gs:[old_int2f]
	mov	dword ptr es:[edi.rmcall._ip],eax
	iretd
	assume	ds:nothing,gs:nothing
callback_fromstub endp

; bool hook_active(int idx@<ecx>);
; ZF clear if hookpoint is active, set if inactive
hook_active	proc near
	cmp	cs:hook_origcode[ecx*2],0F5CDh
	ret
hook_active	endp

; void hook_activate(int idx@<ecx>);
; Activates the idx-th hookpoint if it's inactive.
hook_activate	proc near
	call	hook_active
	jnz	@F
	push	eax
	call	hook_swapcode
	pop	eax
@@:
	ret
hook_activate	endp

; void hook_deactivate(int idx@<ecx>);
; Dectivates the idx-th hookpoint if it's active.
hook_deactivate	proc near
	call	hook_active
	jz	@F
	push	eax
	call	hook_swapcode
	pop	eax
@@:
	ret
hook_deactivate	endp

; int hook_find@<ecx>(void *addx@<eax>);
; Finds and returns the index of the *last* hookpoint in the list
; corresponding to the given addx.
; If none, returns -1
hook_find	proc near	uses es edi
	mov	es,cs:[mydatasel]

	mov	edi,(offset hook_origcode)-4
	mov	ecx,NUM_HOOKS
	std
	repne	scasd
	je	@F
	or	ecx,-1

@@:
	cld
	ret
hook_find	endp

; ushort hook_swapcode@<eax>(int idx@<ecx>);
; Swaps the word at the idx-th hookpoint in the text section
; with the word stored in the table
hook_swapcode	proc near	uses ds ebx edx
	mov	ax,cs:hook_origcode[ecx*2]
	mov	edx,cs:hook_addxs[ecx*4]
	mov	ebx,2			; poke a word

	call	poketext
	mov	ds,cs:[mydatasel]
	assume	ds:payload
	mov	hook_origcode[ecx*2],ax		; store the word we just replaced

	ret
	assume	ds:nothing
hook_swapcode	endp

; int __fastcall poketext(int data, void *addx, unsigned char size)
; Inserts a byte/word/dword (depending on "size") into Rayman's code segment
; at the given addx, and returns what was there before.
poketext	proc near
	push	es
	mov	es,cs:[rayman_cs_asds]
	bt	ebx,0			; single byte?
	jnc	poketext_notbyte
	xchg	al,es:[edx]
	jmp	poketext_retpoint

poketext_notbyte:
	bt	ebx,1			; word?
	jnc	poketext_notword
	xchg	ax,es:[edx]
	jmp	poketext_retpoint

poketext_notword:
	xchg	eax,es:[edx]		; default to dword (we are 32-bit after all!)
poketext_retpoint:
	pop	es
	ret
poketext	endp

; int set_hookpoint@<ecx>(void *addx@<edx>)
; Sets a hookpoint for *execution* at the given addx in Rayman's *code* segment.
set_hookpoint	proc near	uses ds eax
	xor	eax,eax
	call	hook_find		; find a null hookpoint

	mov	ds,cs:[mydatasel]
	assume	ds:payload
	mov	hook_addxs[ecx*4],edx; set the address

	call	hook_activate		; activate the new hookpoint!
	ret

	assume	ds:nothing
set_hookpoint	endp

; void clear_hookpoint(int idx@<ecx>)
clear_hookpoint	proc near	uses ds
	call	hook_deactivate		; first, make sure it's inactive!

	mov	ds,cs:[mydatasel]
	assume	ds:payload
	mov	hook_addxs[ecx*4],0

	ret
	assume	ds:nothing
clear_hookpoint	endp

; void __fastcall change_music(char newtrack);
; Changes the music track (and corresponding length) for the current level and plays
change_music	proc near
	assume	ds:payload	; always called from inside the hook handler...
	; Also, without this assume line, the assembler generates crashing code!

	push	edx
	push	ecx
	push	ebx

	mov	ecx,[pnum_world]
	mov	edx,[pnum_level]
	movzx	ecx,word ptr es:[ecx]
	dec	ecx

	mov	ebx,ecx
	shl	ebx,4			; EBX = (num_world - 1) * 16
	lea	ebx,[ebx+ecx*4]		; EBX = (num_world - 1) * 20
	lea	ebx,[ebx+ecx*2]		; EBX = (num_world - 1) * 22
	add	bx,[es:edx]		; EBX = (num_world - 1) * 22 + num_level

	mov	edx,[ptrack_table]
	mov	cl,al
	lea	edx,[edx+ebx]
	xchg	es:[edx],cl
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
change_music	endp

; =================================================
; == HANDLER for our hooking mechanism on int F5 ==
; =================================================
hook_handler	proc
	assume	ds:nothing		; we're coming from Rayman's code

	sub	dword ptr [esp],2	; rewind to before the int 0F5h instruction
	push	ebp
	lea	ebp,[esp+4]		; convenient pointer to stack frame
	push	ds			; yes PluM, in 32-bit mode, segment pushes are 32 bits...
	push	es
	mov	ds,cs:[mydatasel]	; our own data are of interest now!
	assume	ds:payload
	mov	es,[rayman_ds]

	push	eax
	push	ecx
	mov	eax,[ebp]		; the return addx
	call	hook_find
	call	hook_deactivate

	; update the currently-triggered hook
	xchg	cx,[cur_trig_hook]
	cmp	cx,-1
	je	@F
	; if there's another pending, reactivate it
	; by using the macro "debug_bell_saveregs", I have found this happens quite often!
	call	hook_activate
@@:

	; we'll want the hookpoint reactivated on the next MSCDEX call
	push	gs
	call	get_stub_seg
	assume	gs:stub
	bts	gs:[statusword],4
	; while we're here, check for a US version
	bt	gs:[statusword],0Ah
	; CL = 1 if US version, 0 otherwise
	setc	cl
	pop	gs
	assume	gs:nothing

	cmp	eax,[pLevelStart1]
	je	@@now_in_level
	cmp	eax,[pLevelStart2]
	je	@@now_in_level

	cmp	eax,[pLevelEnd1]
	je	@@no_longer_in_level
	cmp	eax,[pLevelEnd2]
	je	@@no_longer_in_level

	cmp	eax,[pStartVignette]
	je	@@world_loading
	cmp	eax,[pObjectsLoaded]
	je	@@objects_loaded
	cmp	eax,[pManageSndEvent]
	je	@@manage_snd_event
	cmp	eax,[pStartCDbbdead]
	je	@@start_cd_bbdead
	cmp	eax,[pStartFreezeSnd]
	je	@@start_freeze_snd
	cmp	eax,[pStopFreezeSnd]
	je	@@stop_freeze_snd

	cmp	eax,[pDoGrowingPlat]
	je	@@plant_growing
	cmp	eax,[pMoskitoLock]
	je	@@moskito_fight
	cmp	eax,[pMoskitoFast]
	je	@@moskito_ride_speedup
	cmp	eax,[pMoskitoSlow]
	je	@@no_longer_in_level	; restore default music

	cmp	eax,[pExitSign1]
	je	@@yay_fanfare
	cmp	eax,[pExitSign2]
	je	@@yay_fanfare
	cmp	eax,[pPerdu]
	je	@@snif_dead

	cmp	eax,[pExitSignEOA1]
	je	@@eoa_check
	cmp	eax,[pExitSignEOA2]
	je	@@eoa_check
	cmp	eax,[pExitSignEOA3]
	je	@@eoa_check
	cmp	eax,[pDoAnimFrozen]
	je	@@freeze_check

	cmp	eax,[pPlayIntro]
	je	@@cutscene
	cmp	eax,[pPlayOuttro]
	je	@@cutscene

	cmp	eax,[pCutsceneRead]
	je	@@cutscene_read

	; Dunno what hookpoint that was then...
@@retpoint:
	pop	ecx
	pop	eax
	pop	es
	pop	ds
	pop	ebp
	iretd

; Entering a level - restart the music if it's been tampered with...
@@now_in_level:
	call	stop_ambient_track

	xor	ecx,ecx
	cmp	[music_dirty],cl
	jz	@@retpoint

	; It's been tampered with - reset
	mov	eax,[pcdTime]
	mov	es:[eax],ecx
	mov	[music_dirty],cl
	jmp	@@retpoint

; Leaving a level - restore the default music track if needed, and mark as dirty.
@@no_longer_in_level:
	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jz	@@retpoint

	; It's been tampered with - reset
	cmp	eax,[pMoskitoSlow]
	jne	@@delayed_reset

	; Immediately set cdTime to zero to signal the game to play the restored track
	mov	eax,[pcdTime]
	mov	es:[eax],ecx
	jmp	@@reset_decided

@@delayed_reset:
	mov	[music_dirty],1		; set dirty flag so the restored track will play on level reentry

@@reset_decided:
	xchg	[tra_to_restore],cl
	mov	eax,[ptra_to_restore]
	mov	es:[eax],cl		; restore the default track number

	mov	ecx,[len_to_restore]
	mov	eax,[plen_to_restore]
	mov	es:[eax],ecx		; restore the default track length

	jmp	@@retpoint

; The world-loading vignette is appearing on the screen.
; Start the corresponding "MIDI" track...
@@world_loading:
	xor	al,al	; play the first track
	call	play_ambient_track
	jmp	@@retpoint

; A level has finished loading - check if we need to inject one or more Ambient Starters...
@@objects_loaded:
	mov	ecx,[pnum_world]
	mov	al,[es:ecx]
	mov	ecx,[pnum_level]
	mov	ah,[es:ecx]

	lea	ecx,injection_table
@@check_injection:
	; correct world/level pair?
	cmp	word ptr [ecx].InjectableAmbientStarter.bWorld,ax
	jne	@@next_injection

	push	ecx
	push	edi
	push	edx
	push	esi
	push	bx

	; BL --> hitpoints, BH --> object type to replace
	mov	bx,word ptr [ecx].InjectableAmbientStarter.bHitPoints
	; EDX --> X and Y position
	mov	edx,dword ptr [ecx].InjectableAmbientStarter.wXPos

	; Load the count and base of the object array
	mov	edi,[plevel]
	movzx	ecx,[es:edi].Rayman_LevelInfo.wObjCount
	mov	edi,[es:edi].Rayman_LevelInfo.pObjBase

@@obj_search_loop:
	; If we find the PNG object, hold onto it so we can copy the first four pointers
	cmp	[es:edi].Rayman_ObjData.ObjType,TYPE_POING
	jne	@F
	mov	esi,edi
@@:
	; Check if it's the type we want to replace
	cmp	byte ptr [es:edi].Rayman_ObjData.ObjType,bh
	lea	edi,[edi+size Rayman_ObjData]
	loopne	@@obj_search_loop
	jecxz	@F

	; Go back to the object we were just looking at
	sub	edi,size Rayman_ObjData
	; Turn it into an Ambient Starter
	mov	[es:edi].Rayman_ObjData.ObjType,TYPE_AUDIOSTART
	; Values from https://github.com/BinarySerializer/Ray1Map/blob/659ba4e3d078de77324d2025f95115868df08eab/EventManifests/Events.csv#L95
	mov	[es:edi].Rayman_ObjData.Etat,5
	mov	[es:edi].Rayman_ObjData.InitialEtat,5
	mov	[es:edi].Rayman_ObjData.SubEtat,65
	mov	[es:edi].Rayman_ObjData.InitialSubEtat,65
	mov	[es:edi].Rayman_ObjData.OffBX,64
	mov	[es:edi].Rayman_ObjData.OffBY,64
	mov	[es:edi].Rayman_ObjData.OffHY,64
	mov	[es:edi].Rayman_ObjData.FollowSprite,0
	mov	[es:edi].Rayman_ObjData.HitSprite,255

	; For reference here is the hexdump of an Ambient Starter object in CAKE/RAY2.LEV of Rayman v1.21 US:
	; 00070600                                             04 00  |................|
	; 00070610  00 00 04 00 00 00 04 00  00 00 02 00 00 00 00 00  |................|
	; 00070620  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	; 00070630  00 00 00 00 00 00 8c 0e  00 00 75 00 00 00 00 00  |..........u.....|
	; 00070640  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
	; 00070650  00 00 5c 00 00 00 00 00  00 00 00 00 00 00 00 00  |..\.............|
	; 00070660  00 00 00 00 00 00 00 00  00 00 00 00 00 00 1e 00  |................|
	; 00070670  00 00 00 00 00 00 40 40  00 00 41 05 00 00 00 00  |......@@..A.....|
	; 00070680  00 00 40 00 0b 00 07 ff  00 00 00 00 00 00 3e 00  |..@...........>.|
	; 00070690  00 00
	; This tells us that PC_Flags needs to be zero:
	mov	[es:edi].Rayman_ObjData.PC_Flags,0

	; Most importantly, set the position to the desired value:
	movsx	ecx,dx
	mov	[es:edi].Rayman_ObjData.InitialXPosition,dx
	mov	[es:edi].Rayman_ObjData.XPosition,ecx
	sar	edx,10h	; get the Y position from the upper half
	mov	[es:edi].Rayman_ObjData.InitialYPosition,dx
	mov	[es:edi].Rayman_ObjData.YPosition,edx

	; And the hitpoints:
	mov	[es:edi].Rayman_ObjData.HitPoints,bl
	mov	[es:edi].Rayman_ObjData.InitialHitPoints,bl

	; Now copy the four pointers from the beginning of the PNG object to this one:
	mov	ecx,4
	rep	movs dword ptr [es:edi],[es:esi]
	; Now ECX==0 and ES:EDI points at RuntimeCommandsPointer - nullify that:
	mov	[es:edi],ecx
	; Also nullify RuntimeLabelOffsetsPointer:
	mov	[es:edi+4],ecx

@@:	pop	bx
	pop	esi
	pop	edx
	pop	edi
	pop	ecx

@@next_injection:
	add	ecx,size InjectableAmbientStarter
	cmp	ecx,offset end_injection_table
	jb	@@check_injection
	jmp	@@retpoint

; Rayman's collided with an "Ambient Starter" - use its hitpoints to decide what track to play.
; Or, if they're zero, then stop any ambient that's playing!
@@manage_snd_event:
	; Get the EAX value from the stack (it's the pointer to the Ambient Starter object)
	mov	eax,[esp+4]
	; Grab the hitpoints
	mov	al,[es:eax].Rayman_ObjData.HitPoints
	test	al,al
	jz	@F
	call	play_ambient_track
	jmp	@@retpoint
@@:
	call	stop_ambient_track
	jmp	@@retpoint

; A boss has been defeated, and the game wants to start the menu music.
; Play the MIDI "Victory" music instead!
; TODO: Maybe this would sound better as a CD track? It would certainly simplify the code...
; But as a CD track, the looping wouldn't be as seamless...
@@start_cd_bbdead:
	; Skip over the call to start_cd_rap (since we will be calling MSCDEX from inside this handler!)
	add	dword ptr [ebp],5	; length of 32-bit near call instruction

	pushad
	; Stop currently-playing CD audio (this calls MSCDEX!)
	mov	edi,[pStopCD]
	call	call_code_in_rayman

	; Set cdTime to -1 so the game doesn't try to restart CD audio
	mov	edi,[pcdTime]
	mov	dword ptr es:[edi],-1
	popad

	mov	al,2
	call	play_ambient_track
	jmp	@@retpoint

; Game is being paused - stop the current ambient track!
@@start_freeze_snd:
	mov	eax,[midi_cur_track]
	test	eax,eax
	; negative means nothing playing
	js	@@retpoint

	call	stop_ambient_track
	; put this back for the moment so that stop_freeze_snd knows what to restart!
	mov	[midi_cur_track],eax
	jmp	@@retpoint

; Game is being resumed - restart any ambient track that got stopped!
; TODO: It would be nice to resume exactly where it left off, but I'm not sure if any
; mechanism for that exists within SOS, at least the version of it that Rayman uses...
@@stop_freeze_snd:
	xor	eax,eax
	dec	eax
	; set midi_cur_track to -1 to force play_ambient_track to restart it
	xchg	eax,[midi_cur_track]

	test	eax,eax
	; negative means nothing playing
	js	@@retpoint
	call	play_ambient_track
	jmp	@@retpoint

; Rayman's planted a seed - we should switch the music to Suspense if it's not already.
; No need to check the world/level, since there's only one level in the whole game where this happens...
@@plant_growing:
	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jnz	@@retpoint		; music already changed

	mov	al,10			; Suspense - The Flood
	call	change_music
	jmp	@@retpoint

; A mosquito fight is about to begin so the screen has been locked
@@moskito_fight:
	mov	ecx,[pnum_level]
	cmp	word ptr [es:ecx],6
	jne	@@retpoint		; it's not Anguish Lagoon

	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jnz	@@retpoint		; music already changed

	mov	al,7			; Bzzit Attacks
	call	change_music
	jmp	@@retpoint

; Rayman's riding a mosquito, who has just started going really fast - switch the music to "Hold on Tight!" if it's not already.
; No need to check the world/level, since there's only one level in the whole game where this happens...
@@moskito_ride_speedup:
	xor	ecx,ecx
	cmp	[tra_to_restore],cl
	jnz	@@retpoint		; music already changed

	mov	al,6			; Hold on Tight!
	call	change_music
	jmp	@@retpoint

; Rayman's reached the exit sign! Play a CD audio track to celebrate, like the PS1 and Saturn versions.
@@yay_fanfare:
	; We actually want to call Rayman's function to play a CD audio track,
	; and invoke it with track 29 (Rayman's victory fanfare).
	mov	eax,29			; Yeah!
	call	change_music
	mov	[music_dirty],80h	; set fanfare flag

	; Ensure it doesn't get interrupted
	mov	eax,[pflagCDPlay]
	mov	byte ptr es:[eax],0	; reset this so it only becomes non-zero when track ends...
	jmp	@@retpoint

; The game is frozen as Rayman's on an exit sign, and it's trying to decide whether or not to move to the next level.
; It has just called "EOA" on Rayman, and AL is non-zero iff Rayman's "yeah" animation has finished playing.
; We also want to zero AL if the CD audio of the fanfare is still playing!
@@eoa_check:
	test	[music_dirty],80h	; check fanfare flag
	jz	@@retpoint

	mov	eax,[pflagCDPlay]
	mov	al,es:[eax]
	test	al,al
	; If it's non-zero, then that means the music track is finished and the frame counter has started to increment.
	; That means we can allow the signpost code to continue as if EOA returned TRUE - so swap the return values!
	xchg	al,[esp+4]
	; If it wasn't zero, then all we need to do is reset the flags, below.
	jnz	@@fanfare_done

	; if we're here, it's still playing, so make sure the animation doesn't progress too far
	test	al,al			; check if EOA returned TRUE
	jz	@@retpoint
	; if it did, then set an additional flag so that we freeze Rayman until the CD audio is done:
	or	[music_dirty],40h
	jmp	@@retpoint

@@fanfare_done:
	mov	[music_dirty],0		; unset fanfare flag
	jmp	@@retpoint		; we're good, leave AL alone

; The game is frozen on an exit sign, but it's asking Rayman's sprite to animate. Check whether or not to allow this.
@@freeze_check:
	test	[music_dirty],40h
	jz	@@retpoint
	; OK, Rayman's reached the end of his "yeah" animation, so freeze him until the CD audio finishes.
	; We accomplish this by hopping over the call to "DO_ANIM":
	add	dword ptr [ebp],5
	jmp	@@retpoint

; Rayman is dead :( Play a CD audio track, like the PS1 and Saturn versions
@@snif_dead:
	assume	ds:payload
	; We want to return directly to Rayman's function to play a CD audio track,
	; and invoke it with track 30 (Rayman's death cries).
	; Unlike for the fanfare, there's no need to mess with stacks.
	; This is because we're replacing a JMP instruction that hops straight into
	; "PlayTchatchVignette", and we're just redirecting to the CD audio function.
	mov	eax,[pPlayTrack]
	mov	[ebp],eax
	mov	dword ptr [esp+4],30	; EAX --> Perdu
	mov	[music_dirty],1		; set dirty flag to restart level music when Rayman respawns
	; Ensure it doesn't get interrupted
	mov	eax,[pcdTime]
	mov	dword ptr es:[eax],-1	; wait forever before restarting music
	; Also stop any ambient that's playing
	call	stop_ambient_track
	jmp	@@retpoint

; game is about to play a cutscene - select the right music
@@cutscene:
	; CL was set above to indicate whether or not this is a US version -
	; put this into BH for a moment...
	mov	bh,cl

	mov	ecx,[plang]
	mov	bl,es:[ecx]		; BL contains the track number passed to the cutscene function
	add	bl,FIRSTINTROTRACK	; first intro track on custom CD image

	cmp	eax,[pPlayOuttro]
	jne	@@cutscene_adjust_us
	xor	bh,bh			; don't need this value
	add	bl,NUMINTROTRACKS	; add five more to get outro track
	jmp	@@retpoint

@@cutscene_adjust_us:
	rcr	bh,1			; check if the game is a US version
	jnc	@@retpoint
	cmp	byte ptr es:[ecx],0	; check if the language is English
	jne	@@retpoint
	dec	bl			; subtract 1 from intro track to get US one
	jmp	@@retpoint

; Rayman v1.21 US is trying to read from a cutscene file using botched code - do it properly!
@@cutscene_read:
	; First of all, this hookpoint can be triggered as many times as we like;
	; no need to deactivate it until the next MSCDEX call...
	mov	cx,-1
	xchg	cx,[cur_trig_hook]
	; Call hook_activate to undo the deactivation that was done in the boilerplate above.
	call	hook_activate
	; Bypass the function by changing our own return point to its RET instruction
	add	dword ptr [ebp],(2A577h-2A55Ch)

	; Now actually do the read syscall which Rayman was trying to do.
	; Arguments:	EAX = file handle
	;		EDX = buffer
	;		EBX = count
	mov	ah,3Fh		; READ
	mov	ecx,ebx		; count
	; Need to fetch EAX value from the stack...
	xchg	ebx,[esp+4]
	; EDX is already set
	push	es		; Rayman's DS
	pop	ds
	assume	ds:nothing
	; Do it!
	int	21h

	; Get EBX back
	mov	ebx,[esp+4]
	; Set return code for EAX to zero (success)
	mov	dword ptr [esp+4],0
	jnc	@@retpoint
	; If the int 21h failed, change that to -6
	mov	dword ptr [esp+4],-6
	jmp	@@retpoint
hook_handler	endp

end_of_payload:
payload	ends

; Extra support code, resident when running on Windows 9x
extra9x	segment	use16
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing

old_dbvec	label dword
old_dbvec_off	dw ?
old_dbvec_seg	dw ?

dpmi_entry	label dword
dpmi_entry_off	dw ?
dpmi_entry_seg	dw ?

descbuf		dq ?

old_int31	label fword
old_int31_off	dd ?
old_int31_seg	dw ?

; Allow Protected Mode stub code to call into the payload
callback_pm	label fword
		dd offset callback_fromstub
payload_cs	dw ?

raydetect	db 33o,"[35mRayman EXE detected, tracing instructions until DPMI entry...",0Dh,0Ah
		db "(Apologies if you're attempting to single-step with a debugger!)",33o,"[37m",0Dh,0Ah,'$'
intercept	db 33o,"[35mProtected Mode entry intercepted!",33o,"[37m",0Dh,0Ah,'$'

openredir_9x	proc near
	; Are we opening the current EXE?
	call	get_cur_exe
	assume	es:nothing
@@:
	lodsb
	test	al,al
	jz	@F
	scasb
	je	@B
@@:
	jne	@@retpoint

	; If so, is it RAYMAN.EXE?
	push	cs
	pop	es
	assume	es:stub
	lea	si,[si-2]	; go back before the terminating zero
	mov	di,offset raymanexe + sizeof raymanexe - 2
	std
	mov	cx,0Ah		; length of "rayman.exe"
	
@@:
	lodsb
	.if	al >= 'A' && al <= 'Z'
	   or	al,20h	; make sure it's lowercase
	.endif
	scasb
	loope	@B
	cld
	jne	@@retpoint

	; If so, this is probably PMODE/W in Rayman
	; Keep an eye on it...
	push	ds
	push	dx
	mov	ax,cs
	mov	ds,ax
	mov	dx,offset raydetect
	mov	ah,9	; write to stdout
	int	21h
	pop	dx
	pop	ds

	push	bp
	mov	bp,sp
	add	bp,0Eh		; BP+retaddr+AX+CX+DI+SI+ES = 7 words = 14 bytes
	bts	word ptr[bp+4],8; trap flag
	pop	bp

	push	bx
	mov	ax,3501h	; get #DB vector
	assume	es:nothing
	int	21h
	mov	cx,cs
	mov	ax,es
	cmp	ax,cx		; is our handler already installed?
	mov	cx,bx
	pop	bx
	je	@@retpoint
	mov	[old_dbvec_off],cx
	mov	[old_dbvec_seg],es

	push	ds
	push	dx
	mov	ax,cs
	mov	ds,ax
	mov	dx,offset tpls_dbhandler
	mov	ax,2501h
	int	21h
	pop	dx
	pop	ds

@@retpoint:
	ret
openredir_9x	endp

; Return currently-running EXE in ES:DI
get_cur_exe	proc near	uses ax bx cx
	mov	ah,62h	; GET CURRENT PSP ADDRESS
	int	21h

	mov	es,bx
	mov	es,es:[2Ch]	; get env segment

	xor	ax,ax
	mov	di,ax
	cld

@@:
	mov	cx,ax
	not	cx	; CX = -1
	repnz	scasb
	scasb	; second zero indicating end of environment
	jnz	@B

	; Skip over number of auxiliary strings - we only care about the first!
	lea	di,[di+2]
	ret
get_cur_exe	endp

tpls_dbhandler	proc
	assume	ds:nothing,es:nothing

	push	bp
	mov	bp,sp
	push	eax

	mov	eax,[bp+2]	; CS:IP
	cmp	eax,[dpmi_entry]
	je	@F

	pop	eax
	pop	bp
	iret	; Don't pass through to debugger (?)

@@:
	btr	word ptr[bp+6],8; reset trap flag
	push	ds
	push	dx
	lds	dx,[old_dbvec]
	mov	ax,2501h	; restore #DB vector
	int	21h

	mov	ax,cs
	mov	ds,ax
	mov	dx,offset intercept
	mov	ah,9	; write to stdout
	int	21h

	pop	dx
	pop	ds
	pop	eax
	pop	bp
	add	sp,4	; skip CS:IP
	popf

	; Allow any attached debugger to trap DPMI entry
	push	cs
	push	offset @F
	pushf
	push	[dpmi_entry]
	jmp	old_dbvec
@@:
	; Attached debugger returns to the DPMI entry point, which returns to us.
	jc	@F

	; If CF is clear, it means we have successfully entered Protected Mode!
	push	bp
	mov	bp,sp
	pushf
	push	es
	pushad

	mov	ax,0Ah	; create alias descriptor
	mov	bx,cs
	int	31h
	mov	es,ax
	assume	es:stub
	; preset the selector in the payload to avoid duplication
	call	get_stubsel_ptr
	mov	es:[di],ax

	xor	ax,ax	; alloc selectors
	mov	cx,1	; just the one
	int	31h
	xchg	ax,[bp+4]; replace segment in return addx
	movzx	edx,ax

	; copy the properties of this code segment to the one we're making
	mov	edi,offset descbuf
	mov	ax,0Bh	; get descriptor
	mov	bx,cs
	int	31h
	mov	ax,0Ch	; set descriptor
	mov	bx,[bp+4]
	int	31h

	shl	edx,4
	mov	ecx,edx
	shr	ecx,10h
	mov	ax,7	; set base address
	int	31h

	mov	ax,204h	; get interrupt vector
	mov	bl,31h
	int	31h
	mov	[old_int31_off],edx
	mov	[old_int31_seg],cx

	mov	ax,205h	; set interrupt vector
	mov	bl,31h
	mov	cx,cs
	mov	edx,offset tpls_int31
	int	31h

	popad
	pop	es
	assume	es:nothing
	popf
	pop	bp
@@:
	retf
tpls_dbhandler	endp

; Returns in DI an offset that can be used to access "payload:stub_selector"
; from a selector pointing at "stub"
get_stubsel_ptr	proc near
	mov	di,payload
	sub	di,stub
	shl	di,4
	add	edi,offset stub_selector
	ret
get_stubsel_ptr	endp

tpls_int31	proc
	assume	ds:nothing,es:nothing

	cmp	ax,300h	; simulate Real Mode interrupt
	jne	@@go_old
	cmp	bl,2Fh
	jne	@@go_old
	cmp	byte ptr es:[edi+1].rmcall._eax,15h	; MSCDEX call?
	jne	@@go_old

	push	ds
	push	edi
	call	get_stubsel_ptr
	mov	ds,cs:[di]
	assume	ds:stub
	pop	edi

	bt	ds:[statusword],3	; payload active?
	jnc	@F

	btr	ds:[statusword],4	; need to run the callback?
	jnc	@@done

	pushad
	pushfd
	; the payload sets the code segment for this when it activates
	call	callback_pm
	assume	ds:payload
	popad
	jmp	@@done

@@:
	assume	ds:stub
	push	ax
	push	bx
	push	cx

	; Make sure this is clear now in case there is somehow a stale value there
	btr	ds:[statusword],9

	; To avoid duplicating program logic, just pass this through to Real Mode
	mov	ax,302h	; call Real Mode procedure w/IRET frame
	xor	bx,bx
	xor	cx,cx
	mov	es:[edi].rmcall._ip,offset tpls_int2f
	mov	es:[edi].rmcall._cs,stub
	pushfd
	call	old_int31

	pop	cx
	pop	bx
	pop	ax

@@done:
	; Check if RM handler wants us to IRET immediately
	btr	ds:[statusword],9
	pop	ds
	assume	ds:nothing
	jc	@F	; CF set by BTR above

@@go_old:
	jmp	old_int31

@@:
	iretd
tpls_int31	endp
extra9x	ends

; Code in this segment briefly hooks into the int 2Fh chain, to check if we can intercept MSCDEX calls from Real Mode
dummy_hook	segment use16
dummy_hook_off:
	assume	ds:nothing,es:nothing,fs:nothing,gs:nothing
	cmp	ax,1500h
	jne	@F

	; If we were able to intercept int 2Fh, AX=1500h, then there's no need for the extra Win9x support code
	btr	cs:[statusword],6

@@:
	jmp	cs:old_int2f
dummy_hook	ends

stub	group	stubdos,extra9x,dummy_hook

; Initialization code, not resident
init	segment use16
	assume	ds:nothing,es:nothing
entry:
	.8086
	pushf

	pushf
	pop	ax
	and	ah,0Fh	; unset upper four flags
	push	ax
	popf

	pushf
	pop	ax
	and	ah,0F0h
	cmp	ah,0F0h	; all upper flags set?
	mov	dx,offset no386
	je	@@exitwitherr

	or	ah,0F0h	; set upper four flags
	push	ax
	popf

	pushf
	pop	ax
	test	ah,0F0h	; upper flags set?
	; As I understand it, a 386 in Real Mode will have some of them set,
	; but a 286 in Real Mode will have none of them...
	jz	@@exitwitherr

	popf
	.386

	; Check if TPLS is already installed
	mov	ax,0CE00h + 'T'
	mov	bl,'P'
	mov	cl,'L'
	mov	dl,'S'
	int	2Fh
	cmp	al,'P'
	jne	@F
	cmp	bl,'l'
	jne	@F
	cmp	cl,'u'
	jne	@F
	cmp	dl,'M'
	mov	dx,offset already
	je	@@exitwitherr

@@:
	mov	bp,ds	; save PSP

	mov	ax,stub
	mov	fs,ax
	assume	fs:stub

	; start by parsing the command line
	mov	si,81h	; command line in PSP
	movzx	cx,byte ptr ds:[80h]
	test	cx,cx
	jz	@@freeenv

	cld
@@:
	lodsb
	cmp	al,'/'
	loopne	@B

	; we have a switch...
	lodsb
	or	al,20h	; make lowercase
	cmp	al,'e'
	sete	ah
	; set Bit 0 if needed
	or	byte ptr fs:[statusword],ah
	loop	@B

@@freeenv:
	; free environment to save Conventional Memory
	mov	es,ds:[2Ch]	; get env segment

	push	cs
	pop	ds
	assume	ds:init
	mov	dx,offset intro
	mov	ah,9	; write to stdout
	int	21h

	mov	ah,49h	; free memory
	int	21h
	jnc	@F

	mov	dx,offset freeenv_err
	jmp	@@exitwitherr

@@:
	mov	ax,352Fh; get int 2Fh vector
	int	21h
	mov	fs:[old_int2f_off],bx
	mov	fs:[old_int2f_seg],es

	; while checking if MSCDEX is installed, also check (in principle) if we can hook it
	push	fs
	pop	ds
	assume	ds:stub
	mov	ax,252Fh; set int 2Fh vector
	mov	dx,offset dummy_hook_off
	int	21h
	; set bit 6 here - if the OS doesn't intercept the call, dummy_hook will clear it
	bts	[statusword],6

	; Check MSCDEX is installed, and save drive letter range
	mov	ax,1500h
	xor	bx,bx
	int	2Fh

	mov	ax,252Fh; set int 2Fh vector
	lds	dx,fs:[old_int2f]
	assume	ds:nothing
	int	21h

	push	cs
	pop	ds
	assume	ds:init

	test	bx,bx
	jnz	@F
	mov	dx,offset nomscdex
	jmp	@@exitwitherr

@@:
	bt	[statusword],6
	jnc	@F

	btr	[statusword],0	; don't do EMS if under Win9x
	mov	dx,offset win9xfound
	mov	ah,9	; write to stdout
	int	21h

	push	bx
	push	cx
	mov	ax,1687h; DPMI inst check
	int	2Fh
	mov	[dpmi_entry_off],di
	mov	[dpmi_entry_seg],es
	pop	cx
	pop	bx

@@:
	add	cx,'a'	; convert to drive letter
	add	bx,cx	; get last drive letter
	mov	fs:[first_cddrv],cl
	mov	fs:[endof_cddrv],bl

	mov	bx,bp		; get PSP
	mov	bp,dummy_hook	; dummy hook marks end of resident code
	bt	fs:[statusword],6
	jc	@F

	; No need for 9x support code
	mov	bp,extra9x	; end of payload
@@:
	sub	bp,bx	; total resident paragraphs

	bt	fs:[statusword],0
	jnc	@@noems

	mov	bp,payload
	sub	bp,bx	; we only need the stub resident

	mov	ax,3567h; get EMS int vector
	int	21h
	mov	ax,es
	or	ax,bx
	mov	dx,offset noems
	jz	@@exitwitherr

	mov	ah,40h	; EMM status
	int	67h
	test	ah,ah
	jnz	@@exitwitherr

	mov	ah,41h	; get page frame
	int	67h
	test	ah,ah
	mov	dx,offset nopageframe
	jnz	@@exitwitherr
	mov	fs:[pageframe],bx

	mov	ah,43h	; allocate page(s)
	mov	bx,1	; one page
	int	67h
	test	ah,ah
	mov	fs:[emshdl],dx
	mov	dx,offset emsallocerr
	jnz	@@exitwitherr

	call	map_payload_seg
	mov	dx,offset emsmaperr
	jc	@@exitwitherr
	mov	es,ax

	; copy payload into EMS page
	xor	si,si
	mov	di,si
	mov	ax,payload
	mov	gs,ax
	mov	ecx,offset end_of_payload
	add	cx,3
	shr	cx,2
	rep	movsd es:[di],gs:[si]

	mov	dx,offset emswarn
	mov	ah,9	; write to stdout
	int	21h

@@noems:
	mov	dx,offset savingvecs
	mov	ah,9	; write to stdout
	int	21h

	mov	ax,3521h; get int 21h vector
	int	21h
	mov	fs:[old_int21_off],bx
	mov	fs:[old_int21_seg],es

	mov	dx,offset writingvecs
	mov	ah,9	; write to stdout
	int	21h

	push	fs
	pop	ds
	assume	ds:stub

	mov	ax,2521h; set int 21h vector
	mov	dx,offset tpls_int21
	int	21h

	mov	ax,252Fh; set int 2Fh vector
	mov	dx,offset tpls_int2f
	int	21h

	push	cs
	pop	ds
	assume	ds:init
	mov	dx,offset goingresident
	mov	ah,9	; write to stdout
	int	21h

	mov	ax,3100h; KEEP with status 0 (OK)
	mov	dx,bp
	int	21h

@@exitwitherr:
	push	cs
	pop	ds
	assume	ds:init
	mov	ah,9	; write to stdout
	int	21h
	mov	ax,4CFFh; EXIT with status FFh
	int	21h

messages:
no386		db "Looks like you're trying to run this on an 80(2)86. Aborting...",0Dh,0Ah,"$"
already		db "TPLS already resident. Aborting. You can just play Rayman.",0Dh,0Ah,"$"
intro		db "Welcome to ",33o,"[35mP",33o,"[95ml",33o,"[35mu",33o,"[95mM",33o,"[35m'",33o,"[95ms",33o,"[37m TPLS TSR!",0Dh,0Ah,"$"
emswarn		db 33o,"[31mWARNING: EMS support seems to 'work' while you're playing Rayman BUT (on my PC)",0Dh,0Ah
		db "it seems to make DOS act weird (e.g. multiple files with same name...). YMMV.",0Dh,0Ah
		db "To be safe, it might be best to restart your PC / VM and rerun without /E...",33o,"[37m",0Dh,0Ah,"$"
noems		db "/E specified but EMS not reported present and correct, aborting...",0Dh,0Ah,"$"
nopageframe	db "/E specified but EMS has no page frame - this is not supported.",0Dh,0Ah,"$"
emsallocerr	db "/E specified but unable to allocate EMS page, aborting...",0Dh,0Ah,"$"
emsmaperr	db "/E specified but unable to map EMS page, aborting...",0Dh,0Ah,"$"
freeenv_err	db "Couldn't free environment segment, aborting...",0Dh,0Ah,"$"
nomscdex	db "No MSCDEX detected, aborting...",0Dh,0Ah,"$"
win9xfound	db "Protected-Mode OS intercepts MSCDEX calls, this is gonna be fun!",0Dh,0Ah,"$"
savingvecs	db "Saving interrupt vectors...",0Dh,0Ah,"$"
writingvecs	db "Installing new interrupt vectors...",0Dh,0Ah,"$"
goingresident	db "Going resident. You can play Rayman now!",0Dh,0Ah,"$"

init	ends

end	entry
