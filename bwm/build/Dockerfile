#
# Dockerfile for building oncn-bwm docker image
# Usage:
# docker build -f Dockerfile -t oncn-bwm:2.0.0 .
#
# 声明构建参数
ARG TARGETARCH=amd64
#FROM hub.oepkgs.net/openeuler/openeuler:23.03
#FROM openeuler-24.03-lts:latest
FROM openeuler-22.03-lts-sp3:latest

ARG TARGETARCH

# agent configuration is needed for intranet users
#ENV http_proxy=http://peulerosci:EulerOS_123@proxy.com:8080
#ENV https_proxy=http://peulerosci:EulerOS_123@proxy.com:8080

# container work directory
WORKDIR /bwm

RUN rm -rf /etc/yum.repos.d/*
COPY build/openeuler.repo /etc/yum.repos.d/
COPY build/oncn-bwm-*.rpm /bwm/build/
#RUN sed -i '/metalink/d' /etc/yum.repos.d/*.repo
#RUN sed -i '/metadata_expire/d' /etc/yum.repos.d/*.repo
#RUN sed -i 's/repo.openeuler.org/7.223.199.227\/openeuler/g' /etc/yum.repos.d/*.repo

RUN yum install -y iproute \
    && yum install -y build/oncn-bwm-*.rpm \
    && yum install -y kmod \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
#    && yum install -y clang \
#    && yum install -y libbpf-devel \
    && rm -rf /var/cache/yum/* \
    && rm -rf build/oncn-bwm-*.rpm

COPY bin/bwm-cni /usr/bin
RUN chmod +x /usr/bin/bwm-cni
COPY bin/bwm-daemon /usr/bin
RUN chmod +x /usr/bin/bwm-daemon
COPY bin/bwmctl /usr/bin
RUN chmod +x /usr/bin/bwmctl
COPY bin/alg-daemon /usr/bin
RUN chmod +x /usr/bin/alg-daemon
#
COPY build/ko/$TARGETARCH/   /usr/share/bwm
COPY build/ko/$TARGETARCH/  /usr/share/bwm
#
COPY pkg/bpfgo/tcedt_bpfeb.o /usr/share/bwm
COPY pkg/bpfgo/tcedt_bpfel.o /usr/share/bwm
#
COPY script/installcni.sh  /usr/share/bwm
RUN chmod +x /usr/share/bwm/installcni.sh
#
COPY script/custominit.sh  /usr/share/bwm
RUN chmod +x /usr/share/bwm/custominit.sh
# start
ENTRYPOINT ["/usr/bin/alg-daemon"]


