# Fix Location Services - Step by Step

## The Problem
Location services aren't working because the app needs location permission keys configured.

## The Solution (Choose ONE method)

### Method 1: Add via Build Settings (EASIEST - 2 minutes)

1. **In Xcode, close and reopen the project** to refresh the settings
2. **Select the project** (blue icon at top of navigator)
3. **Select "AdventFind" target** (under TARGETS)
4. **Click "Build Settings" tab**
5. **Click "All" and "Combined"** at the top
6. **In the search box, type:** `INFOPLIST_KEY`
7. **Scroll down to find the section with INFOPLIST_KEY settings**
8. **Look for a + button or "Add User-Defined Setting"**
9. **Add these two settings:**
   ```
   INFOPLIST_KEY_NSLocationWhenInUseUsageDescription
   Value: We need your location to help you find nearby Seventh-day Adventist churches.
   
   INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription
   Value: We need your location to help you find nearby churches and provide Sabbath time notifications.
   ```

### Method 2: Edit Info Tab (If it shows iOS properties)

1. **Select project → AdventFind target → Info tab**
2. **Look for "Custom iOS Target Properties"**
3. **Click + button**
4. **Add:**
   - `Privacy - Location When In Use Usage Description`
   - `Privacy - Location Always and When In Use Usage Description`

### Method 3: Test Without Custom Messages (QUICKEST)

The app will actually work even without custom permission messages! iOS will show a default dialog.

**Just run the app now:**
1. Press **Cmd+R**
2. When prompted for location, tap **Allow While Using App**
3. The app will work!

## What I've Already Fixed

✅ Added `onAppear` handler to request location permission
✅ Added automatic search when location is available
✅ Fixed all build errors
✅ Solar package is installed

## Testing Location in Simulator

1. **Run the app** (Cmd+R)
2. **In the simulator menu:** Features → Location → Apple
3. **Or in Xcode:** Debug → Simulate Location → Choose a city
4. **Grant permission** when prompted
5. **The app should now show nearby churches**

## If Location Still Doesn't Work

Check these:
1. **Simulator location is set:** Debug → Simulate Location → Apple Park
2. **Permission was granted:** Settings app → Privacy → Location Services → AdventFind
3. **Check console for errors:** Look for location-related error messages

## Quick Test

Run this in Terminal to verify the build includes location keys:
```bash
cd "/Users/kyleslingo/SDA Church Finder/SDA Church Finder"
xcodebuild -project "AdventFind.xcodeproj" -target "AdventFind" -showBuildSettings | grep INFOPLIST_KEY
```

If you see the location keys listed, they're configured correctly!
