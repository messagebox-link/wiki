#!/bin/bash
set -e

# Clone SnarkVM and SnarkOS
git clone https://github.com/ProvableHQ/snarkVM.git
git clone https://github.com/ProvableHQ/snarkOS.git

# Configure SnarkVM
cd snarkVM
git checkout v1.3.0
sed -i '/\[dependencies\.rocksdb\]/,+4c\[dependencies.rocksdb\]\nversion = "0.23.0"\ndefault-features = false\nfeatures = [ "bindgen-static", "lz4" ]\noptional = true' ledger/store/Cargo.toml

# Configure SnarkOS
cd ../snarkOS
git checkout v3.3.1

# Update Cargo.toml
sed -i 's|#path = "../snarkVM"|path = "../snarkVM"|' Cargo.toml
sed -i 's|^tikv-jemallocator = "0.5"|openssl = { version = "0.10", features = ["vendored"] }|' Cargo.toml
sed -i 's|^#path = "../../../snarkVM/synthesizer"|path = "../../../snarkVM/synthesizer"|' node/rest/Cargo.toml

# Comment out jemalloc configuration in main.rs
sed -i 's|^#\[cfg(all(target_os = "linux", target_arch = "x86_64"))\]|// #[cfg(all(target_os = "linux", target_arch = "x86_64"))]|' snarkos/main.rs && \
sed -i 's|^use tikv_jemallocator::Jemalloc;|// use tikv_jemallocator::Jemalloc;|' snarkos/main.rs && \
sed -i 's|^#\[global_allocator\]|// #[global_allocator]|' snarkos/main.rs && \
sed -i 's|^static GLOBAL: Jemalloc = Jemalloc;|// static GLOBAL: Jemalloc = Jemalloc;|' snarkos/main.rs

# Set exportironment variables
export CC="/opt/musl/bin/x86_64-linux-musl-gcc"
export CXX="/opt/musl/bin/x86_64-linux-musl-g++"
export LD="/opt/musl/bin/x86_64-linux-musl-ld"
export AR="/opt/musl/bin/x86_64-linux-musl-ar"
export RANLIB="/opt/musl/bin/x86_64-linux-musl-ranlib"
export STRIP="/opt/musl/bin/x86_64-linux-musl-strip"
export LD_LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib"

# Set LLVM related paths
export LLVM_CONFIG_PATH="/opt/musl/llvm-build/bin/llvm-config"
export BINDGEN_EXTRA_CLANG_ARGS="-L/opt/musl/llvm-build/lib -lclang"
export LIBCLANG_PATH="/opt/musl/llvm-build/lib"

# Set compilation dependency paths
export PKG_CONFIG_PATH="/opt/musl/x86_64-linux-musl/lib/pkgconfig"
export C_INCLUDE_PATH="/opt/musl/x86_64-linux-musl/include"
export LIBRARY_PATH="/opt/musl/x86_64-linux-musl/lib"
export LD_LIBRARY_PATH="/opt/musl/llvm-build/lib:/opt/musl/x86_64-linux-musl/lib"


# Set Rust with musl target
. $HOME/.cargo/env 
rustup install 1.81.0-x86_64-unknown-linux-musl && \
rustup default 1.81.0-x86_64-unknown-linux-musl && \
rustup override set 1.81.0-x86_64-unknown-linux-musl

# Build SnarkOS
cargo build --release --target x86_64-unknown-linux-musl

# Compress the binary with UPX
echo "Compressing binary with UPX..."
upx --best --lzma target/x86_64-unknown-linux-musl/release/snarkos

# Print the final binary size
echo "Final binary size:"
cp target/x86_64-unknown-linux-musl/release/snarkos /tmp
