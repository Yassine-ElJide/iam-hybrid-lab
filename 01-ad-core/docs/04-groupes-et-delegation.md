# Groupes de securite par tier et delegation

[Retour a l'index 01-ad-core](../README.md)

### Groupes de securite par tier et premiere delegation

**Le probleme que ca resout.** On vient de mettre `adm-yelj` directement dans `Admins du domaine` - correct pour un compte Tier0, c'est sa raison d'etre. Mais si chaque besoin d'administration (meme mineur, comme reinitialiser un mot de passe) passe par un ajout a Domain Admins, on retombe dans le piege demontre par l'attaque LDAP du module 03 : plus il y a de comptes a privilege large, plus la surface d'attaque est grosse. Le principe de delegation AD : un besoin specifique ne necessite pas un privilege large, on scope le droit exactement a ce qui est necessaire, sur l'OU necessaire.

**Design retenu**, en s'appuyant sur les sous-OU `Groupes` deja presentes dans chaque tier :
- `GG-Tier1-ServerAdmins` (dans `OU=Groupes,OU=Tier1`) : reserve pour l'administration des futurs serveurs Tier1 (DC-02, etc.), pas encore delegue.
- `GG-Tier2-HelpDesk` (dans `OU=Groupes,OU=Tier2`) : delegation reelle et testee - reset mot de passe + deverrouillage de compte, **uniquement sur `OU=Utilisateurs,OU=Tier2`**.

Tier0 n'a pas besoin d'un groupe supplementaire : `Admins du domaine` est deja le groupe de controle de Tier0.

Script idempotent : [scripts/create-tier-groups.ps1](../scripts/create-tier-groups.ps1).

![Creation des groupes GG-Tier1-ServerAdmins et GG-Tier2-HelpDesk](../captures/preuve-creation-groupes-tier1-tier2.png)

**Delegation via `dsacls`.** `dsacls` lit et modifie directement le descripteur de securite (ACL) d'un objet AD - l'equivalent en ligne de commande de l'onglet Securite/Avance dans ADUC. Trois droits accordes, volontairement granulaires plutot qu'un `GenericWrite` qui ouvrirait trop de portes :

```powershell
$ouTier2Users = "OU=Utilisateurs,OU=Tier2,$((Get-ADDomain).DistinguishedName)"

dsacls $ouTier2Users /I:S /G "LAB\GG-Tier2-HelpDesk:CA;Reset Password"   # droit etendu de reinitialiser le mot de passe
dsacls $ouTier2Users /I:S /G "LAB\GG-Tier2-HelpDesk:WP;lockoutTime"     # ecriture de l'attribut qui deverrouille un compte
dsacls $ouTier2Users /I:S /G "LAB\GG-Tier2-HelpDesk:WP;pwdLastSet"      # ecriture de l'attribut qui force le changement de mdp a la prochaine connexion
```

`/I:S` = l'autorisation s'applique aux sous-objets (les utilisateurs de l'OU), pas seulement a l'OU elle-meme. `CA` = Control Access Right (droit etendu). `WP` = Write Property (ecriture d'un attribut precis).

Point important a noter sur la sortie de `dsacls` : la commande n'affiche pas seulement le droit qu'on vient d'ajouter, elle reaffiche **toute l'ACL existante de l'objet**, entrees par defaut comprises (Domain Admins, SYSTEM, Enterprise Admins, Account Operators, etc.). Rien d'anormal - c'est le comportement normal de l'outil. On y retrouve d'ailleurs une ligne qui fait echo direct a l'attaque du module 03 : `Autorise Utilisateurs authentifies : READ PERMISSIONS, LIST CONTENTS, READ PROPERTY, LIST OBJECT` - exactement le droit par defaut qu'on a exploite avec `ldapsearch`.

![Sortie complete de dsacls apres ajout de la delegation](../captures/preuve-dsacls-delegation-ajoutee.png)

Verification ciblee (plus lisible qu'un dump complet) :

```powershell
dsacls $ouTier2Users | Select-String "GG-Tier2-HelpDesk"
```

![Les 3 delegations confirmees pour GG-Tier2-HelpDesk](../captures/preuve-dsacls-delegation-confirmee-filtree.png)

### Preuve de fonctionnement : test positif + tests negatifs

**Protocole.** Un compte `test-helpdesk`, membre uniquement de `GG-Tier2-HelpDesk` (pas de `adm-yelj`, pour ne pas violer le tiering en testant un compte Tier0 sur un poste Tier2), connecte sur **WST-01** avec une session PowerShell non elevee. Les droits delegues via AD sont independants des droits locaux de la machine : pas besoin d'etre administrateur du poste pour que la delegation AD fonctionne.

Trois commandes, un seul objectif : prouver que la delegation fait *exactement* ce qu'on a autorise, ni plus ni moins.

```powershell
Import-Module ActiveDirectory

# Test positif : amartin est dans OU=Utilisateurs,OU=Tier2 -> dans le perimetre delegue
Set-ADAccountPassword -Identity amartin -Reset -NewPassword (ConvertTo-SecureString "Nouveau2026!" -AsPlainText -Force)

# Test negatif #1 : svc-backup est hors perimetre (pas dans l'OU Tier2 deleguee)
Set-ADAccountPassword -Identity svc-backup -Reset -NewPassword (ConvertTo-SecureString "Nouveau2026!" -AsPlainText -Force)

# Test negatif #2 : tentative d'auto-elevation de privileges
Add-ADGroupMember -Identity "Admins du domaine" -Members test-helpdesk
```

**Resultat :**

| Test | Attendu | Observe |
|---|---|---|
| Reset mot de passe sur `amartin` (Tier2, dans le perimetre) | Succes | Succes, aucune erreur |
| Reset mot de passe sur `svc-backup` (hors perimetre) | Echec | `Acces refuse` - `UnauthorizedAccessException` |
| Auto-ajout a `Admins du domaine` | Echec | `Droits d'acces insuffisants` - `ADException` |

![Test positif et tests negatifs de la delegation GG-Tier2-HelpDesk depuis WST-01](../captures/preuve-delegation-tier2-helpdesk-tests.png)

**Pourquoi c'est la preuve qui compte.** N'importe qui peut accorder un droit et constater qu'il fonctionne - le vrai test d'une delegation en moindre privilege, c'est de prouver qu'elle ne deborde pas. Le test negatif #1 confirme que le scope (`OU=Utilisateurs,OU=Tier2` uniquement) est respecte. Le test negatif #2 confirme qu'aucun des 3 droits accordes (`Reset Password`, ecriture de `lockoutTime`, ecriture de `pwdLastSet`) ne permet, meme indirectement, une elevation vers un groupe privilegie. C'est la demonstration concrete de ce que l'attaque LDAP du module 03 rend necessaire : moins un compte a de droits larges, moins il represente de risque en cas de compromission.

Le test de delegation `GG-Tier2-HelpDesk` est donc clos : positif et negatifs tous deux confirmes.
