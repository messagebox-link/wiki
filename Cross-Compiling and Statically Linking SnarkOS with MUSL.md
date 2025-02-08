# Aleo(SnarkOS) Node 交叉编译流程
本指南详细介绍了如何使用 `musl` 交叉编译工具链构建 Aleo(SnarkOS) 节点，包括 `LLVM`、`zlib`、`cmake`、`libffi`、`ncurses` 和 `openssl` 的静态编译，以确保 `SnarkOS` 运行在 `musl` 环境下，实现 **完全静态链接**。



### 1. 编译 `MUSL` 交叉编译工具链
为了构建完全静态的 `musl` 交叉编译工具链，我们使用 `musl-cross-make` 来编译 `musl` 版本的 `gcc`，并确保所有工具链组件（`binutils`、`gcc`、`musl libc`）都是静态编译的。

- 1.1 下载并构建 `musl-cross-make`

    ```shell
    git clone https://github.com/richfelker/musl-cross-make.git
    cd musl-cross-make
    ```
- 1.2 配置 `config.mak`

    编辑 `config.mak`，定义编译目标架构和 GCC 版本：

    ```shell
    TARGET = x86_64-linux-musl
    OUTPUT = /opt/musl-toolchain
    BINUTILS_VER = 2.33.1
    GCC_VER = 11.40.0
    MUSL_VER = git-master 
    COMMON_CONFIG += --disable-nls 
    ```

    说明：
    - `TARGET = x86_64-linux-musl` → 目标平台为 `x86_64`，并使用 `musl` 作为 C 运行时库。
    - `OUTPUT = /opt/musl-toolchain` → 编译完成后，工具链会安装到 `/opt/musl-toolchain`。
    - `BINUTILS_VER = 2.33.1` → 使用 `binutils 2.33.1`。
    - `GCC_VER = 11.4.0` → 使用 `GCC 11.4.0`。
    - `MUSL_VER = git-master` → 使用最新的 `musl` 版本。
    - `COMMON_CONFIG += --disable-nls` → 禁用 `nls`（国际化支持），减少不必要的依赖

- 1.3 开始编译

    这将编译 musl 交叉编译工具链，并安装到 /opt/musl-toolchain。

    ```shell
    make -j$(nproc) && make install
    ```

- 1.4 配置 `config.mak` 以构建完整的 `musl` 静态工具链

    创建一个新的 `config.mak` 以确保 `musl` 版本的 gcc 可以进行 **纯静态编译**：
    ```shell
    TARGET = x86_64-linux-musl
    OUTPUT = /opt/musl
    BINUTILS_VER = 2.33.1
    GCC_VER = 11.40.0
    MUSL_VER = git-master 
    COMMON_CONFIG += CC="/opt/musl-toolchain/bin/x86_64-linux-musl-gcc -static --static" CXX="/opt/musl-toolchain/bin/x86_64-linux-musl-g++ -static --static"                                               
    COMMON_CONFIG += --disable-nls 
    ```

    说明：
    - `OUTPUT = /opt/musl` → 这次编译的 `musl` 交叉工具链将安装到 `/opt/musl`，用于完全静态链接的编译。
    - `CC` 和 `CXX` 设置为 `-static --static` → 这将确保 所有生成的二进制文件都是 **纯静态** 的，不依赖 `glibc`。

- 1.5 重新执行 1.3 的编译指令

    此步骤将编译 `musl` 版本的 `gcc`，确保它可以进行完全静态链接的编译。

    ```shell
    make -j$(nproc) && make install
    ```

- 1.6 验证编译结果

    编译完成后，验证 `musl` 交叉编译工具链是否真正是 **纯静态编译** 的：

    ```shell
    file /opt/musl/bin/x86_64-linux-musl-gcc
    ldd /opt/musl/bin/x86_64-linux-musl-gcc
    ```

    **期望输出**：
    ```shell
    /opt/musl/bin/x86_64-linux-musl-gcc: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked
    not a dynamic executable
    ```

    如果 `ldd` 返回 `not a dynamic executable`，说明 `musl` 工具链已成功编译为 **纯静态**。

### 2. 编译基于 `MUSL` 的 `zlib`、`cmake`、`libffi`、`ncurses`、 `openssl`
在 `musl` 环境下编译这些依赖，确保 `SnarkOS` 及其所需的库都是 **纯静态编译** 的，避免 `glibc` 依赖。

- 2.1 编译 `zlib`
    
    `zlib` 是一个广泛使用的数据压缩库，`SnarkOS` 依赖于它。

    ```shell 
    wget http://zlib.net/zlib-1.3.1.tar.gz
    
    tar -xvzf zlib-1.3.1.tar.gz
    
    cd zlib-1.3.1
    
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" ./configure --prefix=/opt/musl --static
    
    make -j$(nproc) && make install
    ````

    确保 `zlib` 为 **静态库**，不依赖 glibc。

- 2.2 编译 `libffi`

    `libffi`（Foreign Function Interface）用于支持 `SnarkOS` 调用外部 C 函数。

    ```shell
    git clone https://github.com/libffi/libffi.git
    
    cd libffi
    
    ./configure --prefix=/opt/musl/bin/x86_64-linux-musl-gcc --disable-shared --enable-static 
    
    make -j$(nproc) && make install 
    ```
    只编译 **静态库**，防止 `SnarkOS` 依赖动态链接库。

- 2.3 编译 `ncurses`

    `ncurses` 负责终端 UI 控制，`SnarkOS` 可能需要它来管理 CLI 界面。

    ```shell
    wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz
   
    tar -xvf ncurses-6.4.tar.gz 
    
    cd ncurses-6.4
    
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" CXX="/opt/musl/bin/x86_64-linux-musl-g++" ./configure \ --prefix=/opt/musl/x86_64-linux-musl \ 
    --disable-shared \ 
    --enable-static \ 
    --with-normal \ 
    --with-cxx-binding \ 
    --enable-widec
    
    make -j$(nproc) && make install  
    ```

    开启 `widec` 支持，增强宽字符处理能力。

- 2.4 编译 `OpenSSL`

    `OpenSSL` 提供加密支持，`SnarkOS` 依赖于 `TLS` 连接和加密功能

    ```shell
    wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
    
    tar -xvzf openssl-1.1.1w.tar.gz && cd openssl-1.1.1w
    
    CC="/opt/musl/bin/x86_64-linux-musl-gcc" CXX="/opt/musl/bin/x86_64-linux-musl-g++" ./Configure no-shared / 
    --prefix=/opt/musl/x86_64-linux-musl / 
    --openssldir=/opt/musl/x86_64-linux-musl linux-x86_64  
    
    make -j$(nproc) && make install 
    ```

    确保 `OpenSSL` 只生成 **静态库** `libcrypto.a` 和 `libssl.a`，避免动态链接 `libssl.so`。


- 2.5 编译 `CMake`

    `CMake` 是构建 `SnarkOS` 依赖的 `LLVM` 和 `Rust` 必不可少的工具。

    ```shell
    git clone https://github.com/Kitware/CMake.git
    
    cd CMake
    
    ./bootstrap --prefix=/opt/musl/x86_64-linux-musl \ 
    --parallel=$(nproc) \
    -- \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="/opt/musl/bin/x86_64-linux-musl-gcc" \
    -DCMAKE_CXX_COMPILER="/opt/musl/bin/x86_64-linux-musl-g++" \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DCMAKE_SHARED_LINKER_FLAGS="-static" \
    -DCMAKE_MODULE_LINKER_FLAGS="-static" \
    -DOPENSSL_ROOT_DIR="/opt/musl/x86_64-linux-musl" 

    make -j$(nproc) && make install
    ```

    静态编译 `CMake`，确保它不会依赖 `glibc`。

- 2.5 依赖编译完成

    ```shell
    ls /opt/musl/lib
    ```
    应该看到：

    ```shell
    libz.a  libffi.a  libncurses.a  libcrypto.a  libssl.a
    ```
所有库都已静态编译完成，准备进入下一步 LLVM 编译。

### 3. 编译基于 `MUSL` 的 `LLVM`

`LLVM`是 `Rust` 依赖的核心组件，为 `SnarkOS` 提供编译支持。

- 3.1 设置环境变量

    ```shell
    export CC="/opt/musl/bin/x86_64-linux-musl-gcc"
    export CXX="/opt/musl/bin/x86_64-linux-musl-g++"
    export LD="/opt/musl/bin/x86_64-linux-musl-ld"
    export AR="/opt/musl/bin/x86_64-linux-musl-ar"
    export RANLIB="/opt/musl/bin/x86_64-linux-musl-ranlib"
    export STRIP="/opt/musl/bin/x86_64-linux-musl-strip"
    export LD_LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib"
    ```
    ⚠️ 确保所有工具都使用 `musl` 交叉编译工具链。

- 3.2 获取 `LLVM` 源码

    ```shell
    git clone https://github.com/llvm/llvm-project.git
    cd llvm-project
    ```

- 3.3 编译 `LLVM`

    ```shell
    /opt/musl/x86_64-linux-musl/bin/cmake -S llvm -B build -G Ninja -DLLVM_ENABLE_PROJECTS=clang \ -DLIBCLANG_BUILD_STATIC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="/opt/musl/bin/x86_64-linux-musl-gcc" \
    -DCMAKE_CXX_COMPILER="/opt/musl/bin/x86_64-linux-musl-g++" \
    -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
    -DLIBCXX_HAS_MUSL_LIBC=ON -DLLVM_TARGETS_TO_BUILD="X86"  

    ninja -c build
    ```

    成功后 `LLVM` 交叉编译工具链可用于 `SnarkOS` 编译。

### 4. 编译 `SnarkOS` 
本节介绍如何在 `musl` 交叉编译环境下 构建 `SnarkOS`，包括 环境变量设置、源码获取、依赖修改和编译，最终生成 完全静态编译的 `SnarkOS` 可执行文件。


- 4.1 设置编译环境变量

    在 `musl` 交叉编译环境下，需要正确配置编译器、库路径和 `LLVM` 相关环境变量。

    ```shell
    export CC="/opt/musl/bin/x86_64-linux-musl-gcc"
    export CXX="/opt/musl/bin/x86_64-linux-musl-g++"
    export LD="/opt/musl/bin/x86_64-linux-musl-ld"
    export AR="/opt/musl/bin/x86_64-linux-musl-ar"
    export RANLIB="/opt/musl/bin/x86_64-linux-musl-ranlib"
    export STRIP="/opt/musl/bin/x86_64-linux-musl-strip"

    # 设置 LLVM 相关路径
    export LLVM_CONFIG_PATH="/root/llvm-project/build/bin/llvm-config"
    export BINDGEN_EXTRA_CLANG_ARGS="-L/root/llvm-project/build/lib -lclang"
    export LIBCLANG_PATH="/root/llvm-project/build/lib"

    # 设定编译依赖路径
    export PKG_CONFIG_PATH="/opt/musl/lib/pkgconfig:$PKG_CONFIG_PATH"
    export C_INCLUDE_PATH="/opt/musl/include:$C_INCLUDE_PATH"
    export LIBRARY_PATH="/opt/musl/lib:$LIBRARY_PATH"
    export LD_LIBRARY_PATH="/root/llvm-project/build/lib:/opt/musl/lib"
    ```
    确保所有工具、编译器和库路径都正确指向 `musl` 交叉编译环境。


- 4.2 获取 `SnarkOS` 和 `SnarkVM` 源码

    ```shell
    git clone https://github.com/ProvableHQ/snarkVM.git
    git clone https://github.com/ProvableHQ/snarkOS.git 
    ```
    确保 `SnarkOS` 依赖的 `SnarkVM` 版本正确。
- 4.3 修改代码以兼容 `musl`

    `musl` 版本的 `SnarkOS` 需要做以下修改，确保 `rocksdb`、`openssl` 和 `jemalloc` 兼容 `musl`。
    
    - 4.3.1 修改 SnarkVM 依赖
        ```shell
        cd snarkVM
        git checkout canary-v1.3.0
        vim ledger/store/Cargo.toml  
        ```
        修改 `ledger/store/Cargo.toml`，确保 `rocksdb` 只使用 **静态绑定**：
        ```toml
        [dependencies.rocksdb]
        version = "0.23.0"
        default-features = false
        features = [ "bindgen-static", "lz4" ]
        optional = true 
        ```
        启用 `bindgen-static`，避免 `rocksdb` 依赖动态库。

    - 4.3.2 让 SnarkOS 使用本地 SnarkVM
        ```shell
        cd snarkOS
        git checkout v3.2.0
        vim Cargo.toml  
        ```
        修改 `Cargo.toml`，让 `SnarkOS` 使用本地 `SnarkVM` 而不是远程仓库：

        ```toml
        [workspace.dependencies.snarkvm] # If this is updated, the rev in `node/rest/Cargo.toml` must be updated as well.
        
        path = "../snarkVM"
        #git = "https://github.com/ProvableHQ/snarkVM.git"
        #rev = "59b109c"
        version = "=1.2.1"
        features = [ "circuit", "console", "rocks" ]  
        
        [target.'cfg(all(target_os = "linux", target_arch = "x86_64"))'.dependencies]
        #tikv-jemallocator = "0.5"
        openssl = { version = "0.10", features = ["vendored"] }  
        ```
        禁用 `jemalloc`，启用 `openssl` 的 `vendored` 模式，避免 `glibc` 依赖。

    - 4.3.3 移除 `jemalloc`

        在 `musl` 下不需要 `jemalloc`，需注释 `SnarkOS` 的 `jemalloc` 代码：
        ```shell
        vim snarkos/main.rs
        ```

        修改 `snarkos/main.rs`，注释 `jemalloc`：

        ```rust
        ...
        // #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
        // use tikv_jemallocator::Jemalloc;
        // #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
        // #[global_allocator
        // static GLOBAL: Jemalloc = Jemalloc;   
        ...
        
        ```
        去掉 `jemalloc`，防止 `musl` 兼容性问题。

- 4.4 编译 `SnarkOS`

    `Rust` 需要使用 `musl` 版本进行编译，因此必须切换到 `musl` 目标环境。

    ```shell
    rustup install 1.81.0-x86_64-unknown-linux-musl
    rustup default 1.81.0-x86_64-unknown-linux-musl
    rustup override set 1.81.0-x86_64-unknown-linux-musl
    ```
    使用 `musl` 交叉编译 `SnarkOS`：
    ```shell
    cargo build --release --target x86_64-unknown-linux-musl
    ```

    成功后，`target/x86_64-unknown-linux-musl/release/snarkos`即为 `SnarkOS` 可执行文件。


- 4.5 验证 `SnarkOS` 是否完全静态

    检查 `snarkos` 是否为完全静态编译：
    ```shell
    ldd target/x86_64-unknown-linux-musl/release/snarkos
    ```

    如果输出：
    ```shell
    statically linked # or not a dynamic executable
    ```
    说明 `SnarkOS` 编译成功，并且是完全静态的 `musl` 版本，可以独立运行！




