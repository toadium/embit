#!/usr/bin/env python3
"""prepare.py — Embit View FFI 环境配置脚本

检测 Selene 可视化引擎库，编译 C wrapper 为静态库，更新 moon.pkg 链接配置。

用法：
    python scripts/prepare.py --with-selene    # 启用真实 Selene 引擎
    python scripts/prepare.py --check          # 仅检测库可用性
    python scripts/prepare.py --clean          # 清理生成的文件

环境变量：
    SELENE_PREFIX   Selene SDK 安装前缀（默认 /usr/local 或 vendor 路径）
    CC              C 编译器（默认 cc/gcc/clang）
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
WRAPPER_SRC = PKG_DIR / "selene_wrapper.c"
WRAPPER_LIB = LIB_DIR / ("embit_selene.lib" if sys.platform == "win32" else "libembit_selene.a")


def find_selene_prefix() -> Path | None:
    prefix = os.environ.get("SELENE_PREFIX")
    if prefix and Path(prefix).exists():
        return Path(prefix)
    candidates = [
        Path("/usr/local"),
        Path("/usr"),
        Path("C:/Program Files/selene"),
        Path("/opt/selene"),
        PKG_DIR / "vendor" / "selene",
    ]
    for c in candidates:
        inc = c / "include" / "selene.h"
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


def check_selene() -> bool:
    prefix = find_selene_prefix()
    if prefix:
        print(f"[OK] Selene found at: {prefix}")
        return True
    print("[MISS] Selene visualization engine not found")
    print("       Install Selene SDK or set SELENE_PREFIX")
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
# 启用真实 Selene 引擎链接（由 prepare.py --with-selene 生成）
link(
  native(
    "stub-cc-flags": "-DEMBIT_HAS_SELENE",
    "cc-link-flags": "-L{LIB_DIR} -lembit_selene",
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
    parser = argparse.ArgumentParser(description="Embit View FFI prepare")
    parser.add_argument("--with-selene", action="store_true", help="Enable real Selene engine")
    parser.add_argument("--check", action="store_true", help="Check library availability only")
    parser.add_argument("--clean", action="store_true", help="Remove generated files")
    args = parser.parse_args()

    if args.clean:
        clean()
        return 0
    if args.check:
        return 0 if check_selene() else 1
    if args.with_selene:
        if not check_selene():
            return 1
        prefix = find_selene_prefix()
        if not prefix or not compile_wrapper(prefix):
            return 1
        update_moon_pkg(enable=True)
        print("[OK] Selene FFI enabled. Run 'moon test --target native' to verify.")
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())