from atproto import Client
from decimal import *
import requests
import os
import sys
from validate_svg import validate_svg


def human_format(num):
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


# Make sure these environment variables are available in your Github repo secrets
handle = os.environ["BLUESKY_APP_HANDLE"]
app_password = os.environ["BLUESKY_APP_PASSWORD"]
client = Client()
client.login(handle, app_password)
data = client.get_profile(actor=handle)
followers_count = human_format(int(data.followers_count))
image_url = (
    "https://img.shields.io/badge/Bluesky-%s-_.svg?style=social&logo=bluesky"
    % followers_count
)
img_data = requests.get(image_url).content
svg_file = "imgs/bluesky.svg"
with open(svg_file, "wb") as handler:
    handler.write(img_data)

# Validate the downloaded SVG
print(f"\nValidating downloaded SVG file: {svg_file}")
is_valid, message = validate_svg(svg_file)
if not is_valid:
    print(f"✗ Validation failed: {message}")
    sys.exit(1)
else:
    print(f"✓ {message}")
