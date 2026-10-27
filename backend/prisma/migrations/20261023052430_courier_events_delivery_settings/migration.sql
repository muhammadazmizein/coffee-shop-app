-- AlterTable
ALTER TABLE `Order` DROP COLUMN `courierRef`,
    ADD COLUMN `courierId` VARCHAR(191) NULL;

-- AlterTable
ALTER TABLE `Outlet` ADD COLUMN `deliveryBaseFee` INTEGER NOT NULL DEFAULT 8000,
    ADD COLUMN `deliveryBaseKm` DECIMAL(5, 2) NOT NULL DEFAULT 1.0,
    ADD COLUMN `deliveryPerKmFee` INTEGER NOT NULL DEFAULT 2500,
    MODIFY `deliveryRadiusKm` DECIMAL(5, 2) NOT NULL DEFAULT 1.0;

-- CreateTable
CREATE TABLE `Courier` (
    `id` VARCHAR(191) NOT NULL,
    `outletId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NOT NULL,
    `isActive` BOOLEAN NOT NULL DEFAULT true,

    INDEX `Courier_outletId_idx`(`outletId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `OrderEvent` (
    `id` VARCHAR(191) NOT NULL,
    `orderId` VARCHAR(191) NOT NULL,
    `status` ENUM('PENDING_PAYMENT', 'PAID', 'PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED', 'CANCELLED', 'EXPIRED') NOT NULL,
    `actorId` VARCHAR(191) NULL,
    `note` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `OrderEvent_orderId_createdAt_idx`(`orderId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `Courier` ADD CONSTRAINT `Courier_outletId_fkey` FOREIGN KEY (`outletId`) REFERENCES `Outlet`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Order` ADD CONSTRAINT `Order_courierId_fkey` FOREIGN KEY (`courierId`) REFERENCES `Courier`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OrderEvent` ADD CONSTRAINT `OrderEvent_orderId_fkey` FOREIGN KEY (`orderId`) REFERENCES `Order`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;


-- Data: radius pengantaran default 1 km untuk outlet yang sudah ada
UPDATE `Outlet` SET `deliveryRadiusKm` = 1.0, `deliveryBaseKm` = 1.0;

-- Data: riwayat status awal dari pesanan yang sudah ada
INSERT INTO `OrderEvent` (`id`, `orderId`, `status`, `createdAt`)
SELECT CONCAT('bf', `id`), `id`, `status`, `createdAt` FROM `Order`;
