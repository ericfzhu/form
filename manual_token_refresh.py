import os
from pydrive2.auth import GoogleAuth

# Remove existing credentials if it exists
if os.path.exists("credentials.json"):
    os.remove("credentials.json")

# Reauth with Google
gauth = GoogleAuth()
gauth.LocalWebserverAuth()
