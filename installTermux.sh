#!/data/data/com.termux/files/usr/bin/bash

set -e  # stop if any command fails

# Ensure proper environment paths (fixes fresh installs)
export PATH=$PREFIX/bin:$PATH

# Initial update & install essential packages
yes | pkg update
yes | pkg upgrade
yes | pkg install proot git termux-tools

# Confirm installation of required tools
for cmd in git wget proot; do
  if ! command -v $cmd > /dev/null 2>&1; then
    echo "❌ $cmd not installed properly. Exiting."
    exit 1
  fi
done

# Clone and run Ubuntu installer
cd ~
rm -rf ubuntu-in-termux
git clone https://github.com/MFDGaming/ubuntu-in-termux.git
cd ubuntu-in-termux
chmod +x ubuntu.sh
./ubuntu.sh -y

# Write Ubuntu setup script
cat > ubuntu-fs/root/ubuntu_setup.sh << 'EOF'
#!/bin/bash

set -e

apt-get update && apt-get upgrade -y
apt-get install -y curl nano python3 python3-venv python3-pip

mkdir -p ~/wosbot && cd ~/wosbot
curl -o install.py https://raw.githubusercontent.com/whiteout-project/install/main/install.py

python3 -m venv venv
source venv/bin/activate

python install.py -y

if [ -f "main.py" ]; then
  python main.py
else
  echo "⚠️ main.py not found. Please check install.py output."
fi

nano bot_token.txt
EOF

chmod +x ubuntu-fs/root/ubuntu_setup.sh

echo ""
echo "✅ Ubuntu installed successfully!"
echo "➡️ Next: run './startubuntu.sh'"
echo "➡️ Inside Ubuntu, run: 'bash ubuntu_setup.sh'"
