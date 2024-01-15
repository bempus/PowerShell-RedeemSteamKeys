

function Invoke-RedeemSteamKeys {


  #Disables Monocle logging
  $monoclePath = Get-Item -Path (Get-Module -Name Monocle | Select-Object -ExpandProperty Path) | Select-Object -ExpandProperty DirectoryName
  $monocleToolPath = Join-Path -Path $monoclePath -ChildPath 'Private/Tools.ps1'
  $monocleTool = Get-Content $monocleToolPath 
  Set-Content -Path $monocleToolPath -Value ($monocleTool -replace '#?write-host', '#write-host')

  function Update-BrowserDriver {
    param(
      [ValidateSet('win', 'mac', 'linux')]
      $systemType
    )

    switch ($systemType) {
      "win" { 
        $chromeDriverFileName = 'chromedriver.exe'
        $dlPlatform = "win32"
      }
      "mac" {
        $chromeDriverFileName = 'chromedriver'
        $dlPlatform = 'mac-x64'
      }
      "linux" {
        $chromeDriverFileName = 'chromedriver'
        $dlPlatform = 'mac-x64'
      }
      Default {}
    }

    $chromeDriverPath = "$monoclePath\lib\Browsers\$systemType\$chromeDriverFileName"
    $chromeDriverVersion = & $chromeDriverPath --version

    $currentChromeDriverMetadata = (Invoke-RestMethod -Method Get -Uri 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json').channels.stable
    $currentChromedriverversion = $currentChromeDriverMetadata.version
    
    if ($chromeDriverVersion -notLike "ChromeDriver $currentChromedriverversion*") {
      Write-Host "ChromeDriver is out of date, updating..." -ForegroundColor Green
      $dlUrl = $currentChromeDriverMetadata.downloads.chromedriver | Where-Object Platform -eq $dlPlatform | Select-Object -ExpandProperty url

      $chromeDriverFolder = (Get-Item $chromeDriverPath).DirectoryName

      $chromeDriverTempFolder = "$chromedriverFolder\temp" 
      $chromeDriverZipFile = "$chromeDriverTempFolder\chromedriver.zip"
      $null = New-Item -Path $chromeDriverTempFolder -ItemType Directory
      Invoke-WebRequest -Uri $dlUrl -OutFile $chromeDriverZipFile
      Expand-Archive -Path $chromeDriverZipFile -DestinationPath $chromeDriverTempFolder
      Remove-Item $chromeDriverPath
      Move-Item "$chromeDriverTempFolder\*\$chromeDriverFileName" "$chromeDriverFolder\$chromeDriverFileName"
      Remove-Item -Path $chromeDriverTempFolder -Recurse
    }
  }
 

  
  function Get-Platform {
    if ($IsWindows -or $PSVersionTable.psversion.Major -le 5 ) {
      return "win"
    }
    if ($IsMacOS) {
      return "mac"
    }
    if ($IsLinux) {
      return "linux"
    }  
  }
  
  $platform = Get-Platform

  try {

    Update-BrowserDriver -systemType $platform
  }
  catch {
    Write-Host "Could not update ChromeDriver: $($_.Exception.Message)"
  }
  
  if ($platform -eq 'win') {
    Add-Type -AssemblyName System.Windows.Forms
    $filePicker = New-Object System.Windows.Forms.OpenFileDialog -Property @{
      InitialDirectory = [System.Environment]::GetFolderPath('Desktop')
      Filter           = 'Allowed Files (*.txt;*.csv)|*.txt;*.csv|Textfile (*.txt)|*.txt|CSV (*.csv)|*.csv'
    }
    $file = $filePicker.ShowDialog()
    if ($file -eq 'Cancel') {
      return Write-Host "A file is required" -ForegroundColor Red
    }
    $file = $filePicker.FileName
    New-Item -path $logpath -ItemType Directory

    $monocleType = "Chrome"
  }
  else {
    while (-not ($file)) {
      $file = Read-Host "Full path to the file containing keys (.csv or .txt)"
      if (-not (Test-Path -Path $file -PathType Leaf)) {
        $file = $null
        Write-Host 'Invalid file, try again' -ForegroundColor Yellow
      }
    }

    $monocleType = 'Firefox'
    
  }


  switch ((Get-Item $file).Extension) {
    '.txt' {
      $keyData = (Get-Content -Path $file) | Where-Object { $_ -match '.{5}-.{5}-.{5}' } | ForEach-Object {
        if ($_ -match '.{5}-.{5}-.{5}-.{5}-.{5}') {
          $_ -replace '.*(.{5}-.{5}-.{5}-.{5}-.{5}).*', '$1'
        }
        else {
          $_ -replace '.*(.{5}-.{5}-.{5}).*', '$1'
        }
      }

    }
    '.csv' {
      $keyHeader = Read-Host "Input the key header (The title of the column, example: Key)"
      $keyDelimiter = Read-Host "Input the delimiter (Usually a comma ',' or a semicolon ';')"
      $keyData = (Import-Csv -Delimiter $keyDelimiter -Path $file).$keyHeader
      $errExt = ' and header'
    }
    '' {
      $keyData = Get-Content -Path $file
    }
    default {
      Write-Host "Invalid file, if the format is correct please rename the extention to either '.csv' or '.txt'"
      return
    }
  }

  $logName = "$(Get-Date -Format 'yyyy-MM-dd')_steam.log"
  $LogFolderPath = Join-Path -path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "Resteamer"
  $LogPath = Join-Path -Path $LogFolderPath -ChildPath $logName

  function New-JS_Toast {
    param (
      [ValidateSet('info', 'error')]
      $type = "info",
      [Parameter(Mandatory)]
      [string]$message,
      [switch]$closeable,
      [int]$timeout,
      [ValidateSet('top', 'bottom')]
      $positionY = 'top',
      [ValidateSet('left', 'right')]
      $positionX = 'left'
    )
  
    $background = switch ($type) {
      "info" { "linear-gradient(rgb(51, 136, 51), rgb(17, 119, 17))" }
      "error" { "linear-gradient(rgb(155 0 0), rgb(215 0 0))" }
    }

    $toastStyle = "position:absolute;$($positionY):1rem;$($positionX):1rem;padding: 1em 2em; background: $background; color: white; font-size: 1.05rem;z-index:9999"

    if ($timeout) {
      $js__timeout = @"
      setTimeout(() => container.remove(), $timeout)
"@
    }
    if ($closeable) {
      $js__closebtn = @"
      const close_btn = document.createElement('button')
      close_btn.style = "position:absolute;top:.5rem;right:.5rem;font-size:.6rem;background:red;color:white;padding:.3rem;border:none;line-height:1"
      close_btn.textContent = "✖" 
      close_btn.addEventListener('click', () => container.remove())
      container.append(close_btn)
"@
    }

    $js__toast = @"
    const container = document.createElement('div')
    container.style = "$toastStyle"
    container.id = "resteamer-toast"
    container.textContent = "$message"
    document.querySelector("body").insertAdjacentElement("afterbegin", container)
    $js__timeout
    $js__closebtn
"@

    Invoke-MonocleJavaScript -Script $js__toast
  }

  $browser = New-MonocleBrowser -Type $monocleType

  Start-MonocleFlow -Name 'Load Steam' -Browser $browser -ScriptBlock {
    Set-MonocleUrl -Url 'https://store.steampowered.com/login/'
    New-JS_Toast -type info -message "Log in to continue"

    while ($true) {
      try {
        Wait-MonocleUrlDifferent -FromUrl 'https://store.steampowered.com/login/'
        if (-not $browser.url) {
          try {
            $browser.quit()
          }
          catch {}
          return 
        }
        break
      }
      catch {}
    }
  }


  function Write-Log {
    param (
      $message,
      [ValidateSet('info', 'warning', 'error', 'debug')]
      $logType = 'info'
    )

    $color = switch ($logType) {
      'info' { [System.ConsoleColor]::Green }
      'warning' { [System.ConsoleColor]::Yellow }
      'error' { [System.ConsoleColor]::Red }
      default { [System.ConsoleColor]::White }
    }

    
  
    Write-Host $(Get-Date -Format 'HH:MM:ss') -NoNewline -ForegroundColor Magenta
    Write-Host ' | ' -NoNewline
    Write-Host "[$logtype] " -ForegroundColor $color -NoNewline
    Write-Host $message
    Write-Host "$(Get-Date -Format 'HH:MM:ss') [$logtype] $message" -ForegroundColor $color

    "$(Get-Date -Format 'HH:MM:ss') | [$logType] $message" | Out-File -FilePath $LogPath -Append -Force
  }

  function Invoke-RedeemKey {
    param($key)
    Start-MonocleFlow -Name 'Redeem Key' -Browser $browser -ScriptBlock {
      Set-MonocleUrl -Url "https://store.steampowered.com/account/registerkey?key=$key" -Force 

      Get-MonocleElement -Id 'accept_ssa' | Set-MonocleElementAttribute -Name "checked" -Value 'true'
      Get-MonocleElement -Id 'register_btn' | Invoke-MonocleElementClick

      try {
        switch ((Get-MonocleElement -Id 'error_display').Text) {
          { $_ -like "$key | The product code you've entered is not valid or is not a product code.*" } {
            Write-Log -message "$key | Invalid key" -logType error
            return
          }
          { $_ -like "$key | The product code you've entered has already been activated by a different Steam account.*" } {
            Write-Log -message "$key | Already activated" -logType error
            return
          }
          { $_ -like "$key | This Steam account already owns the product(s) contained in this offer.*" } {
            Write-Log "$key | Already Owned" -logType warning
            return
          }
          { $_ -like "$key | The product code you've entered requires ownership of another product before activation.*" } {
            Write-Log "$key | Needs another product to activate" -logType warning
            return
          }
        ($_ -like "$key | There have been too many recent activation attempts from this account or Internet address.*") {
            Write-Log "$key | Too many activation attempts, the script will now wait 60 minutes" -logType warning
            for ($i = 0; $i -le 60; $i++) {
              Write-Progress -Activity "Waiting for cooldown" -PercentComplete ((($i) / 60) * 100) -status "($(60 - $i)  minutes remaining)"
              Start-Sleep -Seconds 1
            }
            Write-Progress -Completed
            Write-Log -message "$key | Retrying activation..."
            Invoke-RedeemKey -key $key
          }
        }
      }
      catch {
        if ($_.FullyQualifiedErrorId -ne [OpenQA.Selenium.StaleElementReferenceException].Name) {
          Write-Log -message "Something went wrong, please try again" -logType error
        }
      }
    }
  }

  if (-not $keyData) {
    return Write-Host "No keys found, check the file ($errExt) selected" -ForegroundColor Red
  }

  foreach ($key in $keyData) {
    Invoke-RedeemKey -key $key
  }
}