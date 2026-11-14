<#
.SYNOPSIS
    Cree en masse les utilisateurs AD depuis le CSV 01-ad-core/data/utilisateurs.csv, de maniere idempotente.
.DESCRIPTION
    Pour chaque ligne du CSV : si le SamAccountName existe deja, ne fait rien.
    Sinon, cree le compte dans l'OU indiquee, avec un mot de passe initial
    et l'obligation de le changer a la premiere connexion.
.PARAMETER CsvPath
    Chemin local du CSV sur DC-01 (le fichier doit y etre copie au prealable).
#>

param(
    [string]$CsvPath = ".\utilisateurs.csv"
)

$InitialPassword = ConvertTo-SecureString "ChangeMoi!2026" -AsPlainText -Force
$users = Import-Csv -Path $CsvPath

foreach ($u in $users) {
    $existing = Get-ADUser -Filter "SamAccountName -eq '$($u.SamAccountName)'" -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Host "OK   - $($u.SamAccountName) existe deja" -ForegroundColor Yellow
        continue
    }

    try {
        New-ADUser `
            -Name "$($u.Prenom) $($u.Nom)" `
            -GivenName $u.Prenom `
            -Surname $u.Nom `
            -SamAccountName $u.SamAccountName `
            -UserPrincipalName $u.UserPrincipalName `
            -Path $u.OU `
            -Department $u.Departement `
            -Title $u.Poste `
            -Description $u.Description `
            -AccountPassword $InitialPassword `
            -ChangePasswordAtLogon $true `
            -Enabled $true

        Write-Host "CREE - $($u.SamAccountName) ($($u.Prenom) $($u.Nom)) dans $($u.OU)" -ForegroundColor Green
    }
    catch {
        Write-Host "ERREUR - $($u.SamAccountName) : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nImport termine." -ForegroundColor Cyan
