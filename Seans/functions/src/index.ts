import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { google } from 'googleapis';

admin.initializeApp();

const db = admin.firestore();
const calendar = google.calendar('v3');

// =============================================================================
// Scheduled Cleanup: Delete old bookings
// Runs daily at 3:00 AM UTC
// =============================================================================

export const cleanupOldBookings = functions.pubsub
  .schedule('0 3 * * *')  // Every day at 3:00 AM UTC
  .timeZone('Europe/Kyiv')
  .onRun(async () => {
    const now = Date.now();

    // Delete cancelled bookings older than 30 days
    const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);

    // Delete completed bookings older than 90 days
    const ninetyDaysAgo = new Date(now - 90 * 24 * 60 * 60 * 1000);

    try {
      // Query cancelled bookings
      const cancelledSnapshot = await db.collection('bookings')
        .where('status', '==', 'cancelled')
        .where('cancelledAt', '<', thirtyDaysAgo)
        .get();

      // Query old completed bookings (past sessions)
      const completedSnapshot = await db.collection('bookings')
        .where('status', '==', 'confirmed')
        .where('startTime', '<', ninetyDaysAgo)
        .get();

      // Delete in batches (Firestore limit is 500 per batch)
      const batchSize = 500;
      const allDocs = [...cancelledSnapshot.docs, ...completedSnapshot.docs];

      for (let i = 0; i < allDocs.length; i += batchSize) {
        const batch = db.batch();
        const chunk = allDocs.slice(i, i + batchSize);

        chunk.forEach(doc => batch.delete(doc.ref));

        await batch.commit();
      }

      console.log(`Cleanup complete: deleted ${cancelledSnapshot.size} cancelled + ${completedSnapshot.size} completed bookings`);
    } catch (error) {
      console.error('Cleanup failed:', error);
      throw error;
    }
  });

// =============================================================================
// Cleanup pending bookings (unpaid after 1 hour)
// Runs every hour
// =============================================================================

export const cleanupPendingBookings = functions.pubsub
  .schedule('0 * * * *')  // Every hour
  .timeZone('Europe/Kyiv')
  .onRun(async () => {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

    try {
      const expiredSnapshot = await db.collection('pendingBookings')
        .where('createdAt', '<', oneHourAgo)
        .get();

      if (expiredSnapshot.empty) {
        console.log('No expired pending bookings to clean up');
        return;
      }

      const batch = db.batch();
      expiredSnapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();

      console.log(`Deleted ${expiredSnapshot.size} expired pending bookings`);
    } catch (error) {
      console.error('Pending bookings cleanup failed:', error);
      throw error;
    }
  });

// =============================================================================
// Monobank Webhook: Handle payment notifications
// =============================================================================

interface MonobankWebhookPayload {
  invoiceId: string;
  status: string;
  amount?: number;
  ccy?: number;
  reference?: string;
  createdDate?: string;
  modifiedDate?: string;
}

export const monobankWebhook = functions.https.onRequest(async (req, res) => {
  // Only accept POST requests
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const payload = req.body as MonobankWebhookPayload;
    const { invoiceId, status, reference } = payload;

    console.log('Monobank webhook received:', { invoiceId, status, reference });

    if (!invoiceId || !status) {
      res.status(400).send('Missing required fields');
      return;
    }

    // Find pending booking by payment ID
    const pendingQuery = await db.collection('pendingBookings')
      .where('paymentId', '==', invoiceId)
      .limit(1)
      .get();

    if (pendingQuery.empty) {
      console.log('No pending booking found for invoice:', invoiceId);
      res.status(200).send('OK');
      return;
    }

    const pendingDoc = pendingQuery.docs[0];
    const bookingData = pendingDoc.data();

    if (status === 'success') {
      // Payment successful - move to confirmed bookings
      await db.collection('bookings').doc(pendingDoc.id).set({
        ...bookingData,
        paymentStatus: 'success',
        paidAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Delete from pending
      await pendingDoc.ref.delete();

      console.log('Booking confirmed:', pendingDoc.id);
    } else if (status === 'failure' || status === 'expired') {
      // Payment failed - delete pending booking
      await pendingDoc.ref.delete();

      console.log('Pending booking deleted due to payment failure:', pendingDoc.id);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send('Internal Server Error');
  }
});

// =============================================================================
// Google Calendar: Create event when new booking is confirmed
// =============================================================================

interface BookingData {
  clientId: string;
  clientName: string;
  clientEmail?: string;
  date: admin.firestore.Timestamp;
  startTime: admin.firestore.Timestamp;
  endTime: admin.firestore.Timestamp;
  status: string;
}

interface TherapistConfig {
  calendarAuthCode?: string;
  calendarTokens?: {
    accessToken: string;
    refreshToken: string;
    expirationDate: admin.firestore.Timestamp;
  };
}

// Helper to get or exchange OAuth tokens
async function getOAuth2Client(): Promise<typeof google.auth.OAuth2.prototype | null> {
  const configDoc = await db.collection('config').doc('therapist').get();
  const config = configDoc.data() as TherapistConfig | undefined;

  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    '' // Empty redirect URI for mobile auth code exchange
  );

  // PRIORITY 1: Exchange auth code if available (it's fresh from mobile app)
  if (config?.calendarAuthCode) {
    console.log('Exchanging auth code for tokens...');
    try {
      const { tokens } = await oauth2Client.getToken(config.calendarAuthCode);

      if (!tokens.refresh_token) {
        console.error('No refresh token received from auth code exchange');
        // Fall through to try existing refresh token
      } else {
        // Save tokens for future use and clear old ones
        await db.collection('config').doc('therapist').set({
          calendarTokens: {
            accessToken: tokens.access_token,
            refreshToken: tokens.refresh_token,
            expirationDate: new Date(tokens.expiry_date || Date.now())
          },
          // Clear the auth code since it's single-use
          calendarAuthCode: admin.firestore.FieldValue.delete()
        }, { merge: true });

        console.log('Tokens exchanged and saved successfully');

        oauth2Client.setCredentials({
          refresh_token: tokens.refresh_token
        });
        return oauth2Client;
      }
    } catch (error) {
      console.error('Failed to exchange auth code:', error);
      // Clear invalid auth code
      await db.collection('config').doc('therapist').set({
        calendarAuthCode: admin.firestore.FieldValue.delete()
      }, { merge: true });
      // Fall through to try existing refresh token
    }
  }

  // PRIORITY 2: Use existing refresh token
  if (config?.calendarTokens?.refreshToken) {
    console.log('Using existing refresh token');
    oauth2Client.setCredentials({
      refresh_token: config.calendarTokens.refreshToken
    });
    return oauth2Client;
  }

  console.log('No calendar credentials found');
  return null;
}

export const createCalendarEvent = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.data() as BookingData;
    const bookingId = context.params.bookingId;

    // Only process confirmed bookings
    if (booking.status !== 'confirmed') {
      console.log('Skipping non-confirmed booking:', bookingId);
      return;
    }

    try {
      // Get OAuth2 client with valid credentials
      const oauth2Client = await getOAuth2Client();
      if (!oauth2Client) {
        console.log('No calendar credentials available, skipping calendar event creation');
        return;
      }

      // Get therapist user for email
      const therapistQuery = await db.collection('users')
        .where('isTherapist', '==', true)
        .limit(1)
        .get();

      if (therapistQuery.empty) {
        console.error('No therapist user found');
        return;
      }

      const therapist = therapistQuery.docs[0].data();
      const therapistEmail = therapist.email;

      // Create calendar event with Google Meet
      const event = {
        summary: booking.clientName,
        description: `Сеанс з клієнтом ${booking.clientName}`,
        start: {
          dateTime: booking.startTime.toDate().toISOString(),
          timeZone: 'Europe/Kyiv',
        },
        end: {
          dateTime: booking.endTime.toDate().toISOString(),
          timeZone: 'Europe/Kyiv',
        },
        attendees: [
          ...(therapistEmail ? [{ email: therapistEmail }] : []),
          ...(booking.clientEmail ? [{ email: booking.clientEmail }] : []),
        ],
        conferenceData: {
          createRequest: {
            requestId: bookingId,
            conferenceSolutionKey: { type: 'hangoutsMeet' }
          }
        },
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'popup', minutes: 60 },
            { method: 'email', minutes: 1440 } // 24 hours
          ]
        }
      };

      const response = await calendar.events.insert({
        auth: oauth2Client,
        calendarId: 'primary',
        conferenceDataVersion: 1,
        sendUpdates: 'all', // Send email invites to attendees
        requestBody: event
      });

      const meetLink = response.data.hangoutLink;
      const eventId = response.data.id;

      console.log(`Calendar event created: ${eventId}, Meet link: ${meetLink}`);

      // Save event ID and Meet link to booking
      await snapshot.ref.update({
        calendarEventId: eventId,
        googleMeetLink: meetLink
      });

      console.log(`Updated booking ${bookingId} with calendar event info`);
    } catch (error) {
      console.error('Failed to create calendar event:', error);
      // Don't throw - we don't want to fail the booking creation
    }
  });

// =============================================================================
// Google Calendar: Update event when booking is rescheduled
// =============================================================================

export const updateCalendarEvent = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as BookingData & { calendarEventId?: string; rescheduledAt?: admin.firestore.Timestamp };
    const after = change.after.data() as BookingData & { calendarEventId?: string; rescheduledAt?: admin.firestore.Timestamp };
    const bookingId = context.params.bookingId;

    // Check if this is a reschedule (rescheduledAt changed)
    const wasRescheduled = after.rescheduledAt &&
      (!before.rescheduledAt || !after.rescheduledAt.isEqual(before.rescheduledAt));

    // Check if this is a cancellation
    const wasCancelled = before.status === 'confirmed' && after.status === 'cancelled';

    if (!wasRescheduled && !wasCancelled) {
      return;
    }

    const eventId = after.calendarEventId || before.calendarEventId;
    if (!eventId) {
      console.log('No calendar event ID found, skipping update');
      return;
    }

    try {
      // Get OAuth2 client with valid credentials
      const oauth2Client = await getOAuth2Client();
      if (!oauth2Client) {
        console.log('No calendar credentials available');
        return;
      }

      if (wasCancelled) {
        // Delete the calendar event
        await calendar.events.delete({
          auth: oauth2Client,
          calendarId: 'primary',
          eventId: eventId,
          sendUpdates: 'all'
        });

        console.log(`Calendar event deleted for cancelled booking: ${bookingId}`);
      } else if (wasRescheduled) {
        // Update the calendar event with new time
        await calendar.events.patch({
          auth: oauth2Client,
          calendarId: 'primary',
          eventId: eventId,
          sendUpdates: 'all',
          requestBody: {
            start: {
              dateTime: after.startTime.toDate().toISOString(),
              timeZone: 'Europe/Kyiv',
            },
            end: {
              dateTime: after.endTime.toDate().toISOString(),
              timeZone: 'Europe/Kyiv',
            }
          }
        });

        console.log(`Calendar event updated for rescheduled booking: ${bookingId}`);
      }
    } catch (error) {
      console.error('Failed to update/delete calendar event:', error);
    }
  });
