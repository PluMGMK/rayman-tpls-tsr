; FIXWLDS - recalculate the BIOS and Video BIOS checksums for Rayman's WLD files

; MIT License
; 
; Copyright (c) 2023 PluMGMK
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
; FITNESS FOR A PARICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

.8086
.model	small

TEXT	segment	use16

checksums	label word
bios_checksum	db 0
vbios_checksum	db 0

wldfile	db "RAY"
wldidx	db "1"
	db ".WLD",0

start:
	assume	cs:TEXT,ds:nothing,es:nothing,ss:nothing
	push	cs
	pop	es
	assume	es:TEXT

	lea	di,checksums
	mov	si,0F000h		; first run: get checksum of BIOS
@@get_checksum:
	mov	ds,si
	mov	cx,1000h		; calculate checksum of just first page
	xor	bl,bl
	xor	si,si
@@:
	lodsb
	add	bl,al
	loop	@B
	mov	al,bl
	stosb

	cmp	di,offset checksums + sizeof checksums
	mov	si,0C000h		; second run: get checksum of VBIOS
	jb	@@get_checksum

	; now open the WLD files
	push	cs
	pop	ds
	assume	ds:TEXT

@@nextwld:
	lea	dx,wldfile
	mov	ax,3D12h		; OPEN: RW, DENYALL
	xor	cl,cl			; no attribute mask
	int	21h
	jc	@@failure

	mov	bx,ax
	mov	ax,4200h		; LSEEK from beginning of file
	xor	cx,cx
	mov	dx,5			; seek to position 5 (checksums)
	int	21h
	jc	@@failure

	mov	ah,40h			; WRITE
	mov	cx,sizeof checksums
	lea	dx,checksums
	int	21h

	mov	ah,3Eh			; CLOSE
	int	21h

	inc	[wldidx]
	cmp	[wldidx],'6'
	jna	@@nextwld

	xor	al,al			; exit with success
@@failure:
	mov	ah,4Ch			; EXIT with value = error code
	int	21h

TEXT	ends

end	start
