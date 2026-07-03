import cloudscraper, sys, json

scraper = cloudscraper.create_scraper(
    browser={'browser': 'chrome', 'platform': 'windows', 'mobile': False},
    delay=3000
)

slugs = sys.argv[1:]
if not slugs:
    print(json.dumps({"error": "no slugs"}))
    sys.exit(1)

# Warm up homepage
scraper.get('https://kick.com/')

result = {}
for slug in slugs:
    try:
        r = scraper.get(
            f'https://kick.com/api/v2/channels/{slug}',
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json',
                'Referer': 'https://kick.com/',
                'Origin': 'https://kick.com'
            },
            timeout=15
        )
        if r.status_code == 200:
            data = r.json()
            result[slug] = data.get('followers_count', 0)
        else:
            result[slug] = None
    except Exception as e:
        result[slug] = None

print(json.dumps(result))