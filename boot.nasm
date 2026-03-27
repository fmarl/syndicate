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
;; THIS SOFTWARE IS PROVIDED BY <copyright holder> ''AS IS'' AND ANY
;; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL <copyright holder> BE LIABLE FOR ANY
;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;;  ____                  _ _           _
;; / ___| _   _ _ __   __| (_) ___ __ _| |_ ___
;; \___ \| | | | '_ \ / _` | |/ __/ _` | __/ _ \
;;  ___) | |_| | | | | (_| | | (_| (_| | ||  __/
;; |____/ \__, |_| |_|\__,_|_|\___\__,_|\__\___|
;;        |___/

;; Syndicate BOOTLOADER
;;
;; Stage 1
;;
	
[BITS 16]
[ORG 0x7C00]

jmp 0:boot_init

boot_init:
	cli			; Disable interrupts
	xor ax, ax
	mov ds, ax		; Set data segment
	mov es, ax		; Set extra segment
	mov ss, ax		; Set stack segment
	mov sp, 0x7C00		; Set stack pointer
	sti			; Enable interrupts
	cld

	call set_video_mode

	mov [__drive_number], dl

	mov si, __msg_bootup
	call printer

	call enable_a20

	;; We disable this for now. We need more space for the fat32 implementation.
	;;call detect_bios

	call detect_kern

	mov si, __msg_partfound
	call printer

	; Load Hadron kernel (HADRON.ELF)
	call load_hadron
	jc .boot_failed  ; If carry set, loading failed

	mov si, __msg_hadron_loaded
	call printer

;; Jumping to kernel
	push WORD 0x0100
	push WORD 0x0000
	retf

.boot_failed:
	mov si, __msg_boot_failed
	call printer
	jmp $  ; Halt on error

;; Bye...

;; ---------------------------------------------------------
;; ---------------------------------------------------------
;; ---------------------------------------------------------
;; ---------------------------------------------------------
	
; Includes
%include "print.nasm"
%include "fio.nasm"
;;%include "bios.nasm"

;; ----------------------------------------------------------
;; Set video mode to 80x25 text mode for compatibility
;; ----------------------------------------------------------
set_video_mode:
	mov ax, 0x0003
	int 0x10
	ret

;; ----------------------------------------------------------
;; Enable A20 line for access to memory above 1MB
;; Uses Fast A20 Gate method (PS/2 controller)
;; ----------------------------------------------------------
enable_a20:
	in al, 0x92
	or al, 2
	out 0x92, al
	ret

__msg_bootup: db 'Syndicate', 0xD, 0xA, 0x00
__msg_partfound: db 'Loading Stage 2...', 0xD, 0xA, 0x00
__msg_hadron_loaded: db 'Kernel loaded', 0xD, 0xA, 0x00
__msg_boot_failed: db 'Boot failed!', 0xD, 0xA, 0x00
	
times 510 - ($-$$) db 0x00	; Fill remaining memory
dw 0xAA55			; Magicnumber which marks this as bootable for BIOS

