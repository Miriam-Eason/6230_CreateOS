# 使用 ubuntu:22.04 的 x86_64 版本
FROM --platform=linux/amd64 ubuntu:22.04

# 安装必要的开发工具
RUN apt-get update && apt-get install -y \
    build-essential \
    nasm \
    gcc-multilib \
    qemu-system-x86 \
    make \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /os

# 容器启动时默认运行bash
CMD ["/bin/bash"]