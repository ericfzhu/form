const { Client, Intents } = require('discord.js')
const { token } = require('dotenv').config()


const client = new Client({ intents: [Intents.FLAGS.GUILDS] })

client.once('ready', () => {
    console.log('Ready!')
})

client.login(token)
