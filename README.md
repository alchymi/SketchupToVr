# SketchUp → GLB → VR Loader

Pipeline complet pour export de modèles SketchUp en `.glb`, upload vers un backend PHP, et chargement dynamique dans une scène VR Unity (Pico / Android).

- Export depuis SketchUp via un **plugin Ruby**
- Upload vers une **API PHP** (Dockerisée, prête pour Coolify)
- Stockage des fichiers `.glb` + `manifest.json`
- Endpoint JSON pour lister tous les fichiers
- Client Unity pour :
  - lister les scènes
  - afficher le code court (type `XA1B`)
  - charger le GLB dans la scène VR

---

## ✨ Features

- **Code court unique** par fichier (4 caractères `A–Z` + `0–9`), facile à dicter/afficher.
- **Export GLB** depuis SketchUp (via exporteur GLB compatible `model.export`).
- **API REST légère** en PHP :
  - `POST /upload_glb.php` → upload + mise à jour d’un `manifest.json`
  - `GET  /list_glb.php` → liste des fichiers triés par date
- **Persistance** via volume Docker (`uploads_glb` + `manifest.json`).
- **Client Unity** :
  - récupère la liste
  - affiche un bouton par fichier
  - charge un GLB sélectionné en runtime avec **glTFast**
  - affiche le code en gros dans l’UI

---

## 🧱 Structure du projet

```bash
sketchup-glb-api/
├─ Dockerfile
├─ docker-compose.yml
├─ docker/
│  └─ php-upload.ini         # config PHP (taille d’upload, etc.)
├─ php/
│  ├─ public/
│  │  ├─ upload_glb.php      # endpoint POST (upload GLB)
│  │  ├─ list_glb.php        # endpoint GET (liste des fichiers)
│  │  └─ uploads_glb/        # dossiers des .glb + manifest.json (via volume)
│  └─ src/
│     ├─ config.php          # constantes + BASE_PUBLIC_URL
│     └─ helpers.php         # helpers JSON, CORS, manifest, code court
└─ vr_exporter.rb            # plugin SketchUp (Ruby)
```
