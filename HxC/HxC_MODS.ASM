	IF	INCBOOT
*GET	HXCBOOT			;Boot sector
*GET	HXCCONIO		;System Console
	ENDIF

*GET	HXC			;Main app
*GET	HXCSYS			;System routines
*GET	HXCDISP			;Disp buffer routines
*GET	HXCFDC			;HxC FDC routines
*GET	HXCLBA			;LBA routines
*GET	HXCFAT32		;FAT32 routines
*GET	HXCFILE			;FILE routines
*GET	HXCDIR			;Directory routines
*GET	HXCBrow			;Table Browser
*GET	HXCSELCT		;File Selector
*GET	HXCSlot			;Slot Selector
*GET	HxCSDCFG		;HXCSDFE.CFG routines
*GET	HXCSORT			;Sorting algorithms
*GET	HXCZAP			;Sector Zapper

	END
