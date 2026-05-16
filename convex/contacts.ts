import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const listByUser = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const upsertBatch = mutation({
  args: {
    userId: v.string(),
    contacts: v.array(
      v.object({
        name: v.string(),
        phone: v.string(),
        priority: v.number(),
        language: v.string(),
      }),
    ),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();

    for (const row of existing) {
      await ctx.db.delete(row._id);
    }

    for (const c of args.contacts) {
      await ctx.db.insert("contacts", {
        userId: args.userId,
        name: c.name,
        phone: c.phone,
        priority: c.priority,
        language: c.language,
      });
    }
  },
});
