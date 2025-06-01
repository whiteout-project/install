# WOS Bot Install Script

An automatic install script for [whiteout-project/bot](https://github.com/whiteout-project/bot).

For full bot setup instructions, please visit our [Discord server](https://discord.gg/HFnNnQWnbS).

# 🚀 Installation

1.  **⬇️ Download the Installer:**
    *   Download the [install.py file](https://github.com/whiteout-project/install/blob/main/install.py)
    *   Place it in the directory where you want to run the bot

2.  **▶️ Start the Installer:**
    *   Open a terminal or command prompt **in the new directory you created where install.py is located**.
    *   Run `python install.py` to install the bot. This should automatically pull main.py and other files into the directory.

3.  **▶️ Start the Bot:**
    *   In your terminal or command prompt **in the same directory you created**, run `python main.py` to start the bot.
    *   It will check for updates and double-check dependencies, and prompt you if an update is needed.
    *   When prompted for a Discord bot token, enter your bot token, unless you already have one in bot_token.txt.
    *   The bot should now initialize and connect to Discord.

4.  **🔧 Run /settings in Discord:**
    *   Remember to run /settings for the bot in Discord to configure yourself as the admin.

> [!WARNING]
> Some container hosting platforms (such as KataBump) may run into **disk space issues** during installation, even if sufficient space appears to be available.  
>  
> This typically occurs because these platforms use **Alpine Linux**, which does not include the standard `glibc` C library. As a result, dependencies like [OpenCV](https://pypi.org/project/opencv-python-headless/) lack pre-built wheels for this environment, forcing Python to compile them from source. The build process consumes **several gigabytes of disk space**, often exceeding the container's limits and causing installation to fail.  
>  
> ✅ To avoid this, consider using a container base image that includes `glibc` (such as Debian or Ubuntu).
