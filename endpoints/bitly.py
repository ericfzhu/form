# Shortens a given link via Bitly
import json
import os
import validators
import warnings

import requests
from dotenv import load_dotenv

load_dotenv()

BITLY_TOKEN = os.environ["BITLY_TOKEN"]


def post(url):
    """
    Shortens a given URL

    :param url: URL being shortened

    :return: Shortened URL, or issues warning if invalid URL
    """
    if not validators.url(url):
        warnings.warn("Not a valid url")
        return "Invalid URL was provided"

    endpoint = "https://api-ssl.bitly.com/v4/shorten"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {BITLY_TOKEN}",
    }
    data = json.dumps(
        {"long_url": url, "domain": "bit.ly", "group_guid": "Blbo2svkX02"}
    )
    result = requests.request("POST", endpoint, headers=headers, data=data)
    data = result.json()

    return data["link"]
