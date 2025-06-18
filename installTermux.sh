apt-get update && apt-get upgrade -y
apt-get install -y wget proot git
cd ~
git clone https://github.com/MFDGaming/ubuntu-in-termux.git
cd ubuntu-in-termux
chmod +x ubuntu.sh
./ubuntu.sh -y
./startubuntu.sh
apt-get update && apt-get upgrade
apt install -y curl nano python3.12-full
mkdir wosbot && cd wosbot
curl -o install.py https://raw.githubusercontent.com/whiteout-project/install/main/install.py
python -m venv venv
python install.py -y
source ./venv/bin/activate
python main.py
nano bot_token.txt


