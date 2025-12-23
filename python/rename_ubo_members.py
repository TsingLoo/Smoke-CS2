#!/usr/bin/env python3
"""
GLSL UBO Member Renamer
专门用于重命名UBO实例和成员访问
"""

import re
import argparse
from pathlib import Path


# UBO实例映射
UBO_INSTANCES = {
    "_4459": "cameraData",
    "_4023": "volumeData",
    "_5618": "renderParams",
    "_5037": "screenData",
    "_5538": "lightingData",
}

# UBO成员映射（格式: "实例名.成员" -> "新成员名"）
UBO_MEMBERS = {
    # Camera Data
    "_4459._m0": "viewMatrix",
    "_4459._m1": "projectionParams",
    "_4459._m2": "cameraPosition",
    "_4459._m3": "nearPlane",
    "_4459._m4": "viewDirection",
    "_4459._m5": "farPlane",
    "_4459._m6": "rightVector",
    "_4459._m7": "time",
    # Volume Data
    "_4023._m0": "volumeBoundsMin",
    "_4023._m1": "volumeBoundsMax",
    "_4023._m2": "volumeCenters",
    "_4023._m3": "volumeParams",
    "_4023._m4": "volumeColors",
    "_4023._m5": "volumeDensityParams",
    "_4023._m6": "globalBoundsMin",
    "_4023._m7": "globalBoundsMax",
    "_4023._m8": "lightPositionsStart",
    "_4023._m9": "lightPositionsEnd",
    "_4023._m10": "lightParams",
    "_4023._m11": "dissipationPoints",
    "_4023._m12": "dissipationChannelMask",
    "_4023._m13": "lightCount",
    "_4023._m14": "globalTime",
    "_4023._m15": "dissipationCount",
    # Render Parameters
    "_5618._m0": "jitterScale",
    "_5618._m1": "alphaScale",
    "_5618._m2": "timeScale",
    "_5618._m3": "noise1Influence",
    "_5618._m4": "detailNoiseInfluence",
    "_5618._m5": "normalPerturbScale",
    "_5618._m6": "phaseBlend",
    "_5618._m7": "noiseOffset",
    "_5618._m8": "noise1Scale",
    "_5618._m9": "noise2Scale",
    "_5618._m10": "noisePower",
    "_5618._m11": "noiseColorA",
    "_5618._m12": "noiseColorB",
    "_5618._m13": "baseColorIntensity",
    "_5618._m14": "sunColorIntensity",
    "_5618._m15": "rimLightIntensity",
    "_5618._m16": "densityContrast",
    "_5618._m17": "stepSize",
    "_5618._m18": "normalDetailScale",
    "_5618._m19": "enableSecondPass",
    "_5618._m20": "colorTint",
    "_5618._m21": "godrayIntensity",
    "_5618._m22": "godrayFalloff",
    "_5618._m23": "noiseMixFactor",
    "_5618._m24": "depthDownscale",
    # Screen Data
    "_5037._m0": "noiseTileSize",
    "_5037._m1": "logDepthNear",
    "_5037._m2": "logDepthFar",
    # Lighting Data
    "_5538._m0": "sunDirection",
    "_5538._m1": "sunColor",
}


def rename_ubo_members(shader_code):
    """
    重命名UBO成员访问
    先处理成员访问，然后处理实例名
    """
    result = shader_code
    replacements = {}

    # 步骤1: 替换UBO成员访问 (instance._mX)
    for old_member, new_name in UBO_MEMBERS.items():
        instance, member = old_member.split(".")
        new_instance = UBO_INSTANCES.get(instance, instance)

        # 匹配 instance._mX (包括后续的数组访问、字段访问等)
        # 例如: _4459._m0 或 _4459._m0[i] 或 _4459._m0.xyz
        pattern = r"\b" + re.escape(instance) + r"\." + re.escape(member) + r"\b"
        replacement = f"{new_instance}.{new_name}"

        # 统计替换次数
        matches = re.findall(pattern, result)
        if matches:
            result = re.sub(pattern, replacement, result)
            key = f"{instance}.{member}"
            replacements[key] = (len(matches), replacement)

    # 步骤2: 替换UBO类型名（在uniform声明中）
    ubo_type_replacements = {
        "_633_4459": "CameraDataBlock",
        "_754_4023": "VolumeDataBlock",
        "_2920_5618": "RenderParamsBlock",
        "_1030_5037": "ScreenDataBlock",
        "_1080_5538": "LightingDataBlock",
    }

    for old_type, new_type in ubo_type_replacements.items():
        pattern = r"\buniform\s+" + re.escape(old_type) + r"\b"
        replacement = f"uniform {new_type}"
        result = re.sub(pattern, replacement, result)

    # 步骤3: 在UBO定义末尾替换实例名
    # 例如: } _4459; -> } cameraData;
    for old_instance, new_instance in UBO_INSTANCES.items():
        pattern = r"\}\s*" + re.escape(old_instance) + r"\s*;"
        replacement = f"}} {new_instance};"
        result = re.sub(pattern, replacement, result)

    return result, replacements


def main():
    parser = argparse.ArgumentParser(
        description="Rename UBO instances and members in GLSL shader"
    )
    parser.add_argument("shader_file", type=Path, help="Path to the GLSL shader file")
    parser.add_argument(
        "--output",
        type=Path,
        help="Output file path (default: <input>_ubo_renamed.glsl)",
    )
    parser.add_argument(
        "--stats", action="store_true", help="Print replacement statistics"
    )

    args = parser.parse_args()

    # 验证输入文件
    if not args.shader_file.exists():
        print(f"Error: File '{args.shader_file}' not found")
        return 1

    # 设置输出路径
    if args.output is None:
        output_path = (
            args.shader_file.parent
            / f"{args.shader_file.stem}_ubo_renamed{args.shader_file.suffix}"
        )
    else:
        output_path = args.output

    print(f"Reading shader: {args.shader_file}")
    with open(args.shader_file, "r", encoding="utf-8") as f:
        shader_code = f.read()

    print("Renaming UBO members...")
    renamed_code, stats = rename_ubo_members(shader_code)

    print(f"Writing output to: {output_path}")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(renamed_code)

    print(f"\n✓ Successfully renamed {len(stats)} unique UBO members")
    print(f"✓ Total replacements: {sum(count for count, _ in stats.values())}")

    if args.stats and stats:
        print("\n=== Replacement Statistics ===")
        # 按实例分组
        by_instance = {}
        for old_member, (count, new_member) in stats.items():
            instance = old_member.split(".")[0]
            if instance not in by_instance:
                by_instance[instance] = []
            by_instance[instance].append((old_member, count, new_member))

        # 打印每个实例的替换
        for instance in sorted(by_instance.keys()):
            new_instance = UBO_INSTANCES.get(instance, instance)
            print(f"\n{instance} -> {new_instance}:")
            for old_member, count, new_member in sorted(by_instance[instance]):
                print(
                    f"  {old_member:20s} → {new_member:30s} ({count:3d} replacements)"
                )

    return 0


if __name__ == "__main__":
    exit(main())
