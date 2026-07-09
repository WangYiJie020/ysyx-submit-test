.section entry, "ax"
.global _start
.type _start, @function

_start:
	mv s0, zero
	li sp, 0x0f002000

_fsbl_loader:
	la t0, ssbl_load_start
	la t1, _ssbl_start
	la t2, _ssbl_end
  _ssbl_copy:
	lw a1, 0(t0)
	sw a1, 0(t1)
	addi t0, t0, 4
	addi t1, t1, 4
	blt t1, t2, _ssbl_copy
	la t0, _ssbl_loader
	jalr ra, 0(t0)

.section ssbl, "ax"
.global _ssbl_loader
.type _ssbl_loader, @function

_ssbl_loader:
	la t0, text_load_start
	la t1, _text_start
	la t2, _data_start
  _text_copy:
	lw a1, 0(t0)
	sw a1, 0(t1)
	addi t0, t0, 4
	addi t1, t1, 4
	blt t1, t2, _text_copy

	la t0, data_extra_load_start
	la t1, _data_extra_vma_start
	la t2, _data_extra_vma_end
  _data_extra_copy:
	lbu a1, 0(t0)
	sb a1, 0(t1)
	addi t0, t0, 1
	addi t1, t1, 1
	blt t1, t2, _data_extra_copy

	la t0, data_load_start
	la t1, _data_section_vma
	la t2, _bss_start
  _data_copy:
	lbu a1, 0(t0)
	sb a1, 0(t1)
	addi t0, t0, 1
	addi t1, t1, 1
	blt t1, t2, _data_copy

	la t0, _bss_start
	la t1, _end
	_bss_clear:
	sb x0, 0(t0)
	addi t0, t0, 1
	blt t0, t1, _bss_clear

	la a2, _trm_init
	jalr ra, 0(a2)

.section .text, "ax"
.global _read_csr_mvendorid
.global _read_csr_marchid
.type _read_csr_mvendorid, @function
.type _read_csr_marchid, @function

_read_csr_mvendorid:
	csrr a0, mvendorid
	ret

_read_csr_marchid:
	csrr a0, marchid
	ret
