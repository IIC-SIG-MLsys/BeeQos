# 使用你的基础镜像
FROM jjq52021/godash:latest

RUN sed -i 's/archive.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
    
# 安装调试工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        iputils-ping \
        net-tools \
        procps \
        vim-tiny

# 清理
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*