const functions = require('firebase-functions');
const axios = require('axios');

/**
 * Cloud Function to send verification emails via EmailJS
 * This proxies the request to EmailJS API since mobile apps can't call EmailJS directly
 */
exports.sendVerificationEmail = functions.https.onCall(async (data, context) => {
  // Validate input
  if (!data.email || !data.code) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email and code are required'
    );
  }

  // EmailJS Configuration
  const serviceId = 'service_kgfxsas';
  const templateId = 'template_9zfpx1c';
  const publicKey = 'XP8HqIq2y8uqktNlc';
  const emailJsApiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  try {
    const response = await axios.post(
      emailJsApiUrl,
      {
        service_id: serviceId,
        template_id: templateId,
        user_id: publicKey,
        template_params: {
          user_email: data.email,
          to_email: data.email,
          email: data.email,
          code: data.code,
          passcode: data.code,
          verification_code: data.code,
          time: '5 minutes',
        },
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('EmailJS Response:', response.status, response.data);

    if (response.status === 200) {
      return { success: true, message: 'Verification email sent successfully' };
    } else {
      throw new functions.https.HttpsError(
        'internal',
        'Failed to send email',
        { status: response.status, body: response.data }
      );
    }
  } catch (error) {
    console.error('Error sending verification email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send verification email',
      error.response?.data || error.message
    );
  }
});

