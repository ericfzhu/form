from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive
import sys
import dotenv
import os
import requests

dotenv.load_dotenv()
team_drive_id = os.getenv('TEAM_DRIVE_ID')
parent_folder_id = os.getenv('PARENT_FOLDER_ID')
form_id = os.getenv('FORM_ID')
bitly_token = os.getenv('BITLY_TOKEN')

gauth = GoogleAuth()
gauth.LocalWebserverAuth()
drive = GoogleDrive(gauth)

# Creates the child folder for the form
folder = drive.CreateFile({
    'title': f'{sys.argv[1]} {sys.argv[2]}',
    'mimeType': 'application/vnd.google-apps.folder',
    'parents': [{
        'kind': 'drive#fileLink',
        'id': parent_folder_id,
        'teamDriveId': team_drive_id,
    }]
})
folder.Upload(param={'supportsAllDrives': True})

# Saves the child folder ID as an environment variable
dotenv.set_key('.env', 'CHILD_FOLDER_ID', folder['id'])

# Copies the target form into the folder
form = drive.auth.service.files().copy(
    fileId=form_id,
    body={
        'parents': [{
            'kind': 'drive#fileLink',
            'id': folder['id'],
        }],
        'title': 'Arc Online Event Attendance List',
    }
).execute()
link = f'https://docs.google.com/forms/d/{form["id"]}/viewform?usp=sf_link'

# Convert link to bitly
header = {'Content-Type': 'application/json',
          'Authorization': f'Bearer {bitly_token}'}
json = {'long_url': link}
result = requests.post('https://api-ssl.bitly.com/v4/shorten', json=json, headers=header)
data = result.json()

if 'link' in data.keys():
    print(data['link'])
else:
    print(link)
