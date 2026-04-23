# Ride App — API Integration Guide (Customer + Driver)

> **Updated after full Neon DB + Better Auth migration.**
> This guide covers both the **customer app** and the **driver app** in Flutter.
> No Dart code is written here — this is the contract and flow reference.

---

## Table of Contents

1. [Stack Assumptions](#1-stack-assumptions)
2. [Auth Flow (Both Apps)](#2-auth-flow-both-apps)
3. [Customer Flows](#3-customer-flows)
   - [3.1 Onboarding](#31-onboarding)
   - [3.2 Home — Fare Estimate](#32-home--fare-estimate)
   - [3.3 Book a Ride](#33-book-a-ride)
   - [3.4 Searching for Driver](#34-searching-for-driver)
   - [3.5 Driver En Route](#35-driver-en-route)
   - [3.6 Driver Arrived — OTP Screen](#36-driver-arrived--otp-screen)
   - [3.7 Ride In Progress](#37-ride-in-progress)
   - [3.8 Payment](#38-payment)
   - [3.9 Rate Driver](#39-rate-driver)
   - [3.10 Ride History](#310-ride-history)
   - [3.11 Safety Center](#311-safety-center)
   - [3.12 Profile & Account](#312-profile--account)
4. [Driver Flows](#4-driver-flows)
   - [4.1 Onboarding (KYC)](#41-onboarding-kyc)
   - [4.2 Approval & Going Online](#42-approval--going-online)
   - [4.3 Accepting a Ride](#43-accepting-a-ride)
   - [4.4 Active Ride — Status Updates](#44-active-ride--status-updates)
   - [4.5 OTP Verification](#45-otp-verification)
   - [4.6 Completing a Ride](#46-completing-a-ride)
   - [4.7 Earnings Dashboard](#47-earnings-dashboard)
5. [Push Notifications (FCM)](#5-push-notifications-fcm)
6. [Real-Time Events (Ably)](#6-real-time-events-ably)
7. [Error Handling](#7-error-handling)
8. [API Reference](#8-api-reference)

---

## 1. Stack Assumptions

| Concern | Stack |
|---|---|
| Login | Firebase Auth (Google Sign-In / Phone OTP) — client-side only |
| Session | Better Auth JWT — server issues `sessionToken` on first sync; Flutter stores and sends on every request |
| API | REST over HTTPS. Base URL: `https://<your-backend>/api` |
| Real-time | Ably Realtime SDK |
| Push | Firebase Cloud Messaging (FCM) |
| Maps | Google Maps Flutter plugin |
| File Storage | Uploadthing (compressed server-side before upload) |
| State | Your choice (Riverpod, BLoC, Provider) |

---

## 2. Auth Flow (Both Apps)

### How it works

```
Flutter app
  └─ Firebase sign-in (Google / Phone OTP / Apple)
       └─ firebaseUser.getIdToken()  ──► POST /api/auth/sync-profile
            └─ Backend verifies Firebase ID token (Firebase Admin SDK)
                 ├─ Upserts user in Neon DB
                 ├─ Issues a Better Auth session token (30-day JWT)
                 └─ Returns sessionToken

Flutter stores sessionToken (e.g. flutter_secure_storage)
All subsequent API calls:
  Authorization: Bearer <sessionToken>
```

**Firebase is used only for sign-in. All API calls after sync-profile use the `sessionToken`.**

### First call after login — sync-profile

Call this on every app launch after Firebase sign-in. Use the **Firebase ID token** here only.

```
POST /api/auth/sync-profile
Authorization: Bearer <firebaseIdToken>

Body:
{
  "role":      "customer" | "driver",
  "fullName":  "<Firebase display name>",   // optional
  "email":     "<email>",
  "fcmToken":  "<FCM token>",
  "photoUrl":  "<Google photo URL>"         // optional
}

Response 200:
{
  "status":       "synced",
  "sessionToken": "<Better Auth JWT>",   // ← store this, use on all future calls
  "userId":       "firebase-uid",
  "isNewUser":    true | false,
  "isKycStarted": true | false,          // driver: has license_number been saved?
  "isVerified":   true | false,          // driver: admin approved?
  "isOnline":     true | false,          // driver only
  "role":         "customer" | "driver"
}
```

**Flutter:** Store `sessionToken` in `flutter_secure_storage`. On every API call send `Authorization: Bearer <sessionToken>`.

**Flutter routing logic:**

```
sync-profile response
  ├─ role = 'customer'
  │    └─ isNewUser = true  → CompleteProfileScreen
  │    └─ isNewUser = false → HomeScreen
  └─ role = 'driver'
       ├─ isNewUser = true            → DriverOnboardingScreen (Step 1)
       ├─ !isKycStarted               → DriverOnboardingScreen (Step 1)
       ├─ isKycStarted && !isVerified → PendingApprovalScreen
       └─ isVerified                  → DriverHomeScreen
```

### Session token expiry

Session tokens are valid for **30 days**. On a `401` response, call `sync-profile` again with a fresh Firebase ID token to get a new `sessionToken`. No silent token refresh needed — just re-sync.

```dart
// On 401 from any API call:
final newFirebaseToken = await FirebaseAuth.instance.currentUser!.getIdToken(true);
final syncRes = await syncProfile(firebaseToken: newFirebaseToken);
secureStorage.write('sessionToken', syncRes['sessionToken']);
// retry the original request
```

---

## 3. Customer Flows

---

### 3.1 Onboarding

**Trigger:** `sync-profile` returns `isNewUser: true`.

Show a simple form to collect name and optional photo, then call:

```
POST /api/customer/profile
Authorization: Bearer <token>

Body:
{
  "fullName": "Priya Sharma",
  "phone":    "+919876543210",   // optional
  "photoUrl": "https://..."     // optional
}

Response 200:
{ "status": "updated" }
```

After success, call `sync-profile` again — `isNewUser` will now be `false`. Navigate to `HomeScreen`.

**Also register the FCM token at launch:**

```
POST /api/notification/token
Authorization: Bearer <token>

Body: { "token": "<FCM token>", "platform": "android" }

Response 200: { "status": "registered" }
```

---

### 3.2 Home — Fare Estimate

**Trigger:** Customer selects pickup + drop on the map. Show fare before they confirm booking.

```
GET /api/ride/fare-estimate?pickupLat=12.93&pickupLng=77.62&dropLat=12.97&dropLng=77.59&rideType=human
Authorization: Bearer <token>

Response 200:
{
  "estimatedFare": 120,
  "distanceKm":   6.2,
  "durationMin":  18,
  "breakdown": {
    "base":     30,
    "distance": 74,
    "time":     27,
    "surge":    1.0    // 1.2 between 10PM–6AM
  }
}
```

**Flutter:** Call this whenever pickup/drop changes (debounce ~500ms). Display the `estimatedFare` and `breakdown` on the booking confirmation sheet.

---

### 3.3 Book a Ride

```
POST /api/ride/request
Authorization: Bearer <token>

Body:
{
  "pickup": { "lat": 12.9352, "lng": 77.6245, "address": "Koramangala, Bengaluru" },
  "drop":   { "lat": 12.9716, "lng": 77.5946, "address": "Indiranagar, Bengaluru" },
  "rideType":      "human",
  "paymentMethod": "cash"
}

Response 202:
{
  "rideId":        "uuid",
  "status":        "searching",
  "estimatedFare": 120,
  "fareBreakdown": { "base": 30, "distance": 74, "time": 12, "surge": 1.0 },
  "otp":           "1234"
}

Response 409 (already have active ride):
{
  "error":  "You already have an active ride",
  "rideId": "<existing-ride-id>",
  "status": "driver_en_route"
}
```

**Important:** Store `rideId` and `otp` in app state. The `otp` is displayed to the customer on the OTP screen. On `409`, navigate to the existing active ride instead of creating a new one.

---

### 3.4 Searching for Driver

Subscribe to Ably immediately after booking. Show a spinner/animation while `status = 'searching'`.

```dart
// Flutter: subscribe to ride channel
final channel = ablyClient.channels.get('ride:$rideId');
channel.subscribe('driver_assigned').listen((msg) {
  // { driverId, location: { lat, lng } }
  navigateTo(DriverEnRouteScreen(rideId: rideId));
});
```

**No driver found timeout:** If no `driver_assigned` event arrives within 2–3 minutes, show "No drivers nearby" and cancel:

```
POST /api/ride/:rideId/cancel
Authorization: Bearer <token>

Body: { "reason": "No drivers found" }
Response 200: { "status": "cancelled" }
```

After 5 minutes with no driver the backend auto-marks the ride `stale`. Poll `GET /api/ride/:rideId` every 30s as a fallback; if `status = 'stale'` treat it as cancelled.

---

### 3.5 Driver En Route

```
GET /api/ride/:rideId/track
Authorization: Bearer <token>

Response 200:
{
  "driverLocation": { "lat": 12.94, "lng": 77.61, "recordedAt": "2026-04-19T10:00:00Z" },
  "rideStatus":     "driver_en_route",
  "ablyChan":       "ride:<rideId>:location"
}
```

Subscribe to the location channel for live updates:

```dart
final locChannel = ablyClient.channels.get('ride:$rideId:location');
locChannel.subscribe('driver_location').listen((msg) {
  // { lat, lng, timestamp }
  updateDriverMarker(msg.data);
});
```

Poll ETA every 30s:

```
GET /api/ride/:rideId/eta
Authorization: Bearer <token>

Response 200:
{
  "phase":      "pre_pickup",
  "etaMinutes": 4,
  "distanceKm": 1.2
}
```

Listen for status change to `driver_arrived`:

```dart
channel.subscribe('status_update').listen((msg) {
  if (msg.data['status'] == 'driver_arrived') {
    navigateTo(OtpScreen(rideId: rideId, otp: storedOtp));
  }
});
```

---

### 3.6 Driver Arrived — OTP Screen

Display the 4-digit OTP prominently. The customer reads it aloud to the driver.

The OTP was received in the `POST /ride/request` response. It is also delivered via:

- **FCM notification** — payload: `{ type: 'otp', otp: '1234', rideId: '...' }`
- **Ably event** `otp_issued` on `ride:<rideId>` — payload: `{ rideId }` *(OTP value is NOT in Ably — security fix; get it from FCM or from local state)*

```dart
channel.subscribe('otp_issued').listen((_) {
  // OTP already in local state from booking response or FCM
  // Just ensure OTP screen is visible
});
```

The **driver** calls `POST /ride/verify-otp`. When verified you receive:

```dart
channel.subscribe('status_update').listen((msg) {
  if (msg.data['status'] == 'ride_started') {
    navigateTo(RideInProgressScreen(rideId: rideId));
  }
});
```

---

### 3.7 Ride In Progress

Same Ably subscriptions as 3.5. Switch ETA phase to `in_ride`:

```
GET /api/ride/:rideId/eta
Response 200: { "phase": "in_ride", "etaMinutes": 8, "distanceKm": 3.5 }
```

Listen for completion:

```dart
channel.subscribe('payment_prompt').listen((msg) {
  // { amount, method, rideId }
  navigateTo(PaymentScreen(rideId: rideId, amount: msg.data['amount']));
});
```

---

### 3.8 Payment

A payment record is auto-created by the backend when the driver marks `ride_completed`. Retrieve it:

```
GET /api/payment/:rideId
Authorization: Bearer <token>

Response 200:
{ "id": "uuid", "amount": 120, "status": "pending", "method": "cash" }
```

**Cash payment:**

```
POST /api/payment/confirm
Authorization: Bearer <token>

Body: { "paymentId": "<uuid>" }
Response 200: { "status": "completed" }
```

**UPI / Card (Razorpay):**

```
POST /api/payment/initialize
Body: { "rideId": "uuid", "method": "upi" }
Response 200: { "paymentId": "uuid", "amount": 120, "method": "upi", "status": "initiated" }
```

Open Razorpay SDK with `amount * 100` (paise). On success:

```
POST /api/payment/confirm
Body: { "paymentId": "<uuid>", "transactionId": "<razorpay_payment_id>" }
Response 200: { "status": "completed" }
```

---

### 3.9 Rate Driver

```
POST /api/ride/:rideId/rate
Authorization: Bearer <token>

Body: { "rating": 5, "comment": "Very smooth ride!" }
Response 200: { "status": "rated" }
```

Only works after `status = 'ride_completed'`. Show this screen once, then navigate to Home.

---

### 3.10 Ride History

```
GET /api/ride/history
Authorization: Bearer <token>

Response 200: [ { "id", "pickup_address", "drop_address", "status", "final_fare", "created_at", ... } ]
```

Returns max 20 rides, newest first. Tap a ride → `GET /api/ride/:rideId` for full details.

---

### 3.11 Safety Center

**List contacts:**
```
GET /api/safety/contacts   → { "contacts": [...] }
```

**Add contact:**
```
POST /api/safety/contacts
Body: { "name": "Mom", "phone": "+919876543210", "relationship": "Mother" }
```

**Delete contact:**
```
DELETE /api/safety/contacts/:contactId
```

**Trigger SOS:**
```
POST /api/safety/sos
Body: { "rideId": "uuid", "location": { "lat": 12.93, "lng": 77.62 } }
Response 200: { "status": "sos_triggered" }
```

**Share trip:**
```
POST /api/safety/share-trip
Body: { "rideId": "uuid" }
Response 200: { "token": "abc123", "shareUrl": "https://yourapp.com/track/abc123" }
```

Open the native share sheet with `shareUrl`. The public endpoint `GET /api/safety/share-trip/:token` requires no auth.

---

### 3.12 Profile & Account

```
GET /api/customer/profile
Response 200: { "id", "full_name", "email", "phone", "photo_url", "role", "created_at" }

POST /api/customer/profile
Body: { "fullName": "...", "phone": "...", "photoUrl": "..." }
```

**Sign out:** Call `FirebaseAuth.instance.signOut()`, then deregister FCM:
```
DELETE /api/notification/token
Body: { "token": "<fcm-token>" }
```

---

## 4. Driver Flows

---

### 4.1 Onboarding (KYC)

**Trigger:** `sync-profile` returns `isNewUser: true` OR `isKycStarted: false`.

6 sequential steps — each must succeed before the next screen is shown.

---

**Step 1 — Personal Details**

```
POST /api/onboard/personal-details
Authorization: Bearer <token>

Body:
{
  "fullName":    "Rajan Kumar",
  "dateOfBirth": "1990-05-15",
  "gender":      "Male",
  "address":     "123 MG Road",
  "city":        "Bengaluru",
  "state":       "Karnataka",
  "pincode":     "560001",
  "photoUrl":    "https://..."   // optional
}

Response 200: { "nextStep": "license-details" }
```

---

**Step 2 — License Details**

```
POST /api/onboard/license-details
Body: { "licenseNumber": "KA0120190012345", "expiryDate": "2030-12-31" }
Response 200: { "nextStep": "aadhaar-details" }
```

---

**Step 3 — Aadhaar**

```
POST /api/onboard/aadhaar-details
Body: { "aadhaarNumber": "123456789012" }   // 12 digits
Response 200: { "nextStep": "vehicle-details" }
```

Aadhaar is stored encrypted with AES-256-GCM + random IV (never stored raw).

---

**Step 4 — Vehicle Details**

```
POST /api/onboard/vehicle-details
Body:
{
  "vehiclePlateNumber": "KA01AB1234",
  "vehicleRcNumber":    "KA012023123456",
  "vehicleType":        "sedan"   // "auto" | "sedan" | "suv" | "bike"
}
Response 200: { "nextStep": "upload-urls" }
```

---

**Step 5 — Upload Documents**

Upload each document one at a time as multipart form data. The server compresses the image (JPEG, max 1200px, quality 60 via sharp) before storing on Uploadthing.

```
POST /api/onboard/upload-document
Authorization: Bearer <sessionToken>
Content-Type: multipart/form-data

Fields:
  file          — image file (JPEG/PNG, max 10 MB raw)
  documentType  — one of:
                    driving_license_front | driving_license_back | driving_license_selfie
                    aadhaar_front | aadhaar_back
                    vehicle_rc_front | vehicle_rc_back | vehicle_front | vehicle_back
                    profile_photo

Response 200:
{
  "publicUrl":    "https://utfs.io/f/...",
  "key":          "...",
  "documentType": "driving_license_front"
}
```

**Flutter:** Send each document separately. Show a progress indicator per document. Upload all 10 before proceeding.

```dart
// Example: upload one document
final request = http.MultipartRequest('POST', Uri.parse('$BASE_URL/onboard/upload-document'));
request.headers['Authorization'] = 'Bearer $sessionToken';
request.fields['documentType'] = 'driving_license_front';
request.files.add(await http.MultipartFile.fromPath('file', imagePath));
final response = await request.send();
```

---

**Step 6 — Submit**

After all documents are uploaded, mark KYC as submitted:

```
POST /api/onboard/submit
Authorization: Bearer <sessionToken>

Response 200: { "status": "submitted" }
```

After submission, navigate to `PendingApprovalScreen`. Poll `GET /api/onboard/status` or wait for an FCM push.

---

**Check onboarding status:**

```
GET /api/onboard/status
Response 200:
{
  "verified":  false,
  "documents": [ { "document_type": "driving_license_front", "front_image_url": "..." }, ... ]
}
```

---

### 4.2 Approval & Going Online

**Trigger:** Admin approves the driver. Driver receives FCM:

```
FCM data: { "type": "kyc_status", "approved": "true" }
```

On this notification: call `sync-profile` → `isVerified` will now be `true`. Navigate to `DriverHomeScreen`.

**Going online:**

```
POST /api/availability/toggle
Authorization: Bearer <token>

Body:
{
  "isOnline": true,
  "location": { "lat": 12.97, "lng": 77.59 },
  "headingLocation": "Indiranagar"   // optional — improves ride matching
}

Response 200: { "status": "online", "headingCoords": { "lat": ..., "lng": ... } }

Response 403 (not verified):
{ "error": "Your account is pending verification. You cannot go online until approved." }
```

**Going offline:**

```
POST /api/availability/toggle
Body: { "isOnline": false, "location": { "lat": ..., "lng": ... } }
Response 200: { "status": "offline" }
```

**Check online status:**
```
GET /api/availability/status
Response 200: { "isOnline": true, "location": { "lat", "lng" }, "heading": { "lat", "lng", "name" } | null }
```

---

### 4.3 Accepting a Ride

When online, the driver receives an FCM ride offer:

```
FCM data: { "type": "ride_offer", "rideId": "uuid", "driverId": "uuid" }
```

Show a ride offer card with a 60-second countdown. The driver can:

**View available rides (pull-based):**
```
GET /api/match/requests
Response 200: [ { "id", "pickup_address", "drop_address", "estimated_fare", "distance", ... } ]
```

**Accept:**
```
POST /api/match/respond
Body: { "rideId": "uuid", "driverId": "<driver-profile-id>", "response": "accept" }

Response 200: { "status": "accepted", "ride": { ... } }
Response 409: { "error": "Ride already taken by another driver" }
```

**Reject:**
```
POST /api/match/respond
Body: { "rideId": "uuid", "driverId": "<driver-profile-id>", "response": "reject" }
Response 200: { "status": "rejected" }
```

On `409` (race condition — another driver accepted faster), just dismiss the card.

---

### 4.4 Active Ride — Status Updates

```
POST /api/ride/status
Authorization: Bearer <token>

Body: { "rideId": "uuid", "status": "driver_en_route" }
Response 200: { "status": "updated" }
```

Status progression (driver controls):

```
driver_en_route    → after accepting ride (auto-set by /match/respond)
driver_arrived     → driver physically arrives at pickup
                     (triggers OTP FCM to customer)
ride_completed     → after OTP verified and ride ends
                     (auto-creates payment, sets driver back online)
```

**Send location updates every 5 seconds while active:**

```
POST /api/availability/location
Body: { "lat": 12.97, "lng": 77.59 }
Response 200: { "ack": true }
```

---

### 4.5 OTP Verification

When at pickup, the customer reads their OTP aloud. The driver enters it:

```
POST /api/ride/verify-otp
Authorization: Bearer <token>   (driver role required)

Body: { "rideId": "uuid", "otp": "1234" }

Response 200: { "status": "verified", "rideStarted": true }
Response 400: { "error": "Invalid or expired OTP" }
```

If the customer didn't receive their OTP:

```
POST /api/ride/:rideId/resend-otp
Authorization: Bearer <token>   (driver role required)

Response 200: { "status": "otp_resent" }
```

---

### 4.6 Completing a Ride

```
POST /api/ride/status
Body: { "rideId": "uuid", "status": "ride_completed" }
Response 200: { "status": "updated" }
```

This automatically:
- Sets `final_fare = estimated_fare`
- Creates a payment record
- Publishes `payment_prompt` to customer
- Sets driver back to `is_online = true`

---

### 4.7 Earnings Dashboard

```
GET /api/availability/earnings?date=2026-04-19
Authorization: Bearer <token>

Response 200:
{
  "date":          "2026-04-19",
  "totalRides":    5,
  "totalEarnings": 620.50,
  "rides": [
    { "id": "uuid", "final_fare": 120, "status": "ride_completed", "completed_at": "..." },
    ...
  ]
}
```

Omit `date` to get today's earnings. Show this on the driver home screen.

---

## 5. Push Notifications (FCM)

Register the token on every app launch:

```
POST /api/notification/token
Body: { "token": "<FCM token>", "platform": "android" | "ios" }
```

### Customer — Notification Types

| `data.type` | When | Flutter action |
|---|---|---|
| `otp` | Driver marks `driver_arrived` | Show OTP prominently; `data.otp` contains the value |
| `cancellation` | Driver cancels the ride | Show alert, navigate to Home |

### Driver — Notification Types

| `data.type` | When | Flutter action |
|---|---|---|
| `ride_offer` | New ride matched | Show offer card with 60s timer |
| `kyc_status` | Admin approves/rejects | Call sync-profile, route accordingly |
| `cancellation` | Customer cancels | Show alert, set driver back online UI |

### Background handling (Flutter)

```dart
FirebaseMessaging.onBackgroundMessage(_handleBackground);

Future<void> _handleBackground(RemoteMessage msg) async {
  final type = msg.data['type'];
  if (type == 'otp') {
    // Save to local storage — OTP screen reads it on resume
    await prefs.setString('otp_${msg.data["rideId"]}', msg.data['otp']);
  }
}
```

---

## 6. Real-Time Events (Ably)

```dart
final ably = ably_flutter.Realtime(options: ClientOptions(key: '<ABLY_KEY>'));
```

### `ride:<rideId>` — Ride lifecycle (subscribe on both apps)

| Event | Payload | Who cares |
|---|---|---|
| `driver_assigned` | `{ driverId, location }` | Customer |
| `status_update` | `{ status, updatedAt }` | Both |
| `otp_issued` | `{ rideId }` | Customer — OTP value comes via FCM only, not here |
| `payment_prompt` | `{ amount, method, rideId }` | Customer |
| `ride_cancelled` | `{ cancelledBy, reason }` | Both |

### `ride:<rideId>:location` — Driver GPS

| Event | Payload | Who cares |
|---|---|---|
| `driver_location` | `{ lat, lng, timestamp }` | Customer (map marker) |

### `driver:<driverId>` — Driver status

| Event | Payload | Who cares |
|---|---|---|
| `status` | `{ isOnline, location }` | Driver app (own status sync) |

### Cleanup

Always unsubscribe when leaving a screen to avoid memory leaks:

```dart
@override
void dispose() {
  rideChannel.unsubscribe();
  locationChannel.unsubscribe();
  super.dispose();
}
```

---

## 7. Error Handling

```dart
Future<Map<String, dynamic>> apiCall(String path, {String method = 'GET', Map? body}) async {
  final sessionToken = await secureStorage.read(key: 'sessionToken');

  final response = await http.Request(method, Uri.parse('$BASE_URL$path'))
    ..headers['Authorization'] = 'Bearer $sessionToken'
    ..headers['Content-Type'] = 'application/json'
    ..body = body != null ? jsonEncode(body) : '';

  if (response.statusCode == 401) {
    // Session expired — re-sync with a fresh Firebase token to get a new sessionToken
    final firebaseToken = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final syncRes = await syncProfile(firebaseToken: firebaseToken);
    await secureStorage.write(key: 'sessionToken', value: syncRes['sessionToken']);
    // retry request once with new token
    return apiCall(path, method: method, body: body);
  }

  if (response.statusCode == 403) {
    // Account deactivated OR unverified driver trying to go online
    final err = jsonDecode(response.body);
    showSnackbar(err['error']);
    return {};
  }

  if (response.statusCode == 409) {
    // Conflict: duplicate ride or race condition on match
    final err = jsonDecode(response.body);
    // Handle: navigate to existing ride if rideId present
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode >= 400) throw ApiException(data['error'] ?? 'Unknown error');
  return data;
}
```

### HTTP Status Codes

| Code | Meaning | Flutter action |
|---|---|---|
| `200/201/202` | Success | Handle response |
| `400` | Validation / business rule failure | Show `error` field to user |
| `401` | Session token invalid / expired | Call sync-profile with fresh Firebase token, retry |
| `403` | Not allowed (wrong role, deactivated, unverified) | Show `error`, possibly sign out |
| `404` | Resource not found | Show "not found" UI |
| `409` | Conflict (duplicate ride, race condition) | Navigate to existing resource |
| `500` | Server error | Show generic error, retry |

---

## 8. API Reference

### Customer Endpoints

| Method | Path | Summary |
|---|---|---|
| `POST` | `/auth/sync-profile` | Login hook — creates/updates user, returns routing flags |
| `GET` | `/auth/me` | Full user profile |
| `POST` | `/customer/profile` | Complete profile (name, phone, photo) |
| `GET` | `/customer/profile` | Get customer profile |
| `POST` | `/notification/token` | Register FCM token |
| `DELETE` | `/notification/token` | Deregister FCM token (on sign-out) |
| `GET` | `/availability/location-suggestion?query=` | Location autocomplete |
| `GET` | `/ride/fare-estimate?pickupLat=&pickupLng=&dropLat=&dropLng=&rideType=` | Fare preview before booking |
| `POST` | `/ride/request` | Book a ride |
| `GET` | `/ride/history` | Last 20 rides |
| `GET` | `/ride/:rideId` | Ride details |
| `GET` | `/ride/:rideId/track` | Driver location + Ably channel |
| `GET` | `/ride/:rideId/eta` | Current ETA |
| `POST` | `/ride/:rideId/cancel` | Cancel ride |
| `POST` | `/ride/:rideId/rate` | Rate driver after completion |
| `GET` | `/payment/:rideId` | Get payment record |
| `POST` | `/payment/initialize` | Init Razorpay (UPI/card) |
| `POST` | `/payment/confirm` | Confirm payment |
| `GET` | `/safety/contacts` | List emergency contacts |
| `POST` | `/safety/contacts` | Add emergency contact |
| `DELETE` | `/safety/contacts/:contactId` | Remove emergency contact |
| `POST` | `/safety/sos` | Trigger SOS alert |
| `POST` | `/safety/share-trip` | Create shareable trip link |
| `GET` | `/safety/share-trip/:token` | Resolve share link (no auth) |

### Driver Endpoints

| Method | Path | Summary |
|---|---|---|
| `POST` | `/auth/sync-profile` | Same as customer — use `role: 'driver'` |
| `POST` | `/onboard/personal-details` | Step 1 |
| `POST` | `/onboard/license-details` | Step 2 |
| `POST` | `/onboard/aadhaar-details` | Step 3 |
| `POST` | `/onboard/vehicle-details` | Step 4 — includes `vehicleType` |
| `POST` | `/onboard/upload-document` | Step 5 — upload one document (multipart, server compresses) |
| `POST` | `/onboard/submit` | Step 6 — mark KYC submitted |
| `GET` | `/onboard/status` | KYC status + documents |
| `POST` | `/availability/toggle` | Go online/offline |
| `GET` | `/availability/status` | Current online status + location |
| `POST` | `/availability/location` | Push location update (every 5s while active) |
| `GET` | `/availability/earnings?date=YYYY-MM-DD` | Daily earnings summary |
| `GET` | `/match/requests` | Available ride requests nearby |
| `POST` | `/match/respond` | Accept or reject a ride offer |
| `POST` | `/ride/status` | Update ride status (driver only) |
| `POST` | `/ride/verify-otp` | Verify OTP to start ride (driver only) |
| `POST` | `/ride/:rideId/resend-otp` | Resend OTP to customer (driver only) |
| `GET` | `/ride/history` | Driver's past 20 rides |
| `POST` | `/ride/:rideId/cancel` | Cancel ride |
| `POST` | `/ride/:rideId/rate` | Rate customer |

### Admin Endpoints

| Method | Path | Summary |
|---|---|---|
| `POST` | `/onboard/admin/approve/:driverUserId` | Approve or reject a driver's KYC |
