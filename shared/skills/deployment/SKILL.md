---
name: deployment
description: Conventions de déploiement — CI/CD GitHub Actions, gh CLI, Docker/docker-compose, serveurs Debian/Ubuntu, Postgres. Charger pour déployer une application, écrire un workflow CI/CD, ou diagnostiquer un déploiement.
---

# Deployment

CI/CD par défaut : **GitHub Actions**. Cibles : VPS / serveurs dédiés / NAS maison —
tous Debian/Ubuntu. Packaging : **Docker + docker-compose** (conteneurisation légère).
Base de données : PostgreSQL.

## Outils

- `gh` (GitHub CLI) — installé sur tous les postes de dev. Piloter les workflows
  depuis le terminal :

```bash
gh workflow run <workflow>       # déclencher manuellement
gh run list --workflow=<wf>      # historique des runs
gh run watch                     # suivre le run en cours
gh run view <id> --log-failed    # logs des jobs échoués
```

- `docker compose` (v2, sans tiret) pour le packaging et l'exécution.
- Ansible pour la configuration des serveurs (cf. skill `openclaw` / Nestor).

## Priorités (dans l'ordre)

1. Reproductibilité — le déploiement part de l'état du repo, jamais d'une modif manuelle sur le serveur
2. Migrations DB versionnées et réversibles, jouées avant ou avec le déploiement du code
3. Secrets hors du repo — GitHub Actions secrets en CI, fichier `.env` non versionné côté serveur
4. Healthcheck après déploiement — un déploiement n'est validé que si le service répond

## Règles absolues

- Pipeline GitHub Actions : lint + tests + build doivent passer avant tout déploiement
- Image Docker taguée par SHA de commit — jamais `latest` en production
- `docker-compose.yml` versionné ; un override (`docker-compose.prod.yml`) pour la prod
- Rollback = redéployer le tag précédent — conserver les N dernières images
- Postgres : volume nommé persistant, jamais dans le conteneur applicatif
- Pas de `ssh` + commande manuelle pour livrer — tout passe par le pipeline

Toujours vérifier le run avec `gh run watch` et confirmer le healthcheck avant de
déclarer un déploiement réussi.

## Pièges

- `ssh host 'pkill -f motif'` tue sa propre session : le motif figure dans la
  ligne de commande distante. Écrire `pkill -f '[m]otif'`.
- `docker logs --since` relit tout le fichier de log avant de filtrer (charge et
  blocage sur un gros conteneur). Utiliser `docker logs --tail N`.
- Commande sudo confiée à l'humain qui fait `git pull` puis `cp` d'une config :
  merger la PR AVANT de donner la commande, et y mettre un garde-fou
  (`grep -q <marqueur> fichier &&`). `nginx -t` valide la syntaxe, pas le
  contenu : un vieux modèle HTTP-only est passé et a cassé le HTTPS de prod.
- Derrière le nginx de l'hôte (proxy HTTP/1.0), tester gzip et les en-têtes
  via l'URL publique ou `curl --http1.0`, pas en HTTP/1.1 sur le conteneur.
