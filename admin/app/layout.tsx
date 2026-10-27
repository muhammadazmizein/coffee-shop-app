import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Kopi App Admin',
  description: 'Panel staff dan admin Kopi App',
};

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
