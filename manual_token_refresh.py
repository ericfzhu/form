import os
from pydrive2.auth import GoogleAuth

# Remove existing credentials if it exists
if os.path.exists("credentials.json"):
    os.remove("credentials.json")

# Reauthenticate with Google
gauth = GoogleAuth()
print(gauth.LocalWebserverAuth())
