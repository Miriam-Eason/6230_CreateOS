
## 项目结构
- README.md - 如何配置和运行MiniOS以及现存的问题
- Dockerfile - 设置开发环境的指令
- src/ - 源代码和构建文件目录
  - bootloader.asm - 初始化系统的引导加载程序
  - myos_kernel.asm - 提供文件系统和命令界面的内核代码
  - Makefile - 编译和运行MiniOS的构建指令
  - bootloader.bin - 编译后的引导加载程序（由make生成）
  - kernel.bin - 编译后的内核（由make生成）
  - disk.img - 生成的磁盘映像文件（由make生成）


## 问题
- 没有用c语言写kernel 和 filesystem , 全是用 assembly language 写的
- 这个filesystem 的move， 不会真的移动，只是改了path 这个字段的名字
- 所有的交互都是在terminal 里面， 没有一个图形化的交互页面
- 命令行里输入命令的过程中， 无法删除输入的字符， 点击delete 会有奇怪的图案

## 系统要求

运行MiniOS需要：
- Docker Desktop

## 安装指南

### 1. 安装Homebrew（如果尚未安装）

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

### 2. 使用Homebrew安装Docker

brew install --cask docker

这将在您的Applications文件夹中安装Docker Desktop。

### 3. 启动Docker

- 打开Applications文件夹
- 双击Docker图标启动Docker Desktop
- 等待Docker完全启动（状态栏中的Docker图标停止动画）
- 首次启动时，可能需要提供管理员密码并同意许可协议

### 4. 准备项目文件

1. 解压MiniOS项目文件
2. 确保解压后的目录包含所有必要文件：
   - src/bootloader.asm
   - src/myos_kernel.asm
   - src/Makefile
   - Dockerfile

## 运行MiniOS

### 1. 构建Docker镜像

打开终端并导航到项目根目录：

cd 路径/到/解压目录

构建Docker镜像：

docker build -t minios-dev .

### 2. 创建并运行Docker容器

docker run -it --name minios-container -v $(pwd):/os minios-dev

### 3. 编译和运行MiniOS

在Docker容器内：

cd /os/src
make clean
make
make run

## 使用MiniOS

MiniOS启动后，您将看到命令提示符。可用的命令有：

- help - 显示可用命令
- list - 列出所有文件
- create [名称] - 创建新文件
- delete [名称] - 删除文件
- rename [旧名称] [新名称] - 重命名文件
- move [名称] [路径] - 设置文件路径
- echo [文本] - 显示文本

## 退出和重新启动

### 退出MiniOS和容器

打开一个新的终端窗口并运行：

docker stop minios-container

### 重新启动MiniOS

docker start minios-container
docker exec -it minios-container bash
cd /os/src
make run





