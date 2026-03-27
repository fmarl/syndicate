;; Copyright (c) 2021, Florian Buestgens
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
;; THIS SOFTWARE IS PROVIDED BY Florian Buestgens ''AS IS'' AND ANY
;; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL Florian Buestgens BE LIABLE FOR ANY
;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;; bios.nasm
;; Routine for detecting the BIOS

;; Try to detect EGA, VGA or VESA BIOS
detect_bios:
	pusha

	;; Get EGA Info http://www.ctyme.com/intr/rb-0162.htm
	mov ah, 0x12
	mov bl, 0x10
	int 0x10
	cmp bl, 0x10
	jne _detect_bios_success

	;; Get VGA Info http://www.ctyme.com/intr/rb-0219.htm
	mov ax, 0x1A00
	int 0x10
	cmp al, 0x1A		; Function was supported
	je _detect_bios_success

        ;; Get SuperVGA Info http://www.ctyme.com/intr/rb-0273.htm
	mov ax, ds
	mov es, ax
	mov di, __vesa_info_buffer
	mov ax, 0x4F00
	int 0x10
	cmp ax, 0x004F
	je _detect_bios_success
	

_detect_bios_error:
	mov si, __msg_detect_bios_error
	call printer
	
	jmp $

_detect_bios_success:
	popa

	ret
	

__msg_detect_bios_error: db 0xD, 0xE, `Error: Could not detect BIOS.`, 0x00
__vesa_info_buffer: times 256 db 0
