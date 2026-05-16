import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const record = mutation({
  args: {
    userId: v.optional(v.id("users")),
    triggeredAtMs: v.number(),
    disarmedAtMs: v.optional(v.number()),
    gpsPoints: v.optional(
      v.array(
        v.object({
          lat: v.number(),
          lng: v.number(),
          timestampMs: v.number(),
          source: v.string(),
        }),
      ),
    ),
    payload: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    if (!args.userId) {
      return { skipped: true };
    }
    return await ctx.db.insert("sos_events", {
      userId: args.userId,
      triggeredAtMs: args.triggeredAtMs,
      disarmedAtMs: args.disarmedAtMs,
      gpsPoints: args.gpsPoints ?? [],
      payload: args.payload,
    });
  },
});
