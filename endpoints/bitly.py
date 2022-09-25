# Shortens a given link via Bitly
import os

import requests
from dotenv import load_dotenv

load_dotenv()

BITLY_TOKEN = os.environ['BITLY_TOKEN']


def post(url):
    header = {'Content-Type': 'application/json',
              'Authorization': f'Bearer {BITLY_TOKEN}'}
    json = {'long_url': url}
    result = requests.post('https://api-ssl.bitly.com/v4/shorten', json=json, headers=header)
    data = result.json()

    return data['link']
