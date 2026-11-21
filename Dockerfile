FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bc \
        binutils \
        bison \
        bmap-tools \
        build-essential \
        bzip2 \
        ca-certificates \
        cpio \
        curl \
        debianutils \
        diffutils \
        file \
        findutils \
        flex \
        gawk \
        git \
        gzip \
        libelf-dev \
        libncurses-dev \
        libssl-dev \
        locales \
        make \
        patch \
        perl \
        pkg-config \
        python3 \
        python3-flake8 \
        python3-magic \
        rsync \
        sed \
        tar \
        unzip \
        wget \
        xz-utils \
        zstd \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

WORKDIR /root/buildroot
CMD ["/bin/bash"]
