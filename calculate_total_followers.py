import re
import os
import sys


def parse_follower_count(svg_content, platform):
    """
    Parse follower count from SVG content.
    """
    # Try to find aria-label first - capture the last numeric value
    aria_match = re.search(r'aria-label="[^"]+?([0-9.]+[kKmM]?)"', svg_content)
    if aria_match:
        return aria_match.group(1)
    
    # For some badges, try to extract from text elements
    text_matches = re.findall(r'<text[^>]*>([0-9.]+[kKmM]?)</text>', svg_content)
    if text_matches:
        # Return the last text match as it's usually the count
        for match in reversed(text_matches):
            if re.match(r'^[0-9.]+[kKmM]?$', match):
                return match
    
    return None


def convert_to_number(count_str):
    """
    Convert follower count string (e.g., "9.9k", "752") to integer.
    """
    if not count_str:
        return 0
    
    count_str = count_str.strip().upper()
    multiplier = 1
    
    if count_str.endswith('K'):
        multiplier = 1000
        count_str = count_str[:-1]
    elif count_str.endswith('M'):
        multiplier = 1000000
        count_str = count_str[:-1]
    
    try:
        number = float(count_str) * multiplier
        return int(number)
    except ValueError:
        return 0


def human_format(num):
    """
    Format number to human-readable format (e.g., 52752 -> "52.8k").
    Uses standard rounding to one decimal place.
    """
    magnitude = 0
    while abs(num) >= 1000:
        magnitude += 1
        num /= 1000.0
    # Round to one decimal place
    num = round(num, 1)
    # Format and strip unnecessary zeros
    formatted = f"{num:.1f}".rstrip('0').rstrip('.')
    return f"{formatted}{['', 'k', 'M', 'B', 'T'][magnitude]}"


def main():
    platforms = {
        'twitter': 'imgs/twitter.svg',
        'linkedin': 'imgs/linkedin.svg',
        'bluesky': 'imgs/bluesky.svg',
        'github': 'imgs/github.svg',
        'mastodon': 'imgs/mastodon.svg',
        'substack': 'imgs/substack.svg'
    }
    
    total_followers = 0
    platform_counts = {}
    
    for platform, svg_path in platforms.items():
        if not os.path.exists(svg_path):
            print(f"Warning: {svg_path} not found, skipping {platform}", file=sys.stderr)
            continue
        
        with open(svg_path, 'r') as f:
            svg_content = f.read()
        
        count_str = parse_follower_count(svg_content, platform)
        count_num = convert_to_number(count_str)
        
        platform_counts[platform] = {'str': count_str, 'num': count_num}
        total_followers += count_num
        
        print(f"{platform.capitalize()}: {count_str} ({count_num})", file=sys.stderr)
    
    formatted_total = human_format(total_followers)
    print(f"Total Followers: {formatted_total} ({total_followers})", file=sys.stderr)
    
    # Output just the formatted total for use in other scripts
    print(formatted_total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
