if (-not (Find-Module Monocle)) {
  Install-Module Monocle -Force
}
Update-Module Monocle | Out-Null