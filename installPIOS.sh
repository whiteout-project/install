## run with sudo ##
echo "Starting the wosbot installation script"
sudo apt update && sudo apt upgrade -y
sudo apt install -y python-is-python3 python3-full wget
wget https://raw.githubusercontent.com/whiteout-project/bot/main/main.py
wget https://raw.githubusercontent.com/whiteout-project/install/main/install.py
sudo python3 -m venv venv
source ./venv/bin/activate
sudo python3 install.py
sudo rm install.py
sudo python3 main.py --autoupdate
