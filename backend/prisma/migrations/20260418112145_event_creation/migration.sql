/*
  Warnings:

  - The `status` column on the `Event` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - The `visibility` column on the `Event` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - Added the required column `coverImage` to the `Event` table without a default value. This is not possible if the table is not empty.
  - Changed the type of `policyType` on the `LicensePolicy` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- CreateEnum
CREATE TYPE "EventVisibility" AS ENUM ('PUBLIC', 'PRIVATE');

-- CreateEnum
CREATE TYPE "EventStatus" AS ENUM ('ACTIVE', 'ENDED', 'CLOSED');

-- CreateEnum
CREATE TYPE "PolicyType" AS ENUM ('GEOFENCE', 'TIME_WINDOW');

-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "coverImage" TEXT NOT NULL,
ADD COLUMN     "descritpion" TEXT,
ADD COLUMN     "locationLat" DOUBLE PRECISION,
ADD COLUMN     "locationLng" DOUBLE PRECISION,
ADD COLUMN     "tags" TEXT[],
DROP COLUMN "status",
ADD COLUMN     "status" "EventStatus" NOT NULL DEFAULT 'ACTIVE',
DROP COLUMN "visibility",
ADD COLUMN     "visibility" "EventVisibility" NOT NULL DEFAULT 'PUBLIC';

-- AlterTable
ALTER TABLE "LicensePolicy" DROP COLUMN "policyType",
ADD COLUMN     "policyType" "PolicyType" NOT NULL;
