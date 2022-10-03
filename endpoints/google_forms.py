# Creates an Arc Attendance Form on Google
import os
from datetime import datetime
from typing import Optional

from dotenv import load_dotenv
from pydrive2.auth import GoogleAuth
from pydrive2.drive import GoogleDrive

gauth = GoogleAuth()
gauth.LocalWebserverAuth()
drive = GoogleDrive(gauth)

load_dotenv()
TEAM_DRIVE_ID = os.getenv('TEAM_DRIVE_ID')
PARENT_FOLDER_ID = os.getenv('PARENT_FOLDER_ID')
FORM_ID_ONLINE = os.getenv('FORM_ID_ONLINE')
FORM_ID_OFFLINE = os.getenv('FORM_ID_OFFLINE')


def post(name: str, date: Optional[datetime], choice: int):
    FORM_ID = FORM_ID_ONLINE if choice == 1 else FORM_ID_OFFLINE
    folder = drive.CreateFile({
        'title': f'{date} {name}',
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [{
            'kind': 'drive#fileLink',
            'id': PARENT_FOLDER_ID,
            'teamDriveId': TEAM_DRIVE_ID
        }]
    })
    folder.Upload(param={'supportsAllDrives': True})

    form = drive.auth.service.files().copy(
        fileId=FORM_ID,
        body={
            'parents': [{
                'kind': 'drive#fileLink',
                'id': folder['id'],
            }],
            'title': 'Arc Online Event Attendance List',
        }
    ).execute()

    return f'https://docs.google.com/forms/d/{form["id"]}/viewform'
