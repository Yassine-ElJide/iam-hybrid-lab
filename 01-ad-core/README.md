# 01 - AD Core

Statut : en cours (phase 1 du calendrier)

## VM concernees

- **DC-01** (ex WIN-DA7VN0OLOAL, renomme) : Windows Server 2022, controleur de domaine
- **WST-01** : Windows 11 Pro, poste client de test, joint au domaine, range dans OU=Postes,OU=Tier2

## Etapes realisees

### Reseau isole + connectivite

Carte reseau host-only configuree sur les deux VM (192.168.100.0/24, pas de DHCP, IP statiques). Le ping entre DC-01 et WST-01 echouait malgre une config IP correcte : le pare-feu Windows bloque par defaut les requetes ICMPv4 Echo entrantes. Resolu avec une regle pare-feu locale-independante (voir [00-architecture](../00-architecture/README.md#incident-resolu) pour le detail de l'incident).

![Regle pare-feu ICMPv4 activee](captures/preuve-firewall-icmpv4-active.png)
![Ping DC-01 vers WST-01](captures/preuve-ping-dc01-vers-wst01.png)
![Ping WST-01 vers DC-01](captures/preuve-ping-wst01-vers-dc01.png)
![Configuration carte reseau isolee](captures/preuve-carte-reseau-isolee-hote-uniquement.png)

### Promotion de DC-01 en controleur de domaine

Deux etapes distinctes :

1. **Installation du role AD DS** (`Install-WindowsFeature AD-Domain-Services -IncludeManagementTools`) : copie les binaires du service sur le disque. A ce stade le serveur ne fait encore rien de particulier, le role est juste disponible.
2. **Promotion en controleur de domaine** (`Install-ADDSForest`) : cree la foret `lab.local`, initialise la base d'annuaire (`NTDS.dit`, dans `C:\Windows\NTDS`), demarre les services `NTDS`, `Netlogon` et `DNS`, et configure Kerberos comme protocole d'authentification par defaut du domaine.

```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Install-ADDSForest `
  -DomainName "lab.local" `
  -DomainNetbiosName "LAB" `
  -InstallDns:$true `
  -SafeModeAdministratorPassword (ConvertTo-SecureString "P@$$word" -AsPlainText -Force) `
  -Force:$true
```

Deux avertissements affiches pendant la promotion, non bloquants et attendus pour un lab isole :
- algorithmes de chiffrement compatibles NT4.0 desactives par defaut (point positif cote securite)
- impossible de creer une delegation DNS car aucune zone parente n'existe (normal, il n'y a pas de DNS public au-dessus de ce domaine de lab)

### Pourquoi un controleur de domaine, concretement

Un DC assure 4 roles :

- **Authentification (Kerberos)** : quand une machine du domaine ouvre une session avec un compte AD, c'est le DC qui verifie le mot de passe et delivre un ticket Kerberos (TGT). Ce ticket sert ensuite a prouver l'identite aupres d'autres ressources sans retaper le mot de passe a chaque fois.
- **Annuaire (LDAP)** : le DC repond aux requetes LDAP sur la base `NTDS.dit` (recherche d'utilisateurs, de groupes, d'objets).
- **Replication** : avec plusieurs DC (DC-02 prevu plus tard dans le calendrier), chacun se replique en continu pour garder une base identique.
- **Diffusion des GPO** : le DC distribue les strategies de groupe aux machines du domaine.

### Pourquoi le DNS doit tourner sur le DC lui-meme

Active Directory ne fonctionne pas avec un DNS generique. Pour qu'une machine trouve "ou est le controleur de domaine pour m'authentifier", elle interroge des enregistrements **SRV** speciaux (`_kerberos._tcp.lab.local`, `_ldap._tcp.lab.local`). Ces enregistrements n'existent que dans une zone DNS **integree a Active Directory**, que seul un DC heberge. D'ou la necessite de repointer le client DNS de DC-01 sur lui-meme :

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet1" -ServerAddresses 127.0.0.1
```

Verification post-promotion et post-reboot :

```powershell
Get-Service DNS, NTDS, Netlogon
Get-ADDomain
```

![Services AD actifs (DNS, NTDS, Netlogon)](captures/preuve-services-ad-running.png)
![Sortie Get-ADDomain - foret lab.local](captures/preuve-get-addomain-lab-local.png)
![Client DNS de DC-01 repointe sur 127.0.0.1](captures/preuve-dns-self-pointing-127001.png)

### Renommage en DC-01

Le serveur portait encore son nom genere automatiquement (`WIN-DA7VN0OLOAL`). Pour un controleur de domaine, on ne fait pas un simple `Rename-Computer` : Microsoft recommande `netdom` pour que le renommage mette a jour proprement les enregistrements DNS et Kerberos associes, sans laisser de references fantomes vers l'ancien nom dans la base AD.

```powershell
netdom computername WIN-DA7VN0OLOAL /add:DC-01.lab.local
netdom computername WIN-DA7VN0OLOAL /makeprimary:DC-01.lab.local
Restart-Computer

# apres redemarrage
netdom computername DC-01.lab.local /enumerate
netdom computername DC-01.lab.local /remove:WIN-DA7VN0OLOAL.lab.local
Restart-Computer
```

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

### Arborescence d'OU et modele de tiering (Tier 0/1/2)

**Le probleme que ca resout.** Par defaut, AD range tout dans deux conteneurs plats (`Users`, `Computers`) qui ne distinguent rien par niveau de sensibilite. Un admin qui gere les DC et un utilisateur lambda se retrouvent dans la meme logique de rangement. Le **modele de tiering**, formalise par Microsoft, structure l'annuaire pour limiter le *blast radius* d'une compromission : si un poste utilisateur est infecte, l'attaquant ne doit pas pouvoir remonter jusqu'aux comptes qui administrent la foret.

**La regle centrale du tiering :** un compte d'un tier ne doit jamais s'authentifier sur une machine d'un tier inferieur. Concretement, un admin Tier 0 (DC) ne se connecte jamais avec son compte admin sur un poste Tier 2, meme pour depanner : si ce poste est compromis, l'attaquant peut extraire les identifiants de toute session ouverte en memoire (credential dumping, type Mimikatz) et remonter jusqu'a la foret entiere. C'est le scenario classique de **mouvement lateral** qu'on attaquera nous-memes en phase 3 (attaque AD) du calendrier.

- **Tier 0** : les objets qui controlent entierement la foret -- les DC eux-memes, les comptes qui les administrent, et plus tard les PAW (Privileged Access Workstation, postes dedies et durcis reserves a l'administration Tier 0)
- **Tier 1** : les serveurs applicatifs (futurs serveurs de fichiers, bases de donnees, Keycloak...) et les comptes de service qui les gerent
- **Tier 2** : les postes utilisateurs standards et les comptes utilisateurs classiques

**Utilite de chaque sous-OU :**

| OU | Contenu | Pourquoi une OU dediee |
|---|---|---|
| `Tier0/Admins` | Comptes d'administration de la foret/du domaine | Isoles pour appliquer des GPO de restriction specifiques (ex: interdiction de login sur Tier 1/2) et des strategies de mot de passe renforcees |
| `Tier0/Groupes` | Groupes de securite donnant des droits Tier 0 | Permet de deleguer des droits d'administration de maniere groupee plutot que par compte individuel |
| `Tier0/PAW` | Postes dedies a l'administration des DC | Un PAW n'a jamais acces a Internet ni aux emails -- reduit la surface d'attaque pour les comptes les plus sensibles |
| `Tier1/Serveurs` | Objets ordinateur des serveurs applicatifs | Separe les GPO de durcissement serveur des GPO postes utilisateurs |
| `Tier1/ComptesServices` | Comptes utilises par les applications/services (pas des humains) | Les comptes de service ont des besoins differents (pas d'expiration de mot de passe interactive, droits limites a une tache) |
| `Tier1/Groupes` | Groupes de securite Tier 1 | Meme logique que Tier0/Groupes, perimetre limite aux serveurs |
| `Tier2/Postes` | Objets ordinateur des postes utilisateurs (WST-01 ici) | GPO de poste de travail standard (restrictions utilisateur, durcissement de base) |
| `Tier2/Utilisateurs` | Comptes utilisateurs humains standards | Futurs utilisateurs crees en masse au Jour 9 du calendrier |
| `Tier2/Groupes` | Groupes de securite Tier 2 | Gestion des droits metier (acces fichiers, applications) sans toucher aux droits d'administration |

Le flag `-ProtectedFromAccidentalDeletion $true` sur chaque OU pose une ACL deny-delete : pratique standard en production pour eviter qu'une suppression accidentelle d'OU n'emporte toutes les sous-OU et objets avec elle.

```powershell
# OU racines
New-ADOrganizationalUnit -Name "Tier0" -Path "DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Tier1" -Path "DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Tier2" -Path "DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true

# Sous-OU Tier0
New-ADOrganizationalUnit -Name "Admins"  -Path "OU=Tier0,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Groupes" -Path "OU=Tier0,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "PAW"     -Path "OU=Tier0,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true

# Sous-OU Tier1
New-ADOrganizationalUnit -Name "Serveurs"        -Path "OU=Tier1,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "ComptesServices" -Path "OU=Tier1,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Groupes"         -Path "OU=Tier1,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true

# Sous-OU Tier2
New-ADOrganizationalUnit -Name "Postes"        -Path "OU=Tier2,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Utilisateurs"  -Path "OU=Tier2,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Groupes"       -Path "OU=Tier2,DC=lab,DC=local" -ProtectedFromAccidentalDeletion $true
```

WST-01 deplace ensuite de `Computers` vers sa place definitive :

```powershell
Get-ADComputer WST-01 | Move-ADObject -TargetPath "OU=Postes,OU=Tier2,DC=lab,DC=local"
```

![Creation des OU Tier0/Tier1/Tier2](captures/preuve-creation-ou-tier-model.png)
![WST-01 deplace dans OU=Postes,OU=Tier2](captures/preuve-wst01-deplace-tier2-postes.png)

A noter : Microsoft a fait evoluer ce modele Tier 0/1/2 (2016) vers l'**Enterprise Access Model** (depuis ~2019), plus granulaire (Control Plane / Management Plane / Data Plane). Le tiering classique reste largement utilise et compris, donc choisi comme base pour ce lab.

## Etapes a venir

- Script PowerShell/Ansible idempotent pour recreer les OU (relancable sans erreur si elles existent deja)
- CSV de 20-30 utilisateurs realistes + script de creation en masse
- Groupes de securite par tier et premieres delegations
- Provisioning DC-02 et verification de la replication
- GPO de durcissement (mot de passe, LAPS, Protected Users, restriction de login par tier)
- Premier scan PingCastle

## captures/

Captures brutes et annotees des etapes ci-dessus.
