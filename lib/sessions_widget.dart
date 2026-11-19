// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';

import 'package:intl/intl.dart' show DateFormat;

import 'package:lucid/utils.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/analytics.dart';
import 'package:lucid/analytics_widget.dart';
import 'package:lucid/common_widgets.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_card.dart';
import 'package:lucid/session_files.dart';
import 'package:lucid/session_review_widget.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

class SessionsWidget extends StatefulWidget {
  const SessionsWidget({
    super.key,
    required this.sessions,
    this.drawer,
    this.onMeditate,
  });
  final Box sessions;
  final Widget? drawer; // the side menu, when shown as a main section
  final VoidCallback? onMeditate; // shows the Meditate button

  // These static variables are used with flutter tests
  static String keyMenu = "Menu";
  static const String keySearch = "Search";

  @override
  State<SessionsWidget> createState() => _SessionsWidgetState();
}

/// Rows of the grouped session list (like a training log): search, totals
/// since the start, then years > months > days > sessions.
sealed class _Row {}

class _SearchRow extends _Row {}

class _SinceStartRow extends _Row {
  _SinceStartRow(this.stats);
  final Analytics stats;
}

class _YearRow extends _Row {
  _YearRow(this.year, this.stats);
  final int year;
  final Analytics stats;
}

class _MonthRow extends _Row {
  _MonthRow(this.year, this.month, this.stats);
  final int year, month;
  final Analytics stats;
}

class _DayRow extends _Row {
  _DayRow(this.day);
  final DateTime day;
}

class _SessionRow extends _Row {
  _SessionRow(this.session);
  final Session session;
}

class _MessageRow extends _Row {
  _MessageRow(this.text);
  final String text;
}

class _SessionsWidgetState extends State<SessionsWidget> {
  late List<Session> _list;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedYears = {};
  final Set<int> _expandedMonths = {}; // see _monthKey
  String _query = "";

  @override
  void initState() {
    debugPrint("$widget.initState");
    _init();
    super.initState();
  }

  @override
  void dispose() {
    debugPrint("$widget.dispose");
    _searchController.dispose();
    super.dispose();
  }

  void _init() {
    _list = storedSessions(widget.sessions).reversed.toList();
    // Open the year and month of the latest session
    if (_list.isNotEmpty) {
      DateTime latest = _list
          .map((s) => s.start)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      _expandedYears.add(latest.year);
      _expandedMonths.add(_monthKey(latest.year, latest.month));
    }
  }

  static int _monthKey(int year, int month) => year * 100 + month;

  bool _matches(BuildContext context, Session session, String query) {
    String? type = session.sessionType;
    List<String> fields = [
      session.comment ?? "",
      session.description ?? "",
      type == null || type.isEmpty ? "" : sessionTypeLabel(context, type),
      DateFormat.yMMMMEEEEd().format(session.start),
    ];
    return fields.any((field) => field.toLowerCase().contains(query));
  }

  List<_Row> _getRows(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    String query = _query.trim().toLowerCase();
    bool searching = query.isNotEmpty;
    List<Session> sessions =
        _list.where((s) => !searching || _matches(context, s, query)).toList()
          ..sort((a, b) => b.start.compareTo(a.start));

    List<_Row> rows = [_SearchRow(), _SinceStartRow(Analytics(_list))];
    if (sessions.isEmpty) {
      rows.add(
        _MessageRow(
          _list.isEmpty ? l10n.noSessionsYet : l10n.noMatchingSessions,
        ),
      );
      return rows;
    }

    // While searching, every group with a match is shown open
    Map<int, List<Session>> years = groupBy(sessions, (s) => s.start.year);
    for (MapEntry<int, List<Session>> year in years.entries) {
      rows.add(_YearRow(year.key, Analytics(year.value)));
      if (!searching && !_expandedYears.contains(year.key)) continue;

      Map<int, List<Session>> months = groupBy(
        year.value,
        (s) => s.start.month,
      );
      for (MapEntry<int, List<Session>> month in months.entries) {
        rows.add(_MonthRow(year.key, month.key, Analytics(month.value)));
        if (!searching &&
            !_expandedMonths.contains(_monthKey(year.key, month.key))) {
          continue;
        }

        Map<DateTime, List<Session>> days = groupBy(
          month.value,
          (s) => dayOf(s.start),
        );
        for (MapEntry<DateTime, List<Session>> day in days.entries) {
          rows.add(_DayRow(day.key));
          rows.addAll(day.value.map(_SessionRow.new));
        }
      }
    }
    return rows;
  }

  Widget _getSearchField(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    const BorderRadius radius = BorderRadius.all(Radius.circular(28.0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 6.0),
      child: TextField(
        key: const Key(SessionsWidget.keySearch),
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        decoration: InputDecoration(
          hintText: l10n.search,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.clear,
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _query = "";
                    });
                  },
                ),
          border: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _getRowWidget(BuildContext context, _Row row, bool searching) {
    AppLocalizations l10n = AppLocalizations.of(context);
    switch (row) {
      case _SearchRow():
        return _getSearchField(context);
      case _SinceStartRow():
        return _GroupCard(
          title: l10n.sinceStart,
          stats: row.stats,
          margin: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 6.0),
          onAnalytics: () => openAnalytics(
            context,
            widget.sessions,
            range: AnalyticsRange.allTime,
          ),
        );
      case _YearRow():
        int year = row.year;
        return _GroupCard(
          title: "$year",
          stats: row.stats,
          margin: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 6.0),
          expanded: searching || _expandedYears.contains(year),
          onToggle: searching
              ? null
              : () => setState(() {
                  if (!_expandedYears.remove(year)) _expandedYears.add(year);
                }),
          onAnalytics: () => openAnalytics(
            context,
            widget.sessions,
            range: AnalyticsRange.year,
            year: year,
          ),
        );
      case _MonthRow():
        int key = _monthKey(row.year, row.month);
        return _GroupCard(
          title: DateFormat('MMMM').format(DateTime(row.year, row.month)),
          stats: row.stats,
          margin: const EdgeInsets.fromLTRB(28.0, 6.0, 12.0, 6.0),
          expanded: searching || _expandedMonths.contains(key),
          onToggle: searching
              ? null
              : () => setState(() {
                  if (!_expandedMonths.remove(key)) _expandedMonths.add(key);
                }),
        );
      case _DayRow():
        return Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 14.0, 16.0, 4.0),
          child: Text(
            DateFormat.yMMMMEEEEd().format(row.day),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case _SessionRow():
        Session session = row.session;
        return Dismissible(
          key: Key(session.key.toString()),
          onDismissed: (direction) {
            setState(() {
              session.delete(); // removes from sessions
              _list.remove(session); // removes from list
            });
          },
          child: SessionCard(
            session: session,
            margin: const EdgeInsets.fromLTRB(28.0, 5.0, 12.0, 5.0),
            onTap: () async {
              if (await openSessionReview(context, session)) {
                setState(() {}); // show the new review on the card
              }
            },
          ),
        );
      case _MessageRow():
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              row.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
    }
  }

  Future<void> _clearAll() async {
    if (_list.isNotEmpty) {
      setState(() {
        _list.clear();
      });
      await widget.sessions.clear();
    }
  }

  /// Adds the sessions in CSV [text]; returns a summary such as "Sessions
  /// imported: 12 new, 0 updated, 1 skipped". Throws a FormatException for
  /// files that are not session exports.
  Future<String> _importText(String text) async {
    AppLocalizations l10n = AppLocalizations.of(context);
    ImportSummary summary = await importSessions(widget.sessions, text);
    if (mounted) {
      setState(() {
        _list = storedSessions(widget.sessions).reversed.toList();
      });
    }
    return "${l10n.sessionsImported}: ${summary.added} ${l10n.newUnit}, "
        "${summary.updated} ${l10n.updatedUnit}, "
        "${summary.skipped} ${l10n.skippedUnit}";
  }

  /// Import: pick a CSV file anywhere (e.g. one exported from Brethap).
  Future<void> _import(BuildContext context) async {
    AppLocalizations l10n = AppLocalizations.of(context);
    String message;
    try {
      FilePickerResult? picked = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.import,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return; // cancelled
      }
      PlatformFile file = picked.files.single;
      Uint8List? bytes = file.bytes;
      String? path = file.path;
      if (bytes == null && path != null) {
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null) {
        throw const FileSystemException("No file data");
      }
      message = await _importText(utf8.decode(bytes, allowMalformed: true));
    } on FormatException catch (e) {
      debugPrint(e.toString());
      message = l10n.notASessionsFile;
    } catch (e) {
      debugPrint(e.toString());
      message = l10n.fileError;
    }
    _showSnackBar(context, message, const Duration(seconds: 5));
  }

  /// Export: save all sessions as a CSV file wherever you choose (Downloads,
  /// Drive...), so the data survives even if the app is removed.
  Future<void> _export(BuildContext context) async {
    AppLocalizations l10n = AppLocalizations.of(context);
    String message;
    try {
      String? path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.export,
        fileName: exportFileName(DateTime.now()),
        bytes: sessionsFile(_list),
      );
      if (path == null) {
        return; // cancelled
      }
      message = "${_list.length} ${l10n.sessionsExportedTo}:\n$path";
    } catch (e) {
      debugPrint(e.toString());
      message = l10n.fileError;
    }
    _showSnackBar(context, message, const Duration(seconds: 5));
  }

  void _showSnackBar(BuildContext context, String text, Duration duration) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), duration: duration));
  }

  @override
  Widget build(BuildContext context) {
    VoidCallback? meditate = widget.onMeditate;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).sessions),
        actions: <Widget>[
          PopupMenuButton<String>(
            key: Key(SessionsWidget.keyMenu),
            onSelected: (value) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              switch (value) {
                case CLEAR_ALL_TEXT:
                  showAlertDialog(
                    context,
                    AppLocalizations.of(context).clearAll,
                    AppLocalizations.of(context).clearAllSessions,
                    () {
                      _clearAll();
                      Navigator.of(context).pop();
                      _showSnackBar(
                        context,
                        AppLocalizations.of(context).sessionsCleared,
                        const Duration(seconds: 3),
                      );
                    },
                  );
                  debugPrint(CLEAR_ALL_TEXT);
                  break;
                case IMPORT_TEXT:
                  _import(context);
                  debugPrint(IMPORT_TEXT);
                  break;
                case EXPORT_TEXT:
                  _export(context);
                  debugPrint(EXPORT_TEXT);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                key: const Key(CLEAR_ALL_TEXT),
                value: CLEAR_ALL_TEXT,
                child: Text(AppLocalizations.of(context).clearAll),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                key: const Key(IMPORT_TEXT),
                value: IMPORT_TEXT,
                child: Text(AppLocalizations.of(context).import),
              ),
              PopupMenuItem<String>(
                key: const Key(EXPORT_TEXT),
                value: EXPORT_TEXT,
                child: Text(AppLocalizations.of(context).export),
              ),
            ],
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          bool searching = _query.trim().isNotEmpty;
          List<_Row> rows = _getRows(context);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88.0), // room for the button
            itemCount: rows.length,
            itemBuilder: (context, index) =>
                _getRowWidget(context, rows[index], searching),
          );
        },
      ),
      floatingActionButton: meditate == null
          ? null
          : MeditateButton(onPressed: meditate),
    );
  }
}

/// Card with a title row and totals, for "Since start", a year or a month.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.stats,
    required this.margin,
    this.expanded,
    this.onToggle,
    this.onAnalytics,
  });

  final String title;
  final Analytics stats;
  final EdgeInsetsGeometry margin;
  final bool? expanded; // null: cannot be opened or closed
  final VoidCallback? onToggle, onAnalytics;

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    ColorScheme colors = theme.colorScheme;
    List<TypeSummary> types = stats.byType;
    bool? isExpanded = expanded;
    VoidCallback? analytics = onAnalytics;

    return Card(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 6.0, 8.0, 6.0),
              child: SizedBox(
                height: 48.0,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (types.isNotEmpty) TypePill(types: types),
                    if (analytics != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.insights_rounded),
                          tooltip: l10n.analytics,
                          onPressed: analytics,
                        ),
                      ),
                    if (isExpanded != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: colors.primary,
                        ),
                      )
                    else
                      const SizedBox(width: 8.0),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: OUTLINE_WIDTH,
            thickness: OUTLINE_WIDTH,
            color: lineColor(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
            child: PeriodSummary(stats: stats),
          ),
        ],
      ),
    );
  }
}
