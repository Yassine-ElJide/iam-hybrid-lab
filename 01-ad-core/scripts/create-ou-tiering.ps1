<#
.SYNOPSIS
    Cree l'arborescence d'OU du modele de tiering (Tier 0/1/2) de maniere idempotente.
.DESCRIPTION
    Verifie l'existence de chaque OU avant de la creer. Peut etre relance sans erreur
    si tout ou partie de l'arborescence existe deja.
#>

$DomainDN = (Get-ADDomain).DistinguishedName

function New-OUIfNotExists {
    param(
        [string]$Name,
        [string]$Path
    )
    $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "OK  - OU '$Name' existe deja sous $Path" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "CREE - OU '$Name' sous $Path" -ForegroundColor Green
    }
}

# Tiers racines
foreach ($tier in @("Tier0", "Tier1", "Tier2")) {
    New-OUIfNotExists -Name $tier -Path $DomainDN
}

# Sous-OU Tier0
New-OUIfNotExists -Name "Admins"  -Path "OU=Tier0,$DomainDN"
New-OUIfNotExists -Name "Groupes" -Path "OU=Tier0,$DomainDN"
New-OUIfNotExists -Name "PAW"     -Path "OU=Tier0,$DomainDN"

# Sous-OU Tier1
New-OUIfNotExists -Name "Serveurs"        -Path "OU=Tier1,$DomainDN"
New-OUIfNotExists -Name "ComptesServices" -Path "OU=Tier1,$DomainDN"
New-OUIfNotExists -Name "Groupes"         -Path "OU=Tier1,$DomainDN"

# Sous-OU Tier2
New-OUIfNotExists -Name "Postes"       -Path "OU=Tier2,$DomainDN"
New-OUIfNotExists -Name "Utilisateurs" -Path "OU=Tier2,$DomainDN"
New-OUIfNotExists -Name "Groupes"      -Path "OU=Tier2,$DomainDN"

Write-Host "`nArborescence de tiering verifiee/creee." -ForegroundColor Cyan
