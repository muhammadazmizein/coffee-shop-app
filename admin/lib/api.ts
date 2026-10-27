const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000';
const TOKEN_KEY = 'kopi_admin_token';

export const getToken = () => (typeof window === 'undefined' ? null : localStorage.getItem(TOKEN_KEY));
export const setToken = (t: string | null) => (t ? localStorage.setItem(TOKEN_KEY, t) : localStorage.removeItem(TOKEN_KEY));

export class ApiError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

export async function api<T = unknown>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = getToken();
  let res: Response;
  try {
    res = await fetch(API + path, {
      method: init.method ?? 'GET',
      headers: {
        ...(init.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    });
  } catch {
    throw new ApiError('Tidak dapat terhubung ke server', 0);
  }
  if (res.status === 401 && token) {
    setToken(null);
    window.location.href = '/login';
  }
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const m = data?.message;
    throw new ApiError(Array.isArray(m) ? m.join(', ') : (m ?? `Error ${res.status}`), res.status);
  }
  return data as T;
}

/** URL gambar dari path relatif server ("/uploads/x.png") atau URL penuh. */
export const assetUrl = (path: string | null | undefined) => (path ? (path.startsWith('/') ? API + path : path) : null);

/** Unggah satu file (multipart). Content-Type sengaja tidak diset: browser mengisi boundary-nya sendiri. */
export async function uploadFile<T = unknown>(path: string, file: File, field = 'file'): Promise<T> {
  const token = getToken();
  const body = new FormData();
  body.append(field, file);
  let res: Response;
  try {
    res = await fetch(API + path, { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body });
  } catch {
    throw new ApiError('Tidak dapat terhubung ke server', 0);
  }
  if (res.status === 401 && token) {
    setToken(null);
    window.location.href = '/login';
  }
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const m = data?.message;
    throw new ApiError(res.status === 413 ? 'Ukuran foto melebihi 3 MB' : Array.isArray(m) ? m.join(', ') : (m ?? `Error ${res.status}`), res.status);
  }
  return data as T;
}

export const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID');

export interface Me {
  id: string;
  name: string | null;
  phone: string;
  role: 'CUSTOMER' | 'STAFF' | 'ADMIN';
}
