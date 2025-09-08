export interface Env {
  TAVILY_API_KEY: string;
}

type TavilyResult = {
  results: Array<{ url: string; content: string }>
}

// Simple density extractor - finds "X grams per cup" in content
class DensityExtractor {
  
  static extractDensity(brand: string, searchContent: string): {
    density: number;
    confidence: number;
    reasoning: string[];
    foundValues: number[];
  } {
    const reasoning: string[] = [];
    const foundValues: number[] = [];
    
    const contentLower = searchContent.toLowerCase();
    
    // Extract all density numbers from content
    const densityNumbers = this.findDensityNumbers(contentLower);
    
    if (densityNumbers.length > 0) {
      foundValues.push(...densityNumbers);
      reasoning.push(`Found ${densityNumbers.length} density values: ${densityNumbers.join(', ')} g/cup`);
      
      // Use average if multiple values found
      const avgDensity = Math.round(densityNumbers.reduce((a, b) => a + b, 0) / densityNumbers.length);
      
      return {
        density: avgDensity,
        confidence: 0.9,
        reasoning,
        foundValues
      };
    }
    
    // No density found - return standard fallback
    reasoning.push('No density values found in content - using standard dry kibble density');
    return {
      density: 112,
      confidence: 0.3,
      reasoning,
      foundValues: []
    };
  }
  
  // Find all variations of "X grams per cup" in content
  private static findDensityNumbers(content: string): number[] {
    const patterns = [
      // "113 grams per cup", "113g per cup", "113 g/cup"
      /(\d{2,3})\s*(?:g|grams?)\s*(?:per|\/)\s*cup/gi,
      /(\d{2,3})\s*(?:g|grams?)\s*cup/gi,
      
      // "cup weighs 113 grams", "1 cup = 113g"
      /cup.*?(?:weighs?|=|is)\s*(\d{2,3})\s*(?:g|grams?)/gi,
      /1\s*cup.*?(\d{2,3})\s*(?:g|grams?)/gi,
      
      // "density 113g", "weight per cup 113g"
      /density.*?(\d{2,3})\s*(?:g|grams?)/gi,
      /weight.*?(?:per\s*)?cup.*?(\d{2,3})\s*(?:g|grams?)/gi,
      
      // "113 grams in one cup"
      /(\d{2,3})\s*(?:g|grams?).*?(?:in\s*)?(?:one\s*|1\s*)?cup/gi,
    ];
    
    const numbers: number[] = [];
    
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        const num = parseInt(match[1]);
        // Only accept realistic density values for dry dog food
        if (num >= 85 && num <= 140) {
          numbers.push(num);
        }
      }
    }
    
    // Remove duplicates and return
    return [...new Set(numbers)];
  }
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
        const meta: any = { step: 'start', ai_type: 'density_extraction' };

        // Search for density information
        const tavReq = {
          query: `${brand} dog food grams per cup density weight`,
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

        // Combine all search content
        const searchContent = tav.results?.map(r => r.content).join('\n') || '';
        
        // Extract density from content
        const result = DensityExtractor.extractDensity(brand, searchContent);
        meta.found_values = result.foundValues.length;
        
        // Get source URLs
        const sourceUrls = tav.results?.map(r => r.url) || [];

        const payload: any = {
          brand,
          grams_per_cup: result.density,
          sources: sourceUrls.slice(0, 3), // First 3 sources
          confidence: result.confidence
        };
        
        if (debug) {
          payload.debug = meta;
          payload.reasoning = result.reasoning;
          payload.found_values = result.foundValues;
        }
        
        return json(payload);
        
      } catch (e) {
        return json({ error: 'failed', message: String(e) }, 500);
      }
    }

    return json({ ok: true, message: 'Density extraction ready' });
  }
} satisfies ExportedHandler<Env>;

function json(obj: any, status = 200): Response {
  return new Response(JSON.stringify(obj), { 
    status, 
    headers: { 'Content-Type': 'application/json' } 
  });
}