import subprocess
import sys

try:
    import colorama
    import requests
except ImportError:
    if "--debug" in sys.argv or "--verbose" in sys.argv: 
        subprocess.check_call([sys.executable, "-m", "pip", "install", "colorama", "requests"], timeout=1200)
    else:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "colorama", "requests"], timeout=1200, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        import colorama
        import requests
        
import shutil
import os

F = colorama.Fore
R = colorama.Style.RESET_ALL

def clean_up(path: str):
    try:
        if os.path.exists(path) and os.path.isfile(path):
            os.remove(path)
    except Exception as _:
        print(f"{F.RED}Failed to remove {path}. Please remove it manually.{R}")
        
colorama.init()

print(f"{F.YELLOW}Getting latest release info...{R}")

latest_release_url = "https://api.github.com/repos/whiteout-project/bot/releases/latest"

latest_release_resp = requests.get(latest_release_url)

if latest_release_resp.status_code == 200:
    latest_release_data = latest_release_resp.json()
    latest_release_tag = latest_release_data["tag_name"]
    
    print(f"{F.GREEN}Latest version: {latest_release_tag}{R}")
    print(f"{F.YELLOW}Downloading latest release...{R}")
    
    download_url =  latest_release_data["zipball_url"]
    
    download_resp = requests.get(download_url)
    
    with open("package.zip", "wb") as f:
        f.write(download_resp.content)
        
    shutil.unpack_archive("package.zip", "package")
    clean_up("package.zip")
    
    path_name = os.listdir("package")[0]
    
    for item in os.listdir(f"package/{path_name}"):
        src = os.path.join(f"package/{path_name}", item)
        dst = os.path.join(".", item)
        
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dst)
            
    try:
        shutil.rmtree("package")
    except Exception as _:
        print(f"{F.RED}Failed to remove \"package\" directory. Please remove it manually.{R}")
        
    print(f"{F.GREEN}Download complete!{R}")
    print(f"{F.YELLOW}Cleaning up...{R}")
    
    files_to_remove = ["requirements.txt", ".gitignore", "LICENSE", "README.md", "install.py"]
    
    for file_name in files_to_remove:
        clean_up(file_name)
        
    print(f"{F.GREEN}Cleanup complete!{R}")
    print(f"{F.GREEN}Installation complete! Run your both with \"python3 main.py\"!{R}")
else:
    print(f"{F.RED}Failed to get latest release info: {latest_release_resp.status_code}{R}")
    print(f"{F.RED}Please check your internet connection and try again.{R}")