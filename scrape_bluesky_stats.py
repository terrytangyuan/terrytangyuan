from atproto import Client
from decimal import *
import requests

def human_format(num):
    # set decimal default options!
    getcontext().prec = 1
    getcontext().rounding = ROUND_DOWN

    _num = Decimal(num)
    num = float(f'{_num:.3g}')
    magnitude = 0
    while abs(num) >= 1000:
        magnitude += 1
        num /= 1000.0
    num = int(num * 10) / 10
    return f"{f'{num:f}'.rstrip('0').rstrip('.')}{['', 'k', 'M', 'B', 'T'][magnitude]}"

handle = 'terrytangyuan.xyz'
password = 'b5he-u6re-vyql-cd2h'
client = Client()
client.login(handle, password)
data = client.get_profile(actor=handle)
followers_count = human_format(int(data.followers_count))
image_url = 'https://img.shields.io/badge/Bluesky-%s-_.svg?style=social&logo=bluesky' % followers_count
img_data = requests.get(image_url).content
with open('imgs/bluesky.svg', 'wb') as handler:
    handler.write(img_data)
