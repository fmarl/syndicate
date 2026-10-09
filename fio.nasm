;; Copyright (c) 2020, Florian Büstgens
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are met:
;;     1. Redistributions of source code must retain the above copyright
;;        notice, this list of conditions and the following disclaimer.
;;
;;     2. Redistributions in binary form must reproduce the above copyright notice,
;;        this list of conditions and the following disclaimer in the
;;        documentation and/or other materials provided with the distribution.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ''AS IS'' AND ANY
;; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;; fio.nasm
;; Loading files from the root directory

ATTR_DIR_OR_VOLUME	equ 0x18	; also set for long name entries

struc dirent
	.name:		resb 11
	.attr:		resb 1
	.reserved:	resb 8
	.cluster_hi:	resw 1
	.mtime:		resd 1
	.cluster_lo:	resw 1
	.size:		resd 1
endstruc

;; Emit "name.ext" as zero terminated 8.3 directory name
%macro fat_name 1
	%strlen %%len %1
	%assign %%count 0
	%assign %%ext 0
	%assign %%i 1
	%rep %%len
		%substr %%c %1 %%i
		%if %%c = '.'
			%if %%ext || %%count = 0
				%error invalid 8.3 file name: %1
			%endif
			times 8 - %%count db ' '
			%assign %%ext 1
			%assign %%count 0
		%else
			%if %%c >= 'a' && %%c <= 'z'
				db %%c - 'a' + 'A'
			%else
				db %%c
			%endif
			%assign %%count %%count + 1
			%if %%count > 8 || (%%ext && %%count > 3)
				%error invalid 8.3 file name: %1
			%endif
		%endif
		%assign %%i %%i + 1
	%endrep
	%if %%ext
		times 3 - %%count db ' '
	%else
		times 11 - %%count db ' '
	%endif
	db 0
%endmacro

;; in:  si = 8.3 name, bx = destination segment, ecx = maximum size
;; out: ecx = file size
load_file:
	push bx
	push ecx

	mov eax, [root_cluster]
	mov dx, 0xFFFF
.dir_cluster:
	mov bx, DIR_SEG
	call read_cluster
	mov bp, bx
	sub bp, DIR_SEG
	shr bp, 1			; entries read
	mov di, DIR_BUF
.scan:
	cmp byte [di], 0
	je .not_found
	test byte [di + dirent.attr], ATTR_DIR_OR_VOLUME
	jnz .skip
	pusha
	mov cx, 11
	repe cmpsb
	popa
	je .found
.skip:
	add di, dirent_size
	dec bp
	jnz .scan
	call next_cluster
	jc .dir_cluster
.not_found:
	mov ax, msg_not_found
	jmp .fail

.found:
	pop ecx
	pop bx
	mov edx, [di + dirent.size]
	cmp edx, ecx
	ja .too_large
	mov ecx, edx
	mov ax, [di + dirent.cluster_hi]
	shl eax, 16
	mov ax, [di + dirent.cluster_lo]
	add edx, 511
	shr edx, 9
	jz .done
.load:
	call read_cluster
	test dx, dx
	jz .done
	call next_cluster
	jc .load
	mov ax, msg_corrupt
	jmp .fail
.done:
	ret

.too_large:
	mov ax, msg_too_large
.fail:
	push ax
	call print
	pop si
	jmp fatal

msg_not_found:		db " not found", 0
msg_too_large:		db " too large", 0
msg_corrupt:		db " corrupt", 0
