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
  publicInfo: Prisma.JsonValue;
  subscriptionTier: SubscriptionTier;

  // ─── Friend tier (mutual follows + self) ──────────────
  friendInfo?: Prisma.JsonValue;

  // ─── Private tier (self only) ─────────────────────────
  privateInfo?: Prisma.JsonValue;
  preferences?: Prisma.JsonValue;
  email?: string;
}
