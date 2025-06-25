## run with sudo ##
echo "Starting the wosbot installation script"
sudo apt update && sudo apt upgrade -y
sudo apt install -y python-is-python3 python3 python3-pip python3-venv wget
wget https://raw.githubusercontent.com/whiteout-project/bot/main/main.py
sudo python3 -m venv venv
source ./venv/bin/activate
python3 main.py --autoupdate
