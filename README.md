# LogMeIn

## Démarrage rapide

1. Cloner le repo, aller dans le dossier
2. `docker compose up -d --build`
3. Accéder au dashboard sur http://localhost:3000

- Frontend (statique) sur Nginx, reverse proxy via Nginx
- Backend Flask (API REST) sur port 5000 (caché par le reverse proxy)
- PostgreSQL pour la base de logs
- Tous les services connectés via Docker Compose

**Pour reset tous les logs** : clique sur “Vider”
