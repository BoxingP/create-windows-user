$LogFile = "log.txt"
$LogFilePath = Join-Path $PSScriptRoot $LogFile
$UsersFile = "users.csv"
$UsersFilePath = Join-Path $PSScriptRoot $UsersFile
$OutputFile = "output.csv"
$OutputFilePath = Join-Path $PSScriptRoot $OutputFile


function Write-Log {
  param(
      [Parameter(Mandatory = $true)][string] $Message,
      [Parameter(Mandatory = $false)]
      [ValidateSet("INFO","WARN","ERROR")]
      [string] $Level = "INFO"
  )
  $Timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
  Add-Content -Path $LogFilePath -Value "$Timestamp [$Level] - $Message"
}

function Create-String([Int]$Size = 8, [Char[]]$CharSets = "ULNS", [Char[]]$Exclude) {
    $Chars = @(); $TokenSet = @()
    If (!$TokenSets) {$Global:TokenSets = @{
        U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        L = [Char[]]'abcdefghijklmnopqrstuvwxyz'
        N = [Char[]]'0123456789'
        S = [Char[]]'!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
    }}
    $CharSets | ForEach {
        $Tokens = $TokenSets."$_" | ForEach {If ($Exclude -cNotContains $_) {$_}}
        If ($Tokens) {
            $TokensSet += $Tokens
            If ($_ -cle [Char]"Z") {$Chars += $Tokens | Get-Random}
        }
    }
    While ($Chars.Count -lt $Size) {$Chars += $TokensSet | Get-Random}
    ($Chars | Sort-Object {Get-Random}) -Join ""
}; Set-Alias Create-Password Create-String -Description "Generate a random string (password)"

function Update-LocalUserPassword([string]$Username, [string]$Password) {
    Set-LocalUser -Name "$Username" -Password (ConvertTo-SecureString "$Password" -AsPlainText -Force) -ErrorAction stop
    Write-log -Message ("Account Password Updated Successfully: {0} - {1}" -f $Username,$Password) -Level "INFO"
}

function Create-LocalUser([string]$Username, [string]$Description, [string]$IsAdmin) {
    $Null = @(
        try {
            $Password = Create-String 16 ULNS
            New-LocalUser -Name "$Username" -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -FullName "$Username" -Description "$Description" -ErrorAction stop
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member "$Username" -ErrorAction stop
            if ($IsAdmin -contains 'yes') {
                Add-LocalGroupMember -Group "Administrators" -Member "$Username" -ErrorAction stop
            }
            Write-log -Message ("Account Created Successfully: {0} - {1}" -f $Username,$Password) -Level "INFO"
        } catch [Microsoft.PowerShell.Commands.UserExistsException] {
            Update-LocalUserPassword -Username "$Username" -Password $Password
        } catch {
            $Password = ""
            $ErrorMessage = $_ | Out-String
            Write-Log -Message ("Creating account failed: {0}" -f $ErrorMessage) -Level "ERROR"
            
        }
    )
    return $Password
}

Import-Csv -Path $UsersFilePath -Delimiter "," | ForEach-Object {
    $_.password = Create-LocalUser -Username $_.username -Description $_.description -IsAdmin $_.is_admin
    $_
} | Export-Csv -Path $OutputFilePath -Delimiter "," -NoType
