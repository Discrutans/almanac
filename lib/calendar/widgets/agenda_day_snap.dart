import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/theme/almanac_tokens.dart';

/// Мягкая зона: заголовок в пределах этого расстояния от верха — плавно выравнивается.
const agendaDaySnapActivationDistance = 96.0;

/// Расширенная зона при медленной прокрутке (слабее, чем у карусели недели).
const agendaDaySnapExtendedBand = 168.0;

/// Заголовок выше верхнего края дальше этого порога — читаем события, не откатываем.
const agendaDaySnapContentGrace = 56.0;

/// Считаем заголовок уже выровненным в пределах этого порога.
const agendaDaySnapAlignTolerance = 3.0;

/// Длительность плавного выравнивания заголовка дня после жеста.
const agendaDaySnapDuration = AlmanacDurations.snap;

/// Длительность притяжения заголовка: как у недельной карусели.
Duration agendaDayAttractDuration({required double distance}) {
  return almanacAttractDuration(
    distance: distance,
    unitExtent: agendaDaySnapActivationDistance,
  );
}

/// Смещение прокрутки, при котором заголовок дня окажется в [alignment].
double? agendaDayHeaderScrollOffset(
  GlobalKey headerKey,
  ScrollController controller, {
  double alignment = 0,
}) {
  if (!controller.hasClients) return null;

  final headerTop = agendaDayHeaderViewportTop(headerKey, controller);
  if (headerTop != null) {
    final target = controller.offset + headerTop - alignment;
    return target.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
  }

  final headerContext = headerKey.currentContext;
  if (headerContext == null) return null;

  final renderObject = headerContext.findRenderObject();
  if (renderObject == null) return null;

  final viewport = RenderAbstractViewport.of(renderObject);

  final target = viewport.getOffsetToReveal(renderObject, alignment).offset;
  return target.clamp(
    controller.position.minScrollExtent,
    controller.position.maxScrollExtent,
  );
}

/// Прокручивает список так, чтобы заголовок дня оказался у верхнего края.
Future<bool> agendaEnsureDayHeaderVisible(
  GlobalKey headerKey, {
  double alignment = 0,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) async {
  final headerContext = headerKey.currentContext;
  if (headerContext == null) return false;

  await Scrollable.ensureVisible(
    headerContext,
    alignment: alignment,
    duration: duration,
    curve: curve,
  );
  return true;
}

/// Расстояние от верха заголовка до верха viewport (0 = выровнен).
double? agendaDayHeaderViewportTop(
  GlobalKey headerKey,
  ScrollController controller,
) {
  if (!controller.hasClients) return null;

  final headerContext = headerKey.currentContext;
  if (headerContext == null) return null;

  final renderObject = headerContext.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;

  final scrollable = Scrollable.maybeOf(headerContext);
  if (scrollable == null) return null;

  final scrollableBox = scrollable.context.findRenderObject();
  if (scrollableBox is! RenderBox) return null;

  return renderObject.localToGlobal(Offset.zero, ancestor: scrollableBox).dy;
}

/// Заголовок дня виден в области прокрутки [controller].
bool isAgendaDayHeaderVisible(
  GlobalKey headerKey,
  ScrollController controller,
) {
  if (!controller.hasClients) return false;

  final headerContext = headerKey.currentContext;
  if (headerContext == null) return false;

  final renderObject = headerContext.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return false;

  final headerTop = agendaDayHeaderScrollOffset(headerKey, controller);
  if (headerTop == null) return false;

  final headerBottom = headerTop + renderObject.size.height;
  final viewportTop = controller.offset;
  final viewportBottom = viewportTop + controller.position.viewportDimension;

  return headerBottom > viewportTop + 1 && headerTop < viewportBottom - 1;
}

/// День, чей заголовок сейчас ближе всего к верху списка (по scroll offset).
DateTime? findTopmostAgendaDayHeader({
  required ScrollController controller,
  required Iterable<DateTime> days,
  required GlobalKey Function(DateTime day) headerKeyFor,
}) {
  if (!controller.hasClients) return null;

  final offset = controller.offset;
  DateTime? topmost;
  double? topmostHeaderOffset;

  for (final day in days) {
    final headerOffset = agendaDayHeaderScrollOffset(
      headerKeyFor(day),
      controller,
    );
    if (headerOffset == null) continue;

    if (headerOffset > offset + 4) {
      if (topmost != null) break;
      continue;
    }

    if (topmostHeaderOffset == null || headerOffset > topmostHeaderOffset) {
      topmost = day;
      topmostHeaderOffset = headerOffset;
    }
  }

  return topmost;
}

/// Приблизительный offset секции [target] до layout заголовка в viewport.
///
/// SliverList не измеряет далёкие секции, пока viewport не прокручен —
/// грубая оценка нужна для первичного [ScrollController.jumpTo].
double estimateAgendaDayScrollOffset({
  required List<DateTime> days,
  required DateTime target,
  required bool Function(DateTime day) isCollapsed,
  required int Function(DateTime day) eventCount,
  double headerBlockHeight = 50,
  double collapsedBlockHeight = 44,
  double eventTileHeight = 58,
  double firstSectionTopInset = 8,
  double sectionTopInset = 12,
  double sectionBottomInset = 12,
  double headerToEventsGap = 4,
  double eventGap = 6,
}) {
  var targetIndex = -1;
  for (var i = 0; i < days.length; i++) {
    final day = days[i];
    if (day.year == target.year &&
        day.month == target.month &&
        day.day == target.day) {
      targetIndex = i;
      break;
    }
  }
  if (targetIndex <= 0) return 0;

  var offset = 0.0;
  for (var i = 0; i < targetIndex; i++) {
    offset += i == 0 ? firstSectionTopInset : sectionTopInset;
    if (isCollapsed(days[i])) {
      offset += collapsedBlockHeight;
    } else {
      offset += headerBlockHeight;
      final count = eventCount(days[i]);
      if (count > 0) {
        offset += headerToEventsGap;
        offset += count * eventTileHeight;
        if (count > 1) {
          offset += (count - 1) * eventGap;
        }
      }
    }
    offset += sectionBottomInset;
  }
  return offset;
}

/// День, к которому прокрутить список по кнопке «Сегодня».
DateTime? resolveAgendaTodayScrollTarget({
  required List<DateTime> daysWithEvents,
  required DateTime today,
}) {
  if (daysWithEvents.isEmpty) return null;

  DateTime dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

  final todayKey = dayKey(today);

  for (final day in daysWithEvents) {
    if (dayKey(day) == todayKey) return day;
  }

  for (final day in daysWithEvents) {
    if (!dayKey(day).isBefore(todayKey)) return day;
  }

  return daysWithEvents.last;
}

/// К какому дню выровнять список после жеста пользователя.
///
/// Мягкий snap: ближайший заголовок в зоне у верхнего края плавно центрируется.
/// Не откатывает, если пользователь уже читает события ниже заголовка.
DateTime? resolveAgendaDaySnapTarget({
  required ScrollController controller,
  required Iterable<DateTime> days,
  required GlobalKey Function(DateTime day) headerKeyFor,
  double activationDistance = agendaDaySnapActivationDistance,
  double contentGrace = agendaDaySnapContentGrace,
}) {
  if (!controller.hasClients) return null;

  return resolveAgendaDaySnapTargetFromHeaderTops(
    days: days,
    headerTopFor: (day) =>
        agendaDayHeaderViewportTop(headerKeyFor(day), controller),
    topmostDay: findTopmostAgendaDayHeader(
      controller: controller,
      days: days,
      headerKeyFor: headerKeyFor,
    ),
    activationDistance: activationDistance,
    contentGrace: contentGrace,
  );
}

@visibleForTesting
DateTime? resolveAgendaDaySnapTargetFromHeaderTops({
  required Iterable<DateTime> days,
  required double? Function(DateTime day) headerTopFor,
  required DateTime? topmostDay,
  double activationDistance = agendaDaySnapActivationDistance,
  double extendedBand = agendaDaySnapExtendedBand,
  double contentGrace = agendaDaySnapContentGrace,
}) {
  DateTime? snapBelow;
  double? snapBelowDistance;

  DateTime? snapAbove;
  double? snapAboveDistance;

  for (final day in days) {
    final headerTop = headerTopFor(day);
    if (headerTop == null) continue;

    if (headerTop > agendaDaySnapAlignTolerance &&
        headerTop <= activationDistance) {
      if (snapBelowDistance == null || headerTop < snapBelowDistance) {
        snapBelow = day;
        snapBelowDistance = headerTop;
      }
      continue;
    }

    if (headerTop < -agendaDaySnapAlignTolerance &&
        headerTop >= -contentGrace) {
      if (snapAboveDistance == null || headerTop > snapAboveDistance) {
        snapAbove = day;
        snapAboveDistance = headerTop;
      }
    }
  }

  if (snapBelow != null) return snapBelow;
  if (snapAbove != null) return snapAbove;

  if (topmostDay == null) return null;

  final topmostHeaderTop = headerTopFor(topmostDay);
  if (topmostHeaderTop == null) return null;

  if (topmostHeaderTop.abs() <= agendaDaySnapAlignTolerance) return null;
  if (topmostHeaderTop < -contentGrace) return null;

  if (topmostHeaderTop > activationDistance &&
      topmostHeaderTop <= extendedBand) {
    return topmostDay;
  }

  return null;
}
