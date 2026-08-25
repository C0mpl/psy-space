import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

interface Booking {
  clientId: string;
  clientName: string;
  date: FirebaseFirestore.Timestamp;
  startTime: FirebaseFirestore.Timestamp;
  status: string;
  cancelledBy?: "client" | "therapist";
  cancellationReason?: string;
  rescheduledAt?: FirebaseFirestore.Timestamp;
  rescheduledBy?: "client" | "therapist";
  previousStartTime?: FirebaseFirestore.Timestamp;
}

interface UserToken {
  fcmToken: string;
}

/**
 * Sends a push notification to a user.
 * @param {string} userId - The target user ID.
 * @param {string} title - Notification title.
 * @param {string} body - Notification body.
 * @param {Record<string, string>} data - Additional data payload.
 */
async function sendPush(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const tokenDoc = await db.collection("userTokens").doc(userId).get();

  if (!tokenDoc.exists) {
    console.log(`No FCM token found for user ${userId}`);
    return;
  }

  const tokenData = tokenDoc.data() as UserToken;
  const fcmToken = tokenData.fcmToken;

  if (!fcmToken) {
    console.log(`Empty FCM token for user ${userId}`);
    return;
  }

  try {
    await messaging.send({
      token: fcmToken,
      notification: {title, body},
      apns: {
        payload: {
          aps: {sound: "default", badge: 1},
        },
      },
      data,
    });
    console.log(`Push sent to ${userId}: ${title}`);
  } catch (error) {
    console.error("Error sending push:", error);
  }
}

/**
 * Gets the therapist's user ID from Firestore.
 * @return {Promise<string | null>} The therapist's user ID or null.
 */
async function getTherapistId(): Promise<string | null> {
  const snapshot = await db
    .collection("users")
    .where("isTherapist", "==", true)
    .limit(1)
    .get();

  return snapshot.empty ? null : snapshot.docs[0].id;
}

/**
 * Formats a Firestore timestamp to Ukrainian date/time strings.
 * @param {FirebaseFirestore.Timestamp} timestamp - The timestamp to format.
 * @return {{dateStr: string, timeStr: string}} Formatted date and time.
 */
function formatDateTime(timestamp: FirebaseFirestore.Timestamp) {
  const date = timestamp.toDate();
  const dateStr = date.toLocaleDateString("uk-UA", {
    day: "numeric",
    month: "short",
  });
  const timeStr = date.toLocaleTimeString("uk-UA", {
    hour: "2-digit",
    minute: "2-digit",
  });
  return {dateStr, timeStr};
}

// Triggered when a booking is updated
export const onBookingUpdated = onDocumentUpdated(
  "bookings/{bookingId}",
  async (event) => {
    const before = event.data?.before.data() as Booking | undefined;
    const after = event.data?.after.data() as Booking | undefined;

    if (!before || !after) return null;

    const bookingId = event.params.bookingId;

    // Check for cancellation
    if (before.status !== "cancelled" && after.status === "cancelled") {
      return handleCancellation(after, bookingId);
    }

    // Check for reschedule
    if (after.rescheduledAt && !before.rescheduledAt) {
      return handleReschedule(after, bookingId);
    }

    // Check for reschedule (comparing timestamps)
    if (
      after.rescheduledAt &&
      before.rescheduledAt &&
      after.rescheduledAt.toMillis() !== before.rescheduledAt.toMillis()
    ) {
      return handleReschedule(after, bookingId);
    }

    return null;
  }
);

/**
 * Handles booking cancellation notifications.
 * @param {Booking} booking - The cancelled booking.
 * @param {string} bookingId - The booking ID.
 * @return {Promise<null>} Returns null.
 */
async function handleCancellation(booking: Booking, bookingId: string) {
  const {dateStr, timeStr} = formatDateTime(booking.startTime);
  const reason = booking.cancellationReason;

  let targetUserId: string | null = null;
  let title = "";
  let body = "";

  if (booking.cancelledBy === "therapist") {
    targetUserId = booking.clientId;
    title = "Сеанс скасовано";
    body = `Ваш сеанс на ${dateStr} о ${timeStr} скасовано.`;
  } else if (booking.cancelledBy === "client") {
    targetUserId = await getTherapistId();
    title = "Клієнт скасував запис";
    body = `${booking.clientName} скасував на ${dateStr} о ${timeStr}.`;
  }

  if (!targetUserId) return null;

  if (reason) {
    body += ` Причина: ${reason}`;
  }

  await sendPush(targetUserId, title, body, {
    bookingId,
    type: "booking_cancelled",
    reason: reason || "",
  });

  return null;
}

/**
 * Handles booking reschedule notifications.
 * @param {Booking} booking - The rescheduled booking.
 * @param {string} bookingId - The booking ID.
 * @return {Promise<null>} Returns null.
 */
async function handleReschedule(booking: Booking, bookingId: string) {
  const {dateStr, timeStr} = formatDateTime(booking.startTime);

  let targetUserId: string | null = null;
  let title = "";
  let body = "";

  if (booking.rescheduledBy === "therapist") {
    targetUserId = booking.clientId;
    title = "Сеанс перенесено";
    body = `Ваш сеанс перенесено на ${dateStr} о ${timeStr}.`;
  } else if (booking.rescheduledBy === "client") {
    targetUserId = await getTherapistId();
    title = "Клієнт переніс запис";
    body = `${booking.clientName} переніс на ${dateStr} о ${timeStr}.`;
  }

  if (!targetUserId) return null;

  await sendPush(targetUserId, title, body, {
    bookingId,
    type: "booking_rescheduled",
  });

  return null;
}
