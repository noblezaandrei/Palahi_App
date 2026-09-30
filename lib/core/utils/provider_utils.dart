import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// The next value of [future] (a provider's `.future`), for one-off reads
/// from event handlers.
///
/// Riverpod pauses providers that nothing is listening to, so a bare
/// `ref.read(someStreamProvider.future)` on a screen that doesn't watch
/// that provider never completes — the button just does nothing. Listening
/// while waiting keeps it running.
Future<T> readFuture<T>(
  WidgetRef ref,
  ProviderListenable<Future<T>> future,
) async {
  final subscription = ref.listenManual<Future<T>>(future, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}
