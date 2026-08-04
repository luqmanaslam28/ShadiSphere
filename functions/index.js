/**
 * ShadiSphere Cloud Functions
 * 
 * Listens for new documents in the `notifications` collection and sends
 * FCM push notifications to the recipient's registered devices.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

/**
 * Triggered when a new notification document is created in Firestore.
 * Reads the recipient's FCM tokens from the `users` collection and sends
 * a push notification to all their devices.
 */
exports.sendPushNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const notificationData = snapshot.data();
    const recipientUid = notificationData.recipientUid;
    const title = notificationData.title || "ShadiSphere";
    const body = notificationData.body || "You have a new update.";
    const type = notificationData.type || "general";
    const extraData = notificationData.data || {};

    if (!recipientUid) {
      console.log("No recipientUid found, skipping");
      return;
    }

    // Get recipient's FCM tokens from Firestore
    const db = getFirestore();
    const userDoc = await db.collection("users").doc(recipientUid).get();

    if (!userDoc.exists) {
      console.log(`User ${recipientUid} not found in users collection`);
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens;

    if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
      console.log(`No FCM tokens found for user ${recipientUid}`);
      return;
    }

    // Build the FCM message
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        ...Object.fromEntries(
          Object.entries(extraData).map(([k, v]) => [k, String(v)])
        ),
      },
      webpush: {
        notification: {
          title: title,
          body: body,
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
        },
      },
      android: {
        notification: {
          channelId: "shadi_sphere_notifications",
          priority: "high",
          defaultSound: true,
        },
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const messaging = getMessaging();
    const tokensToRemove = [];

    // Send to each token
    const sendPromises = fcmTokens.map(async (token) => {
      try {
        await messaging.send({ ...message, token: token });
        console.log(`Successfully sent to token: ${token.substring(0, 20)}...`);
      } catch (error) {
        console.error(`Error sending to token ${token.substring(0, 20)}...:`, error.code);
        // If the token is invalid, mark it for removal
        if (
          error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered"
        ) {
          tokensToRemove.push(token);
        }
      }
    });

    await Promise.all(sendPromises);

    // Clean up invalid tokens
    if (tokensToRemove.length > 0) {
      const { FieldValue } = require("firebase-admin/firestore");
      await db.collection("users").doc(recipientUid).update({
        fcmTokens: FieldValue.arrayRemove(...tokensToRemove),
      });
      console.log(`Removed ${tokensToRemove.length} invalid token(s) for user ${recipientUid}`);
    }

    console.log(`Push notification sent to ${recipientUid}: "${title}"`);
  }
);
