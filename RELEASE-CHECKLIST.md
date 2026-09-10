# SENETECH Setup V1.6 — Checklist avant Stable

Aucune build V1.6 ne doit être promue sur `main` tant que les contrôles critiques ci-dessous ne sont pas validés sur de vraies machines.

## 1. Mise à jour SENETECH

- [ ] Mode Installé : détecte une build Develop plus récente.
- [ ] Mode Installé : télécharge, applique puis relance SENETECH automatiquement.
- [ ] Mode Portable : détecte une build Develop plus récente.
- [ ] Mode Portable : télécharge, applique puis relance SENETECH depuis son dossier portable.
- [ ] La sauvegarde/rollback de la version SENETECH précédente existe avant remplacement.
- [ ] Le rollback restaure réellement la version précédente.
- [ ] Une mise à jour incomplète ne lance pas un runtime partiel.

## 2. Démarrage et compatibilité

- [ ] Windows 10 22H2 x64 : démarrage sans erreur.
- [ ] Windows 11 x64 : démarrage sans erreur.
- [ ] Résolution 1366×768 : interface principale lisible.
- [ ] Full HD ou supérieur : interface principale lisible.
- [ ] Mise à l’échelle Windows 100 % / 125 % / 150 % : aucun contrôle important coupé.
- [ ] Aucun caractère corrompu (`â€”`, `Ã©`, etc.).
- [ ] Le numéro de build Develop visible correspond à la version technique.

## 3. Catalogue et profils

- [ ] Le catalogue distant se charge.
- [ ] Le catalogue local prend le relais hors ligne.
- [ ] Toutes les applications ont une clé et un ID WinGet valides.
- [ ] Aucun ID ou clé dupliqué.
- [ ] Toutes les applications référencées par les profils existent dans le catalogue.
- [ ] Essentiel, Bureautique, Étudiant, Gaming, Créateur, Développement, PC léger et Personnalisé sélectionnent les bonnes applications.

## 4. WinGet et applications

- [ ] WinGet déjà présent : détecté sans réparation inutile.
- [ ] App Installer présent mais alias WinGet absent : WinGet est retrouvé/réenregistré.
- [ ] WinGet réellement absent : bootstrap automatique testé.
- [ ] Application déjà installée : SENETECH la détecte et évite une installation inutile.
- [ ] Application absente : téléchargement/installation effectués.
- [ ] Après chaque installation, SENETECH vérifie que l’application est réellement détectée.
- [ ] Un code installateur `0` sans application détectée est signalé comme échec de vérification.
- [ ] Une application en échec n’est jamais affichée comme réussie.

## 5. Cache USB hors ligne

- [ ] Cache déjà présent : détecté.
- [ ] Empreinte SHA-256 du cache créée et contrôlée.
- [ ] Cache modifié/corrompu : refusé.
- [ ] Nouveau téléchargement valide : ancien cache conservé jusqu’à validation du nouveau.
- [ ] Échec du nouveau téléchargement : ancien cache conservé.
- [ ] Installation hors ligne : l’installateur est vérifié avant exécution.
- [ ] Application absente du cache : message explicite et statut d’échec.

## 6. Sauvegarde avant préparation

- [ ] Une sauvegarde d’état JSON est créée avant toute préparation.
- [ ] Son SHA-256 est enregistré et revérifié au contrôle final.
- [ ] La sauvegarde contient au minimum : applications présentes, éléments de démarrage, pilotes signés, profil choisi et applications demandées.
- [ ] Si la sauvegarde d’état ne peut pas être créée, la préparation s’arrête avant les modifications.
- [ ] Le point de restauration Windows est testé lorsque l’option est active.

## 7. Windows Update et pilotes

- [ ] Recherche Windows Update fonctionne sur Windows 10.
- [ ] Recherche Windows Update fonctionne sur Windows 11.
- [ ] Mises à jour facultatives/Preview exclues par défaut.
- [ ] Pilotes Windows Update installés lorsque demandés.
- [ ] Les codes Microsoft Update `Failed` ou `Aborted` sont remontés comme échec.
- [ ] `SucceededWithErrors` est journalisé comme avertissement.
- [ ] Besoin de redémarrage correctement détecté.
- [ ] Pilotes INF hors ligne testés sur une machine appropriée.

## 8. Outils technicien

- [ ] Création du point de restauration.
- [ ] Mise à jour des applications déjà installées.
- [ ] Nettoyage Windows.
- [ ] Gestionnaire de démarrage : liste lisible.
- [ ] Désactivation d’un élément non critique puis restauration réussie.
- [ ] Optimisations Gaming appliquées puis annulées.
- [ ] Optimisations PC léger appliquées puis annulées.
- [ ] Actualisation du catalogue.

## 9. Contrôle final automatique

- [ ] Toutes les applications sélectionnées sont revérifiées.
- [ ] La sauvegarde d’état est revérifiée.
- [ ] Les périphériques en erreur sont signalés.
- [ ] L’état du stockage est signalé lorsqu’il nécessite un contrôle.
- [ ] L’activation Windows non active est signalée.
- [ ] Les avertissements et échecs apparaissent dans le journal et le rapport.
- [ ] Un PC avec un échec bloquant n’est pas annoncé comme « validé ».

## 10. Livraison / Vente

- [ ] Fenêtre Finaliser pour la vente lisible sur petit écran.
- [ ] Voir les applications détectées s’ouvre sans fermer SENETECH.
- [ ] Les applications protégées sont correctement marquées CONSERVER.
- [ ] Mode PC configuré client : applications choisies conservées.
- [ ] Mode PC propre : seules les applications tierces non protégées sont retirées.
- [ ] Pilotes, runtimes et composants Windows protégés ne sont pas supprimés.
- [ ] Nettoyage des traces technicien effectué.
- [ ] Suppression différée du profil technicien testée.
- [ ] Sysprep/OOBE termine sans erreur.
- [ ] PC s’éteint après finalisation.
- [ ] Au démarrage client : écran Windows Bienvenue/OOBE.
- [ ] SENETECH Welcome apparaît une seule fois sur le nouveau profil lorsque demandé.
- [ ] « Non merci » ferme définitivement SENETECH Welcome.
- [ ] Installation d’applications depuis SENETECH Welcome testée.

## Matrice minimale avant promotion Stable

| Test | Windows 10 laptop | Windows 11 PC | Obligatoire |
|---|---|---|---|
| Démarrage/UI | ⬜ | ⬜ | Oui |
| Mise à jour Installé | ⬜ | ⬜ | Oui |
| Mise à jour Portable | ⬜ | ⬜ | Oui |
| WinGet | ⬜ | ⬜ | Oui |
| Profil Essentiel | ⬜ | ⬜ | Oui |
| Cache hors ligne | ⬜ | ⬜ | Oui |
| Windows Update/pilotes | ⬜ | ⬜ | Oui |
| Contrôle final | ⬜ | ⬜ | Oui |
| Livraison/OOBE | ⬜ | Optionnel | Oui sur au moins une machine dédiée à la vente |
| SENETECH Welcome | ⬜ | Optionnel | Oui sur au moins une machine dédiée à la vente |

**Règle de promotion :** zéro échec critique connu. Les avertissements acceptés doivent être documentés avant le passage de `develop` vers `main`.
