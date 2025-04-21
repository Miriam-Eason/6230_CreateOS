[BITS 16]
[ORG 0x7C00]

start:
    ; 设置段寄存器
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; 显示消息
    mov si, msg_boot
    call print_string
    
    ; 加载内核到0x1000
    mov si, msg_load
    call print_string
    
    ; 通过BIOS中断加载内核
    mov ah, 0x02        ; BIOS读取扇区功能
    mov al, 20          ; 读取20个扇区（10KB，足够小型内核）
    mov ch, 0           ; 柱面0
    mov cl, 2           ; 扇区2（启动扇区之后）
    mov dh, 0           ; 磁头0
    mov dl, 0           ; 驱动器0（A驱动器）
    mov bx, 0x1000      ; 加载地址
    int 0x13            ; BIOS中断
    
    ; 检查错误
    jc disk_error
    
    ; 跳转到内核
    mov si, msg_jump
    call print_string
    
    jmp 0x1000          ; 跳转到内核起始地址
    
disk_error:
    mov si, msg_error
    call print_string
    jmp $               ; 无限循环

; 打印字符串函数
print_string:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

; 数据
msg_boot db 'MiniOS Booting...', 13, 10, 0
msg_load db 'Loading kernel...', 13, 10, 0
msg_jump db 'Jumping to kernel...', 13, 10, 0
msg_error db 'Disk error!', 13, 10, 0

; 填充引导扇区
times 510-($-$$) db 0
dw 0xAA55