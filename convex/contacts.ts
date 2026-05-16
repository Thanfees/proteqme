import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const listByUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
  },
});

export const upsertBatch = mutation({
  args: {
    userId: v.id("users"),
    contacts: v.array(
      v.object({
        name: v.string(),
        phone: v.string(),
        priority: v.number(),
        language: v.string(),
      }),
    ),
  },
  handler: async (ctx, { userId, contacts }) => {
    const existing = await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const row of existing) {
      await ctx.db.delete(row._id);
    }

    for (const contact of contacts) {
      await ctx.db.insert("contacts", { userId, ...contact });
    }

    return { count: contacts.length };
  },
});
