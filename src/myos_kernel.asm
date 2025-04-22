[BITS 16]
[ORG 0x1000]

; GUI常量定义
COLOR_HEADER      equ 0x1F    ; 蓝底白字
COLOR_BORDER      equ 0x1F    ; 蓝底白字
COLOR_CONTENT     equ 0x07    ; 黑底白字
COLOR_HIGHLIGHT   equ 0x0F    ; 黑底亮白字
COLOR_STATUS      equ 0x70    ; 白底黑字
COLOR_ERROR       equ 0x0C    ; 黑底红字

; 命令历史记录缓冲区
MAX_HISTORY       equ 5       ; 最多存储5条命令
HISTORY_SIZE      equ 256     ; 每条命令最多256字节

; 文件系统常量
MAX_FILES equ 10
FILE_ENTRY_SIZE equ 48

kernel_start:
    ; 设置文本模式
    mov ax, 0x0003      ; 80x25 文本模式
    int 0x10
    
    ; 绘制GUI界面
    call draw_gui
    
    ; 初始化文件系统
    call init_fs
    
    ; 清空命令历史记录
    call init_history
    
    ; 修复命令循环函数，确保正确清空命令缓冲区
command_loop:
    ; 清除内容区域
    call clear_content_area
    
    ; 更新状态栏，确保它总是正确显示
    call update_status
    
    ; 将光标定位到命令输入区
    mov ah, 02h         ; 设置光标位置
    mov bh, 0           ; 页面号
    mov dh, 22          ; 行 (从0开始)
    mov dl, 9           ; 列 (从0开始)
    int 10h
    
    ; 显示提示符
    mov si, prompt
    call print_string
    
    ; 读取命令
    mov di, cmd_buffer
    call read_string
    
    ; 检查命令是否为空
    cmp byte [cmd_buffer], 0
    je command_loop
    
    ; 添加到历史记录
    call add_to_history
    
    ; 解析命令
    call parse_command
    
    ; 继续循环
    jmp command_loop

; 绘制GUI界面
draw_gui:
    ; 清屏
    mov ax, 0x0003      ; 80x25 文本模式
    int 0x10
    
    ; 绘制标题栏
    mov ax, 0x0600      ; AH=06 (向上滚动) AL=00 (整个窗口)
    mov bh, COLOR_HEADER
    mov cx, 0x0000      ; 左上角: 行=0, 列=0
    mov dx, 0x004F      ; 右下角: 行=0, 列=79
    int 0x10
    
    ; 显示标题
    mov ah, 02h         ; 设置光标位置
    mov bh, 0           ; 页面号
    mov dh, 0           ; 行 (从0开始)
    mov dl, 30          ; 列 (从0开始)
    int 10h
    
    mov si, msg_title
    call print_string_color
    
    ; 绘制内容区域
    mov ax, 0x0600      ; AH=06 (向上滚动) AL=00 (整个窗口)
    mov bh, COLOR_CONTENT
    mov cx, 0x0100      ; 左上角: 行=1, 列=0
    mov dx, 0x164F      ; 右下角: 行=22, 列=79
    int 0x10
    
    ; 绘制状态栏
    mov ax, 0x0600      ; AH=06 (向上滚动) AL=00 (整个窗口)
    mov bh, COLOR_STATUS
    mov cx, 0x1700      ; 左上角: 行=23, 列=0
    mov dx, 0x174F      ; 右下角: 行=23, 列=79
    int 0x10
    
    ; 显示内核消息
    mov ah, 02h         ; 设置光标位置
    mov bh, 0           ; 页面号
    mov dh, 2           ; 行 (从0开始)
    mov dl, 2           ; 列 (从0开始)
    int 10h
    
    mov si, msg_kernel
    call print_string
    
    ; 显示欢迎消息
    mov ah, 02h         ; 设置光标位置
    mov bh, 0           ; 页面号
    mov dh, 4           ; 行 (从0开始)
    mov dl, 2           ; 列 (从0开始)
    int 10h
    
    mov si, msg_welcome
    call print_string
    
    ; 显示状态栏信息
    call update_status
    
    ret

; 修改状态栏更新函数，确保它完全重绘状态栏
update_status:
    pusha           ; 保存所有寄存器

        ; 重绘状态栏背景
    mov ax, 0x0600      ; AH=06 (向上滚动) AL=00 (整个窗口)
    mov bh, COLOR_STATUS
    mov cx, 0x1700      ; 左上角: 行=23, 列=0
    mov dx, 0x174F      ; 右下角: 行=23, 列=79
    int 0x10

    ; 定位到状态栏
    mov ah, 02h         ; 设置光标位置
    mov bh, 0           ; 页面号
    mov dh, 23          ; 行 (从0开始)
    mov dl, 2           ; 列 (从0开始)
    int 10h
    
    ; 显示状态信息
    mov si, msg_status
    mov bl, COLOR_STATUS
    call print_string_attr
    
    popa            ; 恢复所有寄存器
    ret

; 打印带颜色的字符串，使用指定属性
print_string_attr:
    mov ah, 0x09        ; BIOS写字符及属性
.loop:
    lodsb
    test al, al
    jz .done
    
    mov cx, 1           ; 重复次数
    int 0x10
    
    ; 移动光标
    mov ah, 0x03        ; 获取光标位置
    int 0x10
    inc dl              ; 增加列
    mov ah, 0x02        ; 设置光标位置
    int 0x10
    
    mov ah, 0x09        ; 恢复AH
    jmp .loop
.done:
    ret

; 打印带颜色的字符串，使用默认前景/背景色
print_string_color:
    mov bl, COLOR_HEADER
    call print_string_attr
    ret

; 初始化命令历史记录
init_history:
    mov cx, MAX_HISTORY
    mov di, cmd_history
    mov al, 0
.clear_loop:
    mov byte [di], al
    add di, HISTORY_SIZE
    loop .clear_loop
    
    mov word [history_count], 0
    mov word [history_index], 0
    ret

; 添加命令到历史记录
add_to_history:
    ; 检查命令是否为空
    cmp byte [cmd_buffer], 0
    je .done
    
    ; 获取历史记录中的下一个位置
    mov ax, [history_count]
    cmp ax, MAX_HISTORY
    jl .not_full
    
    ; 历史记录已满，需要移动所有条目
    mov cx, MAX_HISTORY - 1
    mov si, cmd_history + HISTORY_SIZE
    mov di, cmd_history
.move_loop:
    push cx
    mov cx, HISTORY_SIZE
    rep movsb
    pop cx
    loop .move_loop
    
    mov di, cmd_history + (MAX_HISTORY - 1) * HISTORY_SIZE
    jmp .copy_cmd
    
.not_full:
    ; 计算目标位置
    push dx           ; 保存dx，因为mul会修改它
    mov cx, HISTORY_SIZE
    mul cx            ; ax = ax * cx
    pop dx            ; 恢复dx
    add ax, cmd_history
    mov di, ax
    inc word [history_count]
    
.copy_cmd:
    ; 复制命令到历史记录
    mov si, cmd_buffer
    mov cx, HISTORY_SIZE
.copy_loop:
    lodsb
    stosb
    test al, al
    jz .done
    loop .copy_loop
    
.done:
    mov word [history_index], 0  ; 重置历史索引
    ret

; 增强的读取字符串函数，支持命令历史记录 修复后的read_string函数，添加Mac删除键支持
read_string:
    xor cx, cx          ; 清零计数器
.read_char:
    mov ah, 0           ; BIOS读取按键
    int 0x16
    
    ; 回车键 - 结束输入
    cmp al, 13
    je .done
    
    ; 退格键 - 删除字符
    cmp al, 8
    je .backspace
    
    ; Mac删除键 - 通常是127
    cmp al, 127
    je .backspace
    
    ; 检查上下箭头键 (特殊键)
    cmp ah, 48h         ; 上箭头
    je .up_arrow
    cmp ah, 50h         ; 下箭头
    je .down_arrow
    
    ; Escape键 - 清空当前输入
    cmp al, 27
    je .clear_input
    
    ; 常规字符
    cmp al, ' '         ; 小于空格的控制字符
    jl .read_char
    cmp al, 126         ; 大于DEL的扩展ASCII(排除127)
    ja .read_char
    
    ; 检查缓冲区上限
    cmp cx, 250
    jge .read_char
    
    mov ah, 0x0E        ; BIOS显示字符
    int 0x10
    
    stosb               ; 存储字符到[di]并递增di
    inc cx
    jmp .read_char
    
.backspace:
    ; 确保有字符可删
    test cx, cx
    jz .read_char
    
    ; 显示退格
    mov ah, 0x0E
    mov al, 8
    int 0x10
    
    ; 显示空格覆盖字符
    mov al, ' '
    int 0x10
    
    ; 再次退格
    mov al, 8
    int 0x10
    
    ; 更新指针和计数器
    dec di
    dec cx
    jmp .read_char
    
.clear_input:
    ; 只有当有字符时才清除
    test cx, cx
    jz .read_char
    
    ; 清除当前行
    mov dx, cx
.clear_loop:
    ; 显示退格
    mov ah, 0x0E
    mov al, 8
    int 0x10
    
    ; 显示空格覆盖字符
    mov al, ' '
    int 0x10
    
    ; 再次退格
    mov al, 8
    int 0x10
    
    dec dx
    jnz .clear_loop
    
    ; 重置指针和计数器
    sub di, cx
    xor cx, cx
    jmp .read_char
    
.up_arrow:
    ; 检查是否有历史记录
    cmp word [history_count], 0
    je .read_char
    
    ; 检查当前索引
    mov ax, [history_index]
    cmp ax, [history_count]
    jge .read_char
    
    ; 清除当前输入
    test cx, cx
    jz .load_history
    
    push ax
    mov dx, cx
.clear_up_loop:
    ; 显示退格
    mov ah, 0x0E
    mov al, 8
    int 0x10
    
    ; 显示空格覆盖字符
    mov al, ' '
    int 0x10
    
    ; 再次退格
    mov al, 8
    int 0x10
    
    dec dx
    jnz .clear_up_loop
    
    pop ax
    
.load_history:
    ; 增加历史索引
    inc word [history_index]
    mov ax, [history_index]
    
    ; 计算历史记录位置
    mov bx, [history_count]
    sub bx, ax
    js .reset_index
    
    push ax
    push dx
    mov ax, bx
    mov cx, HISTORY_SIZE
    mul cx
    mov bx, ax
    pop dx
    pop ax
    add bx, cmd_history
    
    ; 清除当前输入
    push di
    sub di, cx
    mov cx, 0
    
    ; 加载历史命令
    mov si, bx
.load_loop:
    lodsb
    test al, al
    jz .end_load
    
    ; 显示字符
    mov ah, 0x0E
    int 0x10
    
    mov [di], al
    inc di
    inc cx
    
    jmp .load_loop
    
.end_load:
    pop di
    add di, cx
    jmp .read_char
    
.reset_index:
    mov word [history_index], 0
    jmp .read_char
    
.down_arrow:
    ; 检查是否有历史记录
    cmp word [history_count], 0
    je .read_char
    
    ; 检查当前索引
    mov ax, [history_index]
    test ax, ax
    jz .read_char
    
    ; 清除当前输入
    test cx, cx
    jz .load_history_down
    
    push ax
    mov dx, cx
.clear_down_loop:
    ; 显示退格
    mov ah, 0x0E
    mov al, 8
    int 0x10
    
    ; 显示空格覆盖字符
    mov al, ' '
    int 0x10
    
    ; 再次退格
    mov al, 8
    int 0x10
    
    dec dx
    jnz .clear_down_loop
    
    pop ax
    
.load_history_down:
    ; 减少历史索引
    dec word [history_index]
    mov ax, [history_index]
    
    ; 如果索引为0，则清空
    test ax, ax
    jnz .not_zero
    
    ; 清除当前输入
    push di
    sub di, cx
    mov [di], byte 0
    mov cx, 0
    pop di
    jmp .read_char
    
.not_zero:
    ; 计算历史记录位置
    mov bx, [history_count]
    sub bx, ax
    push ax
    push dx
    mov ax, bx
    mov cx, HISTORY_SIZE
    mul cx
    mov bx, ax
    pop dx
    pop ax
    add bx, cmd_history
    
    ; 清除当前输入
    push di
    sub di, cx
    mov cx, 0
    
    ; 加载历史命令
    mov si, bx
.load_down_loop:
    lodsb
    test al, al
    jz .end_load_down
    
    ; 显示字符
    mov ah, 0x0E
    int 0x10
    
    mov [di], al
    inc di
    inc cx
    
    jmp .load_down_loop
    
.end_load_down:
    pop di
    add di, cx
    jmp .read_char
    
.done:
    ; 添加换行
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    
    ; 添加空字符
    mov byte [di], 0
    ret

; 初始化文件系统
init_fs:
    ; 清空文件表
    mov cx, MAX_FILES
    mov di, file_table
.clear_loop:
    mov byte [di], 0    ; 将文件名第一个字节设为0表示未使用
    add di, FILE_ENTRY_SIZE
    loop .clear_loop
    
    ; 创建一个初始文件
    mov si, default_filename
    call create_file
    
    ; 写入内容
    mov si, default_filename
    mov di, default_content
    call write_file
    
    ret

; 解析命令
; 修复解析命令函数，确保所有命令都能正确执行
parse_command:
    ; 首先清除内容区域，为新命令输出做准备
    call clear_content_area

    ; 跳过命令前的空格
    mov si, cmd_buffer
    call skip_spaces
    
    ; 检查命令是否为空
    cmp byte [si], 0
    je .done
    
    ; 保存命令开始位置
    push si
    
    ; 比较命令
    mov di, cmd_help
    call compare_strings
    pop si          ; 恢复命令位置
    jc .cmd_help    ; 注意：这里使用jc而不是je，因为compare_strings返回的是进位标志
    
    push si
    mov di, cmd_create
    call compare_strings
    pop si
    jc .cmd_create
    
    push si
    mov di, cmd_delete
    call compare_strings
    pop si
    jc .cmd_delete
    
    push si
    mov di, cmd_rename
    call compare_strings
    pop si
    jc .cmd_rename
    
    push si
    mov di, cmd_list
    call compare_strings
    pop si
    jc .cmd_list
    
    push si
    mov di, cmd_move
    call compare_strings
    pop si
    jc .cmd_move
    
    push si
    mov di, cmd_echo
    call compare_strings
    pop si
    jc .cmd_echo
    
    ; 未知命令
    mov si, msg_unknown
    call print_string
    jmp .done
    
.cmd_help:
    mov si, help_text
    call print_string
    jmp .done
    
.cmd_create:
    ; 获取文件名参数
    call skip_command
    call skip_spaces
    
    ; 检查参数是否存在
    cmp byte [si], 0
    je .create_error
    
    ; 创建文件
    call create_file
    jmp .done
    
.create_error:
    mov si, msg_missing_arg
    call print_string
    jmp .done
    
.cmd_delete:
    ; 获取文件名参数
    call skip_command
    call skip_spaces
    
    ; 检查参数是否存在
    cmp byte [si], 0
    je .delete_error
    
    ; 删除文件
    call delete_file
    jmp .done
    
.delete_error:
    mov si, msg_missing_arg
    call print_string
    jmp .done
    
.cmd_rename:
    ; 获取第一个参数（旧文件名）
    call skip_command
    call skip_spaces
    
    ; 检查参数是否存在
    cmp byte [si], 0
    je .rename_error
    
    ; 保存旧文件名位置
    mov [temp_ptr], si
    
    ; 跳过第一个参数
    call skip_arg
    call skip_spaces
    
    ; 检查第二个参数是否存在
    cmp byte [si], 0
    je .rename_error
    
    ; 执行重命名
    mov di, si          ; 第二个参数（新文件名）
    mov si, [temp_ptr]  ; 第一个参数（旧文件名）
    call rename_file
    jmp .done
    
.rename_error:
    mov si, msg_rename_usage
    call print_string
    jmp .done
    
.cmd_list:
    call list_files
    jmp .done
    
.cmd_move:
    ; 获取第一个参数（文件名）
    call skip_command
    call skip_spaces
    
    ; 检查参数是否存在
    cmp byte [si], 0
    je .move_error
    
    ; 保存文件名位置
    mov [temp_ptr], si
    
    ; 跳过第一个参数
    call skip_arg
    call skip_spaces
    
    ; 检查第二个参数是否存在
    cmp byte [si], 0
    je .move_error
    
    ; 执行移动
    mov di, si          ; 第二个参数（路径）
    mov si, [temp_ptr]  ; 第一个参数（文件名）
    call move_file
    jmp .done
    
.move_error:
    mov si, msg_move_usage
    call print_string
    jmp .done
    
.cmd_echo:
    ; 获取参数
    call skip_command
    call skip_spaces
    
    ; 显示参数
    call print_string
    
    ; 换行
    mov si, newline
    call print_string
    jmp .done
    
.done:
    ; 更新状态栏，确保它不被命令输出覆盖
    call update_status
    ret

; 新增：清除内容区域函数
clear_content_area:
    pusha           ; 保存所有寄存器
    
    ; 清除内容区域 (行1-21)
    mov ax, 0x0600      ; AH=06 (向上滚动) AL=00 (整个窗口)
    mov bh, COLOR_CONTENT
    mov cx, 0x0100      ; 左上角: 行=1, 列=0
    mov dx, 0x164F      ; 右下角: 行=22, 列=79
    int 0x10
    
    ; 重置光标到内容区域的开始位置
    mov ah, 02h         ; 设置光标位置
    mov bh, 0           ; 页面号
    mov dh, 2           ; 行 (从0开始)
    mov dl, 2           ; 列 (从0开始)
    int 10h
    
    popa            ; 恢复所有寄存器
    ret

; 跳过命令部分
skip_command:
    mov si, cmd_buffer
    call skip_spaces
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    jmp .loop
.done:
    dec si
    ret

; 跳过参数
skip_arg:
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    jmp .loop
.done:
    dec si
    ret

; 跳过空格
skip_spaces:
.loop:
    lodsb
    cmp al, ' '
    je .loop
    dec si
    ret

; 比较字符串
compare_strings:
    push si
    push di
.loop:
    lodsb               ; 加载[si]到al并递增si
    mov ah, [di]        ; 加载[di]到ah
    inc di
    
    cmp al, ah
    jne .not_equal
    
    ; 检查是否到字符串结尾
    cmp al, 0
    je .equal
    
    jmp .loop
    
.not_equal:
    ; 检查是否是命令结束（空格或字符串结束）
    cmp al, ' '
    je .check_end
    cmp al, 0
    je .check_end
    
    pop di
    pop si
    clc                 ; 清除进位标志表示不相等
    ret
    
.check_end:
    cmp ah, 0
    jne .not_equal
    
.equal:
    pop di
    pop si
    stc                 ; 设置进位标志表示相等
    ret

; 打印字符串,使其更可靠地处理换行和光标位置
print_string:
    pusha           ; 保存所有寄存器
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    
    ; 检查是否为回车或换行
    cmp al, 13      ; 回车 (CR)
    je .print_cr
    cmp al, 10      ; 换行 (LF)
    je .print_lf
    
    ; 普通字符
    int 0x10
    jmp .loop
    
.print_cr:
    int 0x10        ; 输出回车
    jmp .loop
    
.print_lf:
    int 0x10        ; 输出换行
    
    ; 检查这里是否需要跟一个回车
    cmp byte [si], 13
    je .loop        ; 如果下一个字符是CR，正常继续
    
    ; 否则我们需要手动定位光标到行首
    pusha
    mov ah, 03h     ; 获取当前光标位置
    mov bh, 0
    int 10h
    
    mov ah, 02h     ; 设置光标位置
    mov dl, 0       ; 列 = 0 (行首)
    int 10h
    popa
    
    jmp .loop
    
.done:
    popa            ; 恢复所有寄存器
    ret

; 文件系统操作
; 创建文件
create_file:
    push si
    
    ; 检查文件是否已存在
    call find_file
    jc .file_exists
    
    ; 查找空闲项
    mov cx, MAX_FILES
    mov di, file_table
.find_slot:
    cmp byte [di], 0
    je .slot_found
    add di, FILE_ENTRY_SIZE
    loop .find_slot
    
    ; 没有空闲空间
    mov si, msg_no_space
    call print_string
    jmp .done
    
.file_exists:
    mov si, msg_file_exists
    call print_string
    jmp .done
    
.slot_found:
    ; 复制文件名
    pop si
    push si
    
    ; 复制不超过15字符的文件名
    mov cx, 15
.copy_name:
    lodsb
    cmp al, 0
    je .end_name
    cmp al, ' '
    je .end_name
    stosb
    loop .copy_name
    
.end_name:
    ; 添加结束符
    mov byte [di], 0
    
    ; 清空内容缓冲区（文件名后16字节）
    add di, 1
    mov cx, 15
    mov al, 0
.clear_content:
    stosb
    loop .clear_content
    
    ; 清空路径缓冲区（内容后16字节）
    mov cx, 16
.clear_path:
    stosb
    loop .clear_path
    
    mov si, msg_file_created
    call print_string
    
.done:
    pop si
    ret

; 删除文件
delete_file:
    ; 查找文件
    call find_file
    jnc .not_found
    
    ; 将文件名第一个字节设为0表示删除
    mov byte [di], 0
    
    mov si, msg_file_deleted
    call print_string
    ret
    
.not_found:
    mov si, msg_file_not_found
    call print_string
    ret

; 重命名文件
rename_file:
    push di          ; 保存新文件名
    
    ; 查找旧文件
    call find_file
    jnc .not_found
    
    ; 保存文件项位置
    push di
    
    ; 检查新文件名是否已存在
    pop di
    pop si          ; 恢复新文件名
    push si
    push di
    
    mov [temp_ptr], di  ; 保存旧文件位置
    
    ; 检查新文件名
    call find_file
    jc .already_exists
    
    ; 执行重命名
    pop di          ; 恢复旧文件位置
    pop si          ; 恢复新文件名
    
    ; 复制新文件名（不超过15字符）
    mov cx, 15
.copy_name:
    lodsb
    cmp al, 0
    je .end_name
    cmp al, ' '
    je .end_name
    stosb
    loop .copy_name
    
.end_name:
    ; 添加结束符
    mov byte [di], 0
    
    mov si, msg_file_renamed
    call print_string
    ret
    
.not_found:
    pop di
    mov si, msg_file_not_found
    call print_string
    ret
    
.already_exists:
    pop di
    pop si
    mov si, msg_file_exists
    call print_string
    ret

; 列出文件
list_files:
    mov si, msg_file_list
    call print_string
    
    ; 遍历文件表
    mov cx, MAX_FILES
    mov si, file_table
    xor dx, dx          ; 文件计数器
    
.next_file:
    ; 检查文件项是否使用
    cmp byte [si], 0
    je .skip_file
    
    ; 显示文件名
    push cx
    push si
    
    ; 显示前缀
    mov si, msg_file_prefix
    call print_string
    
    ; 显示文件名
    pop si
    push si
    call print_string
    
    ; 换行
    mov si, newline
    call print_string
    
    pop si
    pop cx
    
    inc dx              ; 增加计数器
    
.skip_file:
    add si, FILE_ENTRY_SIZE
    loop .next_file
    
    ; 显示文件总数
    test dx, dx
    jnz .done
    
    ; 如果没有文件
    mov si, msg_no_files
    call print_string
    
.done:
    ret

; 移动文件
move_file:
    push di             ; 保存路径
    
    ; 查找文件
    call find_file
    jnc .not_found
    
    ; 找到路径偏移
    add di, 32          ; 跳过文件名和内容区域
    
    ; 复制路径（最多16字符）
    pop si              ; 恢复路径
    mov cx, 15
.copy_path:
    lodsb
    cmp al, 0
    je .end_path
    cmp al, ' '
    je .end_path
    stosb
    loop .copy_path
    
.end_path:
    ; 添加结束符
    mov byte [di], 0
    
    mov si, msg_file_moved
    call print_string
    ret
    
.not_found:
    pop di
    mov si, msg_file_not_found
    call print_string
    ret

; 写入文件
write_file:
    push di             ; 保存内容指针
    
    ; 查找文件
    call find_file
    jnc .not_found
    
    ; 找到内容偏移
    add di, 16          ; 跳过文件名
    
    ; 复制内容（最多16字符）
    pop si              ; 恢复内容指针
    mov cx, 15
.copy_content:
    lodsb
    cmp al, 0
    je .end_content
    stosb
    loop .copy_content
    
.end_content:
    ; 添加结束符
    mov byte [di], 0
    ret
    
.not_found:
    pop di
    ret

; 查找文件
; 输入: SI=文件名
; 输出: CF=1表示找到, DI=文件项地址
find_file:
    push cx
    push si
    
    mov cx, MAX_FILES
    mov di, file_table
.next_file:
    ; 检查文件项是否使用
    cmp byte [di], 0
    je .skip_file
    
    ; 比较文件名
    push si
    push di
    call compare_file_name
    pop di
    pop si
    
    jc .found
    
.skip_file:
    add di, FILE_ENTRY_SIZE
    loop .next_file
    
    ; 文件未找到
    pop si
    pop cx
    clc
    ret
    
.found:
    pop si
    pop cx
    stc
    ret

; 比较文件名
; 输入: SI=查询的文件名, DI=文件表中的文件名
; 输出: CF=1表示匹配
compare_file_name:
.loop:
    mov al, [si]
    mov ah, [di]
    
    cmp al, 0
    je .check_end
    cmp al, ' '
    je .check_end
    
    cmp ah, 0
    je .not_match
    
    cmp al, ah
    jne .not_match
    
    inc si
    inc di
    jmp .loop
    
.check_end:
    cmp ah, 0
    jne .not_match
    
    stc
    ret
    
.not_match:
    clc
    ret

; 数据区
msg_title db 'MiniOS v1.1 - Simple OS Demo', 0
msg_status db 'Status: Ready | Press ESC to clear input | Use UP/DOWN arrows for command history', 0
msg_kernel db 'Kernel loaded successfully!', 13, 10, 0
msg_welcome db 'Welcome to MiniOS!', 13, 10, 'Type "help" for commands.', 13, 10, 0
prompt db 'miniOS> ', 0
help_text db 'Available commands:', 13, 10
          db '  help - Show this help', 13, 10
          db '  create [name] - Create a new file', 13, 10
          db '  delete [name] - Delete a file', 13, 10
          db '  rename [old] [new] - Rename a file', 13, 10
          db '  list - List all files', 13, 10
          db '  move [name] [path] - Move file to path', 13, 10
          db '  echo [text] - Display text', 13, 10, 0
msg_unknown db 'Unknown command. Type "help" for available commands.', 13, 10, 0
msg_missing_arg db 'Missing argument. Type "help" for usage.', 13, 10, 0
msg_rename_usage db 'Usage: rename [oldname] [newname]', 13, 10, 0
msg_move_usage db 'Usage: move [filename] [path]', 13, 10, 0
msg_file_exists db 'File already exists.', 13, 10, 0
msg_file_not_found db 'File not found.', 13, 10, 0
msg_no_space db 'No space left for new files.', 13, 10, 0
msg_file_created db 'File created.', 13, 10, 0
msg_file_deleted db 'File deleted.', 13, 10, 0
msg_file_renamed db 'File renamed.', 13, 10, 0
msg_file_moved db 'File moved.', 13, 10, 0
msg_file_list db 'Files:', 13, 10, 0
msg_file_prefix db '- ', 0
msg_no_files db 'No files found.', 13, 10, 0
newline db 13, 10, 0

cmd_help db 'help', 0
cmd_create db 'create', 0
cmd_delete db 'delete', 0
cmd_rename db 'rename', 0
cmd_list db 'list', 0
cmd_move db 'move', 0
cmd_echo db 'echo', 0

default_filename db 'readme.txt', 0
default_content db 'Welcome to MiniOS!', 0

; 变量
cmd_buffer times 256 db 0
temp_ptr dw 0

; 命令历史记录
cmd_history times (MAX_HISTORY * HISTORY_SIZE) db 0
history_count dw 0    ; 历史记录中的命令数量
history_index dw 0    ; 当前浏览的历史索引

; 文件系统结构
; 每个文件项: 16字节文件名 + 16字节内容 + 16字节路径 = 48字节
file_table times (MAX_FILES * FILE_ENTRY_SIZE) db 0