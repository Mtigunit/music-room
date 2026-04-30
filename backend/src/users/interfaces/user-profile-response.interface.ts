import type { Prisma, SubscriptionTier } from '@prisma/client';

/**
 * The tiered response shape for a user profile.
 * All tiers above the base are optional — populated according to the
 * visibility rules (self / mutual-follow / public).
 */
export interface UserProfileResponse {
  // ─── Public (everyone) ────────────────────────────────
  id: string;
  username: string;
  avatarUrl: string | null;
  publicInfo: Prisma.JsonValue | null;
  subscriptionTier: SubscriptionTier;

  // ─── Friend tier (mutual follows + self) ──────────────
  friendInfo?: Prisma.JsonValue | null;

  // ─── Private tier (self only) ─────────────────────────
  privateInfo?: Prisma.JsonValue | null;
  preferences?: Prisma.JsonValue | null;
  email?: string;
}
