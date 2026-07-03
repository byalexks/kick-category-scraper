# Kick Category Scraper

Busca streamers en Kick por **categoría** e **idioma**, acumula una base de datos deduplicada, obtiene seguidores reales (bypass Cloudflare), y genera un reporte markdown.

## Requisitos

- PowerShell 5.1+
- Python 3 + `cloudscraper` (`pip install cloudscraper`)
- Kick Dev App (client_credentials) — [dev.kick.com](https://dev.kick.com)

## Setup

```powershell
# Guardar credenciales (solo una vez)
powershell -File .\kick-lol-es.ps1 -Setup

# O usar variables de entorno
$env:KICK_CLIENT_ID = "tu_id"
$env:KICK_CLIENT_SECRET = "tu_secret"
```

## Uso

```powershell
# League of Legends — español
.\kick-lol-es.ps1

# Por categoría
.\kick-lol-es.ps1 -Category "VALORANT"
.\kick-lol-es.ps1 -Category "Just Chatting"
.\kick-lol-es.ps1 -Category "Counter-Strike 2"

# Por idioma (default: "es")
.\kick-lol-es.ps1 -Category "VALORANT" -Language "es,en"         # español + inglés
.\kick-lol-es.ps1 -Category "VALORANT" -Language "es,pt"         # español + portugués
.\kick-lol-es.ps1 -Category "Just Chatting" -Language "en"       # solo inglés
.\kick-lol-es.ps1 -Category "VALORANT" -Language "es,en,pt"      # los tres

# Refrescar seguidores de canales existentes
.\kick-lol-es.ps1 -UpdateFollowers
.\kick-lol-es.ps1 -Category "VALORANT" -Language "es,en" -UpdateFollowers

# Si Windows abre el .ps1 con el editor:
powershell -File .\kick-lol-es.ps1 -Category "Just Chatting"
```

## Categorías

Usá el nombre exacto que aparece en Kick (insensible a mayúsculas). No el slug de la URL.

| Correcto | Incorrecto |
|----------|------------|
| `"Just Chatting"` | `"just-chatting"` |
| `"Counter-Strike 2"` | `"cs2"` |

## Cómo funciona

1. **Autenticación** via OAuth client_credentials
2. **Busca la categoría** en la API pública de Kick (`/public/v2/categories`)
3. **Obtiene todos los streams en vivo** con paginación (`/public/v2/livestreams`)
4. **Detecta idioma** en 2 pasadas:
   - 1ª: language_code de la API + palabras clave en el título
   - 2ª: palabras clave en la bio del canal (batch vía `/public/v1/channels`)
5. **Acumula en DB** (JSON, deduplicado por slug, nunca borra canales)
6. **Obtiene seguidores reales** via Python + `cloudscraper` (bypass Cloudflare contra `kick.com/api/v2/channels/{slug}`)
7. **Genera reporte** markdown con tabla de canales

## Archivos

| Archivo | Propósito |
|---------|-----------|
| `kick-lol-es.ps1` | Script principal |
| `get_followers.py` | Helper Python con cloudscraper |
| `streamers-{categoria}-{idioma}.json` | DB acumulada |
| `streamers-{categoria}-{idioma}.md` | Reporte generado |
| `.kick-credentials.json` | Credenciales OAuth (no se sube) |

## Ejemplos de archivos generados

- `streamers-VALORANT-es.json`
- `streamers-VALORANT-es_en.md`
- `streamers-Just-Chatting-es.json`
