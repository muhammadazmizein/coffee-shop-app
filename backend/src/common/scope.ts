import { ForbiddenException } from '@nestjs/common';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { AuthUser } from './auth.js';

/** Outlet yang boleh diakses: admin semua (undefined), staff hanya outletnya. */
export async function outletScope(prisma: PrismaService, user: AuthUser): Promise<string | undefined> {
  if (user.role === 'ADMIN') return undefined;
  const u = await prisma.user.findUniqueOrThrow({ where: { id: user.id } });
  if (!u.outletId) throw new ForbiddenException('Akun staff belum terhubung ke outlet');
  return u.outletId;
}
