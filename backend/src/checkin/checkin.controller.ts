import { Body, Controller, Get, HttpCode, Post, Put, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsArray, IsInt, ValidateNested } from 'class-validator';
import { CurrentUser, JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { CheckinService } from './checkin.service.js';

class RewardDto {
  @IsInt({ message: 'Hari harus bilangan bulat' })
  day: number;

  @IsInt({ message: 'Poin harus bilangan bulat' })
  points: number;
}

class ReplaceRewardsDto {
  @IsArray({ message: 'rewards harus berupa daftar 7 hari' })
  @ValidateNested({ each: true })
  @Type(() => RewardDto)
  rewards: RewardDto[];
}

@Controller()
export class CheckinController {
  constructor(private readonly checkin: CheckinService) {}

  @Get('me/checkin')
  @UseGuards(JwtAuthGuard)
  state(@CurrentUser() user: AuthUser) {
    return this.checkin.state(user.id);
  }

  @Post('me/checkin')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  claim(@CurrentUser() user: AuthUser) {
    return this.checkin.claim(user.id);
  }

  @Get('admin/checkin-rewards')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  rewards() {
    return this.checkin.rewards();
  }

  @Put('admin/checkin-rewards')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  replace(@Body() dto: ReplaceRewardsDto) {
    return this.checkin.replaceRewards(dto.rewards);
  }
}
