export const MAX_TEXT_CODE_POINTS = 4000;

export interface ReportPayload {
  kind: string;
  source: 'website';
  text: string;
  homepage: string;
}

export type PayloadResult = { payload: ReportPayload } | { error: string };

export type SendState =
  | { state: 'sent' }
  | { state: 'rejected'; reason: string | null }
  | { state: 'rate-limited'; minutes: number | null }
  | { state: 'network-error' };

export function codePointCount(text: string): number {
  let n = 0;
  for (const _ of text) n += 1;
  return n;
}

export function buildPayload(kind: string, text: string, homepage: string): PayloadResult {
  if (text.trim() === '') return { error: 'empty text' };
  if (codePointCount(text) > MAX_TEXT_CODE_POINTS) return { error: 'text too long' };
  return { payload: { kind, source: 'website', text, homepage } };
}

export function retryMinutes(retryAfter: string | null): number | null {
  if (retryAfter === null || !/^\d+$/.test(retryAfter.trim())) return null;
  return Math.max(1, Math.ceil(Number(retryAfter) / 60));
}

async function workerError(res: Response): Promise<string | null> {
  try {
    const body: unknown = await res.json();
    const error = (body as { error?: unknown } | null)?.error;
    return typeof error === 'string' ? error : null;
  } catch {
    return null;
  }
}

export async function stateFromResponse(res: Response): Promise<SendState> {
  if (res.status === 202) return { state: 'sent' };
  if (res.status === 429) return { state: 'rate-limited', minutes: retryMinutes(res.headers.get('Retry-After')) };
  if (res.status >= 400 && res.status < 500) return { state: 'rejected', reason: await workerError(res) };
  return { state: 'network-error' };
}

export async function sendReport(
  url: string,
  payload: ReportPayload,
  fetchFn: typeof fetch = fetch
): Promise<SendState> {
  let res: Response;
  try {
    res = await fetchFn(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch {
    return { state: 'network-error' };
  }
  return stateFromResponse(res);
}
