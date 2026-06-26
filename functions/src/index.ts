import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
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

const BADGE_PRICES: Record<string, number> = {
  queen: 1000,
  princess: 1000,
  legendary: 1000,
  star: 1000,
  creepover: 100,
  dawn_of_dance: 100,
  sweet_1600: 100,
  ghouls_rule: 100,
  skull_shores: 100,
  thirteen_wishes: 100,
  frights_camera: 100,
  freaky_fusion: 100,
  haunted_ghouls: 100,
  boo_york: 100,
  great_scarrier: 100,
  skulltimate: 100,
};

export const onUnlockRequestCreated = onDocumentCreated("unlockRequests/{requestId}", async (event) => {
  const requestRef = event.data?.ref;
  if (!requestRef) return;
  const requestData = event.data?.data();
  if (!requestData || requestData.status !== "pending") return;

  const userId = requestData.userId;
  const itemType = requestData.itemType;
  const itemId = requestData.itemId;

  const userRef = db.collection("users").doc(userId);

  try {
    await db.runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw new Error("User document does not exist.");
      }
      const userData = userSnap.data() || {};
      const coins = userData.coins ?? 20;

      let cost = 0;
      let updateField = "";
      let currentUnlocked: string[] = [];

      if (itemType === "badge") {
        cost = BADGE_PRICES[itemId] ?? 0;
        if (cost === 0) {
          throw new Error("Badge is not purchasable or invalid.");
        }
        updateField = "unlockedBadges";
        currentUnlocked = userData.unlockedBadges || ["novice"];
      } else if (itemType === "avatar") {
        cost = 100;
        updateField = "unlockedAvatars";
        currentUnlocked = userData.unlockedAvatars || [];
      } else if (itemType === "frame") {
        cost = 150;
        updateField = "unlockedFrames";
        currentUnlocked = userData.unlockedFrames || [];
      } else if (itemType === "cover") {
        cost = 200;
        updateField = "unlockedCovers";
        currentUnlocked = userData.unlockedCovers || [];
      } else {
        throw new Error("Invalid item type.");
      }

      if (currentUnlocked.includes(itemId)) {
        transaction.update(requestRef, {
          status: "success",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      if (coins < cost) {
        throw new Error("Insufficient coins.");
      }

      transaction.update(userRef, {
        coins: coins - cost,
        [updateField]: FieldValue.arrayUnion(itemId),
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        status: "success",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e: any) {
    await requestRef.update({
      status: "error",
      errorReason: e.message || "Unknown error",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
});

export const onDailyClaimRequestCreated = onDocumentCreated("dailyClaimRequests/{requestId}", async (event) => {
  const requestRef = event.data?.ref;
  if (!requestRef) return;
  const requestData = event.data?.data();
  if (!requestData || requestData.status !== "pending") return;

  const userId = requestData.userId;
  const userRef = db.collection("users").doc(userId);

  try {
    await db.runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw new Error("User document does not exist.");
      }
      const userData = userSnap.data() || {};
      const coins = userData.coins ?? 20;

      const now = new Date();
      const todayStr = now.toISOString().substring(0, 10);

      let alreadyClaimed = false;
      const lastDailyClaim = userData.lastDailyClaim;
      if (lastDailyClaim) {
        let lastClaimDate: Date;
        if (typeof lastDailyClaim.toDate === "function") {
          lastClaimDate = lastDailyClaim.toDate();
        } else {
          lastClaimDate = new Date(lastDailyClaim);
        }
        const lastClaimStr = lastClaimDate.toISOString().substring(0, 10);
        if (lastClaimStr === todayStr) {
          alreadyClaimed = true;
        }
      }

      if (alreadyClaimed) {
        throw new Error("Already claimed today.");
      }

      transaction.update(userRef, {
        coins: coins + 5,
        lastDailyClaim: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        status: "success",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e: any) {
    await requestRef.update({
      status: "error",
      errorReason: e.message || "Unknown error",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
});

export const onCoinPurchaseRequestCreated = onDocumentCreated("coinPurchaseRequests/{requestId}", async (event) => {
  const requestRef = event.data?.ref;
  if (!requestRef) return;
  const requestData = event.data?.data();
  if (!requestData || requestData.status !== "pending") return;

  const userId = requestData.userId;
  const coinsAmount = requestData.coinsAmount;
  const userRef = db.collection("users").doc(userId);

  try {
    if (![150, 500, 1200].includes(coinsAmount)) {
      throw new Error("Invalid coin package amount.");
    }

    await db.runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw new Error("User document does not exist.");
      }
      const userData = userSnap.data() || {};
      const coins = userData.coins ?? 20;

      transaction.update(userRef, {
        coins: coins + coinsAmount,
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        status: "success",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e: any) {
    await requestRef.update({
      status: "error",
      errorReason: e.message || "Unknown error",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
});

export const onCommentCreated = onDocumentCreated("comments/{commentId}", async (event) => {
  const commentData = event.data?.data();
  if (!commentData) return;

  const userId = commentData.userId;
  if (!userId || userId === "local-user") return;

  const text = (commentData.text || "").trim();
  const words = text.split(/\s+/).filter((w: string) => w.length > 1);
  const hasNoRepetitivePunctuation = !/([!?.@#\$%^&*()_+={}\[\]|\\:;\"<>,~\-\/`])\1{3,}/.test(text);

  if (text.length >= 10 && words.length >= 2 && hasNoRepetitivePunctuation) {
    const userRef = db.collection("users").doc(userId);
    const now = new Date();
    const todayStr = now.toISOString().substring(0, 10);

    try {
      await db.runTransaction(async (transaction) => {
        const userSnap = await transaction.get(userRef);
        if (!userSnap.exists) return;

        const userData = userSnap.data() || {};
        const coins = userData.coins ?? 20;
        const lastClaimDate = userData.lastCommentCoinsClaimDate || "";
        let dailyCoinsClaimed = userData.dailyCommentCoinsClaimed ?? 0;

        if (lastClaimDate !== todayStr) {
          dailyCoinsClaimed = 0;
        }

        if (dailyCoinsClaimed < 4) {
          transaction.update(userRef, {
            coins: coins + 2,
            lastCommentCoinsClaimDate: todayStr,
            dailyCommentCoinsClaimed: dailyCoinsClaimed + 2,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      console.error("Error awarding comment coins: ", e);
    }
  }
});
