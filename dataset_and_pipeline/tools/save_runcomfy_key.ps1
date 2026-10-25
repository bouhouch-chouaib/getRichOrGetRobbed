# Enregistre une cle d'API d'images pour gen_image.py, collee masquee dans le terminal (ni chat, ni historique).
#   -Service runcomfy (defaut) : runcomfy.com/profile, "Token 1"  -> %USERPROFILE%\.config\runcomfy\token.txt
#   -Service gemini            : aistudio.google.com/apikey       -> %USERPROFILE%\.config\gemini\key.txt
param([ValidateSet("runcomfy", "gemini")] [string] $Service = "runcomfy")
$where = if ($Service -eq "gemini") { "aistudio.google.com/apikey" } else { "runcomfy.com/profile, Token 1" }
$secure = Read-Host ("Colle ta cle " + $Service + " (" + $where + ") puis Entree - elle ne s'affiche pas") -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr).Trim()
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ($key.Length -lt 20) {
    Write-Host ("Cle trop courte (" + $key.Length + " caracteres) : ce n'est pas une cle d'API, rien n'est enregistre.") -ForegroundColor Red
    exit 1
}
$folder = Join-Path $env:USERPROFILE (".config\" + $Service)
$file = if ($Service -eq "gemini") { "key.txt" } else { "token.txt" }
New-Item -ItemType Directory -Force $folder | Out-Null
[IO.File]::WriteAllText((Join-Path $folder $file), $key)
Write-Host ("Cle enregistree (" + $key.Length + " caracteres) dans " + $folder + "\" + $file) -ForegroundColor Green
