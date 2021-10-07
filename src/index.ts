const { Client, Intents, Permissions } = require('discord.js')
// @ts-ignore
// const { clientId, guildId, token } = require('dotenv').config();
const { token } = require('./config.json');

const client = new Client({ intents: [Intents.FLAGS.GUILDS] })

client.once('ready', () => {
    console.log('Ready!')
})

client.on('interactionCreate', async interaction => {
    if (!interaction.isCommand()) return;

    if (!client.application?.owner) await client.application?.fetch();

    const command = await client.guilds.cache.get('123456789012345678')?.commands.fetch('876543210987654321');

    const permissions = [
        {
            id: '201930117944049664',
            type: 'ROLE',
            permission: true,
        },
    ];

    await command.permissions.set({ permissions });


    const { commandName } = interaction;

    if (commandName === 'form') {
        await interaction.reply('Pong!');
    }
});

client.login(token)
