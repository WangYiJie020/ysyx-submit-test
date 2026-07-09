ENTRY(_start)

MEMORY {
	mrom  : ORIGIN = 0x20000000, LENGTH = 4K
	flash : ORIGIN = 0x30000000, LENGTH = 128M
	sram  : ORIGIN = 0x0f000000, LENGTH = 8K
	psram : ORIGIN = 0x80000000, LENGTH = 4M
	sdram : ORIGIN = 0xa0000000, LENGTH = 32M
}

SECTIONS {
	. = ORIGIN(flash);
	.entry : {
		*(entry)
	} > flash

	. = ORIGIN(sram);
	.ssbl : {
		_ssbl_start = .;
		*(ssbl)
		_ssbl_end = .;
	} > sram AT> flash
	ssbl_load_start = LOADADDR(.ssbl);

	. = ORIGIN(sdram);
  .text : {
		_text_start = .;
    *(.text*)
  } > sdram AT> flash 
	text_load_start = LOADADDR(.text);
  .rodata : {
		. = ALIGN(8);
    *(.rodata*)
		. = ALIGN(8);
		*(.srodata.*)
  } > sdram AT> flash 

  .data.extra : {
    /* section information for finsh shell */
    . = ALIGN(8);
    _data_extra_vma_start = .;
		_data_start = .;
    __fsymtab_start = .;
    KEEP(*(FSymTab))
    __fsymtab_end = .;
    . = ALIGN(8);
    __vsymtab_start = .;
    KEEP(*(VSymTab))
    __vsymtab_end = .;
    . = ALIGN(8);

    /* section information for initial. */
    . = ALIGN(8);
    __rt_init_start = .;
    KEEP(*(SORT(.rti_fn*)))
    __rt_init_end = .;
    . = ALIGN(8);

    __rt_utest_tc_tab_start = .;
    KEEP(*(UtestTcTab))
    __rt_utest_tc_tab_end = .;

    . = ALIGN(8);
    __am_apps_data_start = .;
    *(__am_apps.data*)
    *(__am_apps.sdata*)
    __am_apps_data_end = .;
    _data_extra_vma_end = .;
    . = ALIGN(8);
  } > sdram AT> flash

  .data : {
		. = ALIGN(8);
		_data_section_vma = .;
    *(.data.*)
		. = ALIGN(8);
		*(.sdata.*)
  } > sdram AT> flash 
data_extra_load_start = LOADADDR(.data.extra);
data_load_start = LOADADDR(.data);

  .bss.extra : {
    . = ALIGN(8);
		_bss_start = .;
    __am_apps_bss_start = .;
    *(__am_apps.bss*)
    *(__am_apps.sbss*)
    *(__am_apps.scommon*)
    __am_apps_bss_end = .;
    . = ALIGN(8);
  } > sdram 

  .bss : {
		. = ALIGN(0x8);
    *(.bss*)
    *(.sbss*)
    *(.scommon)
  } > sdram
  end = .;
  _end = .;
  _heap_start = ALIGN(0x1000);
}

