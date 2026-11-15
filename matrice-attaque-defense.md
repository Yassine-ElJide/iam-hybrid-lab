# Matrice attaque / defense

Synthese a remplir au fil des phases. Chaque ligne = une attaque reellement menee dans le lab, avec son correctif et sa preuve. Detail complet de chaque ligne dans [03-attaque-ad/README.md](03-attaque-ad/README.md).

| Couche | Attaque menee | Outil | Detection / correctif | Preuve | Phase |
|---|---|---|---|---|---|
| AD / LDAP | Enumeration LDAP authentifiee (bind anonyme bloque, bind utilisateur lambda reussi -> lecture de l'annuaire complet) | ldapsearch (Kali) | Detection : Event ID 4625 (echecs de bind), Event ID 1644 (requetes LDAP couteuses), Microsoft Defender for Identity en environnement pro. Correction structurelle limitee (comportement voulu d'AD) ; mitigation via bit de confidentialite sur attributs sensibles et groupe Protected Users pour comptes a privilege. | 03-attaque-ad/captures/preuve-ldap-bind-anonyme-bloque.png, preuve-ldap-enumeration-authentifiee.png | 3 |
| AD / Politique de mot de passe | Decouverte annexe via l'enumeration ci-dessus : lockoutThreshold = 0 (aucun verrouillage de compte configure, brute-force/password spraying possible sans blocage) | ldapsearch (decouverte), Set-ADDefaultDomainPasswordPolicy (correctif) | Correctif applique : LockoutThreshold 5, LockoutDuration/ObservationWindow 30 min. Verifie par re-requete LDAP post-correctif. | 03-attaque-ad/captures/preuve-correctif-lockout-policy-et-logs.png, preuve-lockout-threshold-corrige-ldap.png | 3 |
