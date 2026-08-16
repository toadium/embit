#!/usr/bin/env python3
"""prepare.py — Embit Gazebo FFI 环境配置脚本

检测 Ignition Transport 库，编译 C++ wrapper 为静态库，更新 moon.pkg 链接配置。

用法：
    python scripts/prepare.py --with-ignition   # 启用真实 Ignition Transport
    python scripts/prepare.py --check           # 仅检测库可用性
    python scripts/prepare.py --clean           # 清理生成的文件

环境变量：
    IGNITION_PREFIX   Ignition Transport 安装前缀（默认 /usr/local 或 C:/Program Files）
    CXX               C++ 编译器（默认 c++/g++/clang++）
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
WRAPPER_SRC = PKG_DIR / "gazebo_ignition_wrapper.cpp"
WRAPPER_LIB = LIB_DIR / ("embit_ignition.lib" if sys.platform == "win32" else "libembit_ignition.a")


def find_ignition_prefix() -> Path | None:
    prefix = os.environ.get("IGNITION_PREFIX")
    if prefix and Path(prefix).exists():
        return Path(prefix)
    candidates = [
        Path("/usr/local"),
        Path("/usr"),
        Path("C:/Program Files/ignition"),
        Path("C:/Program Files (x86)/ignition"),
        Path("/opt/ignition"),
    ]
    for c in candidates:
        inc = c / "include" / "ignition"
        if inc.exists():
            return c
    return None


def find_cxx() -> str | None:
    cxx = os.environ.get("CXX")
    if cxx:
        return cxx
    for c in ("c++", "g++", "clang++", "cl"):
        if shutil.which(c):
            return c
    return None


def check_ignition() -> bool:
    prefix = find_ignition_prefix()
    if prefix:
        print(f"[OK] Ignition Transport found at: {prefix}")
        inc = prefix / "include" / "ignition"
        print(f"     headers: {inc}")
        return True
    print("[MISS] Ignition Transport not found")
    print("       Install Gazebo Fortress+ or set IGNITION_PREFIX")
    return False


def compile_wrapper(prefix: Path) -> bool:
    cxx = find_cxx()
    if not cxx:
        print("[ERR] No C++ compiler found (set CXX env var)")
        return False
    LIB_DIR.mkdir(exist_ok=True)
    inc_dir = prefix / "include"
    lib_dir = prefix / "lib"
    if sys.platform == "win32":
        cmd = [cxx, "/std:c++17", f"/I{inc_dir}", "/c", str(WRAPPER_SRC), f"/Fo:{WRAPPER_LIB}"]
    else:
        cmd = [cxx, "-std=c++17", "-fPIC", f"-I{inc_dir}", "-c", str(WRAPPER_SRC), "-o", str(WRAPPER_LIB)]
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
# 启用真实 Ignition Transport 链接（由 prepare.py --with-ignition 生成）
link(
  native(
    "stub-cc-flags": "-DEMBIT_HAS_IGNITION",
    "cc-link-flags": "-L{LIB_DIR} -lembit_ignition",
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
    parser = argparse.ArgumentParser(description="Embit Gazebo FFI prepare")
    parser.add_argument("--with-ignition", action="store_true", help="Enable real Ignition Transport")
    parser.add_argument("--check", action="store_true", help="Check library availability only")
    parser.add_argument("--clean", action="store_true", help="Remove generated files")
    args = parser.parse_args()

    if args.clean:
        clean()
        return 0
    if args.check:
        return 0 if check_ignition() else 1
    if args.with_ignition:
        if not check_ignition():
            return 1
        prefix = find_ignition_prefix()
        if not prefix or not compile_wrapper(prefix):
            return 1
        update_moon_pkg(enable=True)
        print("[OK] Ignition Transport FFI enabled. Run 'moon test --target native' to verify.")
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())