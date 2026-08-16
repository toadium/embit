#!/usr/bin/env python3
"""prepare.py — Embit ggml FFI 环境配置脚本

检测 ggml/llama.cpp 库，编译 C wrapper 为静态库，更新 moon.pkg 链接配置。

用法：
    python scripts/prepare.py --with-ggml      # 启用真实 ggml/VLA 推理
    python scripts/prepare.py --check          # 仅检测库可用性
    python scripts/prepare.py --clean          # 清理生成的文件

环境变量：
    GGML_PREFIX    ggml/llama.cpp 安装前缀（默认 /usr/local 或 vendor 路径）
    CC             C 编译器（默认 cc/gcc/clang）
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

PKG_DIR = Path(__file__).resolve().parent.parent
LIB_DIR = PKG_DIR / "lib"
MOON_PKG = PKG_DIR / "moon.pkg"
WRAPPER_SRC = PKG_DIR / "ggml_native_wrapper.c"
WRAPPER_LIB = LIB_DIR / ("embit_ggml.lib" if sys.platform == "win32" else "libembit_ggml.a")


def find_ggml_prefix() -> Path | None:
    prefix = os.environ.get("GGML_PREFIX")
    if prefix and Path(prefix).exists():
        return Path(prefix)
    candidates = [
        Path("/usr/local"),
        Path("/usr"),
        Path("C:/Program Files/ggml"),
        Path("/opt/ggml"),
        PKG_DIR / "vendor" / "ggml",
    ]
    for c in candidates:
        inc = c / "include" / "ggml.h"
        if inc.exists():
            return c
    return None


def find_cc() -> str | None:
    cc = os.environ.get("CC")
    if cc:
        return cc
    for c in ("cc", "gcc", "clang", "cl"):
        if shutil.which(c):
            return c
    return None


def check_ggml() -> bool:
    prefix = find_ggml_prefix()
    if prefix:
        print(f"[OK] ggml found at: {prefix}")
        return True
    print("[MISS] ggml/llama.cpp not found")
    print("       Install ggml or set GGML_PREFIX")
    return False


def compile_wrapper(prefix: Path) -> bool:
    cc = find_cc()
    if not cc:
        print("[ERR] No C compiler found (set CC env var)")
        return False
    LIB_DIR.mkdir(exist_ok=True)
    inc_dir = prefix / "include"
    if sys.platform == "win32":
        cmd = [cc, f"/I{inc_dir}", "/c", str(WRAPPER_SRC), f"/Fo:{WRAPPER_LIB}"]
    else:
        cmd = [cc, "-fPIC", f"-I{inc_dir}", "-c", str(WRAPPER_SRC), "-o", str(WRAPPER_LIB)]
    print(f"[RUN] {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[ERR] Compilation failed:\n{result.stderr}")
        return False
    print(f"[OK] Wrapper compiled: {WRAPPER_LIB}")
    return True


def update_moon_pkg(enable: bool) -> None:
    content = MOON_PKG.read_text(encoding="utf-8")
    marker = "# --- prepare.py generated ---"
    existing_block_start = content.find(marker)
    if existing_block_start != -1:
        content = content[:existing_block_start].rstrip() + "\n"
    if enable:
        block = f"""
{marker}
# 启用真实 ggml/VLA 链接（由 prepare.py --with-ggml 生成）
link(
  native(
    "stub-cc-flags": "-DEMBIT_HAS_GGML",
    "cc-link-flags": "-L{LIB_DIR} -lembit_ggml",
  )
)
"""
        content = content.rstrip() + "\n" + block
    MOON_PKG.write_text(content, encoding="utf-8")
    print(f"[OK] moon.pkg updated (enable={enable})")


def clean() -> None:
    if LIB_DIR.exists():
        shutil.rmtree(LIB_DIR)
        print(f"[OK] Removed {LIB_DIR}")
    update_moon_pkg(enable=False)
    print("[OK] Clean done")


def main() -> int:
    parser = argparse.ArgumentParser(description="Embit ggml FFI prepare")
    parser.add_argument("--with-ggml", action="store_true", help="Enable real ggml/VLA")
    parser.add_argument("--check", action="store_true", help="Check library availability only")
    parser.add_argument("--clean", action="store_true", help="Remove generated files")
    args = parser.parse_args()

    if args.clean:
        clean()
        return 0
    if args.check:
        return 0 if check_ggml() else 1
    if args.with_ggml:
        if not check_ggml():
            return 1
        prefix = find_ggml_prefix()
        if not prefix or not compile_wrapper(prefix):
            return 1
        update_moon_pkg(enable=True)
        print("[OK] ggml/VLA FFI enabled. Run 'moon test --target native' to verify.")
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())