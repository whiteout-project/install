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

# Configuration for multiple update sources
UPDATE_SOURCES = [
    {
        "name": "GitHub",
        "api_url": "https://api.github.com/repos/whiteout-project/bot/releases/latest",
        "primary": True
    },
    {
        "name": "GitLab",
        "api_url": "https://gitlab.whiteout-bot.com/api/v4/projects/1/releases",
        "project_id": 1,
        "primary": False
    }
]

def get_latest_release_info():
    """Try to get latest release info from multiple sources."""
    for source in UPDATE_SOURCES:
        try:
            print(f"{F.YELLOW}Checking for updates from {source['name']}...{R}")
            
            if source['name'] == "GitHub":
                response = requests.get(source['api_url'], timeout=30)
                if response.status_code == 200:
                    data = response.json()
                    # Use GitHub's automatic source archive
                    repo_name = source['api_url'].split('/repos/')[1].split('/releases')[0]
                    download_url = f"https://github.com/{repo_name}/archive/refs/tags/{data['tag_name']}.zip"
                    return {
                        "tag_name": data["tag_name"],
                        "body": data["body"],
                        "download_url": download_url,
                        "zipball_url": data["zipball_url"],  # Keep for compatibility
                        "source": source['name']
                    }
                    
            elif source['name'] == "GitLab":
                response = requests.get(source['api_url'], timeout=30)
                if response.status_code == 200:
                    releases = response.json()
                    if releases:
                        latest = releases[0]  # GitLab returns array, first is latest
                        tag_name = latest['tag_name']
                        # Use GitLab's source archive
                        download_url = f"https://gitlab.whiteout-bot.com/whiteout-project/bot/-/archive/{tag_name}/bot-{tag_name}.zip"
                        return {
                            "tag_name": tag_name,
                            "body": latest.get("description", "No release notes available"),
                            "download_url": download_url,
                            "zipball_url": download_url,  # For compatibility
                            "source": source['name']
                        }
            
        except requests.exceptions.RequestException as e:
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 404:
                    print(f"{F.RED}{source['name']} repository not found or unavailable{R}")
                elif e.response.status_code in [403, 429]:
                    print(f"{F.RED}{source['name']} access limited (rate limit or access denied){R}")
                else:
                    print(f"{F.RED}{source['name']} returned HTTP {e.response.status_code}{R}")
            else:
                print(f"{F.RED}{source['name']} connection failed{R}")
            continue
        except Exception as e:
            print(f"{F.RED}Failed to check {source['name']}: {e}{R}")
            continue
        
    print(f"{F.RED}All update sources failed{R}")
    return None

def clean_up(path: str):
    try:
        if os.path.exists(path) and os.path.isfile(path):
            os.remove(path)
    except Exception as _:
        print(f"{F.RED}Failed to remove {path}. Please remove it manually.{R}")
        
colorama.init()

print(f"{F.YELLOW}Getting latest release info...{R}")

latest_release_data = get_latest_release_info()

if latest_release_data:
    latest_release_tag = latest_release_data["tag_name"]
    source_name = latest_release_data["source"]
    
    print(f"{F.GREEN}Latest version: {latest_release_tag} (from {source_name}){R}")
    print(f"{F.YELLOW}Downloading latest release...{R}")
    
    download_url = latest_release_data["download_url"]
    
    try:
        download_resp = requests.get(download_url, timeout=600)
        
        if download_resp.status_code == 200:
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
                
            print(f"{F.GREEN}Download complete from {source_name}!{R}")
            
            # Create version file to prevent immediate update check
            print(f"{F.YELLOW}Creating version file...{R}")
            with open("version", "w") as f:
                f.write(latest_release_tag)
            
            print(f"{F.YELLOW}Cleaning up...{R}")
            
            files_to_remove = [".gitignore", "LICENSE", "README.md", "install.py", ".gitlab-ci.yml"]
            
            for file_name in files_to_remove:
                clean_up(file_name)
                
            print(f"{F.GREEN}Cleanup complete!{R}")
            
            # Use platform-appropriate Python command
            if sys.platform == "win32":
                python_cmd = "python"
            else:
                python_cmd = "python3"
            
            print(f"{F.GREEN}Installation complete! Run your bot with \"{python_cmd} main.py\"!{R}")
        else:
            print(f"{F.RED}Failed to download from {source_name}: HTTP {download_resp.status_code}{R}")
            print(f"{F.RED}Please check your internet connection and try again.{R}")
    except Exception as e:
        print(f"{F.RED}Error downloading release: {e}{R}")
        print(f"{F.RED}Please check your internet connection and try again.{R}")
else:
    print(f"{F.RED}Failed to get latest release info from any source.{R}")
    print(f"{F.RED}Please check your internet connection and try again.{R}")