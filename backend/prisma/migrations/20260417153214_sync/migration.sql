/*
  Warnings:

  - You are about to drop the column `passwordResetExpires` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `passwordResetToken` on the `User` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[eventId,trackId]` on the table `EventTrack` will be added. If there are existing duplicate values, this will fail.

*/
-- DropIndex
DROP INDEX "User_passwordResetToken_key";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "passwordResetExpires",
DROP COLUMN "passwordResetToken";

-- CreateIndex
CREATE UNIQUE INDEX "EventTrack_eventId_trackId_key" ON "EventTrack"("eventId", "trackId");
