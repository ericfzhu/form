const { Client, Intents, Permissions } = require('discord.js')
// @ts-ignore
// const { clientId, guildId, token } = require('dotenv').config();
const { token } = require('./config.json');

const client = new Client({ intents: [Intents.FLAGS.GUILDS] })

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
        await interaction.reply('Pong!');
    }
});

client.login(token)
