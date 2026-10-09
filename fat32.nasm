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

;; fat32.nasm
;; Read-only access to a FAT32 file system on the first MBR partition
;; https://www.pjrc.com/tech/8051/ide/fat32.html

PARTITION_TABLE		equ 0x7C00 + 446
MAX_SEC_PER_CLUS	equ (0x10000 - DIR_BUF) / 512

struc part
	.status:	resb 1
	.chs_first:	resb 3
	.type:		resb 1
	.chs_last:	resb 3
	.lba:		resd 1
	.sectors:	resd 1
endstruc

struc bpb
	.jmp:		resb 3
	.oem:		resb 8
	.bytes_per_sec:	resw 1
	.sec_per_clus:	resb 1
	.rsvd_secs:	resw 1
	.num_fats:	resb 1
	.root_entries:	resw 1
	.total_secs16:	resw 1
	.media:		resb 1
	.fat_size16:	resw 1
	.secs_per_track:resw 1
	.heads:		resw 1
	.hidden_secs:	resd 1
	.total_secs32:	resd 1
	.fat_size32:	resd 1
	.flags:		resw 1
	.version:	resw 1
	.root_cluster:	resd 1
endstruc

fat_init:
	mov si, PARTITION_TABLE
	mov al, [si + part.type]
	cmp al, 0x0B
	je .fat32
	cmp al, 0x0C
	jne .fail
.fat32:
	mov eax, [si + part.lba]
	mov bx, DIR_SEG
	call read_sector

	cmp word [DIR_BUF + bpb.bytes_per_sec], 512
	jne .fail
	mov cl, [DIR_BUF + bpb.sec_per_clus]
	mov [sec_per_clus], cl
	dec cl
	cmp cl, MAX_SEC_PER_CLUS - 1
	ja .fail

	movzx ecx, word [DIR_BUF + bpb.rsvd_secs]
	add eax, ecx
	mov [fat_lba], eax

	movzx cx, byte [DIR_BUF + bpb.num_fats]
	jcxz .fail
.add_fat:
	add eax, [DIR_BUF + bpb.fat_size32]
	loop .add_fat
	mov [data_lba], eax

	mov eax, [DIR_BUF + bpb.root_cluster]
	mov [root_cluster], eax
	ret
.fail:
	mov si, msg_no_fat32
	jmp fatal

;; Read a cluster, but at most dx sectors
;; in:  eax = cluster, bx = destination segment, dx = sector limit
;; out: bx and dx advanced by the sectors read
read_cluster:
	push eax
	push ecx
	sub eax, 2
	movzx ecx, byte [sec_per_clus]
	imul eax, ecx
	add eax, [data_lba]
.next:
	call read_sector
	inc eax
	add bx, 512 >> 4
	dec dx
	loopnz .next
	pop ecx
	pop eax
	ret

;; in:  eax = cluster
;; out: eax = next cluster, CF set if it is a valid data cluster
next_cluster:
	push bx
	push ecx
	push di
	shl eax, 2
	mov di, ax
	and di, 511
	shr eax, 9
	add eax, [fat_lba]
	mov bx, FAT_SEG
	call read_sector
	mov eax, [FAT_BUF + di]
	and eax, 0x0FFFFFFF
	lea ecx, [eax - 2]
	cmp ecx, 0x0FFFFFF7 - 2		; 2 <= eax < bad cluster marker
	pop di
	pop ecx
	pop bx
	ret

msg_no_fat32:		db "No FAT32", 0
