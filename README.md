<p align="center">
    <img src="assets/icon.png" alt="icon" width="125px" />
</p>
<h1 align="center">
    Discord Forms
</h1>

<p align="center">
    Google Forms simplified for Discord
</p>

## Overview
Discord Forms enables users to create and link Google Forms on Discord using Slash Commands. Due to the nature of Google's OAuth timeout, this bot is currently in the proof of concept stage.

## Installation
Install the necessary dependencies
```bash
yarn install
```
Rename `.env.template` to `.env` and fill the environment variables:

- `TEAM_DRIVE_ID`: ID of the root folder of your shared Google Teams directory (`drive.google.com/drive/u/0/folders/xxxxxxxxxx`)
- `PARENT_FOLDER_ID`: ID of the parent folder that holds all the event forms
- `FORM_ID`: ID of the Google form that you want to copy
- `BITLY_TOKEN`: You can create your own Bitly auth token [here](https://dev.bitly.com/docs/getting-started/authentication/)
- `CLIENT_ID`: ID of your Discord bot (You can find your bot ID by enabling developer tools in Discord, right-clicking the bot and selecting `Copy ID`)
- `GUILD_ID`: ID of the Discord server to deploy the command to (You can find your server ID by right-clicking your server and selecting `Copy ID`)
- `ROLE_ID`: Role that's authorized to use the command to generate forms (usually Admin or Exec)
- `DISCORD_TOKEN`: Token of your Discord bot

## Running the bot
Run `deploy-commands.ts` twice
```bash
cd .\src\
node deploy-commands.ts
node deploy-commands.ts
```
Run `index.ts` to start the Discord bot
```bash
node index.ts
```
