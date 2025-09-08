export interface Env {
  OPENAI_API_KEY: string;
  TAVILY_API_KEY: string;
}

type TavilyResult = {
  results: Array<{ url: string; content: string }>
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/ai/estimate_density') {
      try {
        const body = await request.json<{ brand?: string }>();
        const brand = (body.brand || '').trim();
        if (!brand) return json({ error: 'brand required' }, 400);

        const debug = url.searchParams.get('debug') === '1';
        const meta: any = { step: 'start' };

        // Web search via Tavily (send api_key in body for broader compatibility)
        const tavReq = {
          query: `${brand} dog food grams per cup`,
          max_results: 5,
          api_key: env.TAVILY_API_KEY,
        };
        const tavResp = await fetch('https://api.tavily.com/search', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(tavReq)
        });
        meta.tavily_status = tavResp.status;
        const tav: TavilyResult = await tavResp.json().catch(() => ({ results: [] } as any));
        meta.tavily_results = Array.isArray((tav as any).results) ? (tav as any).results.length : 0;

        // Compose context
        const context = tav.results?.map(r => `URL: ${r.url}\nCONTENT: ${truncate(r.content, 3000)}`).join('\n\n') || '';

        // Rank and validate sources (prefer manufacturer/retailer pages)
        const ranked = rankUrls(((tav.results || []).map(r => r.url))).slice(0, 12);
        const live = await filterLiveUrls(ranked, 3);

        const prompt = `You are a precise nutrition data extractor. Given context from the web about a dry dog food brand, extract its grams per cup value (g/cup). If multiple, pick the most reliable. If unclear, estimate a reasonable typical value for dry kibble and say why in a one-line note. Output STRICT JSON with keys: grams_per_cup (number), sources (array of URLs).

BRAND: ${brand}
CONTEXT:\n${truncate(context, 12000)}
`;

        // Call OpenAI
        const openaiResp = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${env.OPENAI_API_KEY}` },
          body: JSON.stringify({
            model: 'gpt-4o-mini',
            messages: [
              { role: 'system', content: 'Return only valid JSON. No preface.' },
              { role: 'user', content: prompt }
            ],
            temperature: 0.2,
            response_format: { type: 'json_object' }
          })
        });
        meta.openai_status = openaiResp.status;
        const data = await openaiResp.json<any>().catch(() => ({}));
        const text = data.choices?.[0]?.message?.content || '';

        // Parse JSON; sanitize minimal
        let out: any;
        try { out = JSON.parse(text); } catch { out = safeJson(text); }
        if (typeof out?.grams_per_cup !== 'number') {
          // fallback typical density
          out = { grams_per_cup: 112, sources: tav.results?.map(r => r.url).slice(0,3) || [] };
        }
        const payload: any = { brand, grams_per_cup: Math.round(out.grams_per_cup), sources: live };
        if (debug) payload.debug = meta;
        return json(payload);
      } catch (e) {
        return json({ error: 'failed', message: String(e) }, 500);
      }
    }

    return json({ ok: true });
  }
} satisfies ExportedHandler<Env>;

function json(obj: any, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json' } });
}

function truncate(s: string, n: number): string {
  return s && s.length > n ? s.slice(0, n) : s;
}

function safeJson(s: string): any {
  try { return JSON.parse(s.replace(/^```json|```$/g, '')); } catch { return {}; }
}

async function filterLiveUrls(urls: string[], max: number): Promise<string[]> {
  const out: string[] = [];
  for (const u of urls) {
    try {
      const clean = sanitizeUrl(u);
      if (!clean) continue;
      // Try GET first bytes (some sites don't support HEAD correctly)
      const res = await fetch(clean, { method: 'GET', redirect: 'follow' as RequestRedirect });
      if (!res.ok || res.status !== 200) continue;
      const finalUrl = res.url || clean;
      // Basic content sanity
      const ct = res.headers.get('content-type') || '';
      const lenHdr = res.headers.get('content-length');
      const len = lenHdr ? parseInt(lenHdr) : undefined;
      if (!ct.includes('text/html')) { out.push(finalUrl); }
      else {
        if (len !== undefined && len < 800) continue;
        const text = await res.text();
        if (text && text.length > 800 && !/404|not found|moved|no longer exists/i.test(text)) out.push(finalUrl);
      }
    } catch (_) {}
    if (out.length >= max) break;
  }
  return out;
}

function rankUrls(urls: string[]): string[] {
  const allow = [
    'purina.com', 'hillspet.com', 'royalcanin.com', 'bluebuffalo.com',
    'orijen.ca', 'acana.com', 'chewy.com', 'petsmart.com', 'petco.com', 'zooplus.com'
  ];
  const prefer = allow
    .map(d => d.split('.')[0])
    .concat(['nutrition', 'feeding', 'kcal']);
  const avoid = ['facebook.', 'pinterest.', 'twitter.', 'x.com', 'tiktok.', 'instagram.'];
  const score = (u: string): number => {
    const l = u.toLowerCase();
    let s = 0;
    for (const p of prefer) if (l.includes(p)) s += 2;
    for (const a of avoid) if (l.includes(a)) s -= 3;
    if (l.startsWith('https://')) s += 1;
    if (l.includes('nutrition') || l.includes('feeding') || l.includes('kcal')) s += 1;
    return s;
  };
  return urls
    .map(sanitizeUrl)
    .filter((u): u is string => !!u)
    // Allowlist: keep only trusted domains
    .filter(u => {
      try { const h = new URL(u).hostname.toLowerCase(); return allow.some(d => h.endsWith(d)); } catch { return false; }
    })
    .sort((a, b) => score(b) - score(a));
}

function sanitizeUrl(u?: string | null): string | null {
  if (!u) return null;
  let s = u.trim();
  if (s.startsWith('@')) s = s.slice(1);
  // Remove stray spaces and control chars
  s = s.replace(/\s+/g, '');
  // Drop if missing protocol
  if (!/^https?:\/\//i.test(s)) return null;
  // Drop obviously truncated URLs
  const path = (() => { try { return new URL(s).pathname; } catch { return ''; } })();
  if (s.endsWith('-') || s.endsWith('/a') || s.endsWith('-a') || s.length < 15) return null;
  if (path && /\/[A-Za-z]$/.test(path)) return null; // single-letter tail segment
  try {
    const url = new URL(s);
    if (!url.hostname || url.hostname.length < 4) return null;
    return url.toString();
  } catch {
    return null;
  }
}



