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

;; disk.nasm
;; Sector access through the INT 13h extensions

DISK_RETRIES		equ 4

check_lba:
	mov ah, 0x41
	mov bx, 0x55AA
	mov dl, [drive]
	int 0x13
	jc .fail
	cmp bx, 0xAA55
	jne .fail
	ret
.fail:
	mov si, msg_no_lba
	jmp fatal

;; in: eax = LBA, bx = destination segment
read_sector:
	pushad
	mov bp, sp
	mov di, DISK_RETRIES
.retry:
	mov eax, [bp + 28]		; eax as saved by pushad
	push dword 0
	push eax
	push bx
	push word 0
	push word 1
	push word 16
	mov si, sp			; disk address packet
	mov ah, 0x42
	mov dl, [drive]
	int 0x13
	mov sp, bp
	jnc .done
	xor ah, ah
	int 0x13
	dec di
	jnz .retry
	mov si, msg_disk_error
	jmp fatal
.done:
	popad
	ret

msg_no_lba:		db "No LBA", 0
msg_disk_error:		db "Disk error", 0
