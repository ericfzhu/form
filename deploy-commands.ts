const { SlashCommandBuilder } = require('@discordjs/builders');
const { REST } = require('@discordjs/rest');
const { Routes } = require('discord-api-types/v9');
const { clientId, guildId, DISCORD_TOKEN } = require('dotenv').config();

const commands = [
    new SlashCommandBuilder().setName('form')
    .setDescription('Creates a Google form.')
        .addStringOption(option => option.setName('input')
        .setDescription('The input to echo back')
        .setRequired(true))
]
    .map(command => command.toJSON());

const rest = new REST({ version: '9' }).setToken(DISCORD_TOKEN);

rest.put(Routes.applicationGuildCommands(clientId, guildId), { body: commands })
    .then(() => console.log('Successfully registered application commands.'))
    .catch(console.error);