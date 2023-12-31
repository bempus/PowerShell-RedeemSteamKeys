

function Invoke-RedeemSteamKeys {
  if (-not (Get-Module -Name Monocle)) {
    if (-not (Get-InstalledModule -Name Monocle)) {
      Install-Module -Name Monocle
    }
    Import-Module Monocle
  }

  function Update-ChromeDriver {
    $monoclePath = Get-Item -Path (Get-Module -Name Monocle | Select-Object -ExpandProperty Path) | Select-Object -ExpandProperty DirectoryName
    $chromeDriverPath = "$monoclePath\lib\Browsers\win\chromedriver.exe"
    $chromeDriverVersion = & $chromeDriverPath --version
    $currentChromedriverversion = Invoke-RestMethod -Method Get -Uri 'https://raw.githubusercontent.com/bempus/PowerShell-RedeemSteamKeys/main/chromedriver.version'

    if ($chromeDriverVersion -notLike "ChromeDriver $currentChromedriverversion*") {
      Write-Host "ChromeDriver is out of date, updating..." -ForegroundColor Green
      $chromeDriverFolder = (Get-Item $chromeDriverPath).DirectoryName
      $expandedPath = "$chromeDriverFolder\chromedriver"
      $zipPath = "$expandedPath.zip"
      Invoke-WebRequest -Uri "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$currentChromedriverversion/win32/chromedriver-win32.zip" -OutFile $zipPath
      Expand-Archive -Path $zipPath -DestinationPath $expandedPath
      Remove-Item $chromeDriverPath
      Move-Item "$expandedPath\chromedriver-win32\chromedriver.exe" "$chromeDriverFolder\chromedriver.exe"
      Remove-Item -Path $expandedPath, $zipPath -Recurse
    }
  }
 
  try {
    Update-ChromeDriver
  }
  catch {
    Write-Host "Could not update ChromeDriver: $($_.Exception.Message)"
  }

  Add-Type -AssemblyName System.Windows.Forms

  $user = Read-Host "Username"
  $password = Read-Host "Password"

  $filePicker = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [System.Environment]::GetFolderPath('Desktop')
    Filter           = 'Allowed Files (*.txt;*.csv)|*.txt;*.csv|Textfile (*.txt)|*.txt|CSV (*.csv)|*.csv'
  }
  $file = $filePicker.ShowDialog()

  if ($file -eq 'Cancel') {
    return Write-Host "A file is required" -ForegroundColor Red
  }

  switch ((Get-Item $filePicker.FileName).Extension) {
    '.txt' {
      $keyData = Get-Content -Path $filePicker.FileName
    }
    '.csv' {
      $keyHeader = Read-Host "Input the key header (The title of the column, example: Key)"
      $keyDelimiter = Read-Host "Input the delimiter (Usually a comma ',' or a semicolon ';')"
      $keyData = (Import-Csv -Delimiter $keyDelimiter -Path $filePicker.FileName).$keyHeader
      $errExt = ' and header'
    }
    default {
      return Write-Host "Invalid extension, valid extensions: (TXT, CSV)" -ForegroundColor Red
    }
  }
  $keyData = $keyData | Where-Object { $_ -match '.{5}-.{5}-.{5}' } | ForEach-Object {
    $_ -replace '.*(.{5}-.{5}-.{5}).*', '$1'
  }

  $logName = "$(Get-Date -Format 'yyyy-MM-dd')_steam.log"

  $browser = New-MonocleBrowser -Type Chrome
  $browser.Url = 'https://store.steampowered.com/login/'
  Start-Sleep 2
  $browser.FindElementByClassName('newlogindialog_TextInput_2eKVn').SendKeys($user)
  $browser.FindElementByXPath('//input[@type="password"]').SendKeys($password)
  $browser.FindElementByClassName('newlogindialog_SubmitButton_2QgFE').Click()

  while ($browser.url -ne 'https://store.steampowered.com/') {
    Start-Sleep -Seconds 1
  }

  function Invoke-RedeemKeys {
    param ($keys)
    $i = 0
    foreach ($key in $keys) {
      $i++
      Write-Host "Redeeming key $i/$($keys.count)" -ForegroundColor Green
      $retry = $false
      $browser.Url = "https://store.steampowered.com/account/registerkey?key=$key"
      Start-Sleep .2
      $browser.FindElementById('accept_ssa').Click()
      $browser.FindElementById('register_btn').Click()

      $errorDisplayDiv = $browser.FindElementById("error_display")
      $succesDiv = $browser.FindElementById('receipt_form')
      while ($errorDisplayDiv.GetCssValue('display') -eq 'none' -and $succesDiv.GetCssValue('display') -eq 'none') {
        Start-Sleep -Milliseconds 200
      }
      if ($errorDisplayDiv.GetCssValue('display') -eq 'block') {
      
        $errorText = $errorDisplayDiv.Text
        if ($errorText -like "The product code you've entered is not valid or is not a product code.*") {
          $errorText = "Invalid key"
        }
        if ($errorText -like "The product code you've entered has already been activated by a different Steam account.*") {
          $errorText = "Already activated"
        }
        if ($errorText -like "This Steam account already owns the product(s) contained in this offer.*") {
          $errorText = "Game is already owned"
        }
        if ($errorText -like "The product code you've entered requires ownership of another product before activation.*") {
          $errorText = "Requires another game before activation"
        }
        if ($errorText -like "There have been too many recent activation attempts from this account or Internet address.*") {
          $errorText = "Too many activation attempts"
          $retry = $true
        }
      
        Write-Host "$($key): Could not redeem ($errorText)" -ForegroundColor Red
        "$(Get-Date -Format 'HH:MM:ss') | $($key): $errorText" >> "./$logName"
      }
      if ($retry) {
        Start-Sleep -Seconds $cooldownMinutes
        Invoke-RedeemKeys -keys $key
      }
    }
  }

  if (-not $keyData) {
    return Write-Host "No keys found, check the file$errExt selected" -ForegroundColor Red
  }

  Invoke-RedeemKeys -keys $keyData
}