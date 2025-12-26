#!/usr/bin/env python3
"""
Validate SVG files to ensure they are correct before committing.
This script checks if SVG files are well-formed and contain expected content.
"""
import sys
import os
import re
import xml.etree.ElementTree as ET


def validate_svg(file_path, check_numeric=True):
    """
    Validate an SVG file.
    
    Args:
        file_path: Path to the SVG file to validate
        check_numeric: Whether to check for numeric values in the SVG (default: True)
        
    Returns:
        tuple: (is_valid, error_message)
    """
    # Check if file exists
    if not os.path.exists(file_path):
        return False, f"File does not exist: {file_path}"
    
    # Check if file is not empty
    if os.path.getsize(file_path) == 0:
        return False, f"File is empty: {file_path}"
    
    # Check minimum file size (should be at least 100 bytes for a valid SVG)
    if os.path.getsize(file_path) < 100:
        return False, f"File is too small (< 100 bytes): {file_path}"
    
    # Read file content
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        return False, f"Error reading file {file_path}: {str(e)}"
    
    # Check if content looks like an error page (HTML)
    if '<html' in content.lower() or '<!doctype html' in content.lower():
        return False, f"File appears to be an HTML error page: {file_path}"
    
    # Check if content contains svg tag
    if '<svg' not in content.lower():
        return False, f"File does not contain SVG tag: {file_path}"
    
    # Try to parse as XML
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
    except ET.ParseError as e:
        return False, f"Invalid XML in {file_path}: {str(e)}"
    except Exception as e:
        return False, f"Error parsing {file_path}: {str(e)}"
    
    # Check if root element is svg (with namespace handling)
    if not (root.tag == 'svg' or root.tag.endswith('}svg')):
        return False, f"Root element is not 'svg': {file_path}"
    
    # Check if SVG has width and height attributes
    width = root.get('width')
    height = root.get('height')
    if not width or not height:
        return False, f"SVG missing width or height attributes: {file_path}"
    
    # Check for numeric values in the SVG content (except for cv badge)
    if check_numeric:
        # Look for numbers with optional decimal point and k/M/B/T suffix
        # Pattern matches numbers like: 10, 123, 1.2k, 15.7k, 9.5k, 5k, etc.
        numeric_pattern = r'>\d+(?:\.\d+)?[kMBT]?</text>'
        if not re.search(numeric_pattern, content):
            return False, f"SVG does not contain expected numeric values: {file_path}"
    
    return True, "Valid SVG"


def validate_all_svgs(svg_dir='imgs'):
    """
    Validate all SVG files in the specified directory.
    
    Args:
        svg_dir: Directory containing SVG files
        
    Returns:
        bool: True if all SVGs are valid, False otherwise
    """
    if not os.path.exists(svg_dir):
        print(f"Error: Directory {svg_dir} does not exist")
        return False
    
    svg_files = [f for f in os.listdir(svg_dir) if f.endswith('.svg')]
    
    if not svg_files:
        print(f"Warning: No SVG files found in {svg_dir}")
        return True
    
    all_valid = True
    for svg_file in sorted(svg_files):
        file_path = os.path.join(svg_dir, svg_file)
        # CV badge doesn't have numeric values, skip numeric check for it
        check_numeric = (svg_file.lower() != 'cv.svg')
        is_valid, message = validate_svg(file_path, check_numeric=check_numeric)
        
        if is_valid:
            print(f"✓ {svg_file}: {message}")
        else:
            print(f"✗ {svg_file}: {message}")
            all_valid = False
    
    return all_valid


if __name__ == '__main__':
    # Allow passing directory as command line argument
    svg_dir = sys.argv[1] if len(sys.argv) > 1 else 'imgs'
    
    print(f"Validating SVG files in {svg_dir}...")
    success = validate_all_svgs(svg_dir)
    
    if success:
        print("\nAll SVG files are valid!")
        sys.exit(0)
    else:
        print("\nSome SVG files failed validation!")
        sys.exit(1)
