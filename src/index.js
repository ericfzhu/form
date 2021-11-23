const { Client, Intents, Permissions } = require("discord.js");
// @ts-ignore
// const { clientId, guildId, token } = require('dotenv').config();
const { token } = require("./config.json");
const axios = require("axios").default;

const client = new Client({ intents: [Intents.FLAGS.GUILDS] });
const fs = require("fs");
const readline = require("readline");
const { google } = require("googleapis");
const { GoogleAuth } = require("google-auth-library");
const moment = require("moment");

client.once("ready", async () => {
  if (!client.application?.owner) await client.application?.fetch();

  const command = await client.guilds.cache
    .get("860941635047522374")
    ?.commands.fetch("895574855666245672");

  const permissions = [
    {
      id: "895602909390209034",
      type: "ROLE",
      permission: true,
    },
  ];

  await command.permissions.set({ permissions });
  console.log("Ready!");
});

client.on("interactionCreate", async (interaction) => {
  if (!interaction.isCommand()) return;

  const { commandName } = interaction;

  if (commandName === "form") {
    let string = interaction.options.getString("input");
    let date = moment().format("L");
    date.replace("/", "-");
    string = date + " " + string;

    console.log(string);
    // Load client secrets from a local file.
    // const auth = fs.readFile('credentials.json', (err, content) => {
    //     if (err) return console.log('Error loading client secret file:', err);
    //     // Authorize a client with credentials, then call the Google Apps Script API.
    //     return authorize(JSON.parse(content));
    // });

    // Acquire an auth client, and bind it to all future calls
    // const authClient = await auth.getClient();
    // google.options({auth: authClient});

    // const link = runAppsScript(auth, '1GN47fE8lUdv3ItcKIr6sAlb1hsftxVkO', string)
    // await interaction.reply(link);
  }
});

client.login(token);
