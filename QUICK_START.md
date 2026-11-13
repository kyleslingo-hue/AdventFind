# Quick Start Guide - AdventFind

Get your app running in 5 minutes! 🚀

## Step 1: Add Dependencies (2 minutes)

### Add Solar Package
1. Open `AdventFind.xcodeproj` in Xcode
2. **File → Add Package Dependencies...**
3. Paste: `https://github.com/ceeK/Solar.git`
4. Click **Add Package** (twice)

That's it! The Solar package provides sunset calculations for Sabbath times.

## Step 2: Configure Permissions (1 minute)

Add location permissions to your app:

1. Select project (blue icon) → **AdventFind** target → **Info** tab
2. Click **+** in **Custom iOS Target Properties**
3. Add these two keys:
   - `Privacy - Location When In Use Usage Description` = `We need your location to help you find nearby Seventh-day Adventist churches.`
   - `Privacy - Location Always and When In Use Usage Description` = `We need your location to help you find nearby churches and provide Sabbath time notifications.`

## Step 3: Build & Run (1 minute)

1. Select your target device (iPhone 15 Pro or your physical device)
2. Press **Cmd+R** to build and run
3. Wait for build to complete

## Step 4: Test the App (1 minute)

1. **Onboarding**: Swipe through the welcome screens
2. **Grant Location Permission**: Tap "Enable Location"
3. **Discover Churches**: The app will search for nearby churches
4. **Explore**: Try the map view, list view, and church details

## Testing Tips

### On Simulator
- **Simulate Location**: Debug → Simulate Location → Choose a city
- **Recommended**: Apple Park, New York, or London

### On Device
- Make sure Location Services are enabled
- Grant "While Using App" permission
- The app will use your actual location

## What You'll See

### Onboarding Flow
- Welcome screen with app icon
- Features overview
- Location permission request

### Main Screen
- Sabbath time banner (if location available)
- Floating search bar
- Map or list view toggle
- Churches sorted by distance

### Church Details
- Full address and contact info
- Service times
- Languages spoken
- Call, directions, and website buttons
- Save to favorites

## Troubleshooting

### "Cannot find 'Solar' in scope"
**Fix**: Add the Solar package (Step 1)

### Location not working
**Fix**: 
- Check Settings → Privacy → Location Services
- Ensure app has location permission
- Try Debug → Simulate Location on simulator

### No churches showing
**Fix**: 
- The API integration may need configuration
- Check `Services/EAdventistService.swift`
- Verify network connectivity

### Build errors
**Fix**:
- Clean Build Folder: **Cmd+Shift+K**
- Rebuild: **Cmd+B**

## Next Steps

Once the app is running:

1. **Test Features**
   - Search by location
   - Search by zip code
   - Toggle map/list view
   - Save favorites
   - View church details

2. **Customize**
   - Update API endpoints if needed
   - Add app icons
   - Customize colors/branding

3. **Deploy**
   - Test on physical device
   - Configure signing
   - Prepare for App Store

## Important Files

- `SDA_Church_FinderApp.swift` - App entry point
- `HomeView.swift` - Main screen
- `EAdventistService.swift` - API integration
- `Info.plist` - Permissions & config

## Features Checklist

- ✅ Location-based search
- ✅ Zip code search
- ✅ City/state search
- ✅ Interactive map
- ✅ Church details
- ✅ Favorites
- ✅ Sabbath times
- ✅ Liquid glass UI

## Need Help?

Check these files:
- `README.md` - Full documentation
- `SETUP_INSTRUCTIONS.md` - Detailed setup
- `PROJECT_SUMMARY.md` - Complete overview

---

**You're all set! Enjoy building with AdventFind! 🎉**
