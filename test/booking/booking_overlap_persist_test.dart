import 'package:almanac/booking/booking_calendar_helpers.dart';
import 'package:almanac/booking/booking_types.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/events/event_overlap.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/data/profiles/profile_scoped_repositories.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bookingConfirmationFeedback prefers conflict copy when overlapping', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(
      bookingConfirmationFeedback(
        conflict: true,
        eventTitle: 'Гость',
        l10n: l10n,
      ),
      l10n.bookingConfirmedConflict,
    );
    expect(
      bookingConfirmationFeedback(
        conflict: false,
        eventTitle: 'Гость',
        l10n: l10n,
      ),
      l10n.bookingConfirmedEvent('Гость'),
    );
  });

  testWidgets('confirmed booking persists even when time overlaps', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final busy = AppEvent(
      id: 'busy',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 18, 10),
        end: DateTime(2026, 9, 18, 11),
      ),
      title: 'Busy',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.orange,
    );

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAlmanacTheme(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                widgetRef = ref;
                return TextButton(
                  onPressed: () {
                    final repo = ProfileScopedEventRepository(
                      ref.read(eventRepositoryProvider),
                      'default',
                    );
                    repo.addEvent(busy);
                    applyConfirmedLocalBookingToCalendar(
                      context: context,
                      ref: ref,
                      request: BookingRequest(
                        id: 'req-1',
                        profileId: 'default',
                        templateId: 'tpl',
                        templateToken: 'demo',
                        start: DateTime(2026, 9, 18, 10, 30),
                        end: DateTime(2026, 9, 18, 11, 30),
                        createdAt: DateTime(2026, 9, 18),
                        status: BookingRequestStatus.confirmed,
                        notes: 'Гость',
                      ),
                      templateTitle: 'Сеанс',
                    );
                  },
                  child: const Text('confirm'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();

    final repo = ProfileScopedEventRepository(
      widgetRef.read(eventRepositoryProvider),
      'default',
    );
    final events = repo.getMasterEvents();
    expect(events.any((e) => e.id == AppEvent.bookingEventId('req-1')), isTrue);
    expect(
      hasEventConflict(
        candidateStart: DateTime(2026, 9, 18, 10, 30),
        candidateEnd: DateTime(2026, 9, 18, 11, 30),
        existingEvents: events.where((e) => e.id == 'busy').toList(),
      ),
      isTrue,
    );
    expect(
      find.text('Бронирование подтверждено, но конфликт с событием'),
      findsOneWidget,
    );
  });
}
