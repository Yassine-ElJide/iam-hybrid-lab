# 01 - AD Core

Statut : en cours (phase 1 du calendrier)

Ce module couvre le coeur de l'annuaire : foret, controleur de domaine, arborescence d'OU/tiering, et cycle de vie des comptes (OU, groupes, utilisateurs). La gestion des postes clients (jonction au domaine, GPO postes) est documentee separement dans [02-postes](../02-postes/README.md).

## VM concernees

- **DC-01** (ex WIN-DA7VN0OLOAL, renomme) : Windows Server 2022, controleur de domaine

## Documentation detaillee

Le detail de chaque etape est reparti dans plusieurs documents pour rester lisible :

1. [Foret, DC-01 et DNS](docs/01-foret-et-dc.md) - reseau isole, promotion en controleur de domaine, pourquoi un DC, DNS, renommage
2. [Tiering et arborescence d'OU](docs/02-tiering-et-ou.md) - modele Tier 0/1/2, script idempotent de creation des OU
3. [Provisioning des utilisateurs](docs/03-provisioning-utilisateurs.md) - creation en masse via CSV, correction adm-yelj (OU != groupe)
4. [Groupes de securite par tier et delegation](docs/04-groupes-et-delegation.md) - GG-Tier1-ServerAdmins, GG-Tier2-HelpDesk, delegation dsacls
5. [Audit PingCastle - baseline et plan de remediation](docs/05-audit-pingcastle.md) - score de risque initial (55/100) et plan de correction priorise

## Etapes a venir

- Appliquer le plan de remediation PingCastle (voir [docs/05-audit-pingcastle.md](docs/05-audit-pingcastle.md)), en commencant par les corrections rapides et a faible risque
- Provisioning DC-02 et verification de la replication (corrigera aussi la regle PingCastle A-NotEnoughDC)
- GPO de durcissement (mot de passe, LAPS, Protected Users, restriction de login par tier)
- Re-scanner avec PingCastle apres les corrections pour mesurer la progression

## captures/

Captures brutes et annotees des etapes ci-dessus.

## scripts/

Scripts idempotents reutilisables pour reconstruire cette partie du lab.

## data/

Jeux de donnees (CSV) consommes par les scripts.

## pingcastle/

Rapports d'audit PingCastle (HTML complet + captures), un par date de scan, pour suivre la progression du score dans le temps.
