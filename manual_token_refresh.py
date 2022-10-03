import os
from pydrive2.auth import GoogleAuth

os.remove("credentials.json")

gauth = GoogleAuth()
gauth.CommandLineAuth()
