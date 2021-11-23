from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive
import sys
import dotenv
import os

dotenv.load_dotenv()
team_drive_id = os.getenv('TEAM_DRIVE_ID')
parent_folder_id = os.getenv('PARENT_FOLDER_ID')
form_id = os.getenv('FORM_ID')


gauth = GoogleAuth()
gauth.LocalWebserverAuth()
drive = GoogleDrive(gauth)

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

print(f'https://docs.google.com/forms/d/{form["id"]}')
