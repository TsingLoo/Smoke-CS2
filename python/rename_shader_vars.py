#!/usr/bin/env python3
"""
GLSL Shader Variable Renamer
Replaces obfuscated variable names with meaningful ones based on a CSV mapping.
"""

import csv
import re
import argparse
from pathlib import Path


def load_mapping(csv_path):
    """Load variable mapping from CSV file."""
    mapping = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            original = row['original'].strip()
            renamed = row['renamed'].strip()
            if original and renamed and original != renamed:
                mapping.append((original, renamed))
    return mapping


def create_word_boundary_pattern(var_name):
    """
    Create a regex pattern that matches the variable name with word boundaries.
    Handles special GLSL cases like array access, member access, etc.
    """
    # Escape special regex characters
    escaped = re.escape(var_name)
    
    # Pattern ensures we match whole identifiers:
    # - Not preceded by alphanumeric, underscore, or dot
    # - Not followed by alphanumeric or underscore
    # This prevents matching parts of longer identifiers
    pattern = r'(?<![a-zA-Z0-9_\.])' + escaped + r'(?![a-zA-Z0-9_])'
    
    return pattern


def rename_variables(shader_code, mapping):
    """
    Rename variables in shader code according to mapping.
    Processes mappings from longest to shortest to avoid partial replacements.
    """
    # Sort by original variable length (descending) to handle longer names first
    sorted_mapping = sorted(mapping, key=lambda x: len(x[0]), reverse=True)
    
    result = shader_code
    replacements_made = {}
    
    for original, renamed in sorted_mapping:
        pattern = create_word_boundary_pattern(original)
        
        # Count matches before replacement
        matches = re.findall(pattern, result)
        if matches:
            result = re.sub(pattern, renamed, result)
            replacements_made[original] = len(matches)
    
    return result, replacements_made


def main():
    parser = argparse.ArgumentParser(
        description='Rename variables in GLSL shader file using CSV mapping'
    )
    parser.add_argument(
        'shader_file',
        type=Path,
        help='Path to the GLSL shader file to process'
    )
    parser.add_argument(
        '--mapping',
        type=Path,
        default='variable_mapping.csv',
        help='Path to the CSV mapping file (default: variable_mapping.csv)'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: <input>_renamed.glsl)'
    )
    parser.add_argument(
        '--stats',
        action='store_true',
        help='Print replacement statistics'
    )
    
    args = parser.parse_args()
    
    # Validate input file
    if not args.shader_file.exists():
        print(f"Error: Shader file '{args.shader_file}' not found")
        return 1
    
    # Set default output path if not specified
    if args.output is None:
        output_path = args.shader_file.parent / f"{args.shader_file.stem}_renamed{args.shader_file.suffix}"
    else:
        output_path = args.output
    
    # Validate mapping file
    if not args.mapping.exists():
        print(f"Error: Mapping file '{args.mapping}' not found")
        return 1
    
    print(f"Loading mapping from: {args.mapping}")
    mapping = load_mapping(args.mapping)
    print(f"Loaded {len(mapping)} variable mappings")
    
    print(f"Reading shader: {args.shader_file}")
    with open(args.shader_file, 'r', encoding='utf-8') as f:
        shader_code = f.read()
    
    print("Performing variable renaming...")
    renamed_code, stats = rename_variables(shader_code, mapping)
    
    print(f"Writing output to: {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(renamed_code)
    
    print(f"\n✓ Successfully renamed {len(stats)} unique variables")
    print(f"✓ Total replacements: {sum(stats.values())}")
    
    if args.stats:
        print("\n=== Replacement Statistics ===")
        # Sort by replacement count
        sorted_stats = sorted(stats.items(), key=lambda x: x[1], reverse=True)
        for var, count in sorted_stats[:20]:  # Show top 20
            print(f"  {var:30s} → {count:4d} replacements")
        if len(sorted_stats) > 20:
            print(f"  ... and {len(sorted_stats) - 20} more")
    
    return 0


if __name__ == '__main__':
    exit(main())
