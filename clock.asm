; ============================================================
; DOSOS OFFICE - ANALOG CLOCK
; ------------------------------------------------------------
; Spreadsheet Processor
;
; Version:     0.1 Alpha
; Platform:    DOSOS 16-bit
; Architecture: x86
; Assembler:   FASM
;
; Project: DOSOS Office Suite
; License: GNU GPL v3.0
; ============================================================

use16
org 0
db 'DX16'

start:
    push cs
    pop ds
    mov ax,0013h
    int 10h
    mov ax,0A000h
    mov es,ax
    call read_rtc
    mov al,[seconds]
    mov [last_second],al

main_loop:
    call read_rtc
    call clear_screen
    call draw_face
    call draw_hands
    call draw_digital

wait_tick:
    mov ah,01h
    int 16h
    jz .check_time
    xor ah,ah
    int 16h
    cmp al,27
    je exit_program
.check_time:
    call read_rtc
    mov al,[seconds]
    cmp al,[last_second]
    je wait_tick
    mov [last_second],al
    jmp main_loop

exit_program:
    mov ax,0003h
    int 10h
    retf

read_rtc:
    push ax
    push bx
    push cx
    push dx
.retry:
    mov ah,02h
    int 1Ah
    jc .retry
    mov al,dh
    call bcd_to_bin
    mov [seconds],al
    mov al,cl
    call bcd_to_bin
    mov [minutes],al
    mov al,ch
    call bcd_to_bin
    mov [hours],al
    pop dx
    pop cx
    pop bx
    pop ax
    ret

bcd_to_bin:
    push bx
    mov bl,al
    and al,0F0h
    shr al,4
    mov bh,10
    mul bh
    and bl,0Fh
    add al,bl
    pop bx
    ret

clear_screen:
    push ax
    push cx
    push di
    xor di,di
    xor ax,ax
    mov cx,32000
    rep stosw
    pop di
    pop cx
    pop ax
    ret

; AL=color, BX=x, DX=y. Writes one pixel to A000:0000.
pixel:
    push ax
    push bx
    push dx
    push di
    mov di,dx
    imul di,320
    add di,bx
    mov [es:di],al
    pop di
    pop dx
    pop bx
    pop ax
    ret

; Integer DDA line. Uses globals x0,y0,x1,y1,line_color.
draw_line:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax,[x1]
    sub ax,[x0]
    mov [ldx],ax
    mov ax,[y1]
    sub ax,[y0]
    mov [ldy],ax
    mov ax,[ldx]
    test ax,8000h
    jz .absx
    neg ax
.absx:
    mov bx,ax
    mov ax,[ldy]
    test ax,8000h
    jz .absy
    neg ax
.absy:
    cmp ax,bx
    jbe .steps_ok
    mov bx,ax
.steps_ok:
    mov [steps],bx
    cmp word [steps],0
    jne .line_loop
    mov bx,[x0]
    mov dx,[y0]
    mov al,[line_color]
    call pixel
    jmp .done
.line_loop:
    xor si,si
.point:
    mov ax,[ldx]
    imul si
    idiv word [steps]
    add ax,[x0]
    mov bx,ax
    mov ax,[ldy]
    imul si
    idiv word [steps]
    add ax,[y0]
    mov dx,ax
    mov al,[line_color]
    call pixel
    inc si
    cmp si,[steps]
    jbe .point
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_face:
    push ax
    push bx
    push cx
    push dx
    push si
    mov si,circle_points
    mov cx,240
.circle:
    lodsw
    mov bx,ax
    lodsw
    mov dx,ax
    mov al,15
    call pixel
    loop .circle

    mov si,tick_data
    mov cx,60
    mov word [tick_index],0
.ticks:
    lodsw
    mov [x0],ax
    lodsw
    mov [y0],ax
    lodsw
    mov [x1],ax
    lodsw
    mov [y1],ax
    mov byte [line_color],8
    mov ax,[tick_index]
    xor dx,dx
    mov bx,5
    div bx
    test dx,dx
    jnz .small
    mov byte [line_color],14
.small:
    call draw_line
    inc word [tick_index]
    loop .ticks
    mov bx,160
    mov dx,100
    mov al,12
    call pixel
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_hands:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Hour index = (hours mod 12) * 5 + minutes / 12.
    mov al,[hours]
    xor ah,ah
    mov bl,12
    div bl
    mov al,ah
    mov bl,5
    mul bl
    mov si,ax

    mov al,[minutes]
    xor ah,ah
    mov bl,12
    div bl
    xor ah,ah
    add ax,si
    shl ax,2
    mov si,hour_points
    add si,ax
    lodsw
    mov [x1],ax
    lodsw
    mov [y1],ax
    mov word [x0],160
    mov word [y0],100
    mov byte [line_color],14
    call draw_line

    mov al,[minutes]
    xor ah,ah
    shl ax,2
    mov si,minute_points
    add si,ax
    lodsw
    mov [x1],ax
    lodsw
    mov [y1],ax
    mov word [x0],160
    mov word [y0],100
    mov byte [line_color],11
    call draw_line

    mov al,[seconds]
    xor ah,ah
    shl ax,2
    mov si,second_points
    add si,ax
    lodsw
    mov [x1],ax
    lodsw
    mov [y1],ax
    mov word [x0],160
    mov word [y0],100
    mov byte [line_color],12
    call draw_line

    mov bx,160
    mov dx,100
    mov al,15
    call pixel
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Four 3x5 digits form HH:MM.
draw_digital:
    push ax
    push bx
    push cx
    push dx
    mov al,[hours]
    xor ah,ah
    mov bl,10
    div bl
    mov bx,126
    mov dx,183
    call draw_digit
    mov al,[hours]
    xor ah,ah
    mov bl,10
    div bl
    mov al,ah
    mov bx,138
    mov dx,183
    call draw_digit
    mov bx,150
    mov dx,186
    mov al,15
    call pixel
    mov dx,192
    call pixel
    mov al,[minutes]
    xor ah,ah
    mov bl,10
    div bl
    mov bx,162
    mov dx,183
    call draw_digit
    mov al,[minutes]
    xor ah,ah
    mov bl,10
    div bl
    mov al,ah
    mov bx,174
    mov dx,183
    call draw_digit
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; AL=digit 0..9, BX=x, DX=y. 3x5 pixel font.
draw_digit:
    push ax
    push bx
    push cx
    push dx
    push si
    xor ah,ah
    mov si,digit_masks
    mov cl,5
    mul cl
    add si,ax
    mov cx,5
.row:
    mov al,[si]
    inc si
    push cx
    mov cx,3
.col:
    test al,4
    jz .skip
    push ax
    mov al,15
    call pixel
    pop ax
.skip:
    shl al,1
    inc bx
    loop .col
    sub bx,3
    inc dx
    pop cx
    loop .row
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

hours db 0
minutes db 0
seconds db 0
last_second db 255
line_color db 0
x0 dw 0
y0 dw 0
x1 dw 0
y1 dw 0
ldx dw 0
ldy dw 0
steps dw 0
tick_index dw 0

digit_masks:
    db 7,5,5,5,7
    db 2,6,2,2,7
    db 7,1,7,4,7
    db 7,1,7,1,7
    db 5,5,7,1,1
    db 7,4,7,1,7
    db 7,4,7,5,7
    db 7,1,1,1,1
    db 7,5,7,5,7
    db 7,5,7,1,7

circle_points:
    dw 160, 25
    dw 162, 25
    dw 164, 25
    dw 166, 25
    dw 168, 25
    dw 170, 26
    dw 172, 26
    dw 174, 26
    dw 176, 27
    dw 178, 27
    dw 179, 28
    dw 181, 28
    dw 183, 29
    dw 185, 29
    dw 187, 30
    dw 189, 31
    dw 191, 31
    dw 192, 32
    dw 194, 33
    dw 196, 34
    dw 198, 35
    dw 199, 36
    dw 201, 37
    dw 202, 38
    dw 204, 39
    dw 206, 40
    dw 207, 42
    dw 209, 43
    dw 210, 44
    dw 212, 46
    dw 213, 47
    dw 214, 48
    dw 216, 50
    dw 217, 51
    dw 218, 53
    dw 220, 54
    dw 221, 56
    dw 222, 58
    dw 223, 59
    dw 224, 61
    dw 225, 62
    dw 226, 64
    dw 227, 66
    dw 228, 68
    dw 229, 69
    dw 229, 71
    dw 230, 73
    dw 231, 75
    dw 231, 77
    dw 232, 79
    dw 232, 81
    dw 233, 82
    dw 233, 84
    dw 234, 86
    dw 234, 88
    dw 234, 90
    dw 235, 92
    dw 235, 94
    dw 235, 96
    dw 235, 98
    dw 235, 100
    dw 235, 102
    dw 235, 104
    dw 235, 106
    dw 235, 108
    dw 234, 110
    dw 234, 112
    dw 234, 114
    dw 233, 116
    dw 233, 118
    dw 232, 119
    dw 232, 121
    dw 231, 123
    dw 231, 125
    dw 230, 127
    dw 229, 129
    dw 229, 131
    dw 228, 132
    dw 227, 134
    dw 226, 136
    dw 225, 138
    dw 224, 139
    dw 223, 141
    dw 222, 142
    dw 221, 144
    dw 220, 146
    dw 218, 147
    dw 217, 149
    dw 216, 150
    dw 214, 152
    dw 213, 153
    dw 212, 154
    dw 210, 156
    dw 209, 157
    dw 207, 158
    dw 206, 160
    dw 204, 161
    dw 202, 162
    dw 201, 163
    dw 199, 164
    dw 198, 165
    dw 196, 166
    dw 194, 167
    dw 192, 168
    dw 191, 169
    dw 189, 169
    dw 187, 170
    dw 185, 171
    dw 183, 171
    dw 181, 172
    dw 179, 172
    dw 178, 173
    dw 176, 173
    dw 174, 174
    dw 172, 174
    dw 170, 174
    dw 168, 175
    dw 166, 175
    dw 164, 175
    dw 162, 175
    dw 160, 175
    dw 158, 175
    dw 156, 175
    dw 154, 175
    dw 152, 175
    dw 150, 174
    dw 148, 174
    dw 146, 174
    dw 144, 173
    dw 142, 173
    dw 141, 172
    dw 139, 172
    dw 137, 171
    dw 135, 171
    dw 133, 170
    dw 131, 169
    dw 129, 169
    dw 128, 168
    dw 126, 167
    dw 124, 166
    dw 123, 165
    dw 121, 164
    dw 119, 163
    dw 118, 162
    dw 116, 161
    dw 114, 160
    dw 113, 158
    dw 111, 157
    dw 110, 156
    dw 108, 154
    dw 107, 153
    dw 106, 152
    dw 104, 150
    dw 103, 149
    dw 102, 147
    dw 100, 146
    dw 99, 144
    dw 98, 142
    dw 97, 141
    dw 96, 139
    dw 95, 138
    dw 94, 136
    dw 93, 134
    dw 92, 132
    dw 91, 131
    dw 91, 129
    dw 90, 127
    dw 89, 125
    dw 89, 123
    dw 88, 121
    dw 88, 119
    dw 87, 118
    dw 87, 116
    dw 86, 114
    dw 86, 112
    dw 86, 110
    dw 85, 108
    dw 85, 106
    dw 85, 104
    dw 85, 102
    dw 85, 100
    dw 85, 98
    dw 85, 96
    dw 85, 94
    dw 85, 92
    dw 86, 90
    dw 86, 88
    dw 86, 86
    dw 87, 84
    dw 87, 82
    dw 88, 81
    dw 88, 79
    dw 89, 77
    dw 89, 75
    dw 90, 73
    dw 91, 71
    dw 91, 69
    dw 92, 68
    dw 93, 66
    dw 94, 64
    dw 95, 62
    dw 96, 61
    dw 97, 59
    dw 98, 58
    dw 99, 56
    dw 100, 54
    dw 102, 53
    dw 103, 51
    dw 104, 50
    dw 106, 48
    dw 107, 47
    dw 108, 46
    dw 110, 44
    dw 111, 43
    dw 113, 42
    dw 114, 40
    dw 116, 39
    dw 118, 38
    dw 119, 37
    dw 121, 36
    dw 123, 35
    dw 124, 34
    dw 126, 33
    dw 128, 32
    dw 129, 31
    dw 131, 31
    dw 133, 30
    dw 135, 29
    dw 137, 29
    dw 139, 28
    dw 141, 28
    dw 142, 27
    dw 144, 27
    dw 146, 26
    dw 148, 26
    dw 150, 26
    dw 152, 25
    dw 154, 25
    dw 156, 25
    dw 158, 25
tick_data:
    dw 160, 25, 160, 34
    dw 168, 25, 167, 29
    dw 176, 27, 175, 31
    dw 183, 29, 182, 32
    dw 191, 31, 189, 35
    dw 198, 35, 193, 43
    dw 204, 39, 202, 43
    dw 210, 44, 208, 47
    dw 216, 50, 213, 52
    dw 221, 56, 217, 58
    dw 225, 62, 217, 67
    dw 229, 69, 225, 71
    dw 231, 77, 228, 78
    dw 233, 84, 229, 85
    dw 235, 92, 231, 93
    dw 235, 100, 226, 100
    dw 235, 108, 231, 107
    dw 233, 116, 229, 115
    dw 231, 123, 228, 122
    dw 229, 131, 225, 129
    dw 225, 138, 217, 133
    dw 221, 144, 217, 142
    dw 216, 150, 213, 148
    dw 210, 156, 208, 153
    dw 204, 161, 202, 157
    dw 198, 165, 193, 157
    dw 191, 169, 189, 165
    dw 183, 171, 182, 168
    dw 176, 173, 175, 169
    dw 168, 175, 167, 171
    dw 160, 175, 160, 166
    dw 152, 175, 153, 171
    dw 144, 173, 145, 169
    dw 137, 171, 138, 168
    dw 129, 169, 131, 165
    dw 123, 165, 127, 157
    dw 116, 161, 118, 157
    dw 110, 156, 112, 153
    dw 104, 150, 107, 148
    dw 99, 144, 103, 142
    dw 95, 138, 103, 133
    dw 91, 131, 95, 129
    dw 89, 123, 92, 122
    dw 87, 116, 91, 115
    dw 85, 108, 89, 107
    dw 85, 100, 94, 100
    dw 85, 92, 89, 93
    dw 87, 84, 91, 85
    dw 89, 77, 92, 78
    dw 91, 69, 95, 71
    dw 95, 62, 103, 67
    dw 99, 56, 103, 58
    dw 104, 50, 107, 52
    dw 110, 44, 112, 47
    dw 116, 39, 118, 43
    dw 123, 35, 127, 43
    dw 129, 31, 131, 35
    dw 137, 29, 138, 32
    dw 144, 27, 145, 31
    dw 152, 25, 153, 29
hour_points:
    dw 160, 62
    dw 164, 62
    dw 168, 63
    dw 172, 64
    dw 175, 65
    dw 179, 67
    dw 182, 69
    dw 185, 72
    dw 188, 75
    dw 191, 78
    dw 193, 81
    dw 195, 85
    dw 196, 88
    dw 197, 92
    dw 198, 96
    dw 198, 100
    dw 198, 104
    dw 197, 108
    dw 196, 112
    dw 195, 115
    dw 193, 119
    dw 191, 122
    dw 188, 125
    dw 185, 128
    dw 182, 131
    dw 179, 133
    dw 175, 135
    dw 172, 136
    dw 168, 137
    dw 164, 138
    dw 160, 138
    dw 156, 138
    dw 152, 137
    dw 148, 136
    dw 145, 135
    dw 141, 133
    dw 138, 131
    dw 135, 128
    dw 132, 125
    dw 129, 122
    dw 127, 119
    dw 125, 115
    dw 124, 112
    dw 123, 108
    dw 122, 104
    dw 122, 100
    dw 122, 96
    dw 123, 92
    dw 124, 88
    dw 125, 85
    dw 127, 81
    dw 129, 78
    dw 132, 75
    dw 135, 72
    dw 138, 69
    dw 141, 67
    dw 145, 65
    dw 148, 64
    dw 152, 63
    dw 156, 62
minute_points:
    dw 160, 46
    dw 166, 46
    dw 171, 47
    dw 177, 49
    dw 182, 51
    dw 187, 53
    dw 192, 56
    dw 196, 60
    dw 200, 64
    dw 204, 68
    dw 207, 73
    dw 209, 78
    dw 211, 83
    dw 213, 89
    dw 214, 94
    dw 214, 100
    dw 214, 106
    dw 213, 111
    dw 211, 117
    dw 209, 122
    dw 207, 127
    dw 204, 132
    dw 200, 136
    dw 196, 140
    dw 192, 144
    dw 187, 147
    dw 182, 149
    dw 177, 151
    dw 171, 153
    dw 166, 154
    dw 160, 154
    dw 154, 154
    dw 149, 153
    dw 143, 151
    dw 138, 149
    dw 133, 147
    dw 128, 144
    dw 124, 140
    dw 120, 136
    dw 116, 132
    dw 113, 127
    dw 111, 122
    dw 109, 117
    dw 107, 111
    dw 106, 106
    dw 106, 100
    dw 106, 94
    dw 107, 89
    dw 109, 83
    dw 111, 78
    dw 113, 73
    dw 116, 68
    dw 120, 64
    dw 124, 60
    dw 128, 56
    dw 133, 53
    dw 138, 51
    dw 143, 49
    dw 149, 47
    dw 154, 46
second_points:
    dw 160, 36
    dw 167, 36
    dw 173, 37
    dw 180, 39
    dw 186, 42
    dw 192, 45
    dw 198, 48
    dw 203, 52
    dw 208, 57
    dw 212, 62
    dw 215, 68
    dw 218, 74
    dw 221, 80
    dw 223, 87
    dw 224, 93
    dw 224, 100
    dw 224, 107
    dw 223, 113
    dw 221, 120
    dw 218, 126
    dw 215, 132
    dw 212, 138
    dw 208, 143
    dw 203, 148
    dw 198, 152
    dw 192, 155
    dw 186, 158
    dw 180, 161
    dw 173, 163
    dw 167, 164
    dw 160, 164
    dw 153, 164
    dw 147, 163
    dw 140, 161
    dw 134, 158
    dw 128, 155
    dw 122, 152
    dw 117, 148
    dw 112, 143
    dw 108, 138
    dw 105, 132
    dw 102, 126
    dw 99, 120
    dw 97, 113
    dw 96, 107
    dw 96, 100
    dw 96, 93
    dw 97, 87
    dw 99, 80
    dw 102, 74
    dw 105, 68
    dw 108, 62
    dw 112, 57
    dw 117, 52
    dw 122, 48
    dw 128, 45
    dw 134, 42
    dw 140, 39
    dw 147, 37
    dw 153, 36
