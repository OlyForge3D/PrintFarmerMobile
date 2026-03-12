# Ripley - iOS Developer History

## Learnings

### SignalR Real-Time Updates for Dashboard (2026-03-12)
**Files Modified:**
- `PrintFarmer/ViewModels/DashboardViewModel.swift`
- `PrintFarmer/Views/Dashboard/DashboardView.swift`

**Bug Fixed:**
Printer cards in the Dashboard and Printer List were showing stale state after print completion, while the Printer Detail page showed accurate real-time state.

**Root Cause:**
- `PrinterDetailViewModel` ✅ subscribed to SignalR updates via `configureSignalR()`
- `PrinterListViewModel` ✅ subscribed to SignalR updates via `configureSignalR()`
- `DashboardViewModel` ❌ did NOT subscribe to SignalR updates — only loaded data on initial load/refresh

**Solution:**
Added SignalR subscription to `DashboardViewModel` following the same pattern used in `PrinterListViewModel`:

1. **DashboardViewModel Changes:**
   - Added `signalRService` property
   - Created `configureSignalR()` method to subscribe to printer updates
   - Created `applyPrinterUpdate()` method to update printer state in the printers array
   - Updates all printer fields: state, progress, job name, temps, targets, spool info

2. **DashboardView Changes:**
   - Added `viewModel.configureSignalR(services.signalRService)` call in `.task` block
   - Now receives real-time updates alongside initial data load

**Key Pattern:**
All ViewModels that display printer data (list, detail, dashboard) now consistently subscribe to SignalR's `onPrinterUpdated` handler and apply updates to their local printer state. This ensures all views stay in sync with real-time printer status changes.

**Architecture Note:**
SignalRService uses a broadcast pattern — all subscribed ViewModels receive all printer updates. Each ViewModel filters updates by printer ID if needed (e.g., PrinterDetailViewModel only processes updates for its printer, while PrinterListViewModel and DashboardViewModel process all updates).

**Build Result:** ✅ Build succeeded on iPhone 17 Pro simulator

---

### Farm Status Integration into Dashboard (2025-01-20)
**Files Modified:**
- `PrintFarmer/Views/Dashboard/DashboardView.swift`
- `PrintFarmer/ViewModels/DashboardViewModel.swift`
- `PrintFarmer/Extensions/Formatting+Extensions.swift`
- `PrintFarmer/Views/Jobs/JobListView.swift`
- `PrintFarmer/Navigation/AppDestination.swift`

**Files Deleted:**
- `PrintFarmer/Views/Jobs/JobAnalyticsView.swift`

**Changes Made:**
1. **Integrated Farm Status Sections into Dashboard:**
   - Added Queue Health card showing queued/printing/paused counts + average wait time
   - Added "By Printer Model" breakdown with job counts per model
   - Added "Active Print ETAs" showing currently printing jobs with progress
   - Added "Up Next" showing next 5 queued jobs with assigned printers and queue position
   - All sections use existing JobAnalyticsService methods

2. **Updated DashboardViewModel:**
   - Added `queueStats`, `modelStats`, and `upcomingJobs` properties
   - Added `jobAnalyticsService` dependency injection
   - Extended `loadDashboard()` to fetch farm status data alongside printers/queue
   - Added `activePrintingPrinters` computed property

3. **Layout Strategy:**
   - iPad: 2-column layout for Model Breakdown + Active ETAs side-by-side
   - iPhone: stacked vertical layout
   - Farm Status sections placed after Active Jobs, before Dispatch link (iPhone) or alongside Dispatch (iPad)
   - Consistent card styling with `.pfCard`, `.pfBorder`, rounded corners

4. **Added TimeInterval Extension:**
   - Created `etaFormatted` in `Formatting+Extensions.swift`
   - Shows "2:45 PM" for today, "Tomorrow 10:00 AM" for tomorrow, relative format for further dates
   - Complements existing `durationFormatted` for elapsed time

5. **Removed Job Analytics Page:**
   - Deleted `JobAnalyticsView.swift` (functionality now on Dashboard)
   - Removed `case jobAnalytics` from `AppDestination.swift`
   - Removed toolbar button from `JobListView.swift` (lines 39-43)
   - Removed navigation case from `destinationView` (lines 319-320)
   - Updated Xcode project.pbxproj to remove file references

**Key Patterns:**
- Used separate helper functions (`modelStatRow`, `activePrintRow`, `upNextRow`) to break up complex VStack expressions for faster type-checking
- ForEach with `Array()` wrapper and explicit `id:` for non-Binding collections
- Color references use `Color.pfAccent` instead of `.pfAccent` in `.foregroundStyle()` to avoid ShapeStyle type inference issues
- Responsive design: 4-column grid on iPad, 2-column on iPhone for queue stats

**Architecture Decisions:**
- DashboardViewModel now aggregates both fleet status and job analytics data
- JobAnalyticsViewModel kept intact (reusable for future analytics features)
- Farm Status is now the dashboard's primary view of queue health, not a separate navigation destination

**Build Result:** ✅ Build succeeded on iPhone 17 Pro simulator

---

### Temperature Display Enhancements (2025-01-20)
**Files Modified:**
- `PrintFarmer/Views/Components/PrinterCardView.swift` (iPhone)
- `PrintFarmer/Views/Components/iPadPrinterCardView.swift` (iPad)

**Changes Made:**
1. **Dynamic Temperature Format:**
   - Created `temperatureText(current:target:)` function to display "current → target" when heating (target > 0)
   - Shows only "current" when heater off, "---°C" when no data
   - Changed separator from "/" to "→" on iPad to match iPhone
   - Kept `.monospacedDigit()` for consistent text width alignment

2. **Dynamic Icon Colors:**
   - Created `iconColor(for:)` function returning `.pfWarning` (orange) when heater on, `.pfTextTertiary` (gray) when off
   - Applied to both NozzleIcon (hotend) and RadiatorIcon (bed) on both cards
   - Replaced static colors `.pfNotHomed` and `.pfHomed`

3. **Fixed 2-Column Layout:**
   - Added `.frame(maxWidth: .infinity, alignment: .leading)` to each temperature Label
   - Prevents bed icon from shifting when hotend temp text width changes (e.g., "25°C" vs "215°C → 220°C")
   - Both columns now have equal width regardless of content

**Patterns Used:**
- SwiftUI `.frame(maxWidth: .infinity, alignment:)` for equal-width columns without Grid complexity
- Conditional rendering based on optional target value: `if let target, target > 0`
- Extracted helper functions for reusable logic (temperatureText, iconColor)
- Maintained consistent font sizing: `.caption` on iPhone, `.subheadline` on iPad

**Key Decisions:**
- Used simple frame-based layout instead of Grid for cleaner code and broad iOS compatibility
- Arrow "→" styled as `.foregroundStyle(.tertiary)` to match the previous "/" styling
- Target temp shown as `.foregroundStyle(.secondary)` to visually distinguish from current temp
- Heater state determined by target value (> 0) rather than adding new model properties

**Build Result:** ✅ Build succeeded on iPhone 17 Pro simulator

---

### Swipeable Paged Layouts for iPhone (2026-03-12)
**Files Created:**
- `PrintFarmer/Views/Components/PageIndicator.swift`

**Files Modified:**
- `PrintFarmer/Views/Dashboard/DashboardView.swift`
- `PrintFarmer/Views/Jobs/JobListView.swift`
- `PrintFarmer/Views/Maintenance/MaintenanceView.swift`
- `PrintFarmer.xcodeproj/project.pbxproj` (added PageIndicator, removed JobAnalyticsView)

**Changes Made:**
1. **Created PageIndicator Component:**
   - Reusable view showing dot indicators + page title labels
   - Active dot uses `.pfAccent`, inactive uses `.pfTextTertiary.opacity(0.5)`
   - Labels in `.caption2` with active page highlighted
   - Tapping dots/labels animates to that page
   - 8pt dots, 6pt spacing between dots

2. **DashboardView - 3 Swipeable Pages (iPhone only):**
   - **Page 0 "Overview"**: Fleet Overview summary cards + Queue Health
   - **Page 1 "Active"**: Active Jobs + Active Print ETAs sections
   - **Page 2 "Queue"**: Up Next + By Printer Model + Dispatch link
   - **Pinned content**: Maintenance Alert banner (always visible above TabView when alerts exist)
   - iPad keeps existing 2-column ScrollView layout unchanged
   - Each page has independent `.refreshable` support

3. **JobListView - 3 Swipeable Pages (iPhone only):**
   - **Page 0 "Printing"**: Currently printing/active jobs
   - **Page 1 "Queue"**: Queued/pending jobs with swipe actions (Start, Cancel)
   - **Page 2 "Recent"**: Completed/failed/cancelled jobs (last 10)
   - Each page shows empty state when no jobs in that category
   - iPad keeps existing single-List layout with sections
   - All swipe actions preserved on Queue page

4. **MaintenanceView - 2 Swipeable Pages (iPhone only):**
   - **Page 0 "Alerts"**: Active maintenance alerts + Analytics link + Uptime link
   - **Page 1 "Tasks"**: Upcoming maintenance tasks
   - Empty states for each page when no content
   - iPad keeps existing ScrollView layout
   - Navigation links to MaintenanceAnalytics and UptimeReliability preserved

**Implementation Pattern:**
```swift
if sizeClass == .compact {
    VStack(spacing: 0) {
        TabView(selection: $currentPage) {
            Page1().tag(0)
            Page2().tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        
        PageIndicator(currentPage: $currentPage, pageCount: 2, labels: ["Label1", "Label2"])
    }
} else {
    // iPad: existing layout
}
```

**Key Decisions:**
- Used `.page(indexDisplayMode: .never)` to hide default page dots, replaced with custom PageIndicator
- Each page is an extracted `@ViewBuilder` function for clarity
- Branch on `horizontalSizeClass == .compact` for iPhone, `.regular` for iPad
- Each page content wrapped in ScrollView with independent `.refreshable`
- Empty states shown per-page when appropriate
- 16pt padding on all page content
- Smooth animation on page change (`.easeInOut(duration: 0.25)`)

**Design Adherence:**
- Active page indicator: `.pfAccent` color
- Inactive dots: `.pfTextTertiary.opacity(0.5)`
- Page labels: `.caption2`, `.pfTextSecondary` (inactive), `.pfAccent` (active)
- 8pt dot diameter, 6pt spacing
- 16pt padding on page content
- Dark theme compatible

**Build Result:** ✅ Build succeeded on iPhone 17 Pro simulator

---

### Dispatch Page Navigation Crash Fix (2026-03-12)
**Files Modified:**
- `PrintFarmer/ViewModels/DispatchViewModel.swift`

**Bug Fixed:**
App crashed when pressing the back button on the Dispatch Dashboard page (accessed via `AppDestination.dispatchDashboard` from Dashboard).

**Root Cause:**
The `DispatchViewModel` had async methods (`loadQueueStatus()` and `loadHistory()`) that were called from SwiftUI's `.task` and `.refreshable` modifiers. When the user navigated back while these async operations were in progress, the tasks continued execution after the view was dismissed. This caused property updates on the `@Observable` ViewModel during view tear-down, leading to a crash.

**Solution:**
Added `Task.isCancelled` checks in both async methods:
- Check before updating properties after async network calls complete
- Check before updating state properties like `isLoading` and `error`
- Early return if task is cancelled, preventing state mutation during view dismissal

**Pattern Applied:**
```swift
func loadQueueStatus() async {
    // ... async network call
    let status = try await dispatchService.getQueueStatus()
    guard !Task.isCancelled else { return }
    queueStatus = status  // Safe: only update if task not cancelled
}
```

**Key Insight:**
With SwiftUI's `.task` modifier, tasks are automatically cancelled when the view disappears. However, async operations that complete *just as* the view is being dismissed can try to mutate `@Observable` properties during tear-down. Always guard property updates with `Task.isCancelled` checks in async methods called from `.task` or `.refreshable`.

**Build Result:** ✅ Build succeeded on iPhone 17 Pro simulator

