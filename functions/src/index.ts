import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {createHash} from "node:crypto";

initializeApp();

const db = getFirestore();

type ReportTargetType =
  | "user"
  | "profile"
  | "comment"
  | "image"
  | "catalogEntry"
  | "collectionEntry";

type ReportReason =
  | "spam"
  | "harassment"
  | "unsafeLink"
  | "copyright"
  | "wrongInformation"
  | "inappropriateImage"
  | "other";

type NotificationType =
  | "comment"
  | "like"
  | "follow"
  | "friendRequest"
  | "message"
  | "moderation"
  | "pro";

function requireUid(authUid?: string): string {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "Sign-in is required.");
  }

  return authUid;
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }

  return value.trim();
}

function requireEnum<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }

  return value as T;
}

async function isAdmin(uid: string): Promise<boolean> {
  const snapshot = await db.collection("users").doc(uid).get();
  return snapshot.data()?.role === "admin";
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export const createReport = onCall(async (request) => {
  const reporterId = requireUid(request.auth?.uid);
  const targetType = requireEnum<ReportTargetType>(
    request.data?.targetType,
    "targetType",
    [
      "user",
      "profile",
      "comment",
      "image",
      "catalogEntry",
      "collectionEntry",
    ],
  );
  const targetId = requireString(request.data?.targetId, "targetId");
  const reason = requireEnum<ReportReason>(
    request.data?.reason,
    "reason",
    [
      "spam",
      "harassment",
      "unsafeLink",
      "copyright",
      "wrongInformation",
      "inappropriateImage",
      "other",
    ],
  );
  const details =
    typeof request.data?.details === "string"
      ? request.data.details.trim().slice(0, 1200)
      : "";

  const reportRef = await db.collection("reports").add({
    reporterId,
    targetType,
    targetId,
    reason,
    details,
    status: "open",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {id: reportRef.id};
});

export const registerPushToken = onCall(async (request) => {
  const uid = requireUid(request.auth?.uid);
  const token = requireString(request.data?.token, "token");

  await db
    .collection("users")
    .doc(uid)
    .collection("pushTokens")
    .doc(token)
    .set(
      {
        token,
        platform: request.data?.platform ?? "unknown",
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

  return {ok: true};
});

export const sendUserNotification = onCall(async (request) => {
  const uid = requireUid(request.auth?.uid);
  if (!(await isAdmin(uid))) {
    throw new HttpsError("permission-denied", "Admin access is required.");
  }

  const userId = requireString(request.data?.userId, "userId");
  const type = requireEnum<NotificationType>(
    request.data?.type,
    "type",
    ["comment", "like", "follow", "friendRequest", "message", "moderation", "pro"],
  );
  const title = requireString(request.data?.title, "title").slice(0, 120);
  const body = requireString(request.data?.body, "body").slice(0, 240);
  const deepLink =
    typeof request.data?.deepLink === "string" ? request.data.deepLink : "";

  const notificationRef = await db.collection("notifications").add({
    userId,
    type,
    title,
    body,
    deepLink,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const tokensSnapshot = await db
    .collection("users")
    .doc(userId)
    .collection("pushTokens")
    .get();

  const tokens = tokensSnapshot.docs.map((doc) => doc.id);
  if (tokens.length > 0) {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {
        notificationId: notificationRef.id,
        type,
        deepLink,
      },
    });

    const staleTokenDeletes = response.responses
      .map((result, index) => ({result, token: tokens[index]}))
      .filter(({result}) => {
        const code = result.error?.code;
        return (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        );
      })
      .map(({token}) =>
        db
          .collection("users")
          .doc(userId)
          .collection("pushTokens")
          .doc(token)
          .delete(),
      );

    await Promise.all(staleTokenDeletes);
  }

  return {id: notificationRef.id};
});

export const verifyGooglePlayPurchase = onCall(async (request) => {
  const uid = requireUid(request.auth?.uid);
  const productId = requireString(request.data?.productId, "productId");
  const purchaseToken = requireString(
    request.data?.purchaseToken,
    "purchaseToken",
  );

  await db.collection("purchaseVerificationRequests").add({
    uid,
    productId,
    purchaseTokenHash: sha256(purchaseToken),
    status: "pending_server_api_setup",
    createdAt: FieldValue.serverTimestamp(),
  });

  throw new HttpsError(
    "failed-precondition",
    "Google Play Developer API is not connected yet.",
  );
});
