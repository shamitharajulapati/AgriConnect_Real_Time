# Configure Twilio in Supabase Dashboard

## Step 1 — Go to Supabase Auth Settings
1. Open: https://supabase.com/dashboard/project/zkshiowbasmkhbopvvwb/auth/providers
2. Find "Phone" provider → Click to expand

## Step 2 — Enable Phone Auth
- Toggle: ENABLED ✅
- SMS Provider: Select "Twilio"

## Step 3 — Enter Twilio Credentials
Get these from your Twilio Console (console.twilio.com) — never commit real values here.
Account SID:   <YOUR_TWILIO_ACCOUNT_SID>
Auth Token:    <YOUR_TWILIO_AUTH_TOKEN>
From Number:   <YOUR_TWILIO_PHONE_NUMBER>

## Step 4 — Save
Click "Save" button

## Step 5 — Test
In your Flutter app, enter any real phone number
You will receive a real SMS OTP
