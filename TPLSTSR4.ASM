; PluM's TPLS TSR - hybrid SOS-hooking version

; MIT License
; 
; Copyright (c) 2022 PluMGMK
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
	last_audtrack	dd ?
	addr_leadout	db ?
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

; Real/VM86-Mode code, resident in Conventional Memory
stub	segment use16
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
statusword	dw 0

emshdl		dw 0
pageframe	dw 0

first_cddrv	db 0
endof_cddrv	db 0
suitable_cddrv	db 0

hmidrv		db "hmidrv.386",0
fakehmidrv	db "tplsdrv.386",0

raycfg		db "rayman.cfg",0

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
toomanydatatracks db 33o,"[35m","CD in drive "
toomanydatatracks_letter db ?,": has too many data tracks, not using.",33o,"[37m",13,10,"$"
notenoughaudiotracks db 33o,"[35m","CD in drive "
notenoughaudiotracks_letter db ?,": hasn't enough audio tracks, not using.",33o,"[37m",13,10,"$"
unkver		db 33o,"[35m","Unknown Rayman version. Not proceeding with payload injection...",33o,"[37m",13,10,"$"
payload_fail	db 33o,"[35m","Payload injection failed - could not read valid driver spec from config file,",13,10
		db "or could not find the driver in HMIDRV.386, or could not create TPLSDRV.386",33o,"[37m",13,10,"$"

; Rayman version strings
ray121us	db "RAYMAN (US) v1.21"
ray112us	db "RAYMAN (US) v1.12"
ray120de	db "RAYMAN (GERMAN) v1.20"
ray112eu	db "RAYMAN (EU) v1.12"
ray120itspdu	db "RAYMAN (IT-SP-DU) v1.20"


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
; CF set if yes, clear if no
chk_entete	proc near	uses ax cx ds si es di
	mov	si,0B800h	; Video BIOS text buffer
	mov	ds,si
	xor	si,si

	cld
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
	pushf
	call	old_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[logotrack_wrong],edx

	mov	[bp.AudioTrackInfo.track_number],LOGOTRACK_REDIR
	pushf
	call	old_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[logotrack_start],edx
	call	redbook2hsg
	mov	edi,edx

	mov	[bp.AudioTrackInfo.track_number],LOGOTRACK_REDIR+1
	pushf
	call	old_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	call	redbook2hsg
	sub	edx,edi
	mov	cs:[logotrack_len],edx

	mov	[bp.AudioTrackInfo.track_number],MENUTRACK
	pushf
	call	old_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[menutrack_wrong],edx

	mov	[bp.AudioTrackInfo.track_number],MENUTRACK_REDIR
	pushf
	call	old_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	mov	cs:[menutrack_start],edx
	call	redbook2hsg
	mov	edi,edx

	mov	[bp.AudioTrackInfo.track_number],MENUTRACK_REDIR+1
	pushf
	call	old_int2f
	mov	edx,[bp.AudioTrackInfo.starting_point]
	call	redbook2hsg
	sub	edx,edi
	mov	cs:[menutrack_len],edx

	add	sp,((size AudioTrackInfo) + 1) AND (NOT 1)
	pop	bp
	add	sp,((size IOCTLRW) + 1) AND (NOT 1)
	ret
setup_music_redirect endp

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

setup_payload	proc near	uses gs ds dx es edi cx ax bx si
	call	get_payload_seg
	mov	dx,offset emserr
	jc	@@earlyfail
	assume	gs:payload

	push	cs
	pop	es
	push	cs
	pop	ds
	assume	ds:stub,es:stub

	mov	di,offset ray121us
	mov	cx,sizeof ray121us
	call	chk_entete
	jc	@@setup_ptrs_v121us

	mov	di,offset ray112us
	mov	cx,sizeof ray112us
	call	chk_entete
	jc	@@setup_ptrs_v112us

	mov	di,offset ray120de
	mov	cx,sizeof ray120de
	call	chk_entete
	jc	@@setup_ptrs_v120de

	mov	di,offset ray112eu
	mov	cx,sizeof ray112eu
	call	chk_entete
	jc	@@setup_ptrs_v112eu

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
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x6664 in this version
	mov	gs:[pnum_world],(3F88Ch-6664h)		; @ 0x3F88C in the data section
	mov	gs:[pnum_level],(3F87Ch-6664h)		; @ 0x3F87C in the data section
	mov	gs:[ptrack_table],(4F3Bh-6664h)		; @ 0x4F3B in the data section
	mov	gs:[ptimeCd],(4FBCh-6664h)		; @ 0x4FBC in the data section
	mov	gs:[pcdTime],(3D85Ch-6664h)		; @ 0x3D85C in the data section
	mov	gs:[prbook_table],(4E8C7h-6664h)	; @ 0x4E8C7 in the data section
	mov	gs:[prbook_lentable],(4EA5Bh-6664h)	; @ 0x4EA5B in the data section
	mov	gs:[prbook_tablefl],(4EEFEh-6664h)	; @ 0x4EEFE in the data section
	mov	gs:[plowest_atrack],(4E8C1h-6664h)	; @ 0x4E8C1 in the data section
	mov	gs:[phighest_atrack],(4E8C1h-6664h)	; @ 0x4E8C2 in the data section
	mov	gs:[pcd_driveletter],(3FA27h-6664h)	; @ 0x3FA27 in the data section

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x73D6D in this version
	mov	gs:[pCreditsTrackNo],(0CF48h-73D6Dh)	; @ 0xCF48 in the text section
	mov	gs:[pLogoTrackNo],(0CF70h-73D6Dh)	; @ 0xCF70 in the text section
	mov	gs:[pMenuTrackNo],(0CFF0h-73D6Dh)	; @ 0xCFF0 in the text section
	mov	gs:[pGOverTrackNo],(0D018h-73D6Dh)	; @ 0xD018 in the text section
	mov	gs:[pDoGrowingPlat],(6B1A0h-73D6Dh)	; @ 0x6B1A0 in the text section
	mov	gs:[pMoskitoLock],(43D35h-73D6Dh)	; @ 0x43D35 in the text section
	mov	gs:[pMoskitoFast],(4AE94h-73D6Dh)	; @ 0x4AE94 in the text section
	mov	gs:[pMoskitoSlow],(4AEBDh-73D6Dh)	; @ 0x4AEBD in the text section
	mov	gs:[pLevelStart1],(70F0h-73D6Dh)	; @ 0x70F0 in the text section
	mov	gs:[pLevelStart2],(77F6h-73D6Dh)	; @ 0x77F6 in the text section
	mov	gs:[pLevelEnd1],(7697h-73D6Dh)		; @ 0x7697 in the text section
	mov	gs:[pLevelEnd2],(7CA6h-73D6Dh)		; @ 0x7CA6 in the text section
	mov	gs:[pExitSign1],(5234Fh-73D6Dh)		; @ 0x5234F in the text section
	mov	gs:[pExitSign2],(524ACh-73D6Dh)		; @ 0x524AC in the text section
	mov	gs:[pPerdu],(0CF8Eh-73D6Dh)		; @ 0xCF8E in the text section
	mov	gs:[pPlayTrack],(1A710h-73D6Dh)		; @ 0x1A710 in the text section

	jmp	@@payload_fixedup

@@setup_ptrs_v112us:
	; TODO: These pointers are correct for the "UNPROTECTED" version I have.
	; Is there a "PROTECTED" version that might have different pointers?

	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(170520h-137634h)	; @ 0x170520
	mov	gs:[pnum_level],(17050Eh-137634h)	; @ 0x17050E
	mov	gs:[ptrack_table],(135EF3h-137634h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137634h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E4F4h-137634h)		; @ 0x16E4F4
	mov	gs:[prbook_table],(17F667h-137634h)	; @ 0x17F667
	mov	gs:[prbook_lentable],(17F7FBh-137634h)	; @ 0x17F7FB
	mov	gs:[prbook_tablefl],(17FB9Bh-137634h)	; @ 0x17FB9B
	mov	gs:[plowest_atrack],(17F661h-137634h)	; @ 0x17F661
	mov	gs:[phighest_atrack],(17F662h-137634h)	; @ 0x17F662
	mov	gs:[pcd_driveletter],(1706BBh-137634h)	; @ 0x1706BB
	mov	gs:[plang],(1706C8h-137634h)		; @ 0x1706C8

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81216 in this version
	mov	gs:[pCreditsTrackNo],(1AC78h-81216h)	; @ 0x1AC78
	mov	gs:[pLogoTrackNo],(1ACA0h-81216h)	; @ 0x1ACA0
	mov	gs:[pMenuTrackNo],(1AD20h-81216h)	; @ 0x1AD20
	mov	gs:[pGOverTrackNo],(1AD48h-81216h)	; @ 0x1AD48
	mov	gs:[pIntroTrackNo],(163E8h-81216h)	; @ 0x163E8
	mov	gs:[pOuttroTrackNo],(333E6h-81216h)	; @ 0x333E6
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

@@setup_ptrs_v120itspdu:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(17091Ch-137634h)	; @ 0x17091C
	mov	gs:[pnum_level],(17090Ch-137634h)	; @ 0x17090C
	mov	gs:[ptrack_table],(135F0Bh-137634h)	; @ 0x135F0B
	mov	gs:[ptimeCd],(135F8Ch-137634h)		; @ 0x135F8C
	mov	gs:[pcdTime],(16E8ECh-137634h)		; @ 0x16E8EC
	mov	gs:[prbook_table],(17F957h-137634h)	; @ 0x17F957
	mov	gs:[prbook_lentable],(17FAEBh-137634h)	; @ 0x17FAEB
	mov	gs:[prbook_tablefl],(17FF8Eh-137634h)	; @ 0x17FF8E
	mov	gs:[plowest_atrack],(17F951h-137634h)	; @ 0x17F951
	mov	gs:[phighest_atrack],(17F952h-137634h)	; @ 0x17F952
	mov	gs:[pcd_driveletter],(170AB7h-137634h)	; @ 0x170AB7
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

@@setup_ptrs_v120de:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137634 in this version
	mov	gs:[pnum_world],(17091Ch-137634h)	; @ 0x17091C
	mov	gs:[pnum_level],(17090Ch-137634h)	; @ 0x17090C
	mov	gs:[ptrack_table],(135F0Bh-137634h)	; @ 0x135F0B
	mov	gs:[ptimeCd],(135F8Ch-137634h)		; @ 0x135F8C
	mov	gs:[pcdTime],(16E8ECh-137634h)		; @ 0x16E8EC
	mov	gs:[prbook_table],(17F957h-137634h)	; @ 0x17F957
	mov	gs:[prbook_lentable],(17FAEBh-137634h)	; @ 0x17FAEB
	mov	gs:[prbook_tablefl],(17FF8Eh-137634h)	; @ 0x17FF8E
	mov	gs:[plowest_atrack],(17F951h-137634h)	; @ 0x17F951
	mov	gs:[phighest_atrack],(17F952h-137634h)	; @ 0x17F952
	mov	gs:[pcd_driveletter],(170AB7h-137634h)	; @ 0x170AB7
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

@@setup_ptrs_v112eu:
	; Addresses relative to sSOSDIGIInitDriver in Rayman's data section
	; It's at 0x137624 in this version
	mov	gs:[pnum_world],(170770h-137624h)	; @ 0x170770
	mov	gs:[pnum_level],(17075Eh-137624h)	; @ 0x17075E
	mov	gs:[ptrack_table],(135EF3h-137624h)	; @ 0x135EF3
	mov	gs:[ptimeCd],(135F74h-137624h)		; @ 0x135F74
	mov	gs:[pcdTime],(16E744h-137624h)		; @ 0x16E744
	mov	gs:[prbook_table],(17F7B7h-137624h)	; @ 0x17F7B7
	mov	gs:[prbook_lentable],(17F94Bh-137624h)	; @ 0x17F94B
	mov	gs:[prbook_tablefl],(17FDEEh-137624h)	; @ 0x17FDEE
	mov	gs:[plowest_atrack],(17F7B1h-137624h)	; @ 0x17F7B1
	mov	gs:[phighest_atrack],(17F7B2h-137624h)	; @ 0x17F7B2
	mov	gs:[pcd_driveletter],(17090Bh-137624h)	; @ 0x17090B
	mov	gs:[plang],(170918h-137624h)		; @ 0x170918

	; Addresses relative to retpoint of sosDRVInit in Rayman's text section
	; It's at 0x81508 in this version
	mov	gs:[pCreditsTrackNo],(1ADA8h-81508h)	; @ 0x1ADA8
	mov	gs:[pLogoTrackNo],(1ADD0h-81508h)	; @ 0x1ADD0
	mov	gs:[pMenuTrackNo],(1AE50h-81508h)	; @ 0x1AE50
	mov	gs:[pGOverTrackNo],(1AE78h-81508h)	; @ 0x1AE78
	mov	gs:[pIntroTrackNo],(1651Eh-81508h)	; @ 0x1651E
	mov	gs:[pOuttroTrackNo],(33546h-81508h)	; @ 0x33546
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

	pushf
	call	old_int2f
	jc	@@cleanupstack

	bt	es:[bx.IOCTLRW.wStatus],0Fh	; error?
	jc	@@cleanupstack

	cmp	[bp.AudioDiscInfo.first_audtrack],2
	ja	@@toomanydatatracks
	cmp	[bp.AudioDiscInfo.last_audtrack],51
	jb	@@notenoughaudiotracks
	cmp	[bp.AudioDiscInfo.last_audtrack],57
	jnb	@F

	mov	[noextratracks_letter],dl
	sub	[noextratracks_letter],20h	; make uppercase!
	mov	dx,offset noextratracks
	mov	ah,9	; write to stdout
	pushf
	call	old_int21

@@:
	mov	[suitable_cddrv],dl
	clc

@@cleanupstack:
	add	sp,((size AudioDiscInfo) + 1) AND (NOT 1)
	pop	bp
	add	sp,((size IOCTLRW) + 1) AND (NOT 1)
	ret

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

tpls_int21	proc
	assume	ds:nothing,es:nothing

	test	cs:[statusword],110b
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
	jnc	@@passthrough

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
	; Other bits reset for a new run.
	and	[statusword],1

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
	jne	@@passthrough
	bt	cs:[statusword],3	; payload active?
	jnc	@F

	btr	cs:[statusword],4	; need to run the callback?
	jnc	@@passthrough
	; the payload sets this when it activates
	jmp	cs:callback2payload
	; and the callback itself will send us to old_int2f when it's done

@@:
	; We don't have a PM companion, need to handle everything in RM
	bt	cs:[statusword],1	; redirects active?
	jnc	@@mscdex_noredir

	cmp	al,10h		; send driver request
	jne	@@passthrough
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
	jmp	cs:old_int2f
tpls_int2f	endp
stub	ends

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
	
	mov	ax,303h	; allocate RM callback
	mov	esi,offset callback_fromstub
	pop	es	; get saved DS from stack
	mov	edi,offset callback_RMCS
	int	31h
	mov	gs:[callback_off],dx
	mov	gs:[callback_seg],cx

	push	es	; restore DS to what it was
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
	int	31h

@@:
	mov	[rayman_cs_asds],ax

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
	mov	esi,offset psos_InitStruct
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

	mov	edx,[pIntroTrackNo]
	test	edx,edx
	jz	@F
	mov	al,52
	call	poketext

	mov	edx,[pOuttroTrackNo]
	test	edx,edx
	jz	@F
	mov	al,55
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
	jz	@F
	call	set_hookpoint
	mov	edx,[pPlayOuttro]
	test	edx,edx
	jz	@F
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

; Pointers to code in Rayman
psosDRVInit_ret	dd 0
pCreditsTrackNo	dd ?
pLogoTrackNo	dd ?
pMenuTrackNo	dd ?
pGOverTrackNo	dd ?
pIntroTrackNo	dd 0	; For multi-lang versions, intro/outtro track number is a
pOuttroTrackNo	dd 0	;  fixed offset of the language ID - edit this fixed offset
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
end_textptrs:

; Pointers to data in Rayman
psos_InitStruct	dd 0
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
	push	es
	push	edi
	mov	ds,cs:[mydatasel]
	assume	ds:payload

	mov	edi,(offset hook_origcode)-4
	mov	ecx,NUM_HOOKS
	std
	xor	eax,eax
@@hook_reac_loop:
	scasd				; check if there is a hookpoint with this idx
	loope	@@hook_reac_loop	; this decrements ECX!
	je	@@hook_reac_done	; if ECX and [ES:EDI] are both zero, we're finished
	call	hook_activate		; the loope instruction has made this the right idx for here...
	inc	ecx			; cancel the effect of the loope instruction before next iteration
	loop	@@hook_reac_loop
@@hook_reac_done:
	cld

	pop	edi
	pop	es

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

	; we'll want the hookpoint reactivated on the next MSCDEX call
	push	gs
	call	get_stub_seg
	assume	gs:stub
	bts	gs:[statusword],4
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

	cmp	eax,[pPlayIntro]
	je	@@cutscene
	cmp	eax,[pPlayOuttro]
	je	@@cutscene

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
; TODO: Do we really want this? It's a nice idea in principle, but the game seems to stop the audio 
; before it has a chance to finish... We could probably do more hooks to stop that...
@@yay_fanfare:
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
	jz	@@fanfare_privileged	; ZF set/cleared by ARPL above

	; OK, Rayman's at the same privilege level as us, so there's only one stack to worry about
	mov	[ebp+8],ecx		; replace EFLAGS with new return address - now this is a RETF frame instead of IRET!
	pop	ecx
	add	esp,4			; skip EAX on the stack (it's set to our track number!)
	pop	es
	pop	ds
	pop	ebp
	retf

@@fanfare_privileged:
	; Returning to an outer privilege level, which means we're on a different stack.
	sub	dword ptr [ebp+0Ch],4	; create a RETN frame on user-mode stack (user SS:ESP are at SS:EBP+0Ch)
	lds	ebp,[ebp+0Ch]
	assume	ds:nothing
	mov	ds:[ebp],ecx		; put our new return address into this new stack frame

	; Now return by the usual route, but make sure EAX is set to our track number
	mov	[esp+4],eax
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
	jmp	@@retpoint

; Single-lang game version is about to play a cutscene - select the right music
@@cutscene:
	mov	ecx,[plang]
	mov	bl,es:[ecx]		; BL contains the track number passed to the cutscene function
	add	bl,52			; first intro track on custom CD image

	cmp	eax,[pPlayOuttro]
	jne	@@retpoint
	add	bl,3			; add three more to get outtro track
	jmp	@@retpoint
hook_handler	endp

end_of_payload:
payload	ends

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
	; Check MSCDEX is installed, and save drive letter range
	mov	ax,1500h
	xor	bx,bx
	int	2Fh
	test	bx,bx
	jnz	@F

	mov	dx,offset nomscdex
	jmp	@@exitwitherr

@@:
	add	cx,'a'	; convert to drive letter
	add	bx,cx	; get last drive letter
	mov	fs:[first_cddrv],cl
	mov	fs:[endof_cddrv],bl

	mov	bx,bp	; get PSP
	mov	bp,cs	; current code segment == end of payload
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

	mov	ax,352Fh; get int 2Fh vector
	int	21h
	mov	fs:[old_int2f_off],bx
	mov	fs:[old_int2f_seg],es

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
savingvecs	db "Saving interrupt vectors...",0Dh,0Ah,"$"
writingvecs	db "Installing new interrupt vectors...",0Dh,0Ah,"$"
goingresident	db "Going resident. You can play Rayman now!",0Dh,0Ah,"$"

init	ends

end	entry
