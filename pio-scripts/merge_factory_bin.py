Import("env")

import json
import subprocess
from pathlib import Path


def _get_cpp_define_value(build_env, define_name):
    for item in build_env["CPPDEFINES"]:
        if isinstance(item, tuple) and len(item) >= 2 and item[0] == define_name:
            return str(item[1])
    return None


def _find_boot_app0(platform):
    framework_dir = platform.get_package_dir("framework-arduinoespressif32")
    if not framework_dir:
        return None

    candidate = Path(framework_dir) / "tools" / "partitions" / "boot_app0.bin"
    return candidate if candidate.is_file() else None


def _resolve_esptool_py(platform):
    for package_name in ("tool-esptoolpy", "tool-esptool"):
        package_dir = platform.get_package_dir(package_name)
        if not package_dir:
            continue

        candidate = Path(package_dir) / "esptool.py"
        if candidate.is_file():
            return candidate

    return None


def merge_factory_bin(source, target, env):
    board = env.BoardConfig()
    mcu = str(board.get("build.mcu"))
    flash_size = board.get("upload.flash_size")

    build_dir = Path(env.subst("$BUILD_DIR"))
    project_dir = Path(env.subst("$PROJECT_DIR"))

    bootloader_bin = build_dir / "bootloader.bin"
    partitions_bin = build_dir / "partitions.bin"
    app_bin = Path(str(target[0]))

    platform = env.PioPlatform()
    boot_app0_bin = _find_boot_app0(platform)
    esptool_py = _resolve_esptool_py(platform)

    required = [bootloader_bin, partitions_bin, app_bin, boot_app0_bin, esptool_py]
    missing = [str(path) for path in required if not path or not Path(path).is_file()]
    if missing:
        print("[factory-bin] Skipping merge, missing files:")
        for path in missing:
            print(f"  - {path}")
        return

    output_dir = project_dir / "build_output" / "release"
    output_dir.mkdir(parents=True, exist_ok=True)

    version = "unknown"
    package_json = project_dir / "package.json"
    if package_json.is_file():
        with package_json.open("r", encoding="utf-8") as fp:
            version = json.load(fp).get("version", version)

    release_name_def = _get_cpp_define_value(env, "WLED_RELEASE_NAME")
    if release_name_def:
        release_name = release_name_def.replace("\\\"", "")
    else:
        release_name = env["PIOENV"]

    output_file = output_dir / f"WLED_{version}_{release_name}_full.bin"

    python_exe = env.subst("$PYTHONEXE")
    cmd = [
        python_exe,
        str(esptool_py),
        "--chip",
        mcu,
        "merge_bin",
        "--output",
        str(output_file),
        "--fill-flash-size",
        str(flash_size),
        "0x0",
        str(bootloader_bin),
        "0x8000",
        str(partitions_bin),
        "0xe000",
        str(boot_app0_bin),
        "0x10000",
        str(app_bin),
    ]
    print(f"[factory-bin] Running command: {' '.join(cmd)}")
 
    print(f"[factory-bin] Merging firmware image into {output_file}")
    subprocess.run(cmd, check=True, cwd=str(project_dir))


env.AddPostAction("$BUILD_DIR/${PROGNAME}.bin", merge_factory_bin)
