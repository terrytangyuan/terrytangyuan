#!/usr/bin/env python3
"""
Scrape Substack follower count from profile page.
Falls back to environment variable SUBSTACK_FOLLOWERS if scraping fails.
"""
import requests
import os
import sys
import re
from decimal import Decimal, getcontext, ROUND_CEILING
from bs4 import BeautifulSoup
from validate_svg import validate_svg


def human_format(num):
    """Format number to human-readable format (e.g., 1200 -> "1.2k")."""
    getcontext().prec = 1
    getcontext().rounding = ROUND_CEILING
    _num = Decimal(num)
    num = float(f"{_num:.3g}")
    magnitude = 0
    while abs(num) >= 1000:
        magnitude += 1
        num /= 1000.0
    num = int(num * 10) / 10
    return f"{f'{num:f}'.rstrip('0').rstrip('.')}{['', 'k', 'M', 'B', 'T'][magnitude]}"


def scrape_substack_followers(username):
    """
    Attempt to scrape follower count from Substack profile.
    
    Tries multiple approaches:
    1. Direct profile page scraping with BeautifulSoup
    2. Public API endpoints (if available)
    
    Args:
        username: Substack username (e.g., 'terrytangyuan')
    
    Returns:
        int: Follower count, or None if scraping fails
    """
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
    }
    
    # Approach 1: Try the profile page
    try:
        url = f"https://substack.com/@{username}"
        print(f"Fetching Substack profile: {url}", file=sys.stderr)
        response = requests.get(url, headers=headers, timeout=15)
        
        if response.status_code == 200:
            html = response.text
            soup = BeautifulSoup(html, 'html.parser')
            
            # Look for follower count patterns in the HTML
            # Substack may use different patterns: subscribers, followers
            
            # Try to find in text content
            text_patterns = [
                # Match patterns like: "1,200 subscribers"
                r'(\d+(?:,\d+)*)\s+subscribers?',
                # Match patterns like: "1,200 followers"  
                r'(\d+(?:,\d+)*)\s+followers?',
            ]
            
            page_text = soup.get_text()
            for pattern in text_patterns:
                match = re.search(pattern, page_text, re.IGNORECASE)
                if match:
                    count_str = match.group(1).replace(',', '')
                    count = int(count_str)
                    print(f"Found follower count using text pattern: {pattern} = {count}", file=sys.stderr)
                    return count
            
            # Try to find in HTML attributes and structure
            html_patterns = [
                # Match patterns in data attributes
                (r'data-testid="subscriber-count"[^>]*>\s*(\d+(?:,\d+)*)', 1),
                # Match patterns in class names
                (r'subscriber(?:-|_)?count["\']?\s*[>:]\s*(\d+(?:,\d+)*)', 1),
                # Match patterns in JSON-LD or script tags
                (r'"subscriberCount"\s*:\s*(\d+)', 1),
                (r'"num_email_subscribers"\s*:\s*(\d+)', 1),
            ]
            
            for pattern, group_num in html_patterns:
                match = re.search(pattern, html, re.IGNORECASE)
                if match:
                    count_str = match.group(group_num).replace(',', '')
                    count = int(count_str)
                    print(f"Found follower count using HTML pattern: {pattern} = {count}", file=sys.stderr)
                    return count
            
            print("Could not find follower count in page content", file=sys.stderr)
            # Save page title for debugging
            title = soup.find('title')
            if title:
                print(f"Page title: {title.string}", file=sys.stderr)
        else:
            print(f"Failed to fetch Substack profile: HTTP {response.status_code}", file=sys.stderr)
            
    except Exception as e:
        print(f"Error scraping Substack profile page: {e}", file=sys.stderr)
    
    # Approach 2: Try public API endpoints (if they exist)
    try:
        # Some Substack profiles may have public API endpoints
        api_url = f"https://substack.com/api/v1/profile/{username}"
        print(f"Trying Substack API: {api_url}", file=sys.stderr)
        response = requests.get(api_url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            # Look for subscriber/follower count in various possible fields
            possible_fields = ['subscribers', 'subscriber_count', 'followers', 'follower_count', 
                             'num_subscribers', 'num_followers', 'subscriberCount', 'followerCount',
                             'num_email_subscribers']
            
            for field in possible_fields:
                if field in data:
                    count = int(data[field])
                    print(f"Found follower count in API field: {field} = {count}", file=sys.stderr)
                    return count
            
            print(f"API returned data but no subscriber count found. Fields: {list(data.keys())}", file=sys.stderr)
    except Exception as e:
        print(f"Error trying Substack API: {e}", file=sys.stderr)
    
    return None


def main():
    username = "terrytangyuan"
    
    # Try to scrape the follower count
    followers_count = scrape_substack_followers(username)
    
    # If scraping failed, check for environment variable
    if followers_count is None:
        env_value = os.environ.get("SUBSTACK_FOLLOWERS")
        if env_value:
            try:
                followers_count = int(env_value)
                print(f"Using SUBSTACK_FOLLOWERS from environment: {followers_count}", file=sys.stderr)
            except ValueError:
                print(f"Invalid SUBSTACK_FOLLOWERS value: {env_value}", file=sys.stderr)
        
        # If still no value, use default
        if followers_count is None:
            followers_count = 1200  # Default fallback
            print(f"Using default follower count: {followers_count}", file=sys.stderr)
    else:
        print(f"Successfully scraped Substack followers: {followers_count}", file=sys.stderr)
    
    # Format the count
    followers_formatted = human_format(followers_count)
    print(f"Formatted follower count: {followers_formatted}", file=sys.stderr)
    
    # Generate badge URL
    image_url = (
        f"https://img.shields.io/badge/Substack-{followers_formatted}-_.svg?style=social&logo=substack"
    )
    
    # Download the badge
    try:
        response = requests.get(image_url, timeout=10)
        response.raise_for_status()
        img_data = response.content
    except Exception as e:
        print(f"Error downloading badge: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Ensure the imgs directory exists
    svg_dir = "imgs"
    os.makedirs(svg_dir, exist_ok=True)
    
    svg_file = os.path.join(svg_dir, "substack.svg")
    with open(svg_file, "wb") as handler:
        handler.write(img_data)
    
    print(f"Badge saved to {svg_file}", file=sys.stderr)
    
    # Validate the downloaded SVG
    print(f"\nValidating downloaded SVG file: {svg_file}")
    is_valid, message = validate_svg(svg_file)
    if not is_valid:
        print(f"✗ Validation failed: {message}")
        sys.exit(1)
    else:
        print(f"✓ {message}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
