-- AlterTable: make deviceId optional
ALTER TABLE "ControlDelegation" ALTER COLUMN "deviceId" DROP NOT NULL;

-- AlterTable: change isActive default from true to false
ALTER TABLE "ControlDelegation" ALTER COLUMN "isActive" SET DEFAULT false;

-- DropIndex: remove old unique constraint
DROP INDEX IF EXISTS "ControlDelegation_eventId_delegateeId_deviceId_key";

-- CreateIndex: add new unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS "ControlDelegation_eventId_delegateeId_key" ON "ControlDelegation"("eventId", "delegateeId");