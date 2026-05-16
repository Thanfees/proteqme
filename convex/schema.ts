import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    clerkId: v.optional(v.string()),
    displayName: v.string(),
    phone: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_clerk", ["clerkId"]),

  contacts: defineTable({
    userId: v.string(),
    name: v.string(),
    phone: v.string(),
    priority: v.number(),
    language: v.string(),
  }).index("by_user", ["userId"]),

  sos_events: defineTable({
    userId: v.string(),
    triggeredAt: v.number(),
    disarmedAt: v.optional(v.number()),
    gpsPoints: v.array(
      v.object({
        timestamp: v.number(),
        lat: v.number(),
        lng: v.number(),
        accuracy: v.optional(v.number()),
        source: v.string(),
      }),
    ),
    callSummary: v.array(
      v.object({
        contactId: v.optional(v.number()),
        startedAt: v.number(),
        endedAt: v.optional(v.number()),
        durationSec: v.optional(v.number()),
        outcome: v.string(),
      }),
    ),
    deviceMeta: v.optional(v.any()),
  }).index("by_user", ["userId"]),
});
