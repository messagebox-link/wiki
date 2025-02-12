# Use Debian as base image
FROM debian:latest

# Install basic dependencies
RUN apt update && apt install -y \
    build-essential \
    musl-tools \
    git \
    automake \
    autoconf \
    bison \
    flex \
    texinfo \
    gawk \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libisl-dev \
    python3 \
    wget \
    ninja-build \
    curl \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* && \
    cd /tmp && \
    wget https://github.com/upx/upx/releases/download/v4.2.1/upx-4.2.1-amd64_linux.tar.xz && \
    tar -xf upx-4.2.1-amd64_linux.tar.xz && \
    cp upx-4.2.1-amd64_linux/upx /usr/local/bin/ && \
    rm -rf upx-4.2.1-amd64_linux*


# Create working directory
WORKDIR /build

# Build musl cross toolchain
RUN git clone https://github.com/richfelker/musl-cross-make.git && \
    cd musl-cross-make && \
    echo "TARGET = x86_64-linux-musl" > config.mak && \
    echo "OUTPUT = /opt/musl-toolchain" >> config.mak && \
    echo "BINUTILS_VER = 2.33.1" >> config.mak && \
    echo "GCC_VER = 11.4.0" >> config.mak && \
    echo "MUSL_VER = git-master" >> config.mak && \
    echo "COMMON_CONFIG += --disable-nls" >> config.mak && \
    make -j$(nproc) && \
    make install && \
    # Build static musl toolchain
    rm -rf config.mak && make clean && \
    echo "TARGET = x86_64-linux-musl" > config.mak && \
    echo "OUTPUT = /opt/musl" >> config.mak && \
    echo "BINUTILS_VER = 2.33.1" >> config.mak && \
    echo "GCC_VER = 11.4.0" >> config.mak && \
    echo "MUSL_VER = git-master" >> config.mak && \
    echo 'COMMON_CONFIG += CC="/opt/musl-toolchain/bin/x86_64-linux-musl-gcc -static --static" CXX="/opt/musl-toolchain/bin/x86_64-linux-musl-g++ -static --static"' >> config.mak && \
    echo "COMMON_CONFIG += --disable-nls" >> config.mak && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf musl-cross-make

# Install Rust with musl target
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup install 1.81.0-x86_64-unknown-linux-musl && \
    rustup default 1.81.0-x86_64-unknown-linux-musl && \
    rustup override set 1.81.0-x86_64-unknown-linux-musl

# Build zlib
RUN wget http://zlib.net/zlib-1.3.1.tar.gz && \
    tar -xvzf zlib-1.3.1.tar.gz && \
    cd zlib-1.3.1 && \
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" CFLAGS="-fPIC" ./configure --prefix=/opt/musl/x86_64-linux-musl --static && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf zlib-1.3.1*

# Build libffi
RUN wget https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz && \
    tar -xvzf libffi-3.4.4.tar.gz &&  cd libffi-3.4.4 && \
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" ./configure --prefix=/opt/musl/x86_64-linux-musl --disable-shared --enable-static && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf libffi

# Build ncurses
RUN wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz && \
    tar -xvf ncurses-6.4.tar.gz && \
    cd ncurses-6.4 && \
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" CXX="/opt/musl/bin/x86_64-linux-musl-g++" \
    ./configure --prefix=/opt/musl/x86_64-linux-musl \
    --disable-shared \
    --enable-static \
    --with-normal \
    --with-cxx-binding \
    --enable-widec && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf ncurses-6.4*

# Build OpenSSL
RUN wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz && \
    tar -xvzf openssl-1.1.1w.tar.gz && \
    cd openssl-1.1.1w && \
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" CXX="/opt/musl/bin/x86_64-linux-musl-g++" \
    ./Configure no-shared \
    --prefix=/opt/musl/x86_64-linux-musl \
    --openssldir=/opt/musl/x86_64-linux-musl linux-x86_64 && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf openssl-1.1.1w*

# Set environment variables
ENV PATH="/opt/musl/bin:${PATH}"
ENV CC="/opt/musl/bin/x86_64-linux-musl-gcc"
ENV CXX="/opt/musl/bin/x86_64-linux-musl-g++"
ENV LD="/opt/musl/bin/x86_64-linux-musl-ld"
ENV AR="/opt/musl/bin/x86_64-linux-musl-ar"
ENV RANLIB="/opt/musl/bin/x86_64-linux-musl-ranlib"
ENV STRIP="/opt/musl/bin/x86_64-linux-musl-strip"
ENV LD_LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib"

# Build CMake
RUN git clone https://github.com/Kitware/CMake.git && \
    cd CMake && \
    ./bootstrap --prefix=/opt/musl/x86_64-linux-musl \
    --parallel=$(nproc) \
    -- \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="/opt/musl/bin/x86_64-linux-musl-gcc" \
    -DCMAKE_CXX_COMPILER="/opt/musl/bin/x86_64-linux-musl-g++" \
    -DCMAKE_INCLUDE_PATH="/opt/musl/x86_64-linux-musl/include" \
    -DCMAKE_LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib" \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DCMAKE_SHARED_LINKER_FLAGS="-static" \
    -DCMAKE_MODULE_LINKER_FLAGS="-static" \
    -DOPENSSL_ROOT_DIR="/opt/musl/x86_64-linux-musl" && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf CMake

# Set working directory for building LLVM and SnarkOS
WORKDIR /root

# Clone LLVM
RUN  git clone https://github.com/llvm/llvm-project.git && \
    cd llvm-project && \
    /opt/musl/x86_64-linux-musl/bin/cmake -S llvm -B build -G Ninja \
    -DLLVM_ENABLE_PROJECTS=clang \
    -DLIBCLANG_BUILD_STATIC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="/opt/musl/bin/x86_64-linux-musl-gcc" \
    -DCMAKE_CXX_COMPILER="/opt/musl/bin/x86_64-linux-musl-g++" \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBCXX_HAS_MUSL_LIBC=ON \
    -DLLVM_TARGETS_TO_BUILD="X86" && \
    ninja -C build && \
    cd .. 

# Set environment variables
ENV CC="/opt/musl/bin/x86_64-linux-musl-gcc"
ENV CXX="/opt/musl/bin/x86_64-linux-musl-g++"
ENV LD="/opt/musl/bin/x86_64-linux-musl-ld"
ENV AR="/opt/musl/bin/x86_64-linux-musl-ar"
ENV RANLIB="/opt/musl/bin/x86_64-linux-musl-ranlib"
ENV STRIP="/opt/musl/bin/x86_64-linux-musl-strip"
ENV LD_LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib"

# Set LLVM related paths
ENV LLVM_CONFIG_PATH="/root/llvm-project/build/bin/llvm-config"
ENV BINDGEN_EXTRA_CLANG_ARGS="-L/root/llvm-project/build/lib -lclang"
ENV LIBCLANG_PATH="/root/llvm-project/build/lib"

# Set compilation dependency paths
ENV PKG_CONFIG_PATH="/opt/musl/x86_64-linux-musl/lib/pkgconfig"
ENV C_INCLUDE_PATH="/opt/musl/x86_64-linux-musl/include"
ENV LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib"
ENV LD_LIBRARY_PATH="/root/llvm-project/build/lib:/opt/musl/x86_64-linux-musl/lib"

COPY build-snarkos.sh /root/
RUN chmod +x /root/build-snarkos.sh && \
    cd /root && \
    ./build-snarkos.sh

CMD ["/bin/bash"]
