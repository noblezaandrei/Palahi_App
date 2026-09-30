import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/pig_icon.dart';
import '../../../core/widgets/pig_loader.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/breeding_record.dart';
import '../repositories/breeding_record_repository.dart';
import 'package:palahi/core/l10n/app_strings.dart';

/// Follows each of the farmer's sows from breeding to farrowing: when to
/// check for heat, whether she conceived, and the countdown to farrowing.
class BreedingTrackerScreen extends ConsumerWidget {
  const BreedingTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    final tracked = ref.watch(farmerTrackedBreedingsProvider(uid));
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(tr('Breeding Tracker'))),
      body: tracked.when(
        loading: () => const Center(child: PigLoader()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (items) {
          final stages = [for (final t in items) timelineFor(t, today).stage];
          int count(bool Function(TrackerStage) test) =>
              stages.where(test).length;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              GradientHeader(
                title: tr('Your sows'),
                subtitle: tr('Follow each breeding through to farrowing'),
                stats: [
                  (
                    value:
                        '${count((s) => s == TrackerStage.waitingForHeatCheck || s == TrackerStage.heatCheckNow || s == TrackerStage.heatCheckOverdue)}',
                    label: tr('Waiting'),
                  ),
                  (
                    value:
                        '${count((s) => s == TrackerStage.pregnant || s == TrackerStage.farrowingSoon)}',
                    label: tr('Pregnant'),
                  ),
                  (
                    value: '${count((s) => s == TrackerStage.farrowed)}',
                    label: tr('Farrowed'),
                  ),
                ],
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      PigIcon(size: 72),
                      SizedBox(height: 12),
                      Text(
                        'Nothing to track yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'After a breeding, your sow shows up here with her '
                        'heat check and farrowing dates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FadeSlideIn(
                      index: i,
                      child: BreedingTrackerCard(tracked: items[i]),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// [tracked]'s timeline as of [today].
BreedingTimeline timelineFor(TrackedBreeding tracked, DateTime today) =>
    BreedingTimeline(
      bredOn: DateTime.tryParse(tracked.booking.bookingDate) ?? today,
      outcome: tracked.record?.outcome ?? BreedingOutcome.waiting,
      today: today,
    );

/// Whether [tracked] needs the farmer's attention today — shown on Home.
bool needsAttention(TrackedBreeding tracked, DateTime today) =>
    switch (timelineFor(tracked, today).stage) {
      TrackerStage.heatCheckNow ||
      TrackerStage.heatCheckOverdue ||
      TrackerStage.farrowingSoon => true,
      _ => false,
    };

/// One sow's breeding: where she stands, what to look for, and buttons to
/// record what happened.
class BreedingTrackerCard extends ConsumerStatefulWidget {
  final TrackedBreeding tracked;

  const BreedingTrackerCard({super.key, required this.tracked});

  @override
  ConsumerState<BreedingTrackerCard> createState() =>
      _BreedingTrackerCardState();
}

class _BreedingTrackerCardState extends ConsumerState<BreedingTrackerCard> {
  bool _saving = false;

  Future<void> _save(
    BreedingOutcome outcome, {
    int? litterSize,
    String? farrowedOn,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(breedingRecordRepositoryProvider)
          .saveOutcome(
            widget.tracked.booking,
            outcome,
            litterSize: litterSize,
            farrowedOn: farrowedOn,
          )
          .withNetworkTimeout();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Not saved: ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recordFarrowing() async {
    final litter = await showDialog<int>(
      context: context,
      builder: (context) => const _LitterSizeDialog(),
    );
    if (litter == null) return;
    await _save(
      BreedingOutcome.farrowed,
      litterSize: litter,
      farrowedOn: dateKey(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.tracked.booking;
    final record = widget.tracked.record;
    final t = timelineFor(widget.tracked, DateTime.now());
    final stage = t.stage;
    final (label, color) = _stageBadge(stage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: booking.studPigImageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: booking.studPigImageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                const PigPlaceholder(iconSize: 28),
                          )
                        : const PigPlaceholder(iconSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Breeding with {pig}', {'pig': booking.studPigName}),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${booking.breederName} · ${formatShortDate(t.bredOn)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PregnancyBar(timeline: t, record: record),
            const SizedBox(height: 12),
            Text(
              _stageMessage(t, record),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            ..._actions(stage, booking.breederId),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(TrackerStage stage, String breederId) {
    if (_saving) {
      return const [SizedBox(height: 12), Center(child: PigLoader(size: 28))];
    }
    Widget row(List<Widget> buttons) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
    final compact = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
      ),
    );
    switch (stage) {
      case TrackerStage.waitingForHeatCheck:
      case TrackerStage.heatCheckNow:
      case TrackerStage.heatCheckOverdue:
        return [
          row([
            OutlinedButton(
              style: compact,
              onPressed: () => _save(BreedingOutcome.notPregnant),
              child: Text(tr('Came back in heat')),
            ),
            ElevatedButton(
              style: compact,
              onPressed: () => _save(BreedingOutcome.pregnant),
              child: Text(tr('No heat — pregnant')),
            ),
          ]),
        ];
      case TrackerStage.pregnant:
      case TrackerStage.farrowingSoon:
        return [
          row([
            ElevatedButton.icon(
              style: compact,
              onPressed: _recordFarrowing,
              icon: const Icon(Icons.child_friendly_outlined, size: 18),
              label: Text(tr('She farrowed')),
            ),
          ]),
        ];
      case TrackerStage.notPregnant:
        return [
          row([
            ElevatedButton.icon(
              style: compact,
              onPressed: () => context.push('/breeder/$breederId'),
              icon: const Icon(Icons.replay, size: 18),
              label: Text(tr('Book again')),
            ),
          ]),
        ];
      case TrackerStage.farrowed:
        return const [];
    }
  }
}

(String, Color) _stageBadge(TrackerStage stage) {
  final (label, color) = _stageBadgeEnglish(stage);
  return (tr(label), color);
}

(String, Color) _stageBadgeEnglish(TrackerStage stage) => switch (stage) {
  TrackerStage.waitingForHeatCheck => ('Waiting', Colors.blueGrey),
  TrackerStage.heatCheckNow => ('Check for heat', Colors.orange.shade800),
  TrackerStage.heatCheckOverdue => ('Check for heat', Colors.orange.shade800),
  TrackerStage.pregnant => ('Pregnant', AppColors.primary),
  TrackerStage.farrowingSoon => ('Farrowing soon', Colors.deepOrange),
  TrackerStage.notPregnant => ("Didn't conceive", Colors.red.shade700),
  TrackerStage.farrowed => ('Farrowed', Colors.teal),
};

String _range(DateTime from, DateTime to) =>
    '${monthShort(from)} ${from.day}–'
    '${from.month == to.month ? '' : '${monthShort(to)} '}${to.day}';

String _inDays(int days) => days == 0
    ? tr('today')
    : days == 1
    ? tr('tomorrow')
    : days > 0
    ? tr('in {n} days', {'n': days})
    : '${-days} ${days == -1 ? 'day' : 'days'} ago';

String _stageMessage(BreedingTimeline t, BreedingRecord? record) {
  final due = formatShortDate(t.farrowingDue);
  switch (t.stage) {
    case TrackerStage.waitingForHeatCheck:
      final days = t.heatCheckFrom.difference(t.today).inDays;
      return tr(
        "Watch for heat {range} ({when}). If she doesn't come back into heat, she has most likely conceived. Farrowing would be about {due}.",
        {
          'range': _range(t.heatCheckFrom, t.heatCheckTo),
          'when': _inDays(days),
          'due': due,
        },
      );
    case TrackerStage.heatCheckNow:
      return tr(
        'Check her for heat every day until {date}: restlessness, a swollen red vulva, or standing still when you press on her back.',
        {'date': formatShortDate(t.heatCheckTo)},
      );
    case TrackerStage.heatCheckOverdue:
      return tr(
        'The heat check window has passed. Did she come back into heat?',
      );
    case TrackerStage.pregnant:
      return tr('Farrowing due {due} ({when}). Day {day} of about {total}.', {
        'due': due,
        'when': _inDays(t.daysToFarrowing),
        'day': t.dayOfPregnancy,
        'total': gestationDays,
      });
    case TrackerStage.farrowingSoon:
      return tr(
        'Farrowing due {due} ({when}). Get a clean, dry, warm farrowing pen ready.',
        {'due': due, 'when': _inDays(t.daysToFarrowing)},
      );
    case TrackerStage.notPregnant:
      return tr(
        "She didn't conceive this time. You can book another breeding.",
      );
    case TrackerStage.farrowed:
      final on = DateTime.tryParse(record?.farrowedOn ?? '');
      final litter = record?.litterSize;
      return 'Farrowed${on == null ? '' : ' on ${formatShortDate(on)}'}'
          '${litter == null ? '' : ' with $litter ${litter == 1 ? 'piglet' : 'piglets'}'}.';
  }
}

/// Bred → heat check → farrowing, with how far along she is.
class _PregnancyBar extends StatelessWidget {
  final BreedingTimeline timeline;
  final BreedingRecord? record;

  const _PregnancyBar({required this.timeline, this.record});

  @override
  Widget build(BuildContext context) {
    final stage = timeline.stage;
    final failed = stage == TrackerStage.notPregnant;
    final done = stage == TrackerStage.farrowed;
    final fill = done ? 1.0 : timeline.progress;
    final heatAt = heatCheckStartDay / gestationDays;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 14,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLighter.withAlpha(90),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    width: w * fill,
                    decoration: BoxDecoration(
                      color: failed ? Colors.red.shade300 : AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  for (final at in [0.0, heatAt, 1.0])
                    Positioned(
                      left: (w * at - 7).clamp(0, w - 14),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fill >= at
                              ? (failed
                                    ? Colors.red.shade300
                                    : AppColors.primary)
                              : Colors.white,
                          border: Border.all(
                            color: failed
                                ? Colors.red.shade300
                                : AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  tr('Breeding'),
                  style: TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
                SizedBox(width: (w * heatAt - 26).clamp(0.0, w)),
                // Shrink with "…" rather than overflow on narrow phones or
                // with a large system font.
                Flexible(
                  child: Text(
                    tr('Heat check'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.textLight),
                  ),
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Text(
                    tr('Farrowing {date}', {
                      'date': formatShortDate(timeline.farrowingDue),
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Asks how many piglets were born. Owns its text field's controller, so the
/// controller lives until the dialog has finished closing — disposing it
/// right after showDialog returned broke the closing animation (a red screen
/// on phones).
class _LitterSizeDialog extends StatefulWidget {
  const _LitterSizeDialog();

  @override
  State<_LitterSizeDialog> createState() => _LitterSizeDialogState();
}

class _LitterSizeDialogState extends State<_LitterSizeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const PigIcon(size: 44),
      title: const Text('She farrowed!'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: const InputDecoration(
          labelText: 'How many piglets were born?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final n = int.tryParse(_controller.text);
            if (n != null && n <= 30) Navigator.pop(context, n);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
