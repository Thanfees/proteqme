import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    phone: v.string(),
    displayName: v.string(),
    createdAt: v.number(),
  }).index("by_phone", ["phone"]),

  contacts: defineTable({
    userId: v.id("users"),
    name: v.string(),
    phone: v.string(),
    priority: v.number(),
    language: v.string(),
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
