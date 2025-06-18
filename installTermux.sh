#!/data/data/com.termux/files/usr/bin/bash

# Update Termux and install dependencies
apt-get update && apt-get upgrade
apt-get install wget proot git


# Clone Ubuntu installer
cd ~
git clone https://github.com/MFDGaming/ubuntu-in-termux.git
cd ubuntu-in-termux
chmod +x ubuntu.sh
./ubuntu.sh -y

# Write ubuntu_setup.sh into the Ubuntu root filesystem
cat > ubuntu-fs/root/ubuntu_setup.sh << 'EOF'
#!/bin/bash

apt-get update && apt-get upgrade -y
apt-get install -y curl nano python3 python3-venv python3-pip

mkdir ~/wosbot && cd ~/wosbot
curl -o install.py https://raw.githubusercontent.com/whiteout-project/install/main/install.py

python3 -m venv venv
source venv/bin/activate

python install.py -y

if [ -f "main.py" ]; then
    python main.py
else
    echo "⚠️ main.py not found. Please make sure it's downloaded by install.py."
fi

nano bot_token.txt
EOF

# Make the script executable
chmod +x ubuntu-fs/root/ubuntu_setup.sh

echo ""
echo "✅ Ubuntu installed!"
echo "➡️ To continue, run: ./startubuntu.sh"
echo "➡️ Then inside Ubuntu, run: bash ubuntu_setup.sh"

