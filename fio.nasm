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

;; fio.inc
;; Routines to find the kernel on a FAT32 partition

%include "fat32.nasm"

;; Constants
%define FILE_ENTRY_SIZE      0x20
%define FILE_CLUSTER_OFFSET  0x001A
%define FILE_SIZE_OFFSET     0x001C
%define KERNEL_SEGMENT       0x0100  ; Linear 0x1000 (Stage 2 bootloader)
%define KERNEL_CLUSTERS      0x08
%define HADRON_SEGMENT       0x1000  ; Linear 0x10000 (ELF kernel, 64KB offset)
%define HADRON_MAX_CLUSTERS  0x80

;; ----------------------------------------------------------
;; Find the kernel on a FAT32 drive
;; ----------------------------------------------------------
detect_kern:
	pusha

	call prepare_fs		; Preparing the bootloader to read the FAT32 drive
	call find_kernel	; Find kernel by name
	mov WORD[__cluster], dx

;; Preparing kernel location
	mov ax, KERNEL_SEGMENT	; Location
	mov es, ax		; Setting extra segment
	xor bx, bx

;; Reading kernel cluster
	mov cx, KERNEL_CLUSTERS
	mov ax, WORD[__cluster]
	call _lba_conv
	call _read_disk_sectors

	popa
	ret

;; ----------------------------------------------------------
;; Find kernel file by name in root directory
;; Returns: DX = first cluster of kernel
;; ----------------------------------------------------------
find_kernel:
	mov di, ROOT_DIR_BUFFER
	mov bx, 16		; Max entries to check
.loop:
	push bx
	push di
	mov si, __kernel_name
	mov cx, 11		; Compare 11 chars (8.3 filename)
	repe cmpsb
	pop di
	pop bx
	je .found
	add di, FILE_ENTRY_SIZE
	dec bx
	jnz .loop
	; Not found - error
	mov si, __msg_no_kernel
	call printer
	jmp $
.found:
	mov dx, WORD[di + FILE_CLUSTER_OFFSET]
	ret

__kernel_name: db "KERNEL  BIN"
__msg_no_kernel: db "No kernel!", 0xD, 0xA, 0x00
__cluster: dw 0x0000

;; ----------------------------------------------------------
;; Load Hadron ELF kernel
;; ----------------------------------------------------------
load_hadron:
	pusha

	; Find HADRON.ELF in root directory
	call find_hadron
	cmp dx, 0
	je .error_not_found

	mov WORD[__hadron_cluster], dx
	mov DWORD[__hadron_size], eax

	; Check if file size is reasonable (max 512KB for now)
	cmp eax, 0x80000
	ja .error_too_large

	; Prepare location for Hadron kernel
	mov ax, HADRON_SEGMENT
	mov es, ax
	xor bx, bx

	; Calculate number of clusters needed
	mov eax, DWORD[__hadron_size]
	add eax, 511
	shr eax, 9  ; Divide by 512 (bytes per sector)
	mov cx, ax
	cmp cx, HADRON_MAX_CLUSTERS
	jbe .size_ok
	mov cx, HADRON_MAX_CLUSTERS
.size_ok:
	; Read kernel clusters
	mov ax, WORD[__hadron_cluster]
	call _lba_conv
	call _read_disk_sectors

	popa
	clc  ; Clear carry = success
	ret

.error_not_found:
	popa
	mov si, __msg_hadron_not_found
	call printer
	stc  ; Set carry = error
	ret

.error_too_large:
	popa
	mov si, __msg_hadron_too_large
	call printer
	stc  ; Set carry = error
	ret

__msg_hadron_not_found: db "HADRON.ELF not found!", 0xD, 0xA, 0x00
__msg_hadron_too_large: db "HADRON.ELF too large!", 0xD, 0xA, 0x00

;; ----------------------------------------------------------
;; Find Hadron ELF file in root directory
;; Returns: DX = first cluster, EAX = file size
;; ----------------------------------------------------------
find_hadron:
	mov di, ROOT_DIR_BUFFER
	mov bx, 32  ; Check more entries
.loop:
	push bx
	push di
	mov si, __hadron_name
	mov cx, 11
	repe cmpsb
	pop di
	pop bx
	je .found
	add di, FILE_ENTRY_SIZE
	dec bx
	jnz .loop
	; Not found - just return with zero
	xor dx, dx
	xor eax, eax
	ret
.found:
	mov dx, WORD[di + FILE_CLUSTER_OFFSET]
	mov eax, DWORD[di + FILE_SIZE_OFFSET]
	ret

__hadron_name: db "HADRON  ELF"
__hadron_cluster: dw 0x0000
__hadron_size: dd 0x00000000
