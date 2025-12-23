#!/usr/bin/env python3
"""
完整的GLSL shader重命名工具
组合使用UBO重命名和变量重命名

用法:
    python3 rename_all.py input_shader.glsl output_shader.glsl

示例:
    python3 rename_all.py original.glsl renamed.glsl
"""

import sys
import subprocess
import pandas as pd
from pathlib import Path
import shutil


def extract_variable_mapping():
    """从完整映射表中提取变量映射（排除UBO成员）"""
    print("[1/4] 提取变量映射...")

    try:
        df = pd.read_csv("complete_mapping_unity_based.csv")
    except FileNotFoundError:
        print("  ✗ 错误: 找不到 complete_mapping_unity_based.csv")
        print("     请确保该文件在当前目录")
        return None

    # 排除UBO成员（包含._m的）
    var_df = df[~df["original"].str.contains("._m", na=False)].copy()

    # 只保留original和renamed列
    var_df = var_df[["original", "renamed"]]

    # 保存到临时文件
    temp_dir = Path("./temp_rename")
    temp_dir.mkdir(exist_ok=True)
    var_mapping_file = temp_dir / "variable_mapping.csv"
    var_df.to_csv(var_mapping_file, index=False)

    print(f"  ✓ 提取了 {len(var_df)} 个变量映射")
    return var_mapping_file


def rename_ubo_members(input_file, output_file):
    """重命名UBO成员访问"""
    print()
    print("[2/4] 重命名UBO成员访问...")

    if not Path("rename_ubo_members.py").exists():
        print("  ✗ 错误: 找不到 rename_ubo_members.py")
        return False

    result = subprocess.run(
        [
            sys.executable,
            "rename_ubo_members.py",
            input_file,
            "--output",
            str(output_file),
            "--stats",
        ]
    )

    if result.returncode != 0:
        print("  ✗ UBO重命名失败")
        return False

    print("  ✓ UBO成员重命名完成")
    return True


def rename_variables(input_file, mapping_file, output_file):
    """重命名局部变量"""
    print()
    print("[3/4] 重命名局部变量...")

    if not Path("rename_shader_vars.py").exists():
        print("  ✗ 错误: 找不到 rename_shader_vars.py")
        return False

    result = subprocess.run(
        [
            sys.executable,
            "rename_shader_vars.py",
            str(input_file),
            str(mapping_file),
            "--output",
            output_file,
        ]
    )

    if result.returncode != 0:
        print("  ✗ 变量重命名失败")
        return False

    print("  ✓ 局部变量重命名完成")
    return True


def validate_glsl(shader_file):
    """验证GLSL语法（可选）"""
    print()
    print("[4/4] 验证GLSL语法...")

    # 检查是否有glslangValidator
    if not shutil.which("glslangValidator"):
        print("  ⚠ 跳过验证 (未找到glslangValidator)")
        print("     你可以安装Vulkan SDK来获取glslangValidator")
        return True

    result = subprocess.run(
        ["glslangValidator", "-S", "frag", shader_file], capture_output=True, text=True
    )

    if result.returncode == 0:
        print("  ✓ GLSL语法验证通过！")
        return True
    else:
        print("  ✗ GLSL语法验证失败:")
        print(result.stderr)
        return False


def main():
    """主函数"""
    print("=" * 60)
    print("GLSL Shader 完整重命名工具")
    print("组合UBO重命名 + 变量重命名")
    print("=" * 60)

    # 检查参数
    if len(sys.argv) != 3:
        print()
        print("用法: python3 rename_all.py <input_shader.glsl> <output_shader.glsl>")
        print()
        print("示例:")
        print("  python3 rename_all.py original.glsl renamed.glsl")
        print()
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # 检查输入文件
    if not Path(input_file).exists():
        print(f"✗ 错误: 输入文件不存在: {input_file}")
        sys.exit(1)

    print(f"输入文件: {input_file}")
    print(f"输出文件: {output_file}")
    print()

    # 创建临时目录
    temp_dir = Path("./temp_rename")
    temp_dir.mkdir(exist_ok=True)

    # 步骤1: 提取变量映射
    var_mapping_file = extract_variable_mapping()
    if var_mapping_file is None:
        sys.exit(1)

    # 步骤2: 重命名UBO成员
    step1_output = temp_dir / "step1_ubo_renamed.glsl"
    if not rename_ubo_members(input_file, step1_output):
        sys.exit(1)

    # 步骤3: 重命名局部变量
    if not rename_variables(step1_output, var_mapping_file, output_file):
        sys.exit(1)

    # 步骤4: 验证语法
    validate_glsl(output_file)

    # 完成
    print()
    print("=" * 60)
    print("✓ 重命名完成！")
    print(f"  输出文件: {output_file}")
    print()
    print("提示:")
    print("  - 中间文件保存在 ./temp_rename/ 目录")
    print("  - step1_ubo_renamed.glsl 包含UBO重命名结果")
    print("  - 你可以查看中间文件来调试问题")
    print("=" * 60)


if __name__ == "__main__":
    main()
