import { mutation, query } from "./_generated/server";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { getUserIdByToken, tryGetUserIdByToken } from "./auth";

/** Resolve the acting user from either a session token or an explicit userId
 * (back-compat with the legacy OTP path that still passes userId directly). */
async function resolveUserId(
  ctx: QueryCtx | MutationCtx,
  args: { token?: string; userId?: Id<"users"> },
): Promise<Id<"users">> {
  if (args.token) {
    return getUserIdByToken(ctx, args.token);
  }
  if (args.userId) return args.userId;
  throw new Error("Unauthorized");
}

/* ─── Queries ─────────────────────────────────────────────────────── */

export const listByUser = query({
  args: {
    userId: v.optional(v.id("users")),
    token: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    let userId = args.userId;
    if (!userId && args.token) {
      const fromToken = await tryGetUserIdByToken(ctx, args.token);
      if (!fromToken) return [];
      userId = fromToken;
    }
    if (!userId) return [];
    return await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
  },
});

/* ─── Single-contact mutations ────────────────────────────────────── */

/** Add one contact (manual entry or single phone-book pick). */
export const addOne = mutation({
  args: {
    userId: v.optional(v.id("users")),
    token: v.optional(v.string()),
    name: v.string(),
    phone: v.string(),
    priority: v.number(),
    language: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await resolveUserId(ctx, args);
    const now = Date.now();
    const id = await ctx.db.insert("contacts", {
      userId,
      name: args.name,
      phone: args.phone,
      priority: args.priority,
      language: args.language,
      createdAtMs: now,
      updatedAtMs: now,
    });
    return { id };
  },
});

/** Update an existing contact by its document ID. */
export const updateOne = mutation({
  args: {
    contactId: v.id("contacts"),
    token: v.optional(v.string()),
    userId: v.optional(v.id("users")),
    name: v.optional(v.string()),
    phone: v.optional(v.string()),
    priority: v.optional(v.number()),
    language: v.optional(v.string()),
  },
  handler: async (ctx, { contactId, token, userId, ...patch }) => {
    const existing = await ctx.db.get(contactId);
    if (!existing) throw new Error("Contact not found");

    // Authorize: token (if provided) must belong to the contact owner,
    // OR the legacy userId arg must match.
    const actor = await resolveUserId(ctx, { token, userId });
    if (existing.userId !== actor) throw new Error("Unauthorized");

    const updates: Record<string, unknown> = {};
    if (patch.name !== undefined) updates.name = patch.name;
    if (patch.phone !== undefined) updates.phone = patch.phone;
    if (patch.priority !== undefined) updates.priority = patch.priority;
    if (patch.language !== undefined) updates.language = patch.language;
    updates.updatedAtMs = Date.now();

    await ctx.db.patch(contactId, updates);
    return { ok: true };
  },
});

/** Delete one contact by its document ID. */
export const deleteOne = mutation({
  args: {
    contactId: v.id("contacts"),
    token: v.optional(v.string()),
    userId: v.optional(v.id("users")),
  },
  handler: async (ctx, { contactId, token, userId }) => {
    const existing = await ctx.db.get(contactId);
    if (!existing) return { ok: true };
    const actor = await resolveUserId(ctx, { token, userId });
    if (existing.userId !== actor) throw new Error("Unauthorized");
    await ctx.db.delete(contactId);
    return { ok: true };
  },
});

/* ─── Batch mutation (phone-book import) ──────────────────────────── */

/** Upsert all contacts for a user (used when importing from phone).
 *
 * Returns the new IDs in the same order as the input array so the client can
 * persist them locally for future updates.
 */
export const upsertBatch = mutation({
  args: {
    userId: v.optional(v.id("users")),
    token: v.optional(v.string()),
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
    const userId = await resolveUserId(ctx, args);

    const existing = await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    for (const row of existing) {
      await ctx.db.delete(row._id);
    }

    const now = Date.now();
    const ids: string[] = [];
    for (const contact of args.contacts) {
      const id = await ctx.db.insert("contacts", {
        userId,
        ...contact,
        createdAtMs: now,
        updatedAtMs: now,
      });
      ids.push(id);
    }

    return { count: args.contacts.length, ids };
  },
});
