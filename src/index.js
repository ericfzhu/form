const { Client, Intents, Permissions } = require("discord.js");
// @ts-ignore
// const { clientId, guildId, token } = require('dotenv').config();
const { token } = require("./config.json");

const client = new Client({ intents: [Intents.FLAGS.GUILDS] });
const moment = require("moment");
const express = require('express');
const { spawn } = require('child_process');
const wait = require('util').promisify(setTimeout);

client.once("ready", async () => {
  if (!client.application?.owner) await client.application?.fetch();

  const command = await client.guilds.cache
    .get("157263595128881153")
    ?.commands.fetch("912871983488839720");

  const permissions = [
    {
      id: "895602909390209034",
      type: "ROLE",
      permission: true,
    },
    {
      id: "201930117944049664",
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
    date = date.replaceAll("/", "-");

    await interaction.reply('Generating link...');
    let link;
    // spawn new child process to call the python script
    const python = spawn('python', ['script.py', date, string]);
    // collect data from script
    await python.stdout.on('data', function (data) {
      link = data.toString();
      console.log(link);
    });
    await wait(8000);
    await interaction.editReply(String(link));
  }
});

client.login(token);
