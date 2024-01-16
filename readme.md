# Automatically redeem steam keys

## Why

After donating during Jingle Jam and receiving the [Jingle Jam collection](https://jinglejam.tiltify.com/), getting a ton of Steam keys, I found the **very first world problem** of having to redeem all the keys.

For this reason I created this script to automate the process. And I now want to share it with you.

## Requirements

Powershell Core (7 or above)

Google Chrome is required for Windows  
Firefox is required for Mac and Linux (These are not fully tested!)

Because of a limitations in Steam, where there is an maximum number of keys to redeem per hour, the script will attempt to redeem codes until it reaches an error about maximum number of keys. After this it'll wait for 1 hour before continuing. If you stop the script, or turn the power off, you'll have to check the log to get the last failed key and make a new file (or edit the current file) by removing the previous keys and after that run the code again.

## Installation

### PS Gallery

- Open Powershell
- type: `Install-Module -Name Resteamer`
- type: `Import-Module -Name Resteamer`
- type: `Invoke-RedeemSteamKeys`
- Follow the instructions
- Enjoy a good show!

## Manual Install

- Save the unzipped file to your preferred location.
- Open Powershell and type: `cd "path/to/Invoke-RedeemSteamKeys/"`
- Type: `Import-Module ./Invoke-RedeemSteamKeys.psm1`
- Type `Invoke-RedeemSteamKeys`
- Follow the instructions
- Enjoy a good show!
