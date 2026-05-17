import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    phone: v.string(),
    displayName: v.string(),
    createdAt: v.number(),
    // Username/password fields are optional so legacy OTP-only rows still
    // satisfy the schema while we migrate.
    username: v.optional(v.string()),
    passwordHash: v.optional(v.string()),
    passwordSalt: v.optional(v.string()),
    email: v.optional(v.string()),
  })
    .index("by_phone", ["phone"])
    .index("by_username", ["username"]),

  sessions: defineTable({
    userId: v.id("users"),
    token: v.string(),
    createdAt: v.number(),
    lastSeenAt: v.number(),
    deviceLabel: v.optional(v.string()),
  })
    .index("by_token", ["token"])
    .index("by_user", ["userId"]),

  contacts: defineTable({
    userId: v.id("users"),
    name: v.string(),
    phone: v.string(),
    priority: v.number(),
    language: v.string(),
    // Optional millisecond timestamps so the client can pick a winner during
    // last-write-wins merges without breaking older rows.
    createdAtMs: v.optional(v.number()),
    updatedAtMs: v.optional(v.number()),
  }).index("by_user", ["userId"]),

  sos_events: defineTable({
    userId: v.id("users"),
    triggeredAtMs: v.number(),
    disarmedAtMs: v.optional(v.number()),
    gpsPoints: v.array(
      v.object({
        lat: v.number(),
        lng: v.number(),
        timestampMs: v.number(),
        source: v.string(),
      }),
    ),
    payload: v.optional(v.any()),
  }).index("by_user", ["userId"]),

  live_locations: defineTable({
    userId: v.id("users"),
    lat: v.number(),
    lng: v.number(),
    sosActive: v.boolean(),
    timestampMs: v.number(),
  }).index("by_user", ["userId"]),
});
