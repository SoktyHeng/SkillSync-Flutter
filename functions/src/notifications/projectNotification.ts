import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

interface TokenData {
  token: string;
  platform: string;
  updatedAt: admin.firestore.Timestamp;
}

interface TokensDoc {
  tokens: Record<string, TokenData>;
}

/**
 * Helper to get user's FCM tokens
 */
async function getUserTokens(userId: string): Promise<{tokens: string[], tokensMap: Record<string, TokenData>}> {
  const tokensDoc = await admin.firestore()
    .collection("fcm_tokens")
    .doc(userId)
    .get();

  if (!tokensDoc.exists) {
    return {tokens: [], tokensMap: {}};
  }

  const tokensData = tokensDoc.data() as TokensDoc;
  const tokensMap = tokensData?.tokens || {};
  const tokens = Object.values(tokensMap).map((t) => t.token);

  return {tokens, tokensMap};
}

/**
 * Helper to clean up invalid tokens
 */
async function cleanupInvalidTokens(
  userId: string,
  failedTokens: string[],
  tokensMap: Record<string, TokenData>
): Promise<void> {
  if (failedTokens.length === 0) return;

  console.log(`Removing ${failedTokens.length} invalid token(s)`);

  const updates: Record<string, admin.firestore.FieldValue> = {};
  for (const [deviceId, tokenData] of Object.entries(tokensMap)) {
    if (failedTokens.includes(tokenData.token)) {
      updates[`tokens.${deviceId}`] = admin.firestore.FieldValue.delete();
    }
  }

  if (Object.keys(updates).length > 0) {
    await admin.firestore()
      .collection("fcm_tokens")
      .doc(userId)
      .update(updates);
  }
}

/**
 * Helper to send FCM notification and create notification document
 */
async function sendNotificationToUser(
  recipientId: string,
  notification: {title: string; body: string},
  data: {
    type: string;
    projectId: string;
    projectTitle: string;
    fromUserId: string;
    fromUserName: string;
  }
): Promise<void> {
  // 1. Create notification document in Firestore
  await admin.firestore().collection("notifications").add({
    userId: recipientId,
    type: data.type,
    title: notification.title,
    body: notification.body,
    projectId: data.projectId,
    projectTitle: data.projectTitle,
    fromUserId: data.fromUserId,
    fromUserName: data.fromUserName,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`Created notification document for user: ${recipientId}`);

  // 2. Get FCM tokens
  const {tokens, tokensMap} = await getUserTokens(recipientId);

  if (tokens.length === 0) {
    console.log("No FCM tokens found for recipient");
    return;
  }

  console.log(`Found ${tokens.length} FCM token(s) for recipient`);

  // 3. Build FCM payload
  const payload: admin.messaging.MulticastMessage = {
    tokens: tokens,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: {
      type: data.type,
      projectId: data.projectId,
      projectTitle: data.projectTitle,
      fromUserId: data.fromUserId,
      fromUserName: data.fromUserName,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "project_notifications",
        priority: "high",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      payload: {
        aps: {
          badge: 1,
          sound: "default",
        },
      },
    },
  };

  // 4. Send notifications
  const response = await admin.messaging().sendEachForMulticast(payload);

  console.log(`Successfully sent: ${response.successCount}, Failed: ${response.failureCount}`);

  // 5. Clean up invalid tokens
  const failedTokens: string[] = [];
  response.responses.forEach((resp, idx) => {
    if (!resp.success) {
      const errorCode = resp.error?.code;
      console.log(`Token ${idx} failed with error: ${errorCode}`);

      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        failedTokens.push(tokens[idx]);
      }
    }
  });

  await cleanupInvalidTokens(recipientId, failedTokens, tokensMap);
}

/**
 * Cloud Function that triggers when a new contribution request is created.
 * Sends notification to the project owner.
 */
export const onContributionRequest = functions.firestore
  .document("projects/{projectId}/requests/{requestId}")
  .onCreate(async (snapshot, context) => {
    const {projectId} = context.params;
    const requestData = snapshot.data();

    if (!requestData) {
      console.log("No request data found");
      return null;
    }

    const requesterId = requestData.userId as string;

    console.log(`New contribution request for project ${projectId} from ${requesterId}`);

    try {
      // 1. Get project to find owner
      const projectDoc = await admin.firestore()
        .collection("projects")
        .doc(projectId)
        .get();

      if (!projectDoc.exists) {
        console.log("Project not found");
        return null;
      }

      const projectData = projectDoc.data();
      const ownerId = projectData?.uid as string;
      const projectTitle = projectData?.title as string || "a project";

      // Don't notify if owner is requesting to their own project
      if (ownerId === requesterId) {
        console.log("Owner requested to own project, skipping notification");
        return null;
      }

      // 2. Get requester's name
      const requesterDoc = await admin.firestore()
        .collection("users")
        .doc(requesterId)
        .get();

      const requesterData = requesterDoc.data();
      const requesterName = requesterData?.name as string || "Someone";

      // 3. Send notification to project owner
      await sendNotificationToUser(
        ownerId,
        {
          title: "New Contribution Request",
          body: `${requesterName} wants to join "${projectTitle}"`,
        },
        {
          type: "request_received",
          projectId: projectId,
          projectTitle: projectTitle,
          fromUserId: requesterId,
          fromUserName: requesterName,
        }
      );

      console.log(`Notification sent to project owner: ${ownerId}`);
      return null;
    } catch (error) {
      console.error("Error sending contribution request notification:", error);
      return null;
    }
  });

/**
 * Cloud Function that triggers when a contribution request status changes.
 * Sends notification to the requester when accepted/rejected.
 */
export const onRequestStatusChange = functions.firestore
  .document("projects/{projectId}/requests/{requestId}")
  .onUpdate(async (change, context) => {
    const {projectId} = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!beforeData || !afterData) {
      console.log("No data found");
      return null;
    }

    const beforeStatus = beforeData.status as string;
    const afterStatus = afterData.status as string;

    // Only proceed if status changed from pending to accepted/rejected
    if (beforeStatus !== "pending") {
      console.log("Previous status was not pending, skipping");
      return null;
    }

    if (afterStatus !== "accepted" && afterStatus !== "rejected") {
      console.log("New status is not accepted or rejected, skipping");
      return null;
    }

    const requesterId = afterData.userId as string;

    console.log(`Request status changed to ${afterStatus} for user ${requesterId}`);

    try {
      // 1. Get project info
      const projectDoc = await admin.firestore()
        .collection("projects")
        .doc(projectId)
        .get();

      if (!projectDoc.exists) {
        console.log("Project not found");
        return null;
      }

      const projectData = projectDoc.data();
      const ownerId = projectData?.uid as string;
      const projectTitle = projectData?.title as string || "a project";

      // 2. Get owner's name
      const ownerDoc = await admin.firestore()
        .collection("users")
        .doc(ownerId)
        .get();

      const ownerData = ownerDoc.data();
      const ownerName = ownerData?.name as string || "The project owner";

      // 3. Build notification based on status
      const isAccepted = afterStatus === "accepted";
      const notificationType = isAccepted ? "request_accepted" : "request_rejected";
      const title = isAccepted ? "Request Accepted" : "Request Declined";
      const body = isAccepted
        ? `Your request to join "${projectTitle}" was accepted`
        : `Your request to join "${projectTitle}" was declined`;

      // 4. Send notification to requester
      await sendNotificationToUser(
        requesterId,
        {title, body},
        {
          type: notificationType,
          projectId: projectId,
          projectTitle: projectTitle,
          fromUserId: ownerId,
          fromUserName: ownerName,
        }
      );

      console.log(`Notification sent to requester: ${requesterId}`);
      return null;
    } catch (error) {
      console.error("Error sending status change notification:", error);
      return null;
    }
  });
