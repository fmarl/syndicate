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

;;  ____                  _ _           _
;; / ___| _   _ _ __   __| (_) ___ __ _| |_ ___
;; \___ \| | | | '_ \ / _` | |/ __/ _` | __/ _ \
;;  ___) | |_| | | | | (_| | | (_| (_| | ||  __/
;; |____/ \__, |_| |_|\__,_|_|\___\__,_|\__\___|
;;        |___/

;; Syndicate BOOTLOADER
;;
;; Stage 1. The MBR part loads the rest of stage 1 from the sectors
;; following the MBR. The rest loads stage 2 and the kernel from the
;; FAT32 file system on the first partition.
;;
;; Memory layout:
;;   0x00500  variables
;;   0x00600  FAT sector buffer
;;   0x01000  stage 2
;;   0x07000  stack
;;   0x07C00  stage 1, MBR
;;   0x07E00  stage 1, rest
;;   0x08000  directory buffer, up to 32 KiB
;;   0x10000  kernel
;;
;; Stage 2 is entered at STAGE2_SEG:0 with
;;   dl  = boot drive
;;   ecx = kernel size in bytes
;; in real mode, with A20 enabled.

[BITS 16]
[ORG 0x7C00]

%ifndef STAGE2_FILE
%define STAGE2_FILE "STAGE2.BIN"
%endif
%ifndef KERNEL_FILE
%define KERNEL_FILE "KERNEL.BIN"
%endif

STAGE2_SEG		equ 0x0100
STAGE2_MAX		equ 0x6000
KERNEL_SEG		equ 0x1000
KERNEL_MAX		equ 0x80000

FAT_SEG			equ 0x0060
FAT_BUF			equ FAT_SEG << 4
REST_SEG		equ 0x07E0
DIR_SEG			equ 0x0800
DIR_BUF			equ DIR_SEG << 4

STAGE1_MAGIC		equ 0x5953

absolute 0x0500
drive:			resb 1
sec_per_clus:		resb 1
fat_lba:		resd 1
data_lba:		resd 1
root_cluster:		resd 1
a20_test:		resb 1

section .text

	jmp 0:start

start:
	cli
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7C00
	sti
	cld

	mov [drive], dl

	mov ax, 0x0003
	int 0x10

	mov si, msg_boot
	call print

	call enable_a20
	call check_lba

	mov eax, 1
	mov bx, REST_SEG
	mov cx, REST_SECTORS
.load_rest:
	call read_sector
	inc eax
	add bx, 512 >> 4
	loop .load_rest

	cmp word [rest_magic], STAGE1_MAGIC
	jne .incomplete
	jmp rest

.incomplete:
	mov si, msg_incomplete

fatal:
	call print
.halt:
	cli
	hlt
	jmp .halt

%include "print.nasm"
%include "disk.nasm"
%include "a20.nasm"

msg_boot:		db "Syndicate", 13, 10, 0
msg_incomplete:		db "Stage 1 incomplete", 0

%if ($ - $$) > 446
%error "MBR code exceeds 446 bytes"
%endif

	times 510 - ($ - $$) db 0
	dw 0xAA55

rest:
	call fat_init

	mov si, stage2_name
	mov bx, STAGE2_SEG
	mov ecx, STAGE2_MAX
	call load_file

	mov si, kernel_name
	mov bx, KERNEL_SEG
	mov ecx, KERNEL_MAX
	call load_file

	mov dl, [drive]
	jmp STAGE2_SEG:0

%include "fat32.nasm"
%include "fio.nasm"

stage2_name:		fat_name STAGE2_FILE
kernel_name:		fat_name KERNEL_FILE
rest_magic:		dw STAGE1_MAGIC

REST_SECTORS		equ ($ - rest + 511) / 512

%if ($ - rest) > DIR_BUF - (REST_SEG << 4)
%error "stage 1 overlaps the directory buffer"
%endif

	times REST_SECTORS * 512 - ($ - rest) db 0
