-- CreateTable
CREATE TABLE `Promo` (
    `id` VARCHAR(191) NOT NULL,
    `title` VARCHAR(60) NOT NULL,
    `body` VARCHAR(160) NOT NULL,
    `imageUrl` VARCHAR(191) NULL,
    `art` VARCHAR(40) NULL,
    `ctaLabel` VARCHAR(30) NULL,
    `voucherCode` VARCHAR(40) NULL,
    `sort` INTEGER NOT NULL DEFAULT 0,
    `isActive` BOOLEAN NOT NULL DEFAULT true,
    `startsAt` DATETIME(3) NULL,
    `endsAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Promo_isActive_sort_idx`(`isActive`, `sort`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

