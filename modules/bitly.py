# Shortens a given link via Bitly
import json
import os
import validators
import warnings

import requests
from dotenv import load_dotenv

load_dotenv()

BITLY_TOKEN = os.environ["BITLY_TOKEN"]


def shorten_url(url):
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
    params = {"long_url": url}
    response = requests.request("POST", endpoint, headers=headers, json=params)
    if not response.ok:
        warnings.warn(f"Invalid response from Bitly {response.content}")
        return "Invalid response from Bitly"

    try:
        data = response.json()
    except json.JSONDecodeError:
        warnings.warn(f"Response from Bitly could not be decoded {response.content}")
        return "Response could not be decoded"

    return data["link"]
