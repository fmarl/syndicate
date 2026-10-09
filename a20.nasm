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

;; a20.nasm
;; Enable the A20 line, trying the BIOS, the fast A20 gate and the
;; keyboard controller in turn

enable_a20:
	call a20_enabled
	jnz .done

	mov ax, 0x2401
	int 0x15
	call a20_enabled
	jnz .done

	in al, 0x92
	or al, 2
	and al, 0xFE			; bit 0 resets the machine
	out 0x92, al
	call a20_enabled
	jnz .done

	call .kbc_wait
	mov al, 0xD1			; write output port
	out 0x64, al
	call .kbc_wait
	mov al, 0xDF
	out 0x60, al
	call .kbc_wait
	call a20_enabled
	jnz .done

	mov si, msg_no_a20
	jmp fatal
.done:
	ret

.kbc_wait:
	in al, 0x64
	test al, 2
	jnz .kbc_wait
	ret

;; out: ZF clear if A20 is enabled
a20_enabled:
	mov ax, 0xFFFF
	mov fs, ax
	mov byte [a20_test], 0
	mov byte [fs:a20_test + 0x10], 0xFF
	cmp byte [a20_test], 0xFF
	ret

msg_no_a20:		db "No A20", 0
