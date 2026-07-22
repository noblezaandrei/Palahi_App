# Booking, Reviews, and History Implementation Tasks

- [x] Update `BreedingRequestModel` with scheduling, notes, type, and completed fields
- [x] Update `ReviewModel` with `bookingId`, `review`, and `createdAt`
- [x] Update `BreedingRequestRepository` to target `bookings` collection, add conflict checker, completed stream
- [x] Update `ReviewRepository` to prevent duplicates and recalculate breeder average ratings
- [x] Update `StudPigRepository` to clean up old/deleted pig images from Firebase Storage
- [x] Modify `BreederDetailScreen` to display history stats, selection options, and validation
- [x] Modify `farmer_dashboard_screen.dart` with scheduling details and rate/review button/dialog
- [x] Modify `breeding_requests_screen.dart` with status actions (completed, cancelled)
- [x] Create `BreederHistoryScreen` showing completed bookings with filtering
- [x] Link `BreederHistoryScreen` to Breeder's profile page list
- [x] Verify the build and check diagnostics
