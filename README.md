# IAM Hybrid Lab

Un environnement d'identite hybride construit, attaque et defendu couche par couche - AD on-premise, Entra ID, Keycloak, PAM, IGA, PKI, SOC - avec preuves a l'appui.

**Statut : en cours - Phase 1 (socle AD)**

## Pourquoi ce lab

Ce projet reproduit, a l'echelle d'un lab personnel, l'architecture d'identite d'un grand groupe. Chaque brique suit le meme cycle : construire -> automatiser -> attaquer -> defendre -> documenter. L'objectif n'est pas de collectionner des outils, mais de pouvoir expliquer en entretien comment un chemin d'attaque a ete trouve, pourquoi le correctif choisi fonctionne, et prouver les deux.

Lab isole, a usage pedagogique uniquement. Aucune donnee reelle, aucun secret reel, aucune exposition Internet. Chaque element est explicitement etiquete lab vs production.

## Architecture cible

| Couche | Briques | Statut |
|---|---|---|
| Annuaire central | AD DS (1 DC, DC-02 a venir), DNS, GPO | En cours |
| Synchronisation | Entra Connect / Cloud Sync | Planifie |
| Identite cloud | Entra ID (tenant d'essai) | Planifie |
| Federation applicative | Keycloak (SSO SAML/OIDC) | Planifie |
| Acces a privileges | Bastion PAM | Planifie |
| Gouvernance | midPoint / Entra ID Governance | Planifie |
| PKI | AD CS / step-ca | Planifie |
| Supervision / SOC | Wazuh, Sysmon | Planifie |

## Structure du depot

| Dossier | Contenu |
|---|---|
| [00-architecture/](00-architecture/) | Schemas reseau, plan d'adressage, decisions |
| [01-ad-core/](01-ad-core/) | Foret, DC, tiering/OU, provisioning, delegation, audit PingCastle |
| [02-postes/](02-postes/) | Jonction au domaine, tiering des postes |
| [03-attaque-ad/](03-attaque-ad/) | Scripts et preuves des attaques AD |
| [04-entra-hybride/](04-entra-hybride/) | Conditional Access, PIM, synchronisation |
| [05-keycloak-sso/](05-keycloak-sso/) | Realm, configuration, app de test |
| [06-pam/](06-pam/) | Configuration du bastion |
| [07-iga/](07-iga/) | Cycle JML, revues d'acces |
| [08-pki-soc/](08-pki-soc/) | PKI, regles de detection |
| [09-pra-crise/](09-pra-crise/) | Runbook, tests de restauration |
| [matrice-attaque-defense.md](matrice-attaque-defense.md) | Synthese attaque -> correctif -> preuve |

## Progression

- [x] Reseau virtuel isole + hyperviseur
- [x] DC-01 provisionne (Windows Server 2022)
- [x] WST-01 provisionne (Windows 11 Pro)
- [x] Connectivite reseau validee (pare-feu ICMP, ping croise)
- [x] Foret AD lab.local promue
- [x] OU et utilisateurs (modele de tiering Tier 0/1/2, provisioning CSV)
- [x] Groupes de securite par tier + premiere delegation (dsacls)
- [x] Jonction WST-01 au domaine + test de connexion utilisateur Tier2
- [x] Premiere attaque documentee : enumeration LDAP authentifiee (quoi/comment/detection/correction)
- [x] Premier rapport PingCastle (baseline : 55/100, plan de remediation priorise)
- [ ] Test de delegation GG-Tier2-HelpDesk (preuve positive + negative) - en pause
- [ ] Remediation PingCastle (corrections rapides, puis GPO)
- [ ] DC-02 + replication
- [ ] GPO de durcissement (mot de passe, LAPS, Protected Users, restriction de login par tier)

L'historique des commits reflete l'avancement reel, jour par jour.

## A propos

Yassine El Jide - ingenieur reseau/securite, en montee en competence AD/IAM (SC-300 en preparation). Ce lab accompagne ma recherche d'un poste d'expert AD/IAM.
