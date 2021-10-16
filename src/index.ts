import {drive} from "googleapis/build/src/apis/drive";
import {oauth2_v2} from "googleapis";
import Oauth2 = oauth2_v2.Oauth2;
import moment = require("moment");

const { Client, Intents, Permissions } = require('discord.js')
// @ts-ignore
// const { clientId, guildId, token } = require('dotenv').config();
const { token } = require('./config.json');
const axios = require('axios').default;

const client = new Client({ intents: [Intents.FLAGS.GUILDS] })
const fs = require('fs');
const readline = require('readline');
const {google} = require('googleapis');
const { GoogleAuth } = require('google-auth-library');

// If modifying these scopes, delete token.json.
const SCOPES = ['https://www.googleapis.com/auth/script.projects',
    'https://www.googleapis.com/auth/forms',
    'https://www.googleapis.com/auth/drive'];
// The file token.json stores the user's access and refresh tokens, and is
// created automatically when the authorization flow completes for the first
// time.
const TOKEN_PATH = 'token.json';

// Load client secrets from a local file.
fs.readFile('credentials.json', (err, content) => {
    if (err) return console.log('Error loading client secret file:', err);
    // Authorize a client with credentials, then call the Google Apps Script API.
    authorize(JSON.parse(content));
});

/**
 * Create an OAuth2 client with the given credentials, and then execute the
 * given callback function.
 * @param {Object} credentials The authorization client credentials.
 */
function authorize(credentials) {
    const {client_secret, client_id, redirect_uris} = credentials.installed;
    const oAuth2Client = new google.auth.OAuth2(
        client_id, client_secret, redirect_uris[0]);

    // Check if we have previously stored a token.
    fs.readFile(TOKEN_PATH, (err, token) => {
        if (err) return getAccessToken(oAuth2Client);
        oAuth2Client.setCredentials(JSON.parse(token));
        return (oAuth2Client);
    });
}

/**
 * Get and store new token after prompting for user authorization, and then
 * execute the given callback with the authorized OAuth2 client.
 * @param {google.auth.OAuth2} oAuth2Client The OAuth2 client to get token for.
 */
function getAccessToken(oAuth2Client) {
    const authUrl = oAuth2Client.generateAuthUrl({
        access_type: 'offline',
        scope: SCOPES,
    });
    console.log('Authorize this app by visiting this url:', authUrl);
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });
    rl.question('Enter the code from that page here: ', (code) => {
        rl.close();
        oAuth2Client.getToken(code, (err, token) => {
            if (err) return console.error('Error retrieving access token', err);
            oAuth2Client.setCredentials(token);
            // Store the token to disk for later program executions
            fs.writeFile(TOKEN_PATH, JSON.stringify(token), (err) => {
                if (err) return console.error(err);
                console.log('Token stored to', TOKEN_PATH);
            });
            return (oAuth2Client);
        });
    });
}

/**
 * Creates a new script project, upload a file, and log the script's URL.
 * @param {google.auth.OAuth2} auth An authorized OAuth2 client.
 * @param folderId
 * @param folderName
 */
function runAppsScript(auth, folderId, folderName) {
    const script = google.script({version: 'v1', auth: auth});
    const res = script.scripts.run({
        scriptId: '1c3dQkYrnK0W_a20gj9cdYvvN3n-2ifGowcNSMqK88aXeUh10dKWrEtzQ',
        requestBody: {
            'function': 'doGet',
            'paremeters': [folderId, folderName]
        }
    });
    return (res.data);
}

client.once('ready', async () => {
    if (!client.application?.owner) await client.application?.fetch();

    const command = await client.guilds.cache.get('860941635047522374')?.commands.fetch('895574855666245672');

    const permissions = [
        {
            id: '895602909390209034',
            type: 'ROLE',
            permission: true,
        },
    ];

    await command.permissions.set({ permissions });
    console.log('Ready!')
})

client.on('interactionCreate', async interaction => {
    if (!interaction.isCommand()) return;

    const { commandName } = interaction;

    if (commandName === 'form') {
        let string = interaction.options.getString('input');
        let date = moment().format('L');
        date.replace("/", "-")
        string = date + " " + string

        console.log(string)
        // Load client secrets from a local file.
        const auth = fs.readFile('credentials.json', (err, content) => {
            if (err) return console.log('Error loading client secret file:', err);
            // Authorize a client with credentials, then call the Google Apps Script API.
            return authorize(JSON.parse(content));
        });

        // Acquire an auth client, and bind it to all future calls
        // const authClient = await auth.getClient();
        // google.options({auth: authClient});

        const link = runAppsScript(auth, '1GN47fE8lUdv3ItcKIr6sAlb1hsftxVkO', string)
        await interaction.reply(link);
    }
});

client.login(token)
