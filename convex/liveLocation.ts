import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/** Family dashboard: subscribe to this query for live map updates. */
export const watchUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db
      .query("live_locations")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .order("desc")
      .first();
  },
});

export const update = mutation({
  args: {
    userId: v.id("users"),
    lat: v.number(),
    lng: v.number(),
    sosActive: v.boolean(),
    timestampMs: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("live_locations")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        lat: args.lat,
        lng: args.lng,
        sosActive: args.sosActive,
        timestampMs: args.timestampMs,
      });
      return existing._id;
    }

    return await ctx.db.insert("live_locations", args);
  },
});
