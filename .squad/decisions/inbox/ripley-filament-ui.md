# Filament UI Architecture (Ripley, 2025-07-18)
**Status:** Implemented

## Tab Structure Change
- Added **Inventory** tab (6th tab) to ContentView TabView using `cylinder.fill` SF Symbol
- Added `AppTab.inventory` case and `inventoryPath` NavigationPath to AppRouter
- Tab order: Dashboard → Printers → Jobs → Alerts → **Inventory** → Settings

## Filament Section in PrinterDetailView
- Filament section always renders between Camera and Actions sections
- Shows active spool info (color swatch, material, vendor, weight progress bar) or "No filament loaded" empty state
- "Load Filament" / "Change Filament" → presents SpoolPickerView as `.sheet`
- "Eject" → calls `printerService.setActiveSpool(nil)` + `printerService.unloadFilament()`
- `setActiveSpool(_:)` → calls `printerService.setActiveSpool(spoolId)` + `printerService.loadFilament()`

## SpoolService Dependency
- ViewModels use `SpoolServiceProtocol` (Lambert's protocol) via `ServiceContainer.spoolService`
- PrinterDetailViewModel uses `PrinterServiceProtocol` filament methods (setActiveSpool, loadFilament, unloadFilament) — NOT SpoolServiceProtocol
- SpoolPickerViewModel and SpoolInventoryViewModel use `SpoolServiceProtocol` for listing/creating/deleting spools

## Phase 2 NFC Hook
- SpoolPickerView and AddSpoolView are designed to accept NFC-scanned spool data (OpenSpool / OpenPrintTag formats)
- Future work: Add "Scan NFC" button that auto-populates spool fields from tag

**Impact:**
- **Lambert:** No changes needed — all services already built and working
- **Ash:** 3 new ViewModels need test coverage (SpoolPickerViewModel, SpoolInventoryViewModel, AddSpoolViewModel); MockSpoolService needed
- **Dallas:** AppRouter has new `inventory` case — any navigation routing logic should account for it
