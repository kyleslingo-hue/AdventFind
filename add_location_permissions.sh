#!/bin/bash

# Script to add location permissions to the Xcode project

PROJECT_FILE="/Users/kyleslingo/SDA Church Finder/SDA Church Finder/AdventFind.xcodeproj/project.pbxproj"

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Add the location permission keys to the project file
# This adds them to the INFOPLIST_KEY settings

perl -i -pe 's/(INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;)/$1\n\t\t\t\tINFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "We need your location to help you find nearby Seventh-day Adventist churches.";/' "$PROJECT_FILE"

perl -i -pe 's/(INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "We need your location to help you find nearby Seventh-day Adventist churches.";)/$1\n\t\t\t\tINFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription = "We need your location to help you find nearby churches and provide Sabbath time notifications.";/' "$PROJECT_FILE"

echo "Location permissions added to project file"
echo "Backup saved as: $PROJECT_FILE.backup"
