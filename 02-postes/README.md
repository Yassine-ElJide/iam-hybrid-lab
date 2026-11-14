# 02 - Postes et tiering client

Statut : en cours (phase 2 du calendrier)

Ce module couvre le cycle de vie des postes clients : jonction au domaine, placement dans l'OU de tiering correspondante, et (a venir) GPO de durcissement poste. La construction de l'annuaire lui-meme (foret, OU, comptes) est documentee dans [01-ad-core](../01-ad-core/README.md).

## VM concernees

- **WST-01** : Windows 11 Pro, poste client de test, joint au domaine `lab.local`, range dans `OU=Postes,OU=Tier2`

## Etapes realisees

### Jonction de WST-01 au domaine

WST-01 n'heberge aucune zone DNS, contrairement a DC-01. Pour resoudre les enregistrements SRV de `lab.local` et trouver un controleur de domaine, son client DNS doit pointer vers DC-01 (pas vers lui-meme, pas vers la passerelle NAT) :

```powershell
# Sur WST-01
Set-DnsClientServerAddress -InterfaceAlias "Ethernet1" -ServerAddresses 192.168.100.10

# Verification avant de tenter le join
Resolve-DnsName lab.local
nslookup -type=srv _ldap._tcp.lab.local

# Jonction au domaine
Add-Computer -DomainName "lab.local" -Credential (Get-Credential) -Restart
```

Apres redemarrage, WST-01 apparait dans le conteneur `Computers` de `lab.local` via la console Utilisateurs et ordinateurs Active Directory sur DC-01.

![WST-01 joint au domaine lab.local](captures/preuve-wst01-join-domaine-aduc.png)

### Placement dans l'OU de tiering

Un objet ordinateur fraichement joint atterrit par defaut dans le conteneur plat `Computers`, qui ne porte aucune information de tiering. Pour que WST-01 recoive les futures GPO de poste standard (Tier 2), il est deplace dans l'arborescence construite en [01-ad-core](../01-ad-core/README.md#arborescence-dou-et-modele-de-tiering-tier-012) :

```powershell
Get-ADComputer WST-01 | Move-ADObject -TargetPath "OU=Postes,OU=Tier2,DC=lab,DC=local"
```

### Test de connexion utilisateur de bout en bout

Une fois un poste joint au domaine, **par defaut Windows autorise n'importe quel utilisateur authentifie du domaine a ouvrir une session locale** sur une machine membre (pas un DC) -- ce droit vient du parametre `Allow log on locally`, qui inclut implicitement le groupe `Authenticated Users` tant qu'aucune GPO ne vient le restreindre. C'est volontairement ouvert a ce stade : la restriction par tier viendra avec les GPO de durcissement (Jour 11-12).

Connexion testee avec le compte `amartin` (Alice Martin, `Tier2/Utilisateurs`, cree au Jour 9), au format `LAB\amartin` :

1. Windows force le changement du mot de passe initial a la premiere connexion, comme attendu (`-ChangePasswordAtLogon $true` pose au moment de la creation du compte)
2. La session s'ouvre normalement ensuite, confirmant la chaine complete : CSV -> compte AD cree dans la bonne OU -> authentification Kerberos -> session locale sur un poste membre du domaine

**Point de vigilance tiering, volontairement teste** : seuls des comptes `Tier2` doivent servir a se connecter a WST-01. Le compte `adm-yelj` (`Tier0/Admins`) ne doit jamais etre utilise ici, meme si rien ne l'empeche techniquement pour l'instant -- exactement le risque de mouvement lateral explique en [01-ad-core](../01-ad-core/README.md#arborescence-dou-et-modele-de-tiering-tier-012).

![Changement de mot de passe force a la premiere connexion](captures/preuve-changement-mdp-premiere-connexion.png)
![Session ouverte avec succes sous LAB\amartin sur WST-01](captures/preuve-connexion-amartin-wst01.png)

## Etapes a venir

- GPO de poste standard appliquees sur `Tier2/Postes` (restrictions utilisateur, durcissement de base)
- GPO `Deny log on locally` pour restreindre formellement l'acces par tier
- Provisioning d'un deuxieme poste pour tester la coherence des GPO

## captures/

Captures des etapes ci-dessus.
