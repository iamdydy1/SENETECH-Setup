# SENETECH — Architecture d'installation et de mise à jour

## Principe

GitHub reste la source de vérité pour le code, les branches, les versions, les manifests, les changelogs et les releases.

La version installable de SENETECH ne doit plus mettre à jour son propre runtime en empilant des patches dans `Program Files`. Chaque version installable doit être publiée sous forme d'un **installateur complet Inno Setup**.

## Règle de nommage

Le fichier réellement installé reste toujours :

`C:\Program Files\SENETECH\SENETECH-Setup.exe`

Il ne doit jamais être renommé avec le numéro de version. Cela garantit que les raccourcis, la désinstallation Windows et les appels internes pointent toujours vers le même exécutable.

Le fichier téléchargé depuis GitHub Releases est, lui, versionné :

- `SENETECH-Setup-1.6.0.26-DEV.exe`
- `SENETECH-Setup-1.6.0.27-DEV.exe`
- `SENETECH-Setup-1.6.1.0-STABLE.exe`

## Identité Windows permanente

Toutes les versions Stable et Developer utilisent le même Inno Setup `AppId` :

`{D57F5D8B-58E9-4D92-9D48-6EA0A2AC3F2E}`

**Ne jamais modifier cet AppId.** C'est lui qui permet à Windows/Inno Setup de reconnaître les futures versions comme des mises à jour de la même application au lieu de créer plusieurs installations distinctes.

## Ce qu'une mise à jour doit faire

1. SENETECH lit le manifest GitHub du canal sélectionné.
2. Il compare la version installée avec la version distante.
3. Il télécharge l'installateur complet depuis une GitHub Release.
4. Il vérifie la taille et le SHA-256 du fichier téléchargé.
5. Il lance l'installateur Inno Setup.
6. Inno Setup ferme SENETECH si nécessaire.
7. Inno Setup supprime uniquement les anciens fichiers runtime gérés par SENETECH, puis copie le runtime complet de la nouvelle version.
8. Les logs, consentements Reporter et données persistantes placés dans `C:\ProgramData\SENETECH` ne sont pas supprimés.
9. L'application conserve le même chemin et le même nom `SENETECH-Setup.exe`.
10. Après installation validée, SENETECH peut être relancé.

## Pourquoi on ne garde pas plusieurs EXE installés

Il ne faut pas avoir :

- `SENETECH-Setup-1.6.0.25.exe`
- `SENETECH-Setup-1.6.0.26.exe`
- `SENETECH-Setup-1.6.0.27.exe`

à l'intérieur de `Program Files`.

Cela compliquerait les raccourcis, le démarrage, la désinstallation et la détection de version. Seul **l'installateur téléchargé** porte la version. L'application installée garde un nom fixe.

## Stable / Developer / Portable / Recovery

### Stable

- Branche GitHub : `main`
- Installateur complet testé et publié dans GitHub Releases.
- SHA-256 obligatoire.
- Aucune dépendance à un overlay non vérifié.

### Developer

- Branche GitHub : `develop`
- Installateur complet construit depuis le commit exact testé.
- Logs Developer plus détaillés.
- Peut évoluer plus rapidement que Stable.

### Portable

- ZIP complet indépendant.
- Aucun Inno Setup requis.
- Pas d'écriture obligatoire dans `Program Files`.

### Recovery

- Package autonome conservé séparément, notamment sur clé USB.
- Ne dépend pas du bon fonctionnement du runtime actuellement installé.
- Sert uniquement à remettre SENETECH dans un état connu fonctionnel.

## Construction d'un installateur complet

La construction suit trois étapes :

1. `tools/Prepare-SenetechFullPackage.ps1` assemble un runtime complet à partir du `version.json` local du commit checkouté.
2. `tools/Build-SenetechInstaller.ps1` compile ce runtime avec `installer/SENETECH.iss`.
3. `.github/workflows/build-installer.yml` teste l'installation puis une seconde installation par-dessus la première afin de vérifier que les anciens fichiers runtime disparaissent correctement.

Le workflow produit :

- l'installateur `.exe` versionné ;
- un fichier `.sha256` ;
- `installer-manifest.json` contenant version, canal, taille et hash.

## Test d'upgrade obligatoire

Avant publication, le pipeline crée volontairement un fichier obsolète dans `_SENETECH`, relance l'installateur sur la même installation puis vérifie que ce fichier a disparu. Cela garantit que les modules supprimés dans une nouvelle version ne restent pas mélangés avec les nouveaux.

Le pipeline vérifie également qu'après mise à jour il n'existe qu'un seul exécutable applicatif nommé exactement `SENETECH-Setup.exe`.

## Migration depuis l'ancien updater à patches

Le passage à Inno Setup doit être fait progressivement :

1. conserver la Recovery actuelle comme filet de sécurité ;
2. produire un premier installateur complet Developer ;
3. le tester manuellement sur le PC de test ;
4. tester une installation par-dessus une ancienne version ;
5. seulement après validation, modifier le bouton `Mise à jour` de SENETECH pour télécharger et lancer l'installateur complet ;
6. supprimer ensuite la dépendance aux chaînes de patches pour les futures versions installables.

Tant que le premier installateur complet n'a pas passé ces tests, l'ancien mécanisme ne doit pas être retiré brutalement de la build Recovery.

## Futur manifest de mise à jour

Une version installable publiée devra exposer au minimum :

```json
{
  "version": "1.6.0.27",
  "channel": "develop",
  "packageType": "inno",
  "installerUrl": "https://github.com/.../SENETECH-Setup-1.6.0.27-DEV.exe",
  "installerSize": 123456,
  "installerSha256": "..."
}
```

Le client n'a alors plus besoin de reconstruire la version avec plusieurs patches : il vérifie un seul installateur complet et laisse Inno Setup appliquer la mise à jour.
