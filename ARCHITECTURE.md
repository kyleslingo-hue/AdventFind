# AdventFind - Architecture Overview

## Architecture Pattern: MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────────────────┐
│                         App Layer                            │
│                  SDA_Church_FinderApp.swift                  │
│              (Entry point, SwiftData setup)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        View Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ OnboardingView│  │   HomeView   │  │ DetailView   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   MapView    │  │  ListView    │  │FavoritesView │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Component Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  GlassCard   │  │ ChurchCard   │  │LoadingView   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ SearchBar    │  │  TabBar      │  │SabbathBanner │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ViewModel Layer                           │
│                  ChurchViewModel.swift                       │
│         (Business logic, state management)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│     Service Layer        │  │      Model Layer         │
│  ┌──────────────────┐    │  │  ┌──────────────────┐   │
│  │EAdventistService │    │  │  │     Church       │   │
│  └──────────────────┘    │  │  └──────────────────┘   │
│  ┌──────────────────┐    │  │  ┌──────────────────┐   │
│  │LocationManager   │    │  │  │  SearchHistory   │   │
│  └──────────────────┘    │  │  └──────────────────┘   │
│  ┌──────────────────┐    │  │                          │
│  │SabbathTimeService│    │  │   (SwiftData Models)     │
│  └──────────────────┘    │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

## Data Flow

### 1. User Interaction Flow
```
User Action → View → ViewModel → Service → API/Storage
                ↑                              │
                └──────────── Response ────────┘
```

### 2. Location-Based Search Flow
```
1. User opens app
2. LocationManager requests permission
3. LocationManager gets current location
4. ChurchViewModel calls EAdventistService
5. EAdventistService fetches from API
6. Results cached and returned
7. ViewModel updates @Published properties
8. Views automatically update
```

### 3. Favorites Flow
```
1. User taps heart icon
2. ChurchViewModel toggles isFavorite
3. SwiftData automatically persists
4. View updates via @Published property
```

## Key Components

### Models (SwiftData)
- **Church**: Main data model with all church information
- **SearchHistory**: Tracks user search history

### Services
- **EAdventistService**: API integration, caching, network requests
- **LocationManager**: CoreLocation wrapper, permission handling
- **SabbathTimeService**: Sunset calculations using Solar library

### ViewModels
- **ChurchViewModel**: Central business logic, state management

### Views
- **OnboardingView**: Welcome flow, permissions
- **HomeView**: Main screen, search, navigation
- **MapView**: Interactive map with markers
- **ChurchListView**: Scrollable list of churches
- **ChurchDetailView**: Comprehensive church information
- **FavoritesView**: Saved churches

### Components
- **GlassCard**: Reusable frosted glass container
- **ChurchCardView**: Church list item
- **FloatingSearchBar**: Search input with glass effect
- **GlassTabBar**: Custom tab navigation
- **SabbathBanner**: Time-sensitive Sabbath info
- **LoadingView**: Loading state with animation

## State Management

### @Published Properties (ChurchViewModel)
```swift
@Published var churches: [Church]           // All fetched churches
@Published var filteredChurches: [Church]   // Filtered results
@Published var selectedChurch: Church?      // Currently selected
@Published var isLoading: Bool              // Loading state
@Published var error: String?               // Error message
@Published var searchText: String           // Search query
@Published var showMapView: Bool            // View toggle
```

### @StateObject & @ObservedObject
- Views observe ViewModel changes
- Automatic UI updates via Combine

### @AppStorage
- `isOnboardingComplete`: Persistent onboarding state

## Dependency Injection

```swift
// LocationManager injected into ViewModel
init(locationManager: LocationManager) {
    self.locationManager = locationManager
}

// ViewModel injected into Views
@StateObject private var viewModel: ChurchViewModel
```

## Caching Strategy

### API Response Cache
- **Type**: NSCache
- **Key**: Location coordinates or search term
- **Limit**: 100 items
- **Expiration**: Implicit (memory-based)

### SwiftData Persistence
- **Churches**: Stored with favorites flag
- **Search History**: Recent searches
- **Automatic**: No manual save needed

## Navigation

### NavigationStack
- Primary navigation container
- Supports deep linking
- Back navigation automatic

### Sheet Presentation
- Search options
- Share sheet
- Modal overlays

## Animations

### Spring Physics
```swift
.spring(response: 0.3, dampingFraction: 0.7)
```

### Transitions
- `.move(edge:)` for sliding
- `.opacity` for fading
- `.scale` for zoom effects

## Error Handling

### Layers
1. **Service Layer**: Throws typed errors
2. **ViewModel Layer**: Catches and converts to strings
3. **View Layer**: Displays user-friendly messages

### Error Types
- `LocationError`: Location service issues
- `APIError`: Network and API issues
- Automatic retry mechanisms

## Performance Optimizations

### Lazy Loading
- `LazyVStack` for church lists
- On-demand church detail loading

### Debouncing
- Search input debounced (300ms)
- Prevents excessive API calls

### Caching
- API response caching
- Image caching (when implemented)

### Memory Management
- Weak references where appropriate
- Automatic cleanup via ARC

## Accessibility

### VoiceOver Support
- Semantic labels on all interactive elements
- Proper heading hierarchy
- Descriptive button labels

### Dynamic Type
- System fonts scale automatically
- Layout adapts to text size

### Color Contrast
- High contrast mode support
- Sufficient color contrast ratios

## Security & Privacy

### Location Data
- Only used for church discovery
- Not stored permanently
- Permission-based access

### API Keys
- Should be stored in Config.plist (not committed)
- Environment-based configuration

### Data Storage
- Local-only (SwiftData)
- No cloud sync (optional future feature)

## Testing Strategy

### Unit Tests
- ViewModel logic
- Service layer
- Data transformations

### UI Tests
- Navigation flows
- Search functionality
- Favorites management

### Integration Tests
- API integration
- Location services
- Data persistence

## Build Configuration

### Debug
- Verbose logging
- Mock data support
- Simulator-friendly

### Release
- Optimized builds
- Production API endpoints
- Analytics enabled

## Future Scalability

### Modular Design
- Easy to add new views
- Service layer extensible
- Component library reusable

### Feature Flags
- Can add remote configuration
- A/B testing support
- Gradual rollouts

### Internationalization
- Prepared for localization
- String externalization ready
- RTL support possible

---

**This architecture provides a solid foundation for a production-ready iOS app with room for growth and enhancement.**
