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
 * Cloud Function that triggers when a new group chat message is created.
 * Sends FCM notifications to all group members except the sender.
 */
export const onNewGroupChatMessage = functions.firestore
  .document("group_chats/{groupChatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const {groupChatId} = context.params;
    const messageData = snapshot.data();

    if (!messageData) {
      console.log("No message data found");
      return null;
    }

    const senderId = messageData.senderId as string;
    const senderName = messageData.senderName as string || "Someone";
    const messageText = messageData.text as string;

    console.log(`New group message in ${groupChatId} from ${senderId}`);

    try {
      // 1. Get group chat to find members and group name
      const groupChatDoc = await admin.firestore()
        .collection("group_chats")
        .doc(groupChatId)
        .get();

      if (!groupChatDoc.exists) {
        console.log("Group chat not found");
        return null;
      }

      const groupChatData = groupChatDoc.data();
      const members = groupChatData?.members as string[] || [];
      const groupName = groupChatData?.name as string || "Group Chat";

      // Find all recipients (everyone except the sender)
      const recipientIds = members.filter((uid: string) => uid !== senderId);

      if (recipientIds.length === 0) {
        console.log("No recipients found");
        return null;
      }

      console.log(`Sending notifications to ${recipientIds.length} recipient(s)`);

      // 2. Collect all FCM tokens from all recipients
      const allTokens: string[] = [];
      const tokenToRecipient: Record<string, {recipientId: string; deviceId: string}> = {};

      for (const recipientId of recipientIds) {
        const tokensDoc = await admin.firestore()
          .collection("fcm_tokens")
          .doc(recipientId)
          .get();

        if (!tokensDoc.exists) continue;

        const tokensData = tokensDoc.data() as TokensDoc;
        const tokensMap = tokensData?.tokens || {};

        for (const [deviceId, tokenData] of Object.entries(tokensMap)) {
          allTokens.push(tokenData.token);
          tokenToRecipient[tokenData.token] = {recipientId, deviceId};
        }
      }

      if (allTokens.length === 0) {
        console.log("No FCM tokens available");
        return null;
      }

      console.log(`Found ${allTokens.length} FCM token(s) total`);

      // 3. Build notification payload
      const truncatedMessage = messageText.length > 100
        ? messageText.substring(0, 100) + "..."
        : messageText;

      const payload: admin.messaging.MulticastMessage = {
        tokens: allTokens,
        notification: {
          title: `${groupName}`,
          body: `${senderName}: ${truncatedMessage}`,
        },
        data: {
          type: "group_message",
          groupChatId: groupChatId,
          senderId: senderId,
          senderName: senderName,
          groupName: groupName,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "chat_messages",
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
      const invalidTokenUpdates: Map<string, Record<string, admin.firestore.FieldValue>> = new Map();

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          console.log(`Token ${idx} failed with error: ${errorCode}`);

          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            const token = allTokens[idx];
            const info = tokenToRecipient[token];
            if (info) {
              if (!invalidTokenUpdates.has(info.recipientId)) {
                invalidTokenUpdates.set(info.recipientId, {});
              }
              invalidTokenUpdates.get(info.recipientId)![`tokens.${info.deviceId}`] =
                admin.firestore.FieldValue.delete();
            }
          }
        }
      });

      // Remove invalid tokens from Firestore
      for (const [recipientId, updates] of invalidTokenUpdates.entries()) {
        if (Object.keys(updates).length > 0) {
          await admin.firestore()
            .collection("fcm_tokens")
            .doc(recipientId)
            .update(updates);
        }
      }

      return null;
    } catch (error) {
      console.error("Error sending group notification:", error);
      return null;
    }
  });
