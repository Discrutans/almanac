import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';
import 'ical_export.dart';

Future<void> shareVisibleEventsAsIcs({
  required BuildContext context,
  required List<AppEvent> events,
  required String calendarName,
}) async {
  if (events.isEmpty) return;

  final l10n = AppLocalizations.of(context);

  final ics = IcsCalendarExport.exportEvents(
    events,
    calendarName: calendarName,
  );

  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/almanac-export.ics');
    await file.writeAsString(ics);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar', name: 'almanac.ics')],
      subject: calendarName,
      text: l10n.exportIcsAction,
    );
    return;
  }

  await Share.share(ics, subject: calendarName);
}
