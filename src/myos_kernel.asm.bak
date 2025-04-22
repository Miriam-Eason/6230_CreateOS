[BITS 16]
[ORG 0x1000]

kernel_start:
    ; 设置文本模式
    mov ax, 0x0003      ; 80x25 文本模式
    int 0x10
    
    ; 显示内核消息
    mov si, msg_kernel
    call print_string
    
    ; 初始化文件系统
    call init_fs
    
    ; 显示欢迎消息
    mov si, msg_welcome
    call print_string
    
    ; 命令行循环
command_loop:
    ; 显示提示符
    mov si, prompt
    call print_string
    
    ; 读取命令
    mov di, cmd_buffer
    call read_string
    
    ; 解析命令
    call parse_command
    
    ; 继续循环
    jmp command_loop

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

; 读取字符串
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
    
    ; 常规字符
    mov ah, 0x0E        ; BIOS显示字符
    int 0x10
    
    stosb               ; 存储字符到[di]并递增di
    inc cx
    cmp cx, 250         ; 检查缓冲区上限
    jl .read_char
    jmp .done
    
.backspace:
    ; 确保有字符可删
    test cx, cx
    jz .read_char
    
    ; 显示退格
    mov ah, 0x0E
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

; 解析命令
parse_command:
    ; 跳过命令前的空格
    mov si, cmd_buffer
    call skip_spaces
    
    ; 检查命令是否为空
    cmp byte [si], 0
    je .done
    
    ; 比较命令
    mov di, cmd_help
    call compare_strings
    je .cmd_help
    
    mov di, cmd_create
    call compare_strings
    je .cmd_create
    
    mov di, cmd_delete
    call compare_strings
    je .cmd_delete
    
    mov di, cmd_rename
    call compare_strings
    je .cmd_rename
    
    mov di, cmd_list
    call compare_strings
    je .cmd_list
    
    mov di, cmd_move
    call compare_strings
    je .cmd_move
    
    mov di, cmd_echo
    call compare_strings
    je .cmd_echo
    
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

; 打印字符串
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

; 文件系统结构
; 每个文件项: 16字节文件名 + 16字节内容 + 16字节路径 = 48字节
MAX_FILES equ 10
FILE_ENTRY_SIZE equ 48
file_table times (MAX_FILES * FILE_ENTRY_SIZE) db 0