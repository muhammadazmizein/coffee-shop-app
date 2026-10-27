import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { CurrentUser, JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { ReplaceTiersDto } from './membership.dto.js';
import { MembershipService } from './membership.service.js';

@Controller()
export class MembershipController {
  constructor(private readonly membership: MembershipService) {}

  /** Level, progres ke level berikutnya, dan daftar semua level. */
  @Get('me/membership')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthUser) {
    return this.membership.membership(user.id);
  }

  @Get('admin/tiers')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  list() {
    return this.membership.tiers();
  }

  @Put('admin/tiers')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  replace(@Body() dto: ReplaceTiersDto) {
    return this.membership.replaceTiers(dto.tiers);
  }
}
