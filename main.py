import os
from datetime import datetime
from typing import Optional

import nextcord
from dotenv import load_dotenv
from nextcord import SlashOption
from nextcord.ext import commands, application_checks

from endpoints import bitly

load_dotenv()
DISCORD_BOT_TOKEN = os.environ['DISCORD_BOT_TOKEN']

bot = commands.Bot()


@bot.slash_command(description="Creates an Arc Attendance Form.", guild_ids=[860941635047522374])
@application_checks.has_role('Exec')
async def form(
        interaction: nextcord.Interaction,
        name: str = SlashOption(required=True, description='Name of the event.'),
        date: Optional[str] = SlashOption(
            required=False,
            description='Date of the event (YY-MM-DD).',
            default=datetime.today().strftime('%Y-%m-%d'))):

    await interaction.send(f'{date} {name}')


bot.run(DISCORD_BOT_TOKEN)
