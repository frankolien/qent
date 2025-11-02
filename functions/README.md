# Firebase Cloud Functions for Email Verification

This Cloud Function acts as a proxy to send verification emails via EmailJS, since EmailJS blocks direct API calls from mobile applications.

## Setup Instructions

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Install dependencies**:
   ```bash
   cd functions
   npm install
   ```

4. **Deploy the function**:
   ```bash
   firebase deploy --only functions
   ```

   Or from the project root:
   ```bash
   firebase deploy --only functions:sendVerificationEmail
   ```

## Function Details

- **Function Name**: `sendVerificationEmail`
- **Trigger**: HTTPS Callable
- **Purpose**: Proxies EmailJS API calls to bypass mobile app restrictions

## Testing

After deployment, the Flutter app will automatically use this function when users sign up.

