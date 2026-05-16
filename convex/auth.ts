import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/** Buildathon OTP stub — replace with SMS provider in production. */
const OTP_STORE = new Map<string, string>();

export const requestOtp = mutation({
  args: { phone: v.string() },
  handler: async (_ctx, { phone }) => {
    const code = "123456";
    OTP_STORE.set(phone, code);
    return { ok: true, debugCode: code };
  },
});

export const verifyOtp = mutation({
  args: { phone: v.string(), code: v.string() },
  handler: async (ctx, { phone, code }) => {
    const expected = OTP_STORE.get(phone);
    if (expected !== code) {
      throw new Error("Invalid OTP");
    }

    const existing = await ctx.db
      .query("users")
      .withIndex("by_phone", (q) => q.eq("phone", phone))
      .first();

    const userId =
      existing?._id ??
      (await ctx.db.insert("users", {
        phone,
        displayName: "ProteqMe User",
        createdAt: Date.now(),
      }));

    return { userId, displayName: existing?.displayName ?? "ProteqMe User" };
  },
});

export const me = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    return await ctx.db.get(userId);
  },
});
