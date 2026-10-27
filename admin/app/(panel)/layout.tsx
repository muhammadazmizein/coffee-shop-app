'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { createContext, useContext, useEffect, useState } from 'react';
import { api, getToken, setToken, type Me } from '@/lib/api';

const MeContext = createContext<Me | null>(null);
export const useMe = () => useContext(MeContext)!;

export default function PanelLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const path = usePathname();
  const [me, setMe] = useState<Me | null>(null);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    api<Me>('/me')
      .then((m) => {
        if (m.role === 'CUSTOMER') {
          setToken(null);
          router.replace('/login');
        } else setMe(m);
      })
      .catch(() => router.replace('/login'));
  }, [router]);

  if (!me) return <main className="muted">Memuat…</main>;

  const links = [
    { href: '/', label: 'Pesanan' },
    { href: '/riwayat', label: 'Riwayat' },
    { href: '/laporan', label: 'Laporan' },
    { href: '/menu', label: 'Menu' },
    ...(me.role === 'ADMIN' ? [{ href: '/vouchers', label: 'Voucher' }, { href: '/promo', label: 'Promo' }, { href: '/member', label: 'Member' }, { href: '/pengumuman', label: 'Pengumuman' }, { href: '/outlet', label: 'Outlet & kurir' }] : []),
  ];

  return (
    <MeContext.Provider value={me}>
      <header className="top">
        <strong>☕ Kopi App</strong>
        <nav>
          {links.map((l) => (
            <Link key={l.href} href={l.href} className={path === l.href ? 'active' : ''}>
              {l.label}
            </Link>
          ))}
        </nav>
        <span className="muted">{me.name ?? me.phone} • {me.role}</span>
        <button onClick={() => { setToken(null); router.replace('/login'); }}>Keluar</button>
      </header>
      <main>{children}</main>
    </MeContext.Provider>
  );
}
