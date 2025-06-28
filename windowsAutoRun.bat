@echo off
echo Hi! I'm Clippy 2.0 and I will help you install or run your Whiteout Survival Discord Bot.
echo If main.py is missing I will use install.py to download and install the needed files.
echo :
echo DO NOT TOUCH ANYTHING until you get asked for your bot token!
echo :
echo Not your first time here? Just press enter to skip all my talking ;)
timeout 15

:startUpCheck
IF EXIST main.py (
	goto :venvCheck
	) ELSE (
	goto :firstInstall
)

:firstInstall
py --version 3>NUL
if errorlevel 1 goto :errorNoPython
cls

IF EXIST install.py (
	py install.py
	cls
	echo Woohoo! First install step done, I will make a virtual enviroment now.
	echo Be patient, this takes a minute...
	py -m venv bot_venv
	cls
	echo The enviroment is created, I will continue with the initial startup.
	echo Ignore the scary text in blue you see later, it's all good, I promise!
	echo :
	echo Ready for the next step?
	timeout 10
	) ELSE (
	echo :
	echo I will download the latest install.py from GitHub...
	timeout 5
	curl -o install.py https://raw.githubusercontent.com/whiteout-project/install/main/install.py
	goto :firstInstall
)

:venvCheck
IF EXIST bot_venv\ (
	cls
	echo The bot is going to start now.
	echo Are you excited? I know I am!
	echo :
    bot_venv\Scripts\python.exe main.py --autoupdate
    echo.
    echo Bot stopped. Restarting...
    timeout 3
    goto :venvCheck
	) ELSE (
	py -m venv bot_venv
	echo :
	echo Woohoo, the environment is created. I will start the bot now!
	goto :venvCheck
)

:errorNoPython
	cls
	echo Oh no, it looks like you don't have python installed!
	echo Don't worry, we will get that resolved for you now.
	timeout 5
	winget install -e python3
	goto :firstInstall