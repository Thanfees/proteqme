import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const record = mutation({
  args: {
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
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("sos_events", args);
  },
});
