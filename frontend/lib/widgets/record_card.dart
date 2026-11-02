library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/eb_record.dart';
import '../services/api_service.dart';
import '../services/maps_service.dart';
import 'schedule_dialog.dart';

class RecordCard extends StatefulWidget {
  final EbRecord record;
  final VoidCallback onDeleted;
  final VoidCallback? onScheduleUpdated;
  final int index;
  final bool initiallyExpanded;

  const RecordCard({
    super.key,
    required this.record,
    required this.onDeleted,
    this.onScheduleUpdated,
    this.index = 0,
    this.initiallyExpanded = false,
  });

  @override
  State<RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<RecordCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  EbRecord get record => widget.record;

  // ── Launch Google Maps navigation ──────────────────────────────────────
  Future<void> _navigate(BuildContext context) async {
    try {
      HapticFeedback.lightImpact();
      await MapsService.navigateTo(
        latitude: record.latitude,
        longitude: record.longitude,
        label: record.ebNumber,
      );
    } on MapsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Copy EB Number to Clipboard ────────────────────────────────────────
  void _copyEbNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: record.ebNumber));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('EB #${record.ebNumber} copied to clipboard'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Copy GPS Coordinates ─────────────────────────────────────────────────
  void _copyCoordinates(BuildContext context) {
    final text = '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('GPS Coordinates ($text) copied'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Open Schedule Bottom Sheet ─────────────────────────────────────────
  void _openScheduler(BuildContext context) {
    HapticFeedback.selectionClick();
    ScheduleBottomSheet.show(
      context,
      record: record,
      onScheduled: () {
        if (widget.onScheduleUpdated != null) {
          widget.onScheduleUpdated!();
        }
      },
    );
  }

  // ── Confirm and delete ─────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Delete Record?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove EB record #${record.ebNumber}? '
          'This location will no longer be available for navigation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || record.id == null) return;

    try {
      await ApiService.deleteRecord(record.id!);
      widget.onDeleted();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedDate = record.updatedAt ?? record.createdAt;
    final dateLabel = savedDate != null
        ? DateFormat('dd MMM • hh:mm a').format(savedDate.toLocal())
        : '—';

    final delayMs = (widget.index < 10 ? widget.index : 0) * 35;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isExpanded ? 0.08 : 0.04),
              blurRadius: _isExpanded ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: record.isToday
                ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
                : (_isExpanded
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFE2E8F0)),
            width: record.isToday ? 1.5 : (_isExpanded ? 1.2 : 1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── FRONT VIEW (Necessary details always visible) ────────
                    _buildFrontSummary(context),

                    // ── EXPANDED FULL DETAILS (Visible on click) ─────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: _isExpanded
                          ? _buildExpandedDetails(context, dateLabel)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Front Summary View: EB #, Consumer Name, 1-Line Address, Quick Nav ───
  Widget _buildFrontSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 1. EB Number Pill
            InkWell(
              onTap: () => _copyEbNumber(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pin_rounded,
                      size: 13,
                      color: Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.ebNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1565C0),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 2. Schedule Pill (if scheduled)
            if (record.isScheduled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: record.isToday
                      ? const Color(0xFFFFFBEB)
                      : (record.isTomorrow
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF5F3FF)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: record.isToday
                        ? const Color(0xFFFDE68A)
                        : (record.isTomorrow
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFFDDD6FE)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      record.isToday
                          ? Icons.bolt_rounded
                          : Icons.calendar_month_rounded,
                      size: 11,
                      color: record.isToday
                          ? const Color(0xFFD97706)
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      record.isToday
                          ? 'Today'
                          : (record.isTomorrow
                              ? 'Tomorrow'
                              : DateFormat('dd MMM').format(record.scheduledDate!.toLocal())),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: record.isToday
                            ? const Color(0xFFB45309)
                            : (record.isTomorrow
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF6D28D9)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // 3. Quick Directions Icon (One-click navigation without expanding)
            Tooltip(
              message: 'Get Directions',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigate(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_rounded,
                      size: 18,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 4. Expand / Collapse Arrow
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 5. Consumer Name
        Text(
          record.consumerName.isNotEmpty ? record.consumerName : 'Consumer (No Name)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
            color: record.consumerName.isNotEmpty
                ? const Color(0xFF0F172A)
                : const Color(0xFF94A3B8),
            fontStyle: record.consumerName.isNotEmpty ? FontStyle.normal : FontStyle.italic,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // 6. Address Snippet (1-Line Summary)
        if (record.address.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  record.address,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Expanded View: Full Details, Landmark, GPS, Schedule & Actions ─────────
  Widget _buildExpandedDetails(BuildContext context, String dateLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 0.8, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),

        // ── Full Street Address ──────────────────────────────────────────────
        if (record.address.isNotEmpty) ...[
          const Row(
            children: [
              Icon(
                Icons.home_work_outlined,
                size: 15,
                color: Color(0xFF0D47A1),
              ),
              SizedBox(width: 6),
              Text(
                'Full Service Address',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              record.address,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Landmark / Notes ─────────────────────────────────────────────────
        if (record.landmarkNotes.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F)),
                      children: [
                        const TextSpan(
                          text: 'Note: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: record.landmarkNotes),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Scheduled Visit Banner with 'Change' action ──────────────────────
        if (record.isScheduled) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: record.isToday
                  ? const Color(0xFFFFFBEB)
                  : (record.isTomorrow
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF5F3FF)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: record.isToday
                    ? const Color(0xFFFDE68A)
                    : (record.isTomorrow
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFDDD6FE)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  record.isToday ? Icons.bolt_rounded : Icons.schedule_rounded,
                  size: 15,
                  color: record.isToday
                      ? const Color(0xFFD97706)
                      : const Color(0xFF2563EB),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    record.isToday
                        ? '⚡ Visit Scheduled for Today'
                        : (record.isTomorrow
                            ? '📅 Visit Scheduled for Tomorrow'
                            : '📅 Visit: ${DateFormat('EEE, dd MMM yyyy').format(record.scheduledDate!.toLocal())}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: record.isToday
                          ? const Color(0xFFB45309)
                          : (record.isTomorrow
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF6D28D9)),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _openScheduler(context),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── GPS Coordinates & Saved Timestamp ────────────────────────────────
        Row(
          children: [
            InkWell(
              onTap: () => _copyCoordinates(context),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 13,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${record.latitude.toStringAsFixed(5)}, ${record.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.copy_rounded,
                    size: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Saved: $dateLabel',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ── Main Action: Full-Width Navigation Button ────────────────────────
        InkWell(
          onTap: () => _navigate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F3A78),
                  Color(0xFF1565C0),
                  Color(0xFF1E88E5),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Get Directions (Google Maps)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Secondary Actions: Schedule & Delete ─────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openScheduler(context),
                icon: Icon(
                  record.isScheduled
                      ? Icons.event_available_rounded
                      : Icons.edit_calendar_rounded,
                  size: 16,
                  color: const Color(0xFF1565C0),
                ),
                label: Text(
                  record.isScheduled ? 'Reschedule' : 'Schedule Visit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _confirmDelete(context),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Colors.red.shade600,
              ),
              label: Text(
                'Delete',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
