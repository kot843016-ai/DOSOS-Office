; ============================================================
; DOSOS OFFICE - CALC
; ------------------------------------------------------------
; Spreadsheet Processor
;
; Version:     0.1 Alpha
; Platform:    DOSOS 16-bit
; Architecture: x86
; Assembler:   FASM
;
; Features:
;   - Spreadsheet cell editing
;   - CSV file support
;   - Formula calculations
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
        call    hide_cursor

        call    clear_sheet
        call    parse_args
        call    load_csv
        call    recalc_all
        call    draw_static_ui

main_loop:
        call    render_grid
        call    render_top_info

        mov     ah, 03h
        int     60h

        cmp     al, 19
        je      cmd_save
        cmp     al, 27
        je      cmd_exit

        cmp     ah, 48h
        je      nav_up
        cmp     ah, 50h
        je      nav_down
        cmp     ah, 4Bh
        je      nav_left
        cmp     ah, 4Dh
        je      nav_right
        cmp     ah, 49h
        je      nav_pgup
        cmp     ah, 51h
        je      nav_pgdn

        cmp     ah, 53h
        je      cmd_clear
        cmp     ah, 1Ch
        je      cmd_edit
        cmp     ah, 3Ch
        je      cmd_edit

        cmp     al, 32
        jb      main_loop
        cmp     al, 127
        jae     main_loop

        mov     [first_ch], al
        jmp     cmd_edit_char

nav_up:
        cmp     byte [cur_r], 0
        je      main_loop
        dec     byte [cur_r]
        call    fix_scroll
        jmp     main_loop

nav_down:
        cmp     byte [cur_r], 49
        jae     main_loop
        inc     byte [cur_r]
        call    fix_scroll
        jmp     main_loop

nav_left:
        cmp     byte [cur_c], 0
        je      main_loop
        dec     byte [cur_c]
        call    fix_scroll
        jmp     main_loop

nav_right:
        cmp     byte [cur_c], 15
        jae     main_loop
        inc     byte [cur_c]
        call    fix_scroll
        jmp     main_loop

nav_pgup:
        mov     al, [cur_r]
        sub     al, 18
        jnc     .ok
        xor     al, al
.ok:
        mov     [cur_r], al
        call    fix_scroll
        jmp     main_loop

nav_pgdn:
        mov     al, [cur_r]
        add     al, 18
        cmp     al, 49
        jbe     .ok
        mov     al, 49
.ok:
        mov     [cur_r], al
        call    fix_scroll
        jmp     main_loop

fix_scroll:
        mov     al, [cur_r]
        cmp     al, [top_r]
        jae     .rb
        mov     [top_r], al
        jmp     .ch
.rb:
        mov     ah, [top_r]
        add     ah, 18
        cmp     al, ah
        jbe     .ch
        sub     al, 18
        mov     [top_r], al
.ch:
        mov     al, [cur_c]
        cmp     al, [left_c]
        jae     .cr
        mov     [left_c], al
        ret
.cr:
        mov     ah, [left_c]
        add     ah, 6
        cmp     al, ah
        jbe     .ret
        sub     al, 6
        mov     [left_c], al
.ret:
        ret

cmd_clear:
        mov     al, [cur_r]
        mov     ah, [cur_c]
        call    get_cell_ptr
        mov     cx, 32
        xor     al, al
        rep     stosb
        call    recalc_all
        jmp     main_loop

cmd_exit:
        mov     ax, 0003h
        int     10h
        call    show_cursor
        retf

cmd_edit:
        mov     byte [first_ch], 0
cmd_edit_char:
        mov     al, [cur_r]
        mov     ah, [cur_c]
        call    get_cell_ptr
        mov     si, di
        mov     di, edit_buf
        call    strcpy

        mov     si, edit_buf
        call    strlen
        mov     [edit_len], cx

        cmp     byte [first_ch], 0
        je      .edit_loop
        mov     di, edit_buf
        mov     al, [first_ch]
        stosb
        mov     byte [di], 0
        mov     word [edit_len], 1

.edit_loop:
        call    render_edit_line
        mov     ah, 03h
        int     60h

        cmp     al, 13
        je      .commit
        cmp     al, 27
        je      .cancel
        cmp     ah, 0Eh
        je      .bs

        cmp     al, 32
        jb      .edit_loop
        cmp     al, 127
        jae     .edit_loop
        cmp     word [edit_len], 30
        jae     .edit_loop

        mov     bx, [edit_len]
        mov     [edit_buf + bx], al
        inc     word [edit_len]
        mov     byte [edit_buf + bx + 1], 0
        jmp     .edit_loop

.bs:
        cmp     word [edit_len], 0
        je      .edit_loop
        dec     word [edit_len]
        mov     bx, [edit_len]
        mov     byte [edit_buf + bx], 0
        jmp     .edit_loop

.commit:
        mov     al, [cur_r]
        mov     ah, [cur_c]
        call    get_cell_ptr
        mov     si, edit_buf
        call    strcpy
        call    recalc_all

.cancel:
        call    hide_cursor
        jmp     main_loop

render_edit_line:
        push    es
        mov     ax, 0B800h
        mov     es, ax
        mov     di, 160
        mov     ax, 7020h
        mov     cx, 80
        rep     stosw
        pop     es

        mov     byte [v_row], 1
        mov     byte [v_col], 1
        mov     byte [v_attr], 70h

        mov     al, '['
        call    vga_putc
        mov     al, [cur_c]
        add     al, 'A'
        call    vga_putc
        movzx   ax, byte [cur_r]
        inc     ax
        call    vga_putnum
        mov     al, ']'
        call    vga_putc
        mov     al, ' '
        call    vga_putc
        mov     al, '>'
        call    vga_putc
        mov     al, ' '
        call    vga_putc

        mov     si, edit_buf
        call    vga_puts_cur

        mov     ah, 02h
        xor     bh, bh
        mov     dh, 1
        mov     dl, [v_col]
        int     10h
        call    show_cursor
        ret

parse_args:
        mov     si, 0FF00h
.sk:
        lodsb
        cmp     al, ' '
        je      .sk
        cmp     al, 32
        jb      .def
        mov     di, filename
        mov     cx, 60
.cp:
        stosb
        lodsb
        cmp     al, ' '
        jbe     .dn
        loop    .cp
.dn:
        mov     byte [di], 0
        ret
.def:
        mov     si, def_name
        mov     di, filename
        mov     cx, 10
        rep     movsb
        ret

clear_sheet:
        mov     di, sheet_raw
        xor     al, al
        mov     cx, 50 * 16 * 32
        rep     stosb
        ret

load_csv:
        mov     dx, filename
        mov     ah, 20h
        int     60h
        jc      .ret
        mov     bx, ax
        mov     di, io_buf
        mov     cx, 16384
        mov     ah, 22h
        int     60h
        push    ax
        mov     ah, 24h
        int     60h
        pop     cx
        test    cx, cx
        jz      .ret

        mov     si, io_buf
        mov     dx, si
        add     dx, cx
        xor     al, al
        xor     ah, ah

.parse:
        cmp     si, dx
        jae     .ret
        push    ax
        call    get_cell_ptr
        pop     ax
        xor     cx, cx

.cell:
        cmp     si, dx
        jae     .end_cell
        mov     bl, [si]
        inc     si
        cmp     bl, 13
        je      .cell
        cmp     bl, 10
        je      .next_row
        cmp     bl, ','
        je      .next_col
        cmp     cx, 30
        jae     .cell
        mov     [di], bl
        inc     di
        inc     cx
        jmp     .cell

.next_col:
        mov     byte [di], 0
        inc     ah
        cmp     ah, 16
        jb      .parse
        xor     ah, ah
        inc     al
        cmp     al, 50
        jae     .ret
        jmp     .parse

.next_row:
        mov     byte [di], 0
        xor     ah, ah
        inc     al
        cmp     al, 50
        jae     .ret
        jmp     .parse

.end_cell:
        mov     byte [di], 0
.ret:
        ret

cmd_save:
        mov     dx, filename
        mov     ah, 21h
        int     60h
        jc      .err
        mov     bx, ax

        xor     al, al
.r_loop:
        cmp     al, 50
        jae     .close
        mov     di, line_buf
        xor     ah, ah
.c_loop:
        cmp     ah, 16
        jae     .eol
        push    ax
        push    di
        call    get_cell_ptr
        mov     si, di
        pop     di
.cp_c:
        lodsb
        test    al, al
        jz      .cp_done
        stosb
        jmp     .cp_c
.cp_done:
        pop     ax
        cmp     ah, 15
        je      .no_comma
        mov     byte [di], ','
        inc     di
.no_comma:
        inc     ah
        jmp     .c_loop

.eol:
        mov     byte [di], 13
        inc     di
        mov     byte [di], 10
        inc     di

        mov     cx, di
        sub     cx, line_buf
        push    ax
        push    bx
        mov     si, line_buf
        mov     ah, 23h
        int     60h
        pop     bx
        pop     ax
        inc     al
        jmp     .r_loop

.close:
        mov     ah, 24h
        int     60h
        mov     si, msg_saved
        mov     bl, 30h
        call    flash_msg
        jmp     main_loop
.err:
        mov     si, msg_err
        mov     bl, 4Fh
        call    flash_msg
        jmp     main_loop

flash_msg:
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
        mov     ah, 03h
        int     60h
        call    draw_help_bar
        ret

get_cell_ptr:
        push    ax
        push    bx
        movzx   bx, al
        shl     bx, 4
        movzx   ax, ah
        add     bx, ax
        shl     bx, 5
        lea     di, [sheet_raw + bx]
        pop     bx
        pop     ax
        ret

get_val_ptr:
        push    ax
        push    bx
        movzx   bx, al
        shl     bx, 4
        movzx   ax, ah
        add     bx, ax
        shl     bx, 2
        lea     di, [sheet_val + bx]
        pop     bx
        pop     ax
        ret

recalc_all:
        mov     byte [pass_cnt], 0
.pass:
        xor     al, al
.rl:
        cmp     al, 50
        jae     .next_pass
        xor     ah, ah
.cl:
        cmp     ah, 16
        jae     .nr
push    ax
call    eval_cell
pop     ax
inc     ah
jmp     .cl
.nr:
inc     al
jmp     .rl
.next_pass:
inc     byte [pass_cnt]
cmp     byte [pass_cnt], 3
jb      .pass
ret
eval_cell:
push    ax
call    get_cell_ptr
mov     si, di
pop     ax
call    get_val_ptr
mov     [val_dst], di
mov     al, [si]
test    al, al
jz      .zero
cmp     al, '='
je      .formula
call    parse_int
mov     di, [val_dst]
mov     [di], eax
ret
.zero:
mov     di, [val_dst]
mov     dword [di], 0
ret
.formula:
inc     si
call    skip_ws
cmp     byte [si], 'S'
je      .chk_sum
cmp     byte [si], 's'
je      .chk_sum
cmp     byte [si], 'A'
je      .chk_avg
cmp     byte [si], 'a'
je      .chk_avg
.expr:
call    eval_expr
mov     di, [val_dst]
mov     [di], eax
ret
.chk_sum:
cmp     byte [si+1], 'U'
je      .do_sum
cmp     byte [si+1], 'u'
jne     .expr
.do_sum:
add     si, 3
call    eval_range
mov     di, [val_dst]
mov     [di], eax
ret
.chk_avg:
cmp     byte [si+1], 'V'
je      .do_avg
cmp     byte [si+1], 'v'
jne     .expr
.do_avg:
add     si, 3
call    eval_range
test    ecx, ecx
jz      .avg_z
cdq
idiv    ecx
.avg_z:
mov     di, [val_dst]
mov     [di], eax
ret
eval_range:
call    skip_ws
cmp     byte [si], '('
jne     .empty
inc     si
call    parse_ref
jc      .empty
mov     [r_start], ax
call    skip_ws
cmp     byte [si], ':'
jne     .empty
inc     si
call    parse_ref
jc      .empty
mov     [r_end], ax
xor     eax, eax
xor     ecx, ecx
mov     dl, byte [r_start]
.rl:
cmp     dl, byte [r_end]
ja      .done
mov     dh, byte [r_start + 1]
.cl:
cmp     dh, byte [r_end + 1]
ja      .nr
push    eax
push    ecx
push    dx
mov     al, dl
mov     ah, dh
call    get_val_ptr
mov     ebx, [di]
pop     dx
pop     ecx
pop     eax
add     eax, ebx
inc     ecx
inc     dh
jmp     .cl
.nr:
inc     dl
jmp     .rl
.done:
ret
.empty:
xor     eax, eax
xor     ecx, ecx
ret
eval_expr:
call    eval_term
.loop:
call    skip_ws
mov     bl, [si]
cmp     bl, '+'
je      .add
cmp     bl, '-'
je      .sub
ret
.add:
inc     si
push    eax
call    eval_term
mov     ebx, eax
pop     eax
add     eax, ebx
jmp     .loop
.sub:
inc     si
push    eax
call    eval_term
mov     ebx, eax
pop     eax
sub     eax, ebx
jmp     .loop
eval_term:
call    eval_factor
.loop:
call    skip_ws
mov     bl, [si]
cmp     bl, '*'
je      .mul
cmp     bl, '/'
je      .div
ret
.mul:
inc     si
push    eax
call    eval_factor
mov     ebx, eax
pop     eax
imul    ebx
jmp     .loop
.div:
inc     si
push    eax
call    eval_factor
mov     ebx, eax
pop     eax
test    ebx, ebx
jz      .div0
cdq
idiv    ebx
jmp     .loop
.div0:
xor     eax, eax
jmp     .loop
eval_factor:
call    skip_ws
mov     al, [si]
cmp     al, '('
je      .paren
cmp     al, '-'
je      .neg
cmp     al, 'A'
jb      .num
cmp     al, 'P'
jbe     .ref
cmp     al, 'a'
jb      .num
cmp     al, 'p'
jbe     .ref
.num:
call    parse_int
ret
.neg:
inc     si
call    eval_factor
neg     eax
ret
.paren:
inc     si
call    eval_expr
call    skip_ws
cmp     byte [si], ')'
jne     .ret
inc     si
.ret:
ret
.ref:
call    parse_ref
jc      .zero
call    get_val_ptr
mov     eax, [di]
ret
.zero:
xor     eax, eax
ret
parse_ref:
call    skip_ws
mov     al, [si]
cmp     al, 'a'
jb      .up
sub     al, 32
.up:
cmp     al, 'A'
jb      .fail
cmp     al, 'P'
ja      .fail
sub     al, 'A'
mov     [ref_c], al
inc     si
xor     bx, bx
xor     cx, cx
.dig:
mov     al, [si]
cmp     al, '0'
jb      .done_d
cmp     al, '9'
ja      .done_d
sub     al, '0'
movzx   dx, al
imul    bx, 10
add     bx, dx
inc     si
inc     cx
jmp     .dig
.done_d:
test    cx, cx
jz      .fail
dec     bx
cmp     bx, 50
jae     .fail
mov     al, bl
mov     ah, [ref_c]
clc
ret
.fail:
stc
ret
parse_int:
call    skip_ws
xor     eax, eax
xor     cl, cl
cmp     byte [si], '-'
jne     .pos
mov     cl, 1
inc     si
.pos:
mov     bl, [si]
cmp     bl, '0'
jb      .done
cmp     bl, '9'
ja      .done
sub     bl, '0'
movzx   ebx, bl
imul    eax, 10
add     eax, ebx
inc     si
jmp     .pos
.done:
test    cl, cl
jz      .ret
neg     eax
.ret:
ret
skip_ws:
cmp     byte [si], ' '
jne     .ret
inc     si
jmp     skip_ws
.ret:
ret
draw_static_ui:
push    es
mov     ax, 0B800h
mov     es, ax
xor     di, di
mov     ax, 3020h
mov     cx, 80
rep     stosw
mov     ax, 7020h
mov     cx, 80
rep     stosw
mov     ax, 1F20h
mov     cx, 80 * 22
rep     stosw
mov     ax, 3020h
mov     cx, 80
rep     stosw
pop     es
mov     si, title_str
mov     dh, 0
mov     dl, 2
mov     bl, 30h
call    vga_puts
mov     si, filename
call    vga_puts_cur
call    draw_help_bar
ret
draw_help_bar:
push    es
mov     ax, 0B800h
mov     es, ax
mov     di, 24 * 160
mov     ax, 3020h
mov     cx, 80
rep     stosw
pop     es
mov     si, help_str
mov     dh, 24
mov     dl, 2
mov     bl, 30h
call    vga_puts
ret
render_top_info:
push    es
mov     ax, 0B800h
mov     es, ax
mov     di, 160
mov     ax, 7020h
mov     cx, 80
rep     stosw
pop     es
mov     byte [v_row], 1
mov     byte [v_col], 1
mov     byte [v_attr], 70h
mov     al, '['
call    vga_putc
mov     al, [cur_c]
add     al, 'A'
call    vga_putc
movzx   ax, byte [cur_r]
inc     ax
call    vga_putnum
mov     al, ']'
call    vga_putc
mov     al, ' '
call    vga_putc
mov     al, '='
call    vga_putc
mov     al, ' '
call    vga_putc
mov     al, [cur_r]
mov     ah, [cur_c]
call    get_cell_ptr
mov     si, di
call    vga_puts_cur
ret
render_grid:
push    es
mov     ax, 0B800h
mov     es, ax
mov     di, 2 * 160
mov     ax, 7020h
mov     cx, 80
rep     stosw
mov     di, 3 * 160
mov     ax, 1B2Dh
mov     cx, 80
rep     stosw
pop     es
mov     byte [v_row], 2
mov     byte [v_col], 5
mov     byte [v_attr], 70h
mov     al, '|'
call    vga_putc
mov     byte [v_row], 3
mov     byte [v_col], 5
mov     byte [v_attr], 1Bh
mov     al, '+'
call    vga_putc
mov     byte [g_col], 0
.hdr_loop:
cmp     byte [g_col], 7
jae     .rows_start
mov     al, [g_col]
mov     bl, 10
mul     bl
add     al, 6
mov     [col_x], al
mov     byte [v_row], 2
add     al, 4
mov     [v_col], al
mov     byte [v_attr], 70h
mov     al, [left_c]
add     al, [g_col]
add     al, 'A'
call    vga_putc
mov     al, [col_x]
add     al, 9
mov     [v_col], al
mov     al, '|'
call    vga_putc
mov     byte [v_row], 3
mov     al, [col_x]
add     al, 9
mov     [v_col], al
mov     byte [v_attr], 1Bh
mov     al, '+'
call    vga_putc
inc     byte [g_col]
jmp     .hdr_loop
.rows_start:
mov     byte [g_row], 0
.row_loop:
cmp     byte [g_row], 19
jae     .bot_clear
mov     al, 4
add     al, [g_row]
mov     [cur_y], al
mov     [v_row], al
mov     byte [v_col], 0
mov     byte [v_attr], 70h
mov     cx, 5
mov     al, ' '
.rp:
call    vga_putc
loop    .rp
movzx   ax, byte [top_r]
add     al, [g_row]
inc     ax
cmp     ax, 10
jae     .r2d
mov     byte [v_col], 2
jmp     .rpr
.r2d:
mov     byte [v_col], 1
.rpr:
call    vga_putnum
mov     byte [v_col], 5
mov     byte [v_attr], 1Bh
mov     al, '|'
call    vga_putc
mov     byte [g_col], 0
.col_loop:
cmp     byte [g_col], 7
jae     .row_end
mov     al, [g_col]
mov     bl, 10
mul     bl
add     al, 6
mov     [col_x], al
mov     al, [cur_y]
mov     [v_row], al
mov     al, [col_x]
mov     [v_col], al
mov     al, [top_r]
add     al, [g_row]
mov     ah, [left_c]
add     ah, [g_col]
mov     bl, 1Fh
cmp     al, [cur_r]
jne     .nc
cmp     ah, [cur_c]
jne     .nc
mov     bl, 30h
.nc:
mov     [v_attr], bl
push    ax
call    get_cell_ptr
mov     si, di
pop     ax
cmp     byte [si], 0
je      .blank_cell
mov     cl, [si]
cmp     cl, '='
je      .num_cell
cmp     cl, '-'
je      .num_cell
cmp     cl, '0'
jb      .txt_cell
cmp     cl, '9'
jbe     .num_cell
.txt_cell:
mov     cx, 9
.tc:
lodsb
test    al, al
jz      .tc_sp
call    vga_putc
loop    .tc
jmp     .draw_bar
.tc_sp:
mov     al, ' '
call    vga_putc
loop    .tc_sp
jmp     .draw_bar
.num_cell:
call    get_val_ptr
mov     eax, [di]
call    vga_put_i32_9
jmp     .draw_bar
.blank_cell:
mov     cx, 9
mov     al, ' '
.bc:
call    vga_putc
loop    .bc
.draw_bar:
mov     al, [col_x]
add     al, 9
mov     [v_col], al
mov     byte [v_attr], 1Bh
mov     al, '|'
call    vga_putc
inc     byte [g_col]
jmp     .col_loop
.row_end:
mov     byte [v_col], 76
mov     byte [v_attr], 1Fh
mov     cx, 4
mov     al, ' '
.re:
call    vga_putc
loop    .re
inc     byte [g_row]
jmp     .row_loop
.bot_clear:
push    es
mov     ax, 0B800h
mov     es, ax
mov     di, 23 * 160
mov     ax, 1F20h
mov     cx, 80
rep     stosw
pop     es
ret
vga_put_i32_9:
push    ebx
push    ecx
push    edx
mov     di, num_buf + 11
mov     byte [di], 0
xor     cl, cl
test    eax, eax
jns     .pos
mov     cl, 1
neg     eax
.pos:
mov     ebx, 10
.div:
xor     edx, edx
div     ebx
add     dl, '0'
dec     di
mov     [di], dl
test    eax, eax
jnz     .div
test    cl, cl
jz      .len
dec     di
mov     byte [di], '-'
.len:
mov     si, di
call    strlen
cmp     cx, 9
jbe     .pad
mov     cx, 9
jmp     .pr
.pad:
mov     dx, 9
sub     dx, cx
jz      .pr
.pl:
mov     al, ' '
call    vga_putc
dec     dx
jnz     .pl
.pr:
lodsb
test    al, al
jz      .done
call    vga_putc
loop    .pr
.done:
pop     edx
pop     ecx
pop     ebx
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
push    ax
push    bx
push    cx
push    dx
mov     di, num_buf + 7
mov     byte [di], 0
mov     bx, 10
.div:
xor     dx, dx
div     bx
add     dl, '0'
dec     di
mov     [di], dl
test    ax, ax
jnz     .div
mov     si, di
call    vga_puts_cur
pop     dx
pop     cx
pop     bx
pop     ax
ret
strlen:
push    si
xor     cx, cx
.l:
lodsb
test    al, al
jz      .d
inc     cx
jmp     .l
.d:
pop     si
ret
strcpy:
lodsb
stosb
test    al, al
jnz     strcpy
ret
hide_cursor:
mov     ah, 01h
mov     cx, 2000h
int     10h
ret
show_cursor:
mov     ah, 01h
mov     cx, 0607h
int     10h
ret
title_str   db 'DOSOS 16 CALC | ', 0
help_str    db 'Arrows:Move  Enter/F2:Edit  Del:Clear  Ctrl+S:Save  ESC:Exit', 0
def_name    db 'SHEET.CSV', 0
msg_saved   db 'Saved to CSV!', 0
msg_err     db 'Error saving CSV!', 0
cur_r       db 0
cur_c       db 0
top_r       db 0
left_c      db 0
g_row       db 0
g_col       db 0
col_x       db 0
cur_y       db 0
first_ch    db 0
pass_cnt    db 0
ref_c       db 0
v_row       db 0
v_col       db 0
v_attr      db 0
edit_len    dw 0
val_dst     dw 0
r_start     dw 0
r_end       dw 0
num_buf     rb 16
filename    rb 64
edit_buf    rb 32
line_buf    rb 600
sheet_raw   rb 50 * 16 * 32
sheet_val   rb 50 * 16 * 4
io_buf      rb 16384
