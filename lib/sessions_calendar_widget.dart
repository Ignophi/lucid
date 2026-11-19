import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:table_calendar/table_calendar.dart';

import 'package:lucid/hive_storage.dart';
import 'package:lucid/analytics.dart';
import 'package:lucid/common_widgets.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/session_card.dart';
import 'package:lucid/session_review_widget.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

class SessionsCalendarWidget extends StatefulWidget {
  const SessionsCalendarWidget({
    super.key,
    required this.sessions,
    this.drawer,
    this.onMeditate,
  });
  final Box sessions;
  final Widget? drawer; // the side menu, when shown as a main section
  final VoidCallback? onMeditate; // shows the Meditate button

  @override
  State<SessionsCalendarWidget> createState() => _SessionsCalendarWidgetState();
}

class _SessionsCalendarWidgetState extends State<SessionsCalendarWidget> {
  late final List<Session> _list;
  List<Session> _daySessions = [];

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late DateTime _firstDay, _lastDay, _statFirstDay, _statLastDay;

  void _init() {
    _list = widget.sessions.values.toList().cast<Session>();
    _lastDay = DateTime.now();
    _firstDay = _getFirstDate(_list);
    _selectedDay = _focusedDay;
    _statFirstDay = DateTime(_focusedDay.year, _focusedDay.month);
    _statLastDay = _focusedDay;
    _daySessions = _getSessionsForDay(_focusedDay);
  }

  @override
  void initState() {
    debugPrint("$widget.initState");
    _init();
    super.initState();
  }

  @override
  void dispose() {
    debugPrint("$widget.dispose");
    super.dispose();
  }

  DateTime _getFirstDate(List<Session> list) {
    DateTime first = DateTime.now();
    for (Session session in list) {
      if (session.start.isBefore(first)) {
        first = session.start;
      }
    }
    return first;
  }

  List<Session> _getSessionsForDay(DateTime day) {
    List<Session> sessions = <Session>[];
    for (var element in _list) {
      if (isSameDay(element.start, day)) {
        sessions.add(element);
      }
    }
    return sessions;
  }

  /// Sessions in the month or week shown.
  List<Session> _getSessionsShown() {
    return _list
        .where(
          (s) =>
              !s.start.isBefore(_statFirstDay) &&
              s.start.isBefore(_statLastDay),
        )
        .toList();
  }

  void _updateStats() {
    if (_calendarFormat == CalendarFormat.month) {
      _statFirstDay = DateTime(_focusedDay.year, _focusedDay.month);
      _statLastDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
    } else if (_calendarFormat == CalendarFormat.week) {
      // Weeks start on Sunday, like the calendar
      DateTime day = _focusedDay;
      _statFirstDay = DateTime(day.year, day.month, day.day - day.weekday % 7);
      _statLastDay = DateTime(
        _statFirstDay.year,
        _statFirstDay.month,
        _statFirstDay.day + 7,
      );
    }
    debugPrint(
      "focusedDay: $_focusedDay  statFirstDay: $_statFirstDay  statLastDay: $_statLastDay",
    );
  }

  Widget? _getMarker(
    BuildContext context,
    DateTime date,
    List<Session> events,
  ) {
    if (events.isEmpty) {
      return null;
    }
    ThemeData theme = Theme.of(context);
    ColorScheme colors = theme.colorScheme;
    DateTime dt = DateTime(date.year, date.month, date.day);
    // Bubble color = average score of the day's rated sessions (the soft
    // accent when none were rated, as in the year overview)
    double? average = averageRating(events);
    Color color = average == null ? unratedColor(context) : scoreColor(average);
    Border edge = edgeBorder(context, color);
    if (dt.compareTo(_statFirstDay) < 0 || dt.compareTo(_statLastDay) >= 0) {
      color = colors.surfaceContainerHighest;
      edge = lineBorder(context);
    }
    Color textColor = onColor(color);

    // Ring in the card's color separates the bubble from the day number;
    // inside it, the bubble with its thin edge
    return Container(
      width: 19.0,
      height: 19.0,
      padding: const EdgeInsets.all(1.25),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.cardTheme.color ?? colors.surfaceContainerLow,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: edge,
        ),
        child: Center(
          child: Text(
            '${events.length}',
            style: TextStyle(
              color: textColor,
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _getCalendarCard(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    ColorScheme colors = theme.colorScheme;
    BorderSide line = BorderSide(
      color: lineColor(context),
      width: OUTLINE_WIDTH,
    );
    TextStyle weekdayStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600);

    return Card(
      margin: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableCalendar<Session>(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getSessionsForDay,
            // Vertical swipes scroll the page instead of changing the format
            availableGestures: AvailableGestures.horizontalSwipe,
            daysOfWeekHeight: 28.0,
            headerStyle: HeaderStyle(
              titleTextStyle: (theme.textTheme.titleLarge ?? const TextStyle())
                  .copyWith(color: colors.primary, fontWeight: FontWeight.w700),
              headerPadding: const EdgeInsets.fromLTRB(8.0, 10.0, 4.0, 10.0),
              formatButtonTextStyle:
                  (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
                    color: colors.onSurface,
                  ),
              formatButtonDecoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20.0),
                border: lineBorder(context),
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: colors.primary,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: colors.primary,
              ),
            ),
            // Thin line under the weekday names
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: weekdayStyle,
              weekendStyle: weekdayStyle,
              decoration: BoxDecoration(border: Border(bottom: line)),
            ),
            calendarStyle: CalendarStyle(
              // Thin lines between the weeks
              tableBorder: TableBorder(
                horizontalInside: line.copyWith(
                  color: lineColor(context).withValues(alpha: 0.6),
                ),
              ),
              tablePadding: const EdgeInsets.symmetric(horizontal: 6.0),
              selectedDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: edgeBorder(context, colors.primary),
              ),
              selectedTextStyle: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 1.5),
              ),
              todayTextStyle: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
              weekendTextStyle: TextStyle(color: colors.onSurfaceVariant),
              outsideTextStyle: TextStyle(color: colors.outline),
            ),
            availableCalendarFormats: {
              CalendarFormat.month: l10n.month,
              CalendarFormat.week: l10n.week,
            },
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _daySessions = _getSessionsForDay(selectedDay);
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                  _selectedDay = null;
                  _daySessions = [];
                  _updateStats();
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _selectedDay = null;
              setState(() {
                _daySessions = [];
                _updateStats();
              });
            },
            calendarBuilders: CalendarBuilders(markerBuilder: _getMarker),
          ),
          Divider(
            height: OUTLINE_WIDTH,
            thickness: OUTLINE_WIDTH,
            color: line.color,
          ),
          // Totals for the month or week shown
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
            child: PeriodSummary(stats: Analytics(_getSessionsShown())),
          ),
        ],
      ),
    );
  }

  Widget _getMessage(BuildContext context, String text) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    VoidCallback? meditate = widget.onMeditate;
    DateTime? selectedDay = _selectedDay;

    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(title: Text(l10n.calendar)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88.0), // room for the button
        children: [
          _getCalendarCard(context),
          if (selectedDay == null)
            _getMessage(context, l10n.tapADay)
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 14.0, 16.0, 4.0),
              child: Text(
                DateFormat.yMMMMEEEEd().format(selectedDay),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_daySessions.isEmpty)
              _getMessage(context, l10n.noSessionsThisDay),
            for (Session session in _daySessions)
              SessionCard(
                session: session,
                onTap: () async {
                  if (await openSessionReview(context, session)) {
                    setState(() {}); // show the new review on the card
                  }
                },
              ),
          ],
        ],
      ),
      floatingActionButton: meditate == null
          ? null
          : MeditateButton(onPressed: meditate),
    );
  }
}
