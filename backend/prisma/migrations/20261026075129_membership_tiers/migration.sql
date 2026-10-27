-- AlterTable
ALTER TABLE `Order` ADD COLUMN `earnMultiplierPct` INTEGER NOT NULL DEFAULT 100,
    ADD COLUMN `memberDiscount` INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN `tierName` VARCHAR(191) NULL;

-- AlterTable
ALTER TABLE `User` ADD COLUMN `lifetimeSpend` INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE `Tier` (
    `id` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `minSpend` INTEGER NOT NULL,
    `earnMultiplierPct` INTEGER NOT NULL DEFAULT 100,
    `discountPct` INTEGER NOT NULL DEFAULT 0,
    `maxDiscount` INTEGER NULL,
    `sort` INTEGER NOT NULL DEFAULT 0,

    UNIQUE INDEX `Tier_name_key`(`name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;


-- Data: level default (tidak menimpa bila nama sudah ada)
INSERT IGNORE INTO `Tier` (`id`, `name`, `minSpend`, `earnMultiplierPct`, `discountPct`, `maxDiscount`, `sort`) VALUES
  ('tier_member',   'Member',   0,       100, 0, NULL,  0),
  ('tier_silver',   'Silver',   500000,  125, 3, 10000, 1),
  ('tier_gold',     'Gold',     2000000, 150, 5, 15000, 2),
  ('tier_platinum', 'Platinum', 5000000, 200, 8, 25000, 3);

-- Data: belanja terbayar seumur akun dari pesanan yang sudah berstatus penjualan
UPDATE `User` u SET u.`lifetimeSpend` = COALESCE((
  SELECT SUM(o.`total`) FROM `Order` o
  WHERE o.`userId` = u.`id` AND o.`status` IN ('PAID', 'PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED')
), 0);
