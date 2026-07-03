# kick-lol-es.ps1 — Detecta streamers hispanohablantes en Kick por categoría

## Requisitos

- PowerShell 5.1+
- Python + `cloudscraper` (`pip install cloudscraper`)
- Kick Dev App (client_credentials)

## Ejecución

Windows puede abrir `.ps1` con editor en vez de ejecutarlo. Usá estos comandos en terminal:

```powershell
# Opción A: ejecución directa con política bypass
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\kick-lol-es.ps1 -Category "Just Chatting"

# Opción B: con powershell -File
powershell -File .\kick-lol-es.ps1 -Category "Just Chatting"
```

## Setup

```powershell
powershell -File .\kick-lol-es.ps1 -Setup
```
Guarda Client ID y Client Secret en `.kick-credentials.json`.

O usa variables de entorno:
```powershell
$env:KICK_CLIENT_ID = "tu_id"
$env:KICK_CLIENT_SECRET = "tu_secret"
```

## Uso básico

> **Categorías:** usá el nombre exacto que aparece en Kick (insensible a mayúsculas).
> Ej: `"Just Chatting"`, `"VALORANT"`, no `"just-chatting"` ni `"valorant"`.
> **Idioma:** `-Language "es"` por defecto. Podés combinar: `"es,en"`, `"es,pt"`, `"en"`, etc.

```powershell
# League of Legends - español (default)
.\kick-lol-es.ps1

# Otra categoría
.\kick-lol-es.ps1 -Category "VALORANT"
.\kick-lol-es.ps1 -Category "Counter-Strike 2"
.\kick-lol-es.ps1 -Category "Just Chatting"

# Especificar idiomas
.\kick-lol-es.ps1 -Category "VALORANT" -Language "es,en"    # español + inglés
.\kick-lol-es.ps1 -Category "CS2" -Language "es,pt"         # español + portugués
.\kick-lol-es.ps1 -Category "Just Chatting" -Language "en"  # solo inglés

# Combinar categoría + idioma + actualizar seguidores
.\kick-lol-es.ps1 -Category "VALORANT" -Language "es,en" -UpdateFollowers
```

## Mantenimiento

```powershell
# Refrescar seguidores de canales existentes (categoría default)
.\kick-lol-es.ps1 -UpdateFollowers

# Refrescar seguidores de otra categoría
.\kick-lol-es.ps1 -Category "Just Chatting" -UpdateFollowers
```

## Archivos

| Archivo | Propósito |
|---------|-----------|
| `streamers-{categoria}-es.json` | DB de canales detectados |
| `streamers-{categoria}-es.md` | Reporte markdown |
| `.kick-credentials.json` | Credenciales OAuth |
| `get_followers.py` | Helper Python para cloudscraper |

Ejemplo de archivos generados:
- `streamers-VALORANT-es.json`
- `streamers-Counter-Strike-2-es.md`

## Cómo funciona

1. Busca la categoría en la API de Kick (`/public/v2/categories?name=...`)
2. Obtiene todos los streams en vivo de esa categoría (con paginación)
3. Detecta canales en español por: language badge, título, o bio
4. Descarta falsos positivos portugueses
5. Acumula en DB (sin duplicados, por slug)
6. Obtiene seguidores reales vía cloudscraper (bypass Cloudflare)
7. Genera reporte markdown
