# 01 - AD Core

## Statut

En cours. VM provisionnees et reseau valide. Promotion de la foret lab.local a venir.

## VM concernees

- DC-01 (Windows Server 2022, 192.168.100.10) : destine a devenir le premier controleur de domaine.
- WST-01 (Windows 11 Pro, 192.168.100.30) : poste utilisateur standard, rejoindra le domaine en phase 2.

## Etapes realisees

1. Provisionnement DC-01 et WST-01, IP fixes, reseau isole valide (voir 00-architecture/).
2. Resolution d'un blocage ping inter-VM (regle pare-feu ICMPv4 entrant desactivee par defaut) - voir captures/.

## Etapes a venir

- Installation du role AD DS sur DC-01.
- Promotion de la foret lab.local (NetBIOS LAB), role DNS Server inclus.
- Creation de l'arborescence d'OU et d'un jeu de 20-30 utilisateurs depuis un CSV.
- GPO de base : politique de mot de passe, restriction d'ouverture de session, desactivation SMBv1.
- Script Ansible/PowerShell idempotent pour recreer les OU.
- Premier passage PingCastle.

## captures/

Preuves annotees (pare-feu, connectivite reseau) au format PNG, cadre rouge sur l'element probant.
