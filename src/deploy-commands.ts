import { SlashCommandBuilder } from '@discordjs/builders';
import { REST } from '@discordjs/rest';
import { Routes } from 'discord-api-types/v9';

require('dotenv').config();

const commands = [
  new SlashCommandBuilder()
    .setName('form')
    .setDescription('Creates a Google form.')
    .addStringOption((option) => option
      .setName('input')
      .setDescription('The title of the form')
      .setRequired(true))
    .setDefaultPermission(false),
].map((command) => command.toJSON());

const rest = new REST({ version: '9' }).setToken(process.env.DISCORD_TOKEN);

rest
  .put(
    Routes.applicationGuildCommands(
      process.env.CLIENT_ID,
      process.env.GUILD_ID,
    ),
    { body: commands },
  )
  .then(() => console.log('Successfully registered application commands.'))
  .catch(console.error);

async function getfunction() {
  const guildCommands = await rest.get(
    Routes.applicationGuildCommands(
      process.env.CLIENT_ID,
      process.env.GUILD_ID,
    ),
  );
  console.log(guildCommands);
}

getfunction();
