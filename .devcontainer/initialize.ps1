$bwItem = Get-Content .devcontainer\bw-item.txt | Where-Object { $_ -notmatch '^#' }

$ErrorActionPreference = "Stop"
$envFile = ".devcontainer\.env.ssh-key"

try {
    # With no terminal on stdin, bw fails instead of waiting on a master password prompt nobody sees
    # when the desktop app can't unlock the vault
    $item = $null | mise exec -- bwbio get item $bwItem | Out-String
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($item)) {
        throw "bwbio get item exited $LASTEXITCODE or returned no output"
    }

    $key = ($item | ConvertFrom-Json).sshKey.privateKey
    if ([string]::IsNullOrEmpty($key)) {
        throw "Bitwarden item '$bwItem' has no SSH private key"
    }

    # OpenSSH rejects a private key without a trailing newline
    $keyB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($key.TrimEnd() + "`n"))
    Set-Content -Path $envFile -Value "SSH_PRIVATE_KEY_B64=$keyB64" -NoNewline
} catch {
    Remove-Item -Path $envFile -ErrorAction SilentlyContinue
    Write-Error "Failed to retrieve the SSH key from Bitwarden: $_"
    exit 1
}
