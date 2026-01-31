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
 * Cloud Function that triggers when a new chat message is created.
 * Sends FCM notification to the recipient.
 */
export const onNewChatMessage = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const {conversationId} = context.params;
    const messageData = snapshot.data();

    if (!messageData) {
      console.log("No message data found");
      return null;
    }

    const senderId = messageData.senderId as string;
    const messageText = messageData.text as string;

    console.log(`New message in conversation ${conversationId} from ${senderId}`);

    try {
      // 1. Get conversation to find participants
      const conversationDoc = await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        console.log("Conversation not found");
        return null;
      }

      const conversationData = conversationDoc.data();
      const participants = conversationData?.participants as string[] || [];

      // Find recipient (the participant who is not the sender)
      const recipientId = participants.find((uid: string) => uid !== senderId);

      if (!recipientId) {
        console.log("Recipient not found");
        return null;
      }

      console.log(`Sending notification to recipient: ${recipientId}`);

      // 2. Get sender's name for notification title
      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(senderId)
        .get();

      const senderData = senderDoc.data();
      const senderName = senderData?.name as string || "Someone";

      // 3. Get recipient's FCM tokens
      const tokensDoc = await admin.firestore()
        .collection("fcm_tokens")
        .doc(recipientId)
        .get();

      if (!tokensDoc.exists) {
        console.log("No FCM tokens found for recipient");
        return null;
      }

      const tokensData = tokensDoc.data() as TokensDoc;
      const tokensMap = tokensData?.tokens || {};
      const tokens = Object.values(tokensMap).map((t) => t.token);

      if (tokens.length === 0) {
        console.log("No tokens available");
        return null;
      }

      console.log(`Found ${tokens.length} FCM token(s) for recipient`);

      // 4. Build notification payload
      const truncatedMessage = messageText.length > 100
        ? messageText.substring(0, 100) + "..."
        : messageText;

      const payload: admin.messaging.MulticastMessage = {
        tokens: tokens,
        notification: {
          title: senderName,
          body: truncatedMessage,
        },
        data: {
          type: "chat_message",
          conversationId: conversationId,
          senderId: senderId,
          senderName: senderName,
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

      // 5. Send notifications
      const response = await admin.messaging().sendEachForMulticast(payload);

      console.log(`Successfully sent: ${response.successCount}, Failed: ${response.failureCount}`);

      // 6. Clean up invalid tokens
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

      // Remove invalid tokens from Firestore
      if (failedTokens.length > 0) {
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
            .doc(recipientId)
            .update(updates);
        }
      }

      return null;
    } catch (error) {
      console.error("Error sending notification:", error);
      return null;
    }
  });
