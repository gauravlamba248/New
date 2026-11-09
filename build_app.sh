#!/bin/bash
set -e

echo "==> Building Aegis Native macOS Application in Release Mode..."
swift build -c release

APP_DIR="Aegis.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

echo "==> Constructing native macOS App Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$RESOURCES_DIR/bin"

cp .build/release/Aegis "$MACOS_DIR/Aegis"
cp Info.plist "$CONTENTS_DIR/Info.plist"

if [ -f "AppIcon.icns" ]; then
    echo "==> Embedding AppIcon.icns into app bundle..."
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "AppIcon.png" ]; then
    cp "AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
fi

TOR_BIN=""
if [ -f "/opt/homebrew/opt/tor/bin/tor" ]; then
    TOR_BIN="/opt/homebrew/opt/tor/bin/tor"
elif [ -f "/opt/homebrew/bin/tor" ]; then
    TOR_BIN="/opt/homebrew/bin/tor"
elif [ -f "/usr/local/bin/tor" ]; then
    TOR_BIN="/usr/local/bin/tor"
elif which tor >/dev/null 2>&1; then
    TOR_BIN="$(which tor)"
fi

if [ -n "$TOR_BIN" ]; then
    echo "==> Embedding Tor binary into app bundle: $TOR_BIN"
    cp "$TOR_BIN" "$RESOURCES_DIR/tor"
    chmod +x "$RESOURCES_DIR/tor"
fi

# Bundle Standalone LLM Engine & Apple Silicon Metal Frameworks
LLAMA_BIN="/opt/homebrew/Cellar/llama.cpp/0.9.0/bin/llama-cli"
if [ -f "$LLAMA_BIN" ]; then
    echo "==> Embedding Standalone LLM Engine (aegis-llm-engine) into app bundle..."
    cp "$LLAMA_BIN" "$RESOURCES_DIR/bin/aegis-llm-engine"
    chmod +x "$RESOURCES_DIR/bin/aegis-llm-engine"

    echo "==> Packaging standalone LLM & GGML Metal runtime frameworks..."
    python3 -c "
import os, subprocess, shutil

bundle_bin = os.path.abspath('$RESOURCES_DIR/bin/aegis-llm-engine')
bundle_fw = os.path.abspath('$FRAMEWORKS_DIR')

libs = [
    '/opt/homebrew/Cellar/ggml/0.29.0/lib/libggml-base.0.29.0.dylib',
    '/opt/homebrew/Cellar/ggml/0.29.0/lib/libggml.0.29.0.dylib',
    '/opt/homebrew/Cellar/libomp/23.1.5/lib/libomp.dylib',
    '/opt/homebrew/Cellar/llama.cpp/0.9.0/lib/libllama-cli-impl.dylib',
    '/opt/homebrew/Cellar/llama.cpp/0.9.0/lib/libllama-common.0.9.0.dylib',
    '/opt/homebrew/Cellar/llama.cpp/0.9.0/lib/libllama-server-impl.dylib',
    '/opt/homebrew/Cellar/llama.cpp/0.9.0/lib/libllama.0.9.0.dylib',
    '/opt/homebrew/Cellar/llama.cpp/0.9.0/lib/libmtmd.0.9.0.dylib',
    '/opt/homebrew/Cellar/openssl@4/4.1.0/lib/libcrypto.4.dylib',
    '/opt/homebrew/Cellar/openssl@4/4.1.0/lib/libssl.4.dylib'
]

for lib in libs:
    if os.path.exists(lib):
        shutil.copy2(lib, bundle_fw)
        os.chmod(os.path.join(bundle_fw, os.path.basename(lib)), 0o755)

symlinks = {
    'libggml-base.0.dylib': 'libggml-base.0.29.0.dylib',
    'libggml.0.dylib': 'libggml.0.29.0.dylib',
    'libllama-common.0.dylib': 'libllama-common.0.9.0.dylib',
    'libllama.0.dylib': 'libllama.0.9.0.dylib',
    'libmtmd.0.dylib': 'libmtmd.0.9.0.dylib'
}
for link, target in symlinks.items():
    link_path = os.path.join(bundle_fw, link)
    if os.path.exists(link_path): os.unlink(link_path)
    os.symlink(target, link_path)

ggml_libexec = '/opt/homebrew/Cellar/ggml/0.29.0/libexec'
if os.path.exists(ggml_libexec):
    for f in os.listdir(ggml_libexec):
        if f.endswith('.so') or f.endswith('.dylib'):
            shutil.copy2(os.path.join(ggml_libexec, f), bundle_fw)

subprocess.run(['install_name_tool', '-add_rpath', '@executable_path/../../Frameworks', bundle_bin], stderr=subprocess.DEVNULL)

out = subprocess.check_output(['otool', '-L', bundle_bin]).decode()
for line in out.splitlines()[1:]:
    dep = line.strip().split()[0]
    base = os.path.basename(dep)
    if 'openssl' in dep or 'ggml' in dep or 'libomp' in dep:
        subprocess.run(['install_name_tool', '-change', dep, f'@rpath/{base}', bundle_bin], check=True)

for f in os.listdir(bundle_fw):
    if not (f.endswith('.dylib') or f.endswith('.so')): continue
    fpath = os.path.join(bundle_fw, f)
    if os.path.islink(fpath): continue
    subprocess.run(['install_name_tool', '-id', f'@rpath/{f}', fpath], stderr=subprocess.DEVNULL)
    subprocess.run(['install_name_tool', '-add_rpath', '@loader_path', fpath], stderr=subprocess.DEVNULL)
    out_lib = subprocess.check_output(['otool', '-L', fpath]).decode()
    for line in out_lib.splitlines()[1:]:
        dep = line.strip().split()[0]
        base = os.path.basename(dep)
        if dep.startswith('/opt/homebrew'):
            subprocess.run(['install_name_tool', '-change', dep, f'@rpath/{base}', fpath], check=True)
"
    echo "==> Codesigning bundled frameworks..."
    codesign --force --sign - "$FRAMEWORKS_DIR"/*
    codesign --force --sign - "$RESOURCES_DIR/bin/aegis-llm-engine"
fi

echo "==> Signing with hardened runtime and sandboxing entitlements..."
codesign --force --deep --sign - --entitlements Aegis.entitlements "$APP_DIR"

echo "==> Successfully packaged: $APP_DIR"
echo "==> Launch with: open Aegis.app"
