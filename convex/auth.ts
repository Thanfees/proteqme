import { mutation, query } from "./_generated/server";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { v } from "convex/values";

/* ─── Helpers ────────────────────────────────────────────────────── */

/** Hex-encode a Uint8Array. */
function toHex(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, "0");
  }
  return out;
}

/** Generate `len` random hex characters (uses WebCrypto in V8). */
function randomHex(len: number): string {
  const bytes = new Uint8Array(Math.ceil(len / 2));
  globalThis.crypto.getRandomValues(bytes);
  return toHex(bytes).slice(0, len);
}

/** SHA-256 the input string and return lowercase hex. */
async function sha256Hex(input: string): Promise<string> {
  const digest = await globalThis.crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return toHex(new Uint8Array(digest));
}

/** Constant-time equality on equal-length hex strings. */
function constantTimeEq(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;

/** Look up the userId for a session token. Throws when invalid/missing. */
export async function getUserIdByToken(
  ctx: QueryCtx | MutationCtx,
  token: string | undefined,
): Promise<Id<"users">> {
  if (!token) throw new Error("Unauthorized");
  const session = await ctx.db
    .query("sessions")
    .withIndex("by_token", (q) => q.eq("token", token))
    .first();
  if (!session) throw new Error("Unauthorized");
  return session.userId;
}

/** Same as above but returns null instead of throwing. */
export async function tryGetUserIdByToken(
  ctx: QueryCtx | MutationCtx,
  token: string | undefined,
): Promise<Id<"users"> | null> {
  if (!token) return null;
  const session = await ctx.db
    .query("sessions")
    .withIndex("by_token", (q) => q.eq("token", token))
    .first();
  return session ? session.userId : null;
}

/* ─── Legacy OTP (preserved for back-compat) ─────────────────────── */

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

/* ─── Username + password auth ──────────────────────────────────── */

export const signup = mutation({
  args: {
    username: v.string(),
    password: v.string(),
    displayName: v.string(),
    phone: v.optional(v.string()),
    deviceLabel: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const username = args.username.trim().toLowerCase();
    if (!USERNAME_RE.test(username)) {
      throw new Error(
        "Username must be 3–20 chars: letters, digits, underscore",
      );
    }
    if (args.password.length < 6) {
      throw new Error("Password must be at least 6 characters");
    }
    const displayName = args.displayName.trim();
    if (displayName.length === 0) {
      throw new Error("Display name is required");
    }

    const collision = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (collision) throw new Error("Username taken");

    const passwordSalt = randomHex(32);
    const passwordHash = await sha256Hex(passwordSalt + args.password);

    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      phone: args.phone ?? "",
      displayName,
      createdAt: now,
      username,
      passwordHash,
      passwordSalt,
    });

    const token = randomHex(64);
    await ctx.db.insert("sessions", {
      userId,
      token,
      createdAt: now,
      lastSeenAt: now,
      deviceLabel: args.deviceLabel,
    });

    return { userId, token, displayName };
  },
});

export const signin = mutation({
  args: {
    username: v.string(),
    password: v.string(),
    deviceLabel: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const username = args.username.trim().toLowerCase();
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (!user || !user.passwordHash || !user.passwordSalt) {
      throw new Error("Invalid credentials");
    }

    const candidate = await sha256Hex(user.passwordSalt + args.password);
    if (!constantTimeEq(candidate, user.passwordHash)) {
      throw new Error("Invalid credentials");
    }

    const now = Date.now();
    const token = randomHex(64);
    await ctx.db.insert("sessions", {
      userId: user._id,
      token,
      createdAt: now,
      lastSeenAt: now,
      deviceLabel: args.deviceLabel,
    });

    return { userId: user._id, token, displayName: user.displayName };
  },
});

export const signout = mutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    const session = await ctx.db
      .query("sessions")
      .withIndex("by_token", (q) => q.eq("token", token))
      .first();
    if (session) {
      await ctx.db.delete(session._id);
    }
    return { ok: true };
  },
});

export const validateSession = mutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    const session = await ctx.db
      .query("sessions")
      .withIndex("by_token", (q) => q.eq("token", token))
      .first();
    if (!session) return null;

    await ctx.db.patch(session._id, { lastSeenAt: Date.now() });
    const user = await ctx.db.get(session.userId);
    if (!user) return null;

    return { userId: session.userId, displayName: user.displayName };
  },
});

export const updateProfile = mutation({
  args: {
    token: v.string(),
    displayName: v.optional(v.string()),
    phone: v.optional(v.string()),
  },
  handler: async (ctx, { token, displayName, phone }) => {
    const userId = await getUserIdByToken(ctx, token);
    const patch: Record<string, unknown> = {};
    if (displayName !== undefined) {
      const trimmed = displayName.trim();
      if (trimmed.length === 0) throw new Error("Display name cannot be empty");
      patch.displayName = trimmed;
    }
    if (phone !== undefined) patch.phone = phone;

    if (Object.keys(patch).length > 0) {
      await ctx.db.patch(userId, patch);
    }
    const user = await ctx.db.get(userId);
    return {
      userId,
      displayName: user?.displayName,
      phone: user?.phone,
    };
  },
});
