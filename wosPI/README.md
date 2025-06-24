# WOS Bot raspberry pi images

For full bot setup instructions, please visit our [Discord server](https://discord.gg/HFnNnQWnbS).

# 🚀 Installation

1.  **⬇️ Download the files:**
    *   Download and install the [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
    *   Download the RIGHT image for your pi version and install it with the Raspbeery Pi Imager
      
    *   Select your pi model
    *   ![image](https://github.com/user-attachments/assets/f4cbc405-c390-4d59-8341-b1437ec83f62)
    *   Select your pi image
    *   ![image](https://github.com/user-attachments/assets/7b87b488-b7e7-451a-ac85-8f3059b33ed1)
      
    *   You can setup custom information like username, password and wifi settings (if your pi supports wifi) if you don't do this the username/password will be wosland/wosland
    *   ![image](https://github.com/user-attachments/assets/fd7581ee-9e30-44ad-8e1c-36f52fa95b83)




2.  **▶️ Setup the bot:**
    *   Plug your pi in.
    *   Open a terminal or command prompt, if you didn't change anything in the last step of step 1 the type: 'ssh wosland -l wosland' if you did change something type: 'ssh YOURHOSTNAME -l YOURUSERNAME'
    *   After you got connected and logged in into your pi type: 'nano bot_token.txt' paste here your bot token (when using cmd right mouse click copies into the terminal) then ctrl + x and then y

3.  **▶️ Start the Bot:**
    *   Now you need to restart the bot do this by typing: 'sudo systemctl start wosbot'
    *   Check if the bot is running by typing: 'systemctl status wosbot'
    *   Now you can ivite the bot to your discord server if you haven't done that already

3.  **🔧 Run /settings in Discord:**
    *   Remember to run /settings for the bot in Discord to configure yourself as the admin.

For any questions or suggestions feel free to check out our discord

**Download links**
* Raspberry PI 2(B) ----- coming soon
* Raspberry PI 3(B) ----- coming soon
* Raspberry PI 4    ----- coming soon
* [Raspberry PI 5](https://drive.google.com/file/d/1FkO3QRyh7SWpVcrNBDPu6zfj_5Ziaimk/view?usp=sharing)
