-- AlterTable
ALTER TABLE `Payment` ADD COLUMN `amount` INTEGER NULL,
    ADD COLUMN `attempt` INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN `billKey` VARCHAR(191) NULL,
    ADD COLUMN `billerCode` VARCHAR(191) NULL,
    ADD COLUMN `deeplinkUrl` TEXT NULL,
    ADD COLUMN `expiresAt` DATETIME(3) NULL,
    ADD COLUMN `payerPhone` VARCHAR(191) NULL,
    ADD COLUMN `qrImageUrl` TEXT NULL,
    ADD COLUMN `qrString` TEXT NULL,
    ADD COLUMN `vaBank` VARCHAR(191) NULL,
    ADD COLUMN `vaNumber` VARCHAR(191) NULL,
    MODIFY `snapToken` VARCHAR(191) NULL,
    MODIFY `redirectUrl` VARCHAR(191) NULL;


-- Data: baris pembayaran lama (Snap) diberi nominal dari pesanannya
UPDATE `Payment` p JOIN `Order` o ON o.`id` = p.`orderId` SET p.`amount` = o.`total` WHERE p.`amount` IS NULL;
