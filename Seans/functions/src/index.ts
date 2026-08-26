import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

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
