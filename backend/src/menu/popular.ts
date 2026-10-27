export const POPULAR_LIMIT = 8;
export const POPULAR_DAYS = 30;

/**
 * Urutkan produk terlaris: qty terjual menurun (id naik sebagai pemutus seri agar hasil stabil),
 * hanya produk yang boleh tampil (`allowed`), maksimal `limit`.
 */
export function rankPopular(sold: { productId: string; qty: number }[], allowed: Set<string>, limit = POPULAR_LIMIT): string[] {
  return sold
    .filter((s) => s.qty > 0 && allowed.has(s.productId))
    .sort((a, b) => b.qty - a.qty || a.productId.localeCompare(b.productId))
    .slice(0, limit)
    .map((s) => s.productId);
}
