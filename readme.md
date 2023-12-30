# Automatically redeem steam keys

## Why

After purchasing the [Jingle Jam collection](https://jinglejam.tiltify.com/) again, recieving a ton of Steam keys, I found the **very first world problem** of having to redeem all the keys.

For this reason I created this script to automate the process. And I now want to share it with you.

## Requirements

As it is written in PowerShell, Windows is kind of a requirement.
Also Google Chrome is used in this instance, if you run into a problem with chromedriver.exe, try to install the latest version of Chrome, if that doesn't help you can create an issue and I'll update the package.

Because of a limitations in Steam, where the maximum number of keys to redeem per hour is 47, and because this might change in the future, the script will attempt to redeem codes until it reaches an error about maximum number of keys. After this it'll wait for 1 hour before continuing. If you stop the script, or turn the power off, you'll have to check the log to get the last failed key and make a new file (or edit the current file) by removing the previous keys and after that run the code again.

## Usage

- Save the unzipped file to your preferred location.
- Open Powershell and type: `cd "path/to/Invoke-RedeemSteamKeys/"`
- Type: `Import-Module ./Invoke-RedeemSteamKeys.psm1`
- Type `Invoke-RedeemSteamKeys`
- Follow the instructions
- Enjoy a good show!
