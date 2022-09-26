# Creates an Arc Attendance Form on Google
import os

from dotenv import load_dotenv
from pydrive2.auth import GoogleAuth
from pydrive2.drive import GoogleDrive

gauth = GoogleAuth()
gauth.LocalWebserverAuth()
drive = GoogleDrive(gauth)

load_dotenv()
TEAM_DRIVE_ID = os.getenv('TEAM_DRIVE_ID')
PARENT_FOLDER_ID = os.getenv('PARENT_FOLDER_ID')
FORM_ID = os.getenv('FORM_ID')


def post(name, date):
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
