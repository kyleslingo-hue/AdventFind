# How to Add Location Permissions - Manual Method

Since the Xcode UI is only showing macOS properties, follow these steps:

## Option 1: Edit in Xcode (Recommended)

1. **In Xcode, go to the top menu:**
   - Product → Scheme → Edit Scheme...
   - OR just press **Cmd+<** (Command + Less Than)

2. **Select "Run" on the left sidebar**

3. **Go to the "Arguments" tab**

4. **Under "Environment Variables", click the + button and add:**
   - Name: `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`
   - Value: `We need your location to help you find nearby Seventh-day Adventist churches.`

5. **Click + again and add:**
   - Name: `INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription`
   - Value: `We need your location to help you find nearby churches and provide Sabbath time notifications.`

## Option 2: Edit Build Settings Directly

1. **In Xcode, select your project** (blue icon at top of navigator)
2. **Select the "AdventFind" target**
3. **Click on "Build Settings" tab** (not Info)
4. **Search for "Info.plist"** in the filter box
5. **Find "Info.plist Values"** section
6. **Click the + button** and add:
   - `NSLocationWhenInUseUsageDescription` = `We need your location to help you find nearby Seventh-day Adventist churches.`
   - `NSLocationAlwaysAndWhenInUseUsageDescription` = `We need your location to help you find nearby churches and provide Sabbath time notifications.`

## Option 3: Quick Fix - Just Run It!

The app will actually work without these permissions being set in advance. When you run the app:

1. Press **Cmd+R** to build and run
2. When the app requests location permission, iOS will show a default message
3. The app will still function correctly

You can add the custom permission messages later if needed.

## Verify Solar Package

Good news: I can see Solar package (v3.0.1) is already added to your project!

## Ready to Test

Your app is ready to run! Just press **Cmd+R** and test it out.
