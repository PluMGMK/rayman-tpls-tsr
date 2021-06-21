.8086
.MODEL	TINY
.STACK	80h
OPTION	MZ:	0:16:0:0	; zeros to minimize all allocations (make room for Rayman and TSR)

.CODE
entry:
	push	cs
	pop	ds		; standard for "tiny" programs...

	; Fill in the segment for stuff to copy to child PSPs
	mov	word ptr [pfCmdTail+2],es
	mov	word ptr [pfrFCB_1+2],es
	mov	word ptr [pfrFCB_2+2],es

	; Check for VCPI
	mov	ax,3567h	; get interrupt vector 67h
	int	21h
	mov	word ptr [ems_vec],bx
	mov	word ptr [ems_vec+2],es

	; TODO: Check for DPMI and invoke CWSDPMI if necessary and possible

	or	bx,word ptr [ems_vec+2]
	jz	no_vcpi		; vector is null

	; Before actually checking for VCPI, check for Windows 3.0
	; Apparently, it "objects violently" to VCPI checks...
	mov	ax,4680h
	int	2Fh
	test	ax,ax
	jz	hide_vcpi	; Windows 3.0 running - hide VCPI to make sure nothing else incurs its wrath!

	mov	ax,1600h
	int	2Fh
	cmp	ax,0003h	; Windows 3.0 in enhanced mode
	je	hide_vcpi

	mov	ax,0DE00h	; VCPI installation check
	int	67h
	test	ah,ah
	jnz	no_vcpi		; AH did not get zeroed

hide_vcpi:
	; OK, VCPI is available.
	; This means we need to hide it from DOS32 to make it use DPMI!
	; (May also be the case for Rayman itself, depending on how 
	;  PMODE/W was compiled...)
	mov	ax,2567h	; set interrupt vector 67h
	mov	dx,offset vcpi_hider
	int	21h

no_vcpi:
	; Check if TPLS is already installed
	mov	ax,0CE00h + 'T'
	mov	bl,'P'
	mov	cl,'L'
	mov	dl,'S'
	int	2Fh
	cmp	al,'P'
	jne	install_tsr
	cmp	bl,'l'
	jne	install_tsr
	cmp	cl,'u'
	jne	install_tsr
	cmp	dl,'M'
	je	tsr_installed

install_tsr:
	mov	ax,4B00h	; exec and load
	mov	dx,offset tsr_exe
	push	ds
	pop	es
	mov	bx,offset wEnvSeg
	mov	word ptr [orig_stack],sp
	mov	word ptr [orig_stack+2],ss
	int	21h		; execute the TSR
	; restore the stack after the exec call:
	mov	ss,word ptr [cs:orig_stack+2]
	mov	sp,word ptr [cs:orig_stack]
	; and the data segment
	push	cs
	pop	ds

	jc	failed_tsr_exec

	mov	ah,4Dh		; get exit code
	int	21h
	cmp	ah,3		; TSR-ed
	jne	failure		; no need to print a message since the TSR will have done so anyway

tsr_installed:
	; We're good so far - run Rayman now!
	mov	ax,4B00h	; exec and load
	mov	dx,offset ray_exe
	push	ds
	pop	es
	mov	bx,offset wEnvSeg
	mov	word ptr [orig_stack],sp
	mov	word ptr [orig_stack+2],ss
	int	21h		; execute the TSR
	; restore the stack after the exec call:
	mov	ss,word ptr [cs:orig_stack+2]
	mov	sp,word ptr [cs:orig_stack]
	; and the data segment
	push	cs
	pop	ds

	jc	failed_ray_exec

	mov	[exit_code],0
	jmp	finish
	
failed_tsr_exec:
	mov	dx,offset failed_tsr_msg
	jmp	failure_msg

failed_ray_exec:
	mov	dx,offset failed_ray_msg

failure_msg:
	mov	ah,9		; print message
	int	21h
failure:
	mov	[exit_code],-1

finish:
	; restore EMS/VCPI vector - it's saved anyway, whether or not we modified it
	push	ds
	lds	dx,[ems_vec]
	mov	ax,2567h	; set interrupt vector 67h
	int	21h
	pop	ds

	mov	ah,4Ch		; exit
	mov	al,[exit_code]
	int	21h


vcpi_hider:
	cmp	ax,0DE00h	; VCPI installation check
	je	vcpi_hider_ret
	jmp	cs:ems_vec
vcpi_hider_ret:
	; Pretend VCPI's not installed
	; Only hide the installation check, not any other calls,
	; since the DPMI host may itself be using them.
	iret


.DATA
	TSR_EXE_DEF	equ "TPLSTSR3.EXE"
	RAY_EXE_DEF	equ "RAYMAN.EXE"
	tsr_exe		db TSR_EXE_DEF,0
	ray_exe		db RAY_EXE_DEF,0

	failed_tsr_msg	db "Couldn't exec ",TSR_EXE_DEF," - is it in the right directory?",0Dh,0Ah,'$'
	failed_ray_msg	db "Couldn't exec ",RAY_EXE_DEF," - is it in the right directory?",0Dh,0Ah
			db "Note TPLS is resident anyway, so you can try running Rayman directly now",0Dh,0Ah,'$'

	; exec parameters
	wEnvSeg		dw 0	; copy parent environment
	pfCmdTail	dd 80h	; copy parent cmdline (seg to fill in at runtime)
	pfrFCB_1	dd 5Ch	; copy parent FCB1 (seg to fill in at runtime)
	pfrFCB_2	dd 6Ch	; copy parent FCB2 (seg to fill in at runtime)

.DATA?
	ems_vec		dd ?
	orig_stack	dd ?
	exit_code	db ?

END entry
