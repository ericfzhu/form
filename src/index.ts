import { Client, Intents } from 'discord.js';
import moment = require('moment');
import { spawn } from 'child_process';

const client = new Client({ intents: [Intents.FLAGS.GUILDS] });
require('dotenv').config();

const axios = require('axios').default;

client.once('ready', async () => {
  if (!client.application?.owner) await client.application?.fetch();
  // get(guildId)?.commands.fetch(commandId);
  const command = await client.guilds.cache
    .get(process.env.GUILD_ID)
    ?.commands.fetch('912871983488839720');

  const permissions = [
    // Feature testing role ID
    {
      id: '895602909390209034',
      type: 'ROLE',
      permission: true,
    },
    // PCSoc exec role ID
    {
      id: process.env.ROLE_ID,
      type: 'ROLE',
      permission: true,
    },
  ];

  await command.permissions.set({ permissions });
  console.log('Command permissions set');
});

client.on('interactionCreate', async (interaction) => {
  if (!interaction.isCommand()) return;

  const { commandName } = interaction;

  if (commandName === 'form') {
    const string = interaction.options.getString('input');
    let date = moment().format('L');
    date = date.replaceAll('/', '-');

    // let url = 'https://script.googleapis.com/v1/scripts/AKfycbw1TaLKmd24DnaY9aDVLr_XSvOtEOKORQLfmBHvDpNyvou4YNbZ5cxCBXttyNBYiQI:run?folderId';
    // axios({
    //   method: 'get',
    //   url: url,
    //   data: {
    //     folderId: '1hlCengkODUbKymUQHRvOk2cgSCMYrU-0',
    //     folderName: date + string,
    //   }
    // }).then(function (link) {
    //   console.log(link);
    // });

    await interaction.reply('Generating link...');
    let link;
    // Spawns a child process to run the python script
    const python = spawn('python', ['script.py', date, string]);

    // Collect response from script
    await python.stdout.on('data', (data) => {
      link = data.toString();
      console.log(link);
    });

    // Edit original message with script response after script closes
    await python.on('close', () => {
      interaction.editReply(String(link));
    });
  }
});

client.login(process.env.DISCORD_TOKEN);
