import os
from datetime import datetime
from typing import Optional

import nextcord
from dotenv import load_dotenv
from nextcord import SlashOption
from nextcord.ext import commands, application_checks

from endpoints import bitly, google_forms

load_dotenv()
DISCORD_BOT_TOKEN = os.environ["DISCORD_BOT_TOKEN"]

bot = commands.Bot()


@bot.slash_command(
    description="Creates an Arc Attendance Form",
    guild_ids=[860941635047522374, 157263595128881153],
)
@application_checks.has_role("Exec")
async def form(
    interaction: nextcord.Interaction,
    name: str = SlashOption(required=True, description="Name of the event"),
    choice: int = SlashOption(name="format", choices={"Online": 1, "Offline": 2}),
    date: str = SlashOption(
        required=False,
        description="Date of the event (YYYY-MM-DD, defaults to today)",
        default=datetime.today().strftime("%Y-%m-%d"),
    ),
):
    """
    Creates an Attendance Form

    :param interaction: The /form slash command
    :param str name: Name of the event
    :param int choice: Whether it's an online or offline event
    :param Optional[datetime] date: The date of the event in YYYY-MM-DD format, defaults to the current date if not
    provided

    :return: Shortened URL of the attendance form with Bitly
    """

    await interaction.response.defer()

    url = google_forms.post(name, choice, date)

    shortened_url = bitly.post(url)

    await interaction.send(f"{date} {name}: {shortened_url}")


bot.run(DISCORD_BOT_TOKEN)
