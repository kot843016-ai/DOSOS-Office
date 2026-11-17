; ============================================================
; DOSOS OFFICE - EDIT
; ------------------------------------------------------------
; Text Editor
;
; Version:     0.1 Alpha
; Platform:    DOSOS 16-bit
; Architecture: x86
; Assembler:   FASM
;
; Features:
;   - Text editing
;   - Document management
;
; Project: DOSOS Office Suite
; License: GNU GPL v3.0
; ============================================================

use16
org 0
db 'DX16'

start:
        push    cs
        pop     ds
        push    cs
        pop     es
        cld

        mov     ax, 0003h
        int     10h

        call    parse_args
        call    load_file
        call    draw_frame

main_loop:
        call    calc_cursor_pos
        call    ensure_visible
        call    render_text
        call    update_status
        call    place_hw_cursor

        mov     ah, 03h
        int     60h

        cmp     al, 19
        je      cmd_save
        cmp     al, 27
        je      cmd_exit

        cmp     ah, 4Bh
        je      nav_left
        cmp     ah, 4Dh
        je      nav_right
        cmp     ah, 48h
        je      nav_up
        cmp     ah, 50h
        je      nav_down
        cmp     ah, 47h
        je      nav_home
        cmp     ah, 4Fh
        je      nav_end
        cmp     ah, 49h
        je      nav_pgup
        cmp     ah, 51h
        je      nav_pgdn

        cmp     ah, 0Eh
        je      edit_backspace
        cmp     ah, 53h
        je      edit_delete
        cmp     ah, 1Ch
        je      edit_enter

        cmp     al, 32
        jb      main_loop
        cmp     al, 127
        je      main_loop
        call    insert_char
        jmp     main_loop

parse_args:
        mov     si, 0FF00h
.skip:
        lodsb
        cmp     al, ' '
        je      .skip
        cmp     al, 32
        jb      .default

        mov     di, filename
        mov     cx, 60
.copy:
        stosb
        lodsb
        cmp     al, ' '
        jbe     .done
        loop    .copy
.done:
        mov     byte [di], 0
        ret

.default:
        mov     si, def_filename
        mov     di, filename
        mov     cx, 13
        rep     movsb
        ret

load_file:
        mov     word [buf_len], 0
        mov     word [cur_off], 0
        mov     word [top_line], 0
        mov     word [left_col], 0
        mov     byte [modified], 0

        mov     dx, filename
        mov     ah, 20h
        int     60h
        jc      .ret

        mov     bx, ax
        mov     di, text_buf
        mov     cx, 32000
        mov     ah, 22h
        int     60h
        jc      .close
        mov     [buf_len], ax

        mov     si, text_buf
        mov     di, text_buf
        mov     cx, [buf_len]
        xor     dx, dx
        test    cx, cx
        jz      .stripped
.strip_loop:
        lodsb
        cmp     al, 13
        je      .next
        stosb
        inc     dx
.next:
        loop    .strip_loop
.stripped:
        mov     [buf_len], dx

.close:
        mov     ah, 24h
        int     60h
.ret:
        ret

cmd_save:
        mov     dx, filename
        mov     ah, 21h
        int     60h
        jc      .err

        mov     bx, ax
        mov     si, text_buf
        mov     cx, [buf_len]
        test    cx, cx
        jz      .ok

.write_loop:
        mov     di, line_tmp
        xor     dx, dx
.pack:
        lodsb
        dec     cx
        cmp     al, 10
        je      .eol
        mov     [di], al
        inc     di
        inc     dx
        cmp     dx, 240
        jae     .flush
        test    cx, cx
        jnz     .pack
        jmp     .flush
.eol:
        mov     byte [di], 13
        mov     byte [di+1], 10
        add     dx, 2
.flush:
        push    cx
        push    si
        mov     si, line_tmp
        mov     cx, dx
        mov     ah, 23h
        int     60h
        pop     si
        pop     cx
        jc      .err_close
        test    cx, cx
        jnz     .write_loop

.ok:
        mov     ah, 24h
        int     60h
        mov     byte [modified], 0
        mov     si, msg_saved
        mov     bl, 30h
        call    show_banner
        jmp     main_loop

.err_close:
        mov     ah, 24h
        int     60h
.err:
        mov     si, msg_err
        mov     bl, 4Fh
        call    show_banner
        jmp     main_loop

cmd_exit:
        cmp     byte [modified], 0
        je      .quit

        mov     si, msg_confirm
        mov     bl, 4Fh
        call    show_banner
.ask:
        mov     ah, 03h
        int     60h
        cmp     al, 'y'
        je      .quit
        cmp     al, 'Y'
        je      .quit
        cmp     al, 'n'
        je      .cancel
        cmp     al, 'N'
        je      .cancel
        cmp     al, 27
        je      .cancel
        jmp     .ask

.cancel:
        call    draw_bottom_bar
        jmp     main_loop

.quit:
        mov     ax, 0003h
        int     10h
        retf

insert_char:
        mov     cx, [buf_len]
        cmp     cx, 31998
        jae     .ret
        mov     bx, [cur_off]
        sub     cx, bx
        mov     si, text_buf
        add     si, [buf_len]
        dec     si
        mov     di, si
        inc     di
        std
        rep     movsb
        cld

        mov     di, text_buf
        add     di, bx
        mov     [di], al
        inc     word [buf_len]
        inc     word [cur_off]
        mov     byte [modified], 1
.ret:
        ret

edit_enter:
        mov     al, 10
        call    insert_char
        jmp     main_loop

edit_backspace:
        cmp     word [cur_off], 0
        je      main_loop
        dec     word [cur_off]
        call    delete_char
        jmp     main_loop

edit_delete:
        mov     ax, [cur_off]
        cmp     ax, [buf_len]
        jae     main_loop
        call    delete_char
        jmp     main_loop

delete_char:
        mov     bx, [cur_off]
        mov     cx, [buf_len]
        sub     cx, bx
        dec     cx
        mov     di, text_buf
        add     di, bx
        mov     si, di
        inc     si
        cld
        rep     movsb
        dec     word [buf_len]
        mov     byte [modified], 1
        ret

nav_left:
        cmp     word [cur_off], 0
        je      main_loop
        dec     word [cur_off]
        jmp     main_loop

nav_right:
        mov     ax, [cur_off]
        cmp     ax, [buf_len]
        jae     main_loop
        inc     word [cur_off]
        jmp     main_loop

nav_home:
        mov     bx, [cur_off]
.l:
        test    bx, bx
        jz      .done
        cmp     byte [text_buf + bx - 1], 10
        je      .done
        dec     bx
        jmp     .l
.done:
        mov     [cur_off], bx
        jmp     main_loop

nav_end:
        mov     bx, [cur_off]
        mov     dx, [buf_len]
.l:
        cmp     bx, dx
        jae     .done
        cmp     byte [text_buf + bx], 10
        je      .done
        inc     bx
        jmp     .l
.done:
        mov     [cur_off], bx
        jmp     main_loop

nav_up:
        call    calc_cursor_pos
        cmp     word [cur_line], 0
        je      main_loop
        mov     ax, [cur_line]
        dec     ax
        mov     dx, [cur_col]
        call    move_to_lc
        jmp     main_loop

nav_down:
        call    calc_cursor_pos
        mov     ax, [cur_line]
        inc     ax
        mov     dx, [cur_col]
        call    move_to_lc
        jmp     main_loop

nav_pgup:
        call    calc_cursor_pos
        mov     ax, [cur_line]
        sub     ax, 21
        jnc     .ok
        xor     ax, ax
.ok:
        mov     dx, [cur_col]
        call    move_to_lc
        jmp     main_loop

nav_pgdn:
        call    calc_cursor_pos
        mov     ax, [cur_line]
        add     ax, 21
        mov     dx, [cur_col]
        call    move_to_lc
        jmp     main_loop

move_to_lc:
        xor     bx, bx
        xor     cx, cx
        mov     si, [buf_len]
.fl:
        cmp     cx, ax
        je      .at_l
        cmp     bx, si
        jae     .end_b
        cmp     byte [text_buf + bx], 10
        jne     .nx
        inc     cx
.nx:
        inc     bx
        jmp     .fl
.at_l:
        xor     cx, cx
.fc:
        cmp     cx, dx
        je      .set
        cmp     bx, si
        jae     .set
        cmp     byte [text_buf + bx], 10
        je      .set
        inc     bx
        inc     cx
        jmp     .fc
.end_b:
        mov     bx, si
.set:
        mov     [cur_off], bx
        ret

calc_cursor_pos:
        xor     bx, bx
        xor     cx, cx
        xor     dx, dx
        mov     si, [cur_off]
.l:
        cmp     bx, si
        jae     .done
        cmp     byte [text_buf + bx], 10
        je      .nl
        inc     dx
        jmp     .nx
.nl:
        inc     cx
        xor     dx, dx
.nx:
        inc     bx
        jmp     .l
.done:
        mov     [cur_line], cx
        mov     [cur_col], dx
        ret

ensure_visible:
        mov     ax, [cur_line]
        cmp     ax, [top_line]
        jae     .b
        mov     [top_line], ax
        jmp     .h
.b:
        mov     bx, [top_line]
        add     bx, 20
        cmp     ax, bx
        jbe     .h
        sub     ax, 20
        mov     [top_line], ax
.h:
        mov     ax, [cur_col]
        cmp     ax, [left_col]
        jae     .r
        mov     [left_col], ax
        ret
.r:
        mov     bx, [left_col]
        add     bx, 75
        cmp     ax, bx
        jbe     .ret
        sub     ax, 75
        mov     [left_col], ax
.ret:
        ret

draw_frame:
        push    es
        mov     ax, 0B800h
        mov     es, ax
        xor     di, di

        mov     ax, 7020h
        mov     cx, 80
        rep     stosw

        mov     ax, 1F20h
        stosw
        mov     ax, 1FC9h
        stosw
        mov     ax, 1FCDh
        mov     cx, 76
        rep     stosw
        mov     ax, 1FBBh
        stosw
        mov     ax, 1F20h
        stosw

        mov     dx, 21
.mid:
        mov     ax, 1F20h
        stosw
        mov     ax, 1FBAh
        stosw
        mov     ax, 1F20h
        mov     cx, 76
        rep     stosw
        mov     ax, 1FBAh
        stosw
        mov     ax, 1F20h
        stosw
        dec     dx
        jnz     .mid

        mov     ax, 1F20h
        stosw
        mov     ax, 1FC8h
        stosw
        mov     ax, 1FCDh
        mov     cx, 76
        rep     stosw
        mov     ax, 1FBCh
        stosw
        mov     ax, 1F20h
        stosw

        pop     es

mov     si, title_str
mov     dh, 0
mov     dl, 2
mov     bl, 70h
call    vga_puts
call    draw_bottom_bar
ret
draw_bottom_bar:
mov     si, help_bar
mov     bl, 70h
call    show_banner
ret
show_banner:
push    si
push    bx
push    es
mov     ax, 0B800h
mov     es, ax
mov     di, 24 * 160
mov     al, ' '
mov     ah, bl
mov     cx, 80
rep     stosw
pop     es
pop     bx
pop     si
mov     dh, 24
mov     dl, 2
call    vga_puts
ret
update_status:
mov     si, filename
mov     dh, 0
mov     dl, 21
mov     bl, 70h
call    vga_puts
mov     al, ' '
cmp     byte [modified], 0
je      .ns
mov     al, '*'
.ns:
call    vga_putc
mov     al, ' '
call    vga_putc
call    vga_putc
mov     si, stat_ln
mov     dh, 0
mov     dl, 56
mov     bl, 70h
call    vga_puts
mov     ax, [cur_line]
inc     ax
call    vga_putnum
mov     si, stat_col
call    vga_puts_cur
mov     ax, [cur_col]
inc     ax
call    vga_putnum
mov     al, ' '
call    vga_putc
call    vga_putc
call    vga_putc
ret
render_text:
push    es
mov     ax, 0B800h
mov     es, ax
mov     si, text_buf
mov     dx, [buf_len]
add     dx, text_buf
mov     cx, [top_line]
test    cx, cx
jz      .rows
.skip_l:
cmp     si, dx
jae     .rows
lodsb
cmp     al, 10
jne     .skip_l
loop    .skip_l
.rows:
mov     bp, 2
.row_l:
cmp     bp, 23
jae     .done
mov     ax, bp
mov     bx, 160
push    dx
mul     bx
pop     dx
add     ax, 4
mov     di, ax
mov     cx, [left_col]
test    cx, cx
jz      .cols
.skip_c:
cmp     si, dx
jae     .fill_r
cmp     byte [si], 10
je      .eol_f
inc     si
loop    .skip_c
.cols:
mov     cx, 76
mov     ah, 1Fh
.col_l:
cmp     si, dx
jae     .fill_s
lodsb
cmp     al, 10
je      .pad_e
cmp     al, 9
jne     .put
mov     al, ' '
.put:
stosw
loop    .col_l
.eat:
cmp     si, dx
jae     .next_r
lodsb
cmp     al, 10
jne     .eat
jmp     .next_r
.eol_f:
inc     si
.fill_r:
mov     cx, 76
.pad_e:
mov     ah, 1Fh
.fill_s:
mov     al, ' '
rep     stosw
.next_r:
inc     bp
jmp     .row_l
.done:
pop     es
ret
place_hw_cursor:
mov     ax, [cur_line]
sub     ax, [top_line]
add     al, 2
mov     dh, al
mov     ax, [cur_col]
sub     ax, [left_col]
add     al, 2
mov     dl, al
mov     ah, 02h
xor     bh, bh
int     10h
ret
vga_puts:
mov     [v_row], dh
mov     [v_col], dl
mov     [v_attr], bl
vga_puts_cur:
lodsb
test    al, al
jz      .ret
call    vga_putc
jmp     vga_puts_cur
.ret:
ret
vga_putc:
push    ax
push    bx
push    cx
push    dx
push    di
push    es
mov     cx, 0B800h
mov     es, cx
mov     cl, al
movzx   ax, byte [v_row]
mov     bx, 160
mul     bx
movzx   dx, byte [v_col]
shl     dx, 1
add     ax, dx
mov     di, ax
mov     al, cl
mov     ah, [v_attr]
stosw
inc     byte [v_col]
pop     es
pop     di
pop     dx
pop     bx
pop     cx
pop     ax
ret
vga_putnum:
push    bx
push    cx
push    dx
mov     bx, 10
xor     cx, cx
.div:
xor     dx, dx
div     bx
push    dx
inc     cx
test    ax, ax
jnz     .div
.prt:
pop     ax
add     al, '0'
call    vga_putc
loop    .prt
pop     dx
pop     cx
pop     bx
ret
title_str    db 'DOSOS 16 EDIT | ', 0
help_bar     db 'Ctrl+S: Save   ESC: Exit   Arrows/Home/End/PgUp/PgDn: Move', 0
stat_ln      db 'Ln:', 0
stat_col     db '  Col:', 0
def_filename db 'UNTITLED.TXT', 0
msg_saved    db 'Saved!', 0
msg_err      db 'Write error!', 0
msg_confirm  db 'Unsaved changes! Quit anyway? (Y/N)', 0
modified     db 0
v_row        db 0
v_col        db 0
v_attr       db 0
buf_len      dw 0
cur_off      dw 0
cur_line     dw 0
cur_col      dw 0
top_line     dw 0
left_col     dw 0
filename     rb 64
line_tmp     rb 256
text_buf     rb 32000
