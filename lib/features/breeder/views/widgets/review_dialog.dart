import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../repositories/review_repository.dart';
import '../../models/breeding_request_model.dart';
import '../../models/review_model.dart';
import 'package:palahi/core/utils/error_messages.dart';

/// Opens the rate-and-review dialog for a completed booking. Resolves to true
/// if a review was submitted.
///
/// [context] must stay mounted after the booking's status changes. Completing
/// a booking removes its card from the active list, so a context taken from
/// that card makes the dialog silently never open — pass a Navigator's
/// context (`Navigator.of(context).context`) captured before completing.
///
/// [completing] is the in-flight "mark as completed" update when the dialog
/// opens alongside it. Submitting waits for it, since the security rules
/// only accept a review once its booking is completed.
Future<bool> showReviewDialog({
  required BuildContext context,
  required ReviewRepository reviewRepository,
  required BreedingRequestModel booking,
  Future<void>? completing,
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    // Tapping outside shouldn't throw away a half-written review; "Later" is
    // the explicit way out, and the booking stays rateable from History.
    barrierDismissible: false,
    builder: (_) => _ReviewDialog(
      reviewRepository: reviewRepository,
      booking: booking,
      completing: completing,
    ),
  );
  return submitted ?? false;
}

class _ReviewDialog extends StatefulWidget {
  final ReviewRepository reviewRepository;
  final BreedingRequestModel booking;
  final Future<void>? completing;

  const _ReviewDialog({
    required this.reviewRepository,
    required this.booking,
    this.completing,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _breederReviewController = TextEditingController();
  final _pigReviewController = TextEditingController();
  double _breederRating = 5.0;
  double _pigRating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _breederReviewController.dispose();
    _pigReviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final booking = widget.booking;

    try {
      await widget.completing;
      await widget.reviewRepository
          .addReview(
            ReviewModel(
              id: '',
              bookingId: booking.id,
              breederId: booking.breederId,
              farmerId: booking.farmerId,
              farmerName: booking.farmerName,
              rating: _breederRating,
              review: _breederReviewController.text.trim(),
              studPigId: booking.studPigId,
              studPigName: booking.studPigName,
              studPigRating: _pigRating,
              studPigReview: _pigReviewController.text.trim(),
              createdAt: DateTime.now(),
            ),
          )
          .withNetworkTimeout();
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks! Your review was submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            // The rules only accept reviews for completed bookings, so this
            // means marking it completed didn't go through (yet).
            e is FirebaseException && e.code == 'permission-denied'
                ? "This booking isn't marked as completed yet, so it can't be "
                      'rated. You can rate it later from History.'
                : 'Error submitting review: ${friendlyError(e)}',
          ),
        ),
      );
    }
  }

  Widget _starRow(double value, ValueChanged<double> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final star = index + 1;
        // Default IconButtons are 48px each (240px for the row), wider than
        // the dialog's content area on small phones, which overflowed.
        return IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            star <= value ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 28,
          ),
          onPressed: _isSubmitting
              ? null
              : () => setState(() => onChanged(star.toDouble())),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const sectionStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('Rate Breeder & Stud Pig'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Rate Breeder & Farm:', style: sectionStyle),
            const SizedBox(height: 4),
            _starRow(_breederRating, (v) => _breederRating = v),
            const SizedBox(height: 4),
            TextField(
              controller: _breederReviewController,
              maxLength: 2000,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Breeder review (optional)',
                hintText: 'Share feedback about the breeder...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              '2. Rate Stud Pig (${widget.booking.studPigName}):',
              style: sectionStyle,
            ),
            const SizedBox(height: 4),
            _starRow(_pigRating, (v) => _pigRating = v),
            const SizedBox(height: 4),
            TextField(
              controller: _pigReviewController,
              maxLength: 2000,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Stud pig review (optional)',
                hintText: 'Share feedback about the stud pig...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          // The app theme gives ElevatedButtons an infinite minimum width,
          // which forces this onto its own full-width row in the dialog.
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit Review'),
        ),
      ],
    );
  }
}
