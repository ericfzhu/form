import nextcord
from nextcord.ext import commands
from dotenv import load_dotenv
import os

load_dotenv()
DISCORD_BOT_TOKEN = os.environ['DISCORD_BOT_TOKEN']

bot = commands.Bot()


@bot.slash_command(description="Creates an Arc Attendance Form.")
async def form_builder(interaction: nextcord.Interaction):
    await interaction.send("test", ephemeral=True)


bot.run(DISCORD_BOT_TOKEN)
