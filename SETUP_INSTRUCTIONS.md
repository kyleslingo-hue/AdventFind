# Setup Instructions for AdventFind

Follow these steps to complete the setup of your AdventFind app.

## Step 1: Add Swift Package Dependencies

The app requires the **Solar** package for calculating sunset times for Sabbath mode.

### In Xcode:

1. Open `AdventFind.xcodeproj` in Xcode
2. In the menu bar, go to **File → Add Package Dependencies...**
3. In the search field, enter: `https://github.com/ceeK/Solar.git`
4. Click **Add Package**
5. Select **Solar** from the list
6. Click **Add Package** again

## Step 2: Configure Location Permissions

You need to add location permission descriptions to your app's configuration.

### In Xcode:

1. In Xcode, select your project in the navigator (blue icon at top)
2. Select the **AdventFind** target (under TARGETS)
3. Go to the **Info** tab
4. In the **Custom iOS Target Properties** section, click the **+** button to add new keys
5. Add the following two keys:

   **Key 1:**
   - Key: `Privacy - Location When In Use Usage Description`
   - Type: String
   - Value: `We need your location to help you find nearby Seventh-day Adventist churches.`

   **Key 2:**
   - Key: `Privacy - Location Always and When In Use Usage Description`
   - Type: String
   - Value: `We need your location to help you find nearby churches and provide Sabbath time notifications.`

**Note:** Modern iOS projects (iOS 17+) don't use a separate Info.plist file. All configuration is done through the target settings in Xcode.

## Step 3: Verify EAdventist API Configuration

The app is configured to use the EAdventist directory API. You may need to verify or update the API endpoints.

1. Open `Services/EAdventistService.swift`
2. Check the `baseURL` constant (currently set to `https://www.adventistdirectory.org`)
3. If the API requires authentication or different endpoints, update accordingly

**Note**: The current implementation assumes a REST API. If the actual EAdventist API differs, you may need to:
- Add API keys or authentication tokens
- Update the endpoint URLs
- Modify the request/response handling

## Step 4: Build and Test

1. Select your target device or simulator (iOS 17.0+)
2. Press **Cmd+B** to build the project
3. Fix any build errors (mainly related to missing dependencies)
4. Press **Cmd+R** to run the app

## Step 5: Test Location Services

1. When the app launches, you'll see the onboarding flow
2. Grant location permissions when prompted
3. The app should request your location and attempt to find nearby churches

### Testing on Simulator:

To test location features on the simulator:
1. In the simulator, go to **Features → Location**
2. Choose a preset location (e.g., "Apple" or "Custom Location")
3. Or use **Debug → Simulate Location** in Xcode

## Troubleshooting

### Build Errors

**Error: "Cannot find 'Solar' in scope"**
- Solution: Make sure you've added the Solar package dependency (Step 1)
- Clean build folder: **Product → Clean Build Folder** (Cmd+Shift+K)
- Rebuild the project

**Error: "Missing Info.plist keys"**
- Solution: Add the location permission keys (Step 2)

### Runtime Issues

**Location not working:**
- Check that location permissions are granted in Settings → Privacy → Location Services
- Verify Info.plist has the correct permission descriptions
- Check that location services are enabled on the device/simulator

**No churches showing:**
- The API integration may need adjustment based on the actual EAdventist API
- Check console logs for API errors
- Verify network connectivity

**App crashes on launch:**
- Check that SwiftData models are properly configured
- Verify all dependencies are correctly added
- Check console for specific error messages

## Optional: Configure for Production

### 1. Update App Icons
- Add app icons to `Assets.xcassets/AppIcon`
- Use 1024x1024 PNG for the App Store icon

### 2. Configure Signing
- Select your project → Target → Signing & Capabilities
- Choose your development team
- Configure bundle identifier

### 3. Update API Configuration
- If using a production API, update the base URL in `EAdventistService.swift`
- Add any required API keys to a secure configuration file
- Never commit API keys to version control

### 4. Test on Physical Device
- Connect an iOS device
- Select it as the run destination
- Build and run to test real location services

## Next Steps

Once setup is complete:
1. Test all features thoroughly
2. Verify location-based search works correctly
3. Test the map view and church details
4. Verify favorites persistence
5. Test Sabbath time calculations
6. Check accessibility features

## Need Help?

If you encounter issues:
1. Check the console logs in Xcode for error messages
2. Verify all dependencies are correctly installed
3. Ensure iOS deployment target is set to 17.0 or higher
4. Review the README.md for additional information

## Important Notes

- The app currently uses mock/example API endpoints for EAdventist
- You may need to contact EAdventist for official API access
- Consider implementing offline caching for better performance
- Test thoroughly on both iOS devices and simulators
