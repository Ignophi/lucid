import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/measured_card.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/format.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// Opens the review screen for [session].
/// Returns true if a review was saved, so the caller can refresh its list.
Future<bool> openSessionReview(BuildContext context, Session session) async {
  bool? saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => SessionReviewWidget(session: session),
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).reviewSaved),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  return saved ?? false;
}

/// Lets the user rate a session (0-100), pick its type and add a comment.
/// Shows what the sensors measured, if anything.
class SessionReviewWidget extends StatefulWidget {
  const SessionReviewWidget({super.key, required this.session});
  final Session session;

  // These static variables are used with flutter tests
  static const String keyType = "Review Type",
      keyRating = "Review Rating",
      keyComment = "Review Comment",
      keySave = "Review Save";

  @override
  State<SessionReviewWidget> createState() => _SessionReviewWidgetState();
}

class _SessionReviewWidgetState extends State<SessionReviewWidget> {
  // Where the slider sits before the session has been rated
  static const int _unratedPosition = (RATING_MIN + RATING_MAX) ~/ 2;

  late final TextEditingController _commentController;
  int? _rating;
  String? _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.session.rating;
    _type = widget.session.sessionType;
    _commentController = TextEditingController(
      text: widget.session.comment ?? "",
    );
    // Rebuild on typing so unsaved changes are detected
    _commentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String? get _comment {
    String text = _commentController.text.trim();
    return text.isEmpty ? null : text;
  }

  bool get _hasChanges =>
      _rating != widget.session.rating ||
      _type != widget.session.sessionType ||
      _commentController.text.trim() != (widget.session.comment ?? "").trim();

  void _setRating(int? value) {
    setState(() {
      _rating = value?.clamp(RATING_MIN, RATING_MAX);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    Session session = widget.session;
    int? oldRating = session.rating;
    String? oldType = session.sessionType, oldComment = session.comment;
    session.rating = _rating;
    session.sessionType = _type;
    session.comment = _comment;
    try {
      await session.save();
    } catch (e) {
      debugPrint(e.toString());
      // Put the old values back so memory matches what is stored
      session.rating = oldRating;
      session.sessionType = oldType;
      session.comment = oldComment;
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    debugPrint("reviewed session: $session");
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmDiscard() async {
    AppLocalizations l10n = AppLocalizations.of(context);
    bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(l10n.discardChanges),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.discard),
            ),
          ],
        );
      },
    );
    return discard ?? false;
  }

  Widget _getSummaryCard(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Session session = widget.session;
    Duration duration = roundDuration(session.end.difference(session.start));
    String preset = session.description ?? "";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat(DATE_FORMAT).format(session.start),
              style: theme.textTheme.titleMedium,
            ),
            if (preset.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  preset,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 4.0),
                Text(getDurationString(duration)),
                const SizedBox(width: 16.0),
                Icon(Icons.air, color: theme.colorScheme.primary),
                const SizedBox(width: 4.0),
                Text("${session.breaths}"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getRating(BuildContext context) {
    ThemeData theme = Theme.of(context);
    AppLocalizations l10n = AppLocalizations.of(context);
    int? rating = _rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.rating, style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              rating == null ? l10n.notRated : "$rating",
              key: const Key(SessionReviewWidget.keyRating),
              style: rating == null
                  ? theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : theme.textTheme.headlineSmall?.copyWith(
                      color: scoreColor(rating),
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: rating == null || rating <= RATING_MIN
                  ? null
                  : () => _setRating(rating - 1),
            ),
            Expanded(
              // Faded until the user rates the session
              child: Opacity(
                opacity: rating == null ? 0.4 : 1.0,
                child: Slider(
                  value: (rating ?? _unratedPosition).toDouble(),
                  min: RATING_MIN.toDouble(),
                  max: RATING_MAX.toDouble(),
                  divisions: RATING_MAX - RATING_MIN,
                  label: "${rating ?? _unratedPosition}",
                  activeColor: rating == null ? null : scoreColor(rating),
                  thumbColor: rating == null ? null : scoreColor(rating),
                  onChanged: (double value) => _setRating(value.round()),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: rating == null || rating >= RATING_MAX
                  ? null
                  : () => _setRating(rating + 1),
            ),
          ],
        ),
        if (rating != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _setRating(null),
              child: Text(l10n.clear),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);

    // Keep a saved type that isn't in the list selectable, so it isn't lost
    List<String> types = List.of(SESSION_TYPES);
    String? type = _type;
    if (type != null && type.isNotEmpty && !types.contains(type)) {
      types.add(type);
    }

    Map? measures = widget.session.measurements;

    return PopScope(
      canPop: !_hasChanges || _saving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        bool discard = await _confirmDiscard();
        if (discard && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reviewSession),
          actions: [
            IconButton(
              icon: const Icon(Icons.check_rounded),
              tooltip: l10n.save,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _getSummaryCard(context),
              if (measures != null && measures.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                MeasuredCard(
                  measures: measures,
                  type: _type,
                  onUseType: (String value) {
                    setState(() {
                      _type = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 24.0),
              // Keyed by the type, so it shows a type picked with "Use"
              KeyedSubtree(
                key: ValueKey<String?>(_type),
                child: DropdownMenu<String>(
                  key: const Key(SessionReviewWidget.keyType),
                  initialSelection: _type,
                  expandedInsets: EdgeInsets.zero,
                  label: Text(l10n.sessionType),
                  leadingIcon: Icon(sessionTypeIcon(_type)),
                  dropdownMenuEntries: [
                    for (String t in types)
                      DropdownMenuEntry<String>(
                        value: t,
                        label: sessionTypeLabel(context, t),
                        leadingIcon: Icon(sessionTypeIcon(t)),
                      ),
                  ],
                  onSelected: (String? value) {
                    setState(() {
                      _type = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24.0),
              _getRating(context),
              const SizedBox(height: 16.0),
              TextField(
                key: const Key(SessionReviewWidget.keyComment),
                controller: _commentController,
                minLines: 3,
                maxLines: 6,
                maxLength: COMMENT_MAX_LENGTH,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.comment,
                  hintText: l10n.commentHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16.0),
              FilledButton.icon(
                key: const Key(SessionReviewWidget.keySave),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
