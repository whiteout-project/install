@echo off
echo Hi! I'm clipie 2.0 and I will help you install or run your whitoutsurvival discord bot
echo If main.py is missing I will use install.py to download and install the needed files
echo :
echo DO NOT TOUCH ANYTHING until you get asked for your bot token!
echo :
echo Not the first time, just press enter to skip all my talking ;)

timeout 10

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
	echo woohoo first install step done, I will make a virtual enviroment now
	echo be patient, this takes a minute
	py -m venv bot_venv
	cls
	echo The enviroment is created, I wil continue with the initial startup
	echo Ignore the scary text in blue you see later, it's all good I promise!
	echo :
	echo ready for the next step?
	timeout 10
	goto :startUpcheck
	) ELSE (
	echo :
	echo I will download the latest install.py from github
	timeout 5
	curl -o install.py https://raw.githubusercontent.com/whiteout-project/install/main/install.py
	goto :firstInstall
)

:venvCheck
IF EXIST bot_venv\ (
	cls
	echo The bot is going to start now
	echo Are you excited? I know I'm!
	echo :
    bot_venv\Scripts\python.exe main.py --autoupdate
	) ELSE (
	py -m venv bot_venv
	echo :
	echo Wooohoo enviroment is created, I will start the bot now!
	goto :venvCheck
)

:errorNoPython
	cls
	echo Oh no, it looks like you don't have python installed!
	echo let's get that resolved for you
	timeout 5
	winget install -e python3
	goto :firstInstall
