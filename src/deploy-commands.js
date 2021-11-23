const { SlashCommandBuilder } = require("@discordjs/builders");
const { REST } = require("@discordjs/rest");
const { Routes } = require("discord-api-types/v9");
// @ts-ignore
// const { clientId, guildId, token } = require('dotenv').config();
const { clientId, guildId, token } = require("./config.json");

const commands = [
  new SlashCommandBuilder()
    .setName("form")
    .setDescription("Creates a Google form.")
    .addStringOption((option) =>
      option
        .setName("input")
        .setDescription("The title of the form")
        .setRequired(true)
    )
    .setDefaultPermission(false),
].map((command) => command.toJSON());

const rest = new REST({ version: "9" }).setToken(token);

rest
  .put(Routes.applicationGuildCommands(clientId, guildId), { body: commands })
  .then(() => console.log("Successfully registered application commands."))
  .catch(console.error);

async function getfunction() {
  const guildCommands = await rest.get(
    Routes.applicationGuildCommands(clientId, guildId)
  );
  console.log(guildCommands);
}

getfunction();
