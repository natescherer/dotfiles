$passItem = Get-Content .devcontainer\pass-item.txt | Where-Object { $_ -notmatch '^#' }

$ErrorActionPreference = "Stop"
$envFile = ".devcontainer\.env.ssh-key"

try {
    $key = pass-cli item view $passItem | Out-String
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($key)) {
        throw "pass-cli item view exited $LASTEXITCODE or returned no output"
    }

    $keyB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($key))
    Set-Content -Path $envFile -Value "SSH_PRIVATE_KEY_B64=$keyB64" -NoNewline
} catch {
    Remove-Item -Path $envFile -ErrorAction SilentlyContinue
    Write-Error "Failed to retrieve the SSH key from Proton Pass: $_"
    exit 1
}
