palette_obj1_colors:
	.dw $0421 * 31 + $8000
	.dw $0421 * 21 + $8000
	.dw $0421 * 10
	.dw $0421 * 0

palette_obj0_colors:
	.dw $0421 * 31 + $8000
	.dw $0421 * 21 + $8000
	.dw $0421 * 10
	.dw $0421 * 0

palette_bg_colors:
	.dw $0421 * 31 + $8000
	.dw $0421 * 21 + $8000
	.dw $0421 * 10
	.dw $0421 * 0

update_palettes:
	ld hl,(hram_base+BGP)
curr_palettes = $+1
	ld de,$FFFFFF
	or a
	sbc hl,de
	ret z
	add hl,de
	ld (curr_palettes),hl
	ld de,mpLcdPalette + (9*2)-1
	push bc
	 ld ix,palette_obj1_colors+1-8
	 ld c,(9*2) + 3
update_palettes_next_loop:
	 lea ix,ix+8
	 ld b,4
update_palettes_loop:
	 xor a
	 add hl,hl
	 adc a,a
	 add hl,hl
	 adc a,a
	 add a,a
	 djnz _
	 dec c
	 jr nz,update_palettes_next_loop
	 inc de
	 ld e,16*2-1
	 scf
_
	 ld (update_palettes_smc),a
	 push hl
update_palettes_smc = $+2
	  lea hl,ix
	  ldd
	  ldd
	 pop hl
	 jr nc,update_palettes_loop
	pop bc
	ret
	
cursorcode:
	.org cursormem
#include "opgenroutines.asm"
	
draw_sprites_done:
draw_sprites_save_sp = $+1
	ld sp,0
	ret
	
draw_sprites:
	ld (draw_sprites_save_sp),sp
	ld ix,hram_base+$FEA1
draw_next_sprite:
	dec ixl
	jr z,draw_sprites_done
	lea ix,ix-3
	ld a,(ix-1)
	dec a
	cp 159
	jr nc,draw_next_sprite
	ld e,a
	ld a,(ix)
	ld b,a
	dec a
	cp 167
	jr nc,draw_next_sprite
	
	ld iy,scanlineLUT
	ld d,3
	mlt de
	add iy,de
	
	ld e,(ix+1)
	ld d,64
	mlt de
	ld hl,vram_pixels_start
	add hl,de
	ex de,hl
	
	; Set HL=0
	sbc hl,hl
	
	ld c,(ix+2)
	bit 5,c
	jr nz,draw_sprite_hflip
	sub 7
	jr c,_
	ld b,8
	ld l,a
	add a,256-152
	jr nc,draw_sprite_no_hflip_done
	cpl
	adc a,b
	ld b,a
	jr draw_sprite_no_hflip_done
_
	ld a,e
	add a,8
	sub b
	ld e,a
	jr draw_sprite_no_hflip_done
	
draw_sprite_hflip:
	ld l,a
	cp 7
	jr c,draw_sprite_hflip_done
	ld b,8
	sub 159
	jr c,draw_sprite_hflip_done
	ld l,159
	ld b,a
	add a,e
	ld e,a
	ld a,8
	sub b
	ld b,a
draw_sprite_hflip_done:
	ld a,$2B	;DEC HL
	jr _
draw_sprite_no_hflip_done:
	ld a,$23	;INC HL
_
	
	inc hl
	ld sp,hl
	
	bit 4,c
	ld l,$33
	jr z,_
	add hl,hl
_
	
	bit 6,c
	ld h,3
	jr z,_
	ld h,-3
LCDC_2_smc_1 = $+2
	lea iy,iy+(7*3)
_
	
	bit 7,c
LCDC_2_smc_2 = $+1
	ld c,8
LCDC_2_smc_3 = $+1
	res 6,c		;res 6,e when 8x16 sprites
	jr nz,draw_sprite_priority
	
draw_sprite_normal:
	ld (draw_sprite_normal_hdir),a
	ld a,l
	ld (draw_sprite_normal_palette),a
	ld a,h
	ld (draw_sprite_normal_vdir),a
	ld a,e
draw_sprite_normal_row:
	ld hl,(iy)
	add hl,sp
draw_sprite_normal_vdir = $+2
	lea iy,iy+3
	jr c,draw_sprite_normal_vclip
	push.s bc
draw_sprite_normal_palette = $+1
	 ld c,$33
draw_sprite_normal_pixels:
	 ld a,(de)
	 add a,c
	 jr c,_
	 ld (hl),a
_
	 inc de
draw_sprite_normal_hdir:
	 inc hl
	 djnz draw_sprite_normal_pixels
	pop.s bc
	ld a,e
	sub b
draw_sprite_normal_vclip:
	add a,8
	ld e,a
	dec c
	jr nz,draw_sprite_normal_row
	jp draw_next_sprite
	
draw_sprite_priority:
	ld (draw_sprite_priority_hdir),a
	ld a,l
	ld (draw_sprite_priority_palette),a
	ld a,h
	ld (draw_sprite_priority_vdir),a
	ld a,e
draw_sprite_priority_row:
	ld hl,(iy)
	add hl,sp
draw_sprite_priority_vdir = $+2
	lea iy,iy+3
	jr c,draw_sprite_priority_vclip
	push.s bc
draw_sprite_priority_palette = $+1
	 ld c,$33
draw_sprite_priority_pixels:
	 ld a,(hl)
	 inc a
	 jr nz,_
	 ld a,(de)
	 add a,c
	 jr c,_
	 ld (hl),a
_
	 inc de
draw_sprite_priority_hdir:
	 inc hl
	 djnz draw_sprite_priority_pixels
	pop.s bc
	ld a,e
	sub b
draw_sprite_priority_vclip:
	add a,8
	ld e,a
	dec c
	jr nz,draw_sprite_priority_row
	jp draw_next_sprite
	
write_vram_and_expand:
	exx
	push bc
	 ld c,a
	 ex af,af'
	 xor a
	 ld (mpTimerCtrl),a
	 ld a,$FE
	 ld (mpTimer1Count),a
	 ld hl,vram_base
	 lea de,ix
	 add hl,de
	 ld (hl),c
	 ld a,d
	 sub $98
	 jr c,write_vram_pixels
	 ld h,a
	 ld a,e
	 and $E0
	 ld l,a
	 xor e
	 add a,a
	 ld e,a
	 ld a,c
	 add hl,hl
	 add hl,hl
	 add.s hl,hl
	 ld bc,vram_tiles_start
	 add hl,bc
	 ld d,0
	 add hl,de
	 ld e,64
	 ld c,a
	 ld b,e
	 mlt bc
	 ld (hl),c
	 inc hl
	 ld (hl),b
	 add hl,de
	 ld (hl),b
	 dec hl
	 ld (hl),c
	 add hl,de
	 add a,a
	 jr c,_
	 set 6,b
_
	 ld (hl),c
	 inc hl
	 ld (hl),b
	 add hl,de
	 ld (hl),b
	 dec hl
	 ld (hl),c
	pop bc
	exx
	pop.s ix
	ld a,TMR_ENABLE
	ld (mpTimerCtrl),a
	ex af,af'
	jp.s (ix)
write_vram_pixels:
	 res 0,l
	 ld hl,(hl)
	 ex de,hl
	 res 0,l
	 add hl,hl
	 add hl,hl
	 ld bc,vram_pixels_start-($8000*4)
	 add hl,bc
	 ld bc,$0011
	 ld a,d \ cpl \ add a,a \ ld d,a
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a \ inc hl \ sla d
	 sbc a,a \ or c \ sla e \ jr nc,$+4 \ rlca \ adc a,b \ ld (hl),a

	pop bc
	exx
	pop.s ix
	ld a,TMR_ENABLE
	ld (mpTimerCtrl),a
	ex af,af'
	jp.s (ix)
	
scanline_do_subtile:
	ld a,8
	sub b
	jr nc,_
	xor a
_
	pop.s bc
	add hl,bc
	ld c,a
	ld a,ixl
	sub c
	ret c
	ld b,0
	add hl,bc
	ld c,a
	inc c
	ldir
	ret
	
	
	; Input: B=Start X+8, A=Length-1, HL=pixel base pointer, DE=pixel output pointer, IY=scanline pointer, SPS=tilemap pointer
scanline_do_render:
	ld c,a
	and 7
	ld ixl,a
	xor c
	jr z,scanline_do_subtile
	ld c,a
	rrca
	rrca
	sub c
	add a,20*6
	ld (scanline_unrolled_smc),a
	ld sp,hl
	
	ld a,8
	sub b
	jr nc,_
	xor a
	ld b,8
_
	ld c,a
	ld a,b
	pop.s hl
	add hl,sp
	ld b,0
	add hl,bc
	ld c,a
	ldir
	ld a,8
scanline_unrolled_smc = $+1
	jr $+2
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl \ add hl,sp \ ld c,a \ ldir
	pop.s hl
	add hl,sp
	ld c,ixl
	inc c
	ldir
	
render_save_spl = $+1
	ld sp,0
	ret
cursorcodesize = $-cursormem
	.org cursorcode+cursorcodesize
	
	.echo "Cursor memory code size: ", cursorcodesize
	
palettecode:
	.org palettemem

	.dw 0,0,0,0,0,0,0,0,0
	.dw 0
	.dw $DA5A,$AE92,$FFFF,$0000,$088A
	.dw 0
	
render_scanline_off:
	push de
	pop hl
	inc de
	ld bc,159
	ld (hl),WHITE_BYTE
	ldir
	jp render_scanline_next
	
	; Input: A=LY (A<144 unless called from vblank)
render_scanlines:
myLY = $+1
	ld c,0
	sub c
	ret z
	ld b,a
	push ix
	 push iy
scanline_ptr = $+1
	  ld de,0
scanlineLUT_ptr = $+2
	  ld iy,0
#ifndef DBGNOSCALE
scanline_scale_accumulator = $+2
	  ld ixh,0
#endif
	  ld.sis (render_save_sps),sp
	  ld a,vram_tiles_start >> 16
	  ld mb,a
	  ld hl,-6
	  add hl,sp
	  ld (render_save_spl),hl
render_scanline_loop:
	  push bc
	   ; Store current scanline pointer minus 1 in LUT
	   ; Or store -1 if sprites are disabled
	   ; Carry flag is set
	   sbc hl,hl
LCDC_1_smc:
	   nop	; add hl,de when sprites enabled
	   ld (iy),hl
	   lea iy,iy+3
	   
	   ; Zero flag is reset
LCDC_7_smc:
	   jr z,render_scanline_off
	   ld a,c
SCY_smc = $+1
	   add a,0
	   rrca
	   rrca
	   rrca
	   ld l,a
	   and $1F
	   ld h,a
	   xor l
	   rrca
	   rrca
	   
SCX_smc_1 = $+1
	   ld l,0
	
LCDC_4_smc = $+2
LCDC_3_smc = $+3
	   ld.sis sp,vram_tiles_start & $FFFF
	   add.s hl,sp
	   ld.s sp,hl
	 
LCDC_0_smc = $+3
	   ld hl,vram_pixels_start
	   ld l,a
	   
SCX_smc_2 = $+1
	   ld b,8
	 
LCDC_5_smc:
	   ; Carry flag is reset
	   jr nc,scanline_no_window
	 
	   ld a,c
WY_smc = $+1
	   cp 0
WX_smc_1:
	   jr c,scanline_no_window
	   
WX_smc_2 = $+1
	   ld a,0
	   sub b
	   call nc,scanline_do_render
	 
window_tile_ptr = $+2
	   ld.sis sp,vram_tiles_start & $FFFF	;(+$2000) (+$80)
	 
window_tile_offset = $+1
	   ld hl,vram_pixels_start
	   ld a,l
	   add a,8
	   cp 64
	   jr c,_
	   ld a,(window_tile_ptr+1)
	   inc a
	   ld (window_tile_ptr+1),a
	   xor a
_
	   ld (window_tile_offset),a
	 
WX_smc_3 = $+1
	   ld b,0
	 
scanline_no_window:
	   ld a,167
	   sub b
	   call nc,scanline_do_render
	 
render_scanline_next:
	   ; Advance to next scanline
#ifndef DBGNOSCALE
	   ld a,ixh
	   add a,$55
	   ld ixh,a
	   jr c,_
	   ex de,hl
	   ld c,160
	   add hl,bc
	   ex de,hl
	   scf
_
#endif
	  pop bc
	  inc c
	  djnz render_scanline_loop
	  ld (scanline_ptr),de
	  ld (scanlineLUT_ptr),iy
#ifndef DBGNOSCALE
	  ld a,ixh
	  ld (scanline_scale_accumulator),a
#endif
	  ld a,c
	  ld (myLY),a
	  ; Restore important Z80 things
	  ld a,z80codebase >> 16
	  ld mb,a
	  ld.sis sp,(render_save_sps)
	 pop iy
	pop ix
	ret
	
palettecodesize = $-palettemem
	.org palettecode+palettecodesize
	
	.echo "Palette memory code size: ", palettecodesize