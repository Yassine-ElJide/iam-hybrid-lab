# 00 - Architecture

## Hyperviseur

VMware Workstation Pro (licence gratuite usage personnel, v17.5+).

## Reseau

- Type : reseau isole Hote uniquement (VMware), pas de pont, pas de NAT direct sur les cartes isolees
- Plage : 192.168.100.0/24
- Chaque VM dispose en plus d'une seconde carte en NAT (VMnet8) pour les mises a jour Windows et le telechargement d'outils. Le service DNS Server (une fois installe sur DC-01) est restreint a ecouter uniquement sur l'interface isolee.

## Plan d'adressage

| VM | Role | OS | IP (isole) |
|---|---|---|---|
| DC-01 | Controleur de domaine | Windows Server 2022 | 192.168.100.10 |
| WST-01 | Poste utilisateur | Windows 11 Pro | 192.168.100.30 |

## Decisions et deviations par rapport au plan initial

- Sous-reseau choisi : 192.168.100.0/24 (au lieu de 192.168.50.0/24 initialement envisage).
- Convention de nommage : <role>-<numero> avec tiret (DC-01, WST-01).
- Deux cartes reseau par VM plutot qu'une bascule manuelle : une isolee (lab), une NAT (mises a jour). Choix pragmatique de lab, documente comme tel.

## Incident resolu

Le ping croise entre DC-01 et WST-01 echouait initialement malgre une configuration IP correcte. Cause : le pare-feu Windows bloque les requetes ICMPv4 Echo Request entrantes par defaut. Resolu par l'ajout d'une regle dediee (voir captures dans 01-ad-core/captures/).
