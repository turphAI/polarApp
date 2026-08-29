# Polar View — Testing Guide

## Prerequisites

✅ **Already Complete:**
- OAuth2 authentication flow implemented
- API configuration service set up
- Deep link handling configured
- Keychain token storage
- Beautiful LoginView UI
- Dashboard and Settings screens

✅ **API Credentials:**
- `.api-config.plist` created with your Polar API credentials
- ClientID: `12c90ec4-6125-42fa-936c-c88168e0abb3`
- ClientSecret: `5530e09d-a959-4b2e-9e6f-704b7e2d4d58`

## Pre-Flight Checklist

Before building in Xcode, verify these items:

### 1. URL Scheme Configuration
In Xcode:
1. Select **polarView** project
2. Go to **polarView** target → **Info** tab
3. Scroll to **URL Types**
4. Verify these URL Types exist:
   - **Identifier**: `com.turphai.polarView`
   - **URL Schemes**: `polarapp`

✅ **If not present**, add them:
   1. Click **+** under URL Types
   2. Set Identifier: `com.turphai.polarView`
   3. Set URL Schemes: `polarapp`

### 2. Privacy Descriptions
In Xcode:
1. Select **polarView** project
2. Go to **Info** tab
3. Verify **Key** column has these entries (or add them):
   - `NSHealthShareUsageDescription`
   - `NSHealthUpdateUsageDescription`

✅ **If not present**, add them:
   1. Click **+** next to **Custom iOS Target Properties**
   2. Key: `NSHealthShareUsageDescription`
   3. Value: `Polar View needs access to read your health data.`
   4. Repeat with `NSHealthUpdateUsageDescription`

### 3. Bundle Identifier
In Xcode, verify:
- **Product Bundle Identifier**: `com.turphai.polarView.polarView`

## Testing Scenarios

### Scenario 1: First Launch (No Token)
**Expected Behavior:**
1. App launches
2. LoginView appears with red "Sign in with Polar" button
3. Three benefits listed
4. Privacy links functional

**Steps:**
1. Build and run in simulator
2. Observe LoginView displays correctly
3. Try tapping the privacy links (should open Safari)

### Scenario 2: Sign In Flow
**Expected Behavior:**
1. Tap "Sign in with Polar"
2. Browser (Safari) opens with Polar Flow login page
3. App remains visible but dimmed behind browser
4. User enters Polar credentials in Polar Flow

**Steps:**
1. From LoginView, tap "Sign in with Polar"
2. Verify Safari opens with Polar authorization page
3. Look for "polarapp://callback" in the URL scheme

**Note:** Due to test environment limitations, you may see:
- A mock authorization page
- "ASWebAuthenticationSession" sheet instead of full browser
- This is normal for simulator testing

### Scenario 3: State Validation (CSRF Protection)
**Expected Behavior:**
- If state parameter doesn't match, authorization fails with security message
- Prevents man-in-the-middle attacks

**How It Works (Behind the Scenes):**
1. App generates random UUID as `state`
2. Sends `state` to Polar Flow authorization URL
3. On callback, validates `state` matches
4. If mismatch: error "Security validation failed"

### Scenario 4: Token Storage
**Expected Behavior:**
- After successful sign in, token stored in Keychain
- On app relaunch, user remains signed in
- No login screen appears

**Steps:**
1. Sign in successfully (or use mock token)
2. Force quit app
3. Relaunch app
4. Should go directly to Dashboard (no LoginView)

### Scenario 5: Sign Out
**Expected Behavior:**
1. Go to Settings tab
2. Tap "Sign Out"
3. Confirmation dialog appears
4. Tap "Sign Out" in dialog
5. Token cleared from Keychain
6. LoginView appears

**Steps:**
1. From Dashboard, tap "Settings" tab
2. Tap "Sign Out"
3. Confirm dialog
4. Verify LoginView appears

### Scenario 6: Dashboard Display
**Expected Behavior:**
1. After signing in, Dashboard tab active
2. Shows "Current Heart Rate" placeholder
3. Shows "Today's Summary" (High/Low/Avg)
4. Shows "Connected to Polar" status

**Steps:**
1. Sign in (or skip to dashboard if already signed in)
2. Verify all cards render correctly
3. Verify all text is readable

### Scenario 7: Metrics Tab
**Expected Behavior:**
1. Tap "Metrics" tab
2. See segmented picker (Heart Rate, Steps, Sleep, Activity)
3. Large current value display
4. 7-day trend placeholder
5. Statistics section

**Steps:**
1. Tap "Metrics" tab
2. Try switching between metric types
3. Verify values change appropriately

### Scenario 8: Settings Tab
**Expected Behavior:**
1. Tap "Settings" tab
2. See Account section with "Connected" status
3. Heart Rate Thresholds section (placeholders)
4. Notifications toggles
5. About section with links

**Steps:**
1. Tap "Settings" tab
2. Verify all sections display
3. Try toggling notification switches
4. Try tapping Privacy Policy and Terms links

## Common Issues & Troubleshooting

### Issue: LoginView doesn't appear on first launch
**Solution:**
- Check `OAuthCallbackHandler.swift` is being initialized
- Verify `ContentView.swift` creates `AuthenticationViewModel`
- Check console for warnings

### Issue: "Sign in with Polar" button does nothing
**Solution:**
- Verify URL scheme is configured in Info.plist
- Check `ConfigurationService.swift` can load `.api-config.plist`
- Add `print()` statements in `AuthenticationViewModel.signIn()`

### Issue: Token not persisting after app relaunch
**Solution:**
- Keychain operations may fail on simulator with certain configurations
- Try on physical device for reliable Keychain testing
- Check console for Keychain errors

### Issue: Can't sign out
**Solution:**
- Verify `viewModel.signOut()` is being called in SettingsView
- Check Keychain clear operation in `OAuthCallbackHandler`

## Console Output to Watch For

When running with proper logging, expect to see:

✅ **Good Signs:**
```
✅ Configuration loaded
✅ OAuth handler initialized
✅ Token saved to Keychain
✅ Authentication successful
✅ Token loaded from Keychain
✅ User signed out
```

❌ **Bad Signs:**
```
⚠️ Warning: .api-config.plist not found
❌ State mismatch! Potential CSRF attack detected.
❌ Authentication failed
❌ Token exchange error
```

## Next Steps After Testing

1. **If Auth Flow Works:**
   - Proceed to PolarAPIService implementation
   - Start fetching real heart rate data
   - Implement Daily Timeline view

2. **If Issues Found:**
   - Check error messages in console
   - Verify all files are in correct directories
   - Ensure all imports are present

3. **Security Validation:**
   - CSRF protection with state parameter ✅
   - Proper URL encoding for token exchange ✅
   - Keychain storage instead of UserDefaults ✅
   - Deep link handling with polarapp:// scheme ✅

## Performance Notes

- First launch takes ~2-3 seconds (normal)
- Keychain operations are synchronous (acceptable for token)
- No network calls until sign in button tapped
- Tab switching is smooth and responsive

---

**Ready to Test?** Build and run in Xcode, then follow the scenarios above!

