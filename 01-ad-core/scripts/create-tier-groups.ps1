<#
.SYNOPSIS
    Cree les groupes de securite par tier, de maniere idempotente.
.DESCRIPTION
    GG-Tier1-ServerAdmins : reserve pour l'administration des serveurs Tier1 (pas encore delegue, en attente de DC-02/serveurs).
    GG-Tier2-HelpDesk : delegation reelle - reset mot de passe + deverrouillage sur OU=Utilisateurs,OU=Tier2 uniquement.
#>

$DomainDN = (Get-ADDomain).DistinguishedName

function New-GroupIfNotExists {
    param([string]$Name, [string]$Path, [string]$Description)
    $existing = Get-ADGroup -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "OK   - Groupe '$Name' existe deja" -ForegroundColor Yellow
    } else {
        New-ADGroup -Name $Name -Path $Path -GroupScope Global -GroupCategory Security -Description $Description
        Write-Host "CREE - Groupe '$Name' sous $Path" -ForegroundColor Green
    }
}

New-GroupIfNotExists -Name "GG-Tier1-ServerAdmins" -Path "OU=Groupes,OU=Tier1,$DomainDN" -Description "Administration serveurs Tier1 (reserve, pas encore delegue)"
New-GroupIfNotExists -Name "GG-Tier2-HelpDesk"     -Path "OU=Groupes,OU=Tier2,$DomainDN" -Description "Delegation reset mdp / deverrouillage compte, OU Utilisateurs Tier2 uniquement"

# Delegation reelle sur GG-Tier2-HelpDesk, scopee a OU=Utilisateurs,OU=Tier2 uniquement
$ouTier2Users = "OU=Utilisateurs,OU=Tier2,$DomainDN"

# Droit de reinitialiser le mot de passe
dsacls $ouTier2Users /I:S /G "LAB\GG-Tier2-HelpDesk:CA;Reset Password"

# Droit de deverrouiller un compte (ecriture de l'attribut lockoutTime)
dsacls $ouTier2Users /I:S /G "LAB\GG-Tier2-HelpDesk:WP;lockoutTime"

# Droit de forcer le changement de mdp a la prochaine connexion (ecriture pwdLastSet)
dsacls $ouTier2Users /I:S /G "LAB\GG-Tier2-HelpDesk:WP;pwdLastSet"

Write-Host "`nGroupes de securite par tier et delegation Tier2-HelpDesk verifies/crees." -ForegroundColor Cyan
