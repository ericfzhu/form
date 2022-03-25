<p align="center">
    <img src="assets/icon.png" alt="icon" width="125px" />
</p>
<h1 align="center">
    Discord Forms
</h1>

<p align="center">
    <a href="https://www.javascript.com/">
        <img src="https://img.shields.io/badge/-JavaScript-323330?logo=typescript&logoColor=F7DF1E&style=flat" alt="Typescript"/>
    </a>
    <a href="https://github.com/discordjs/discord.js">
        <img src="https://img.shields.io/badge/-Discord.js-5865F2?logo=discord&style=flat&logoColor=FFFFFF" alt="Notion.so">
    </a>
    <a href="https://prettier.io/">
        <img src="https://img.shields.io/badge/-Prettier-1A2B34?logo=prettier&style=flat" alt="Prettier.io">
    </a>  
</p>
<p align="center">
    Discord Forms is a Discord.js bot that allows you to create Google Forms in your Discord server.
</p>

## Getting Started
Clone this repo
```bash
git clone https://github.com/ericfzhu/discord-forms.git
```
Install the necessary dependencies
```bash
npm install
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

## Usage
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