library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/eb_record.dart';
import '../services/api_service.dart';

class ScheduleBottomSheet extends StatefulWidget {
  final EbRecord record;
  final VoidCallback onScheduled;

  const ScheduleBottomSheet({
    super.key,
    required this.record,
    required this.onScheduled,
  });

  static Future<void> show(
    BuildContext context, {
    required EbRecord record,
    required VoidCallback onScheduled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleBottomSheet(
        record: record,
        onScheduled: onScheduled,
      ),
    );
  }

  @override
  State<ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<ScheduleBottomSheet> {
  DateTime? _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.record.scheduledDate?.toLocal();
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveSchedule(DateTime? date) async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      await ApiService.updateSchedule(
        widget.record.id!,
        scheduledDate: date,
        visitStatus: date != null ? 'Pending' : 'Cancelled',
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onScheduled();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              date != null
                  ? 'House scheduled for ${DateFormat('dd MMM yyyy').format(date)}'
                  : 'Schedule cleared.',
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update schedule: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule House Visit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EB #${widget.record.ebNumber}${widget.record.consumerName.isNotEmpty ? " • ${widget.record.consumerName}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'When do you plan to attend this house?',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Quick selection chips
          Row(
            children: [
              // 1. Today
              Expanded(
                child: _QuickDateButton(
                  label: 'Today',
                  subtitle: DateFormat('dd MMM').format(today),
                  icon: Icons.today_rounded,
                  isSelected: _selectedDate != null &&
                      _selectedDate!.year == today.year &&
                      _selectedDate!.month == today.month &&
                      _selectedDate!.day == today.day,
                  onTap: () => setState(() => _selectedDate = today),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Tomorrow
              Expanded(
                child: _QuickDateButton(
                  label: 'Tomorrow',
                  subtitle: DateFormat('dd MMM').format(tomorrow),
                  icon: Icons.wb_sunny_outlined,
                  isSelected: _selectedDate != null &&
                      _selectedDate!.year == tomorrow.year &&
                      _selectedDate!.month == tomorrow.month &&
                      _selectedDate!.day == tomorrow.day,
                  onTap: () => setState(() => _selectedDate = tomorrow),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Custom Date Picker Button
          InkWell(
            onTap: _pickCustomDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedDate != null &&
                          !_isSameDay(_selectedDate!, today) &&
                          !_isSameDay(_selectedDate!, tomorrow)
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDate != null &&
                              !_isSameDay(_selectedDate!, today) &&
                              !_isSameDay(_selectedDate!, tomorrow)
                          ? 'Selected Date: ${DateFormat('EEE, dd MMM yyyy').format(_selectedDate!)}'
                          : 'Choose Another Date from Calendar...',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _selectedDate != null &&
                                !_isSameDay(_selectedDate!, today) &&
                                !_isSameDay(_selectedDate!, tomorrow)
                            ? const Color(0xFF1565C0)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons: Save & Clear
          Row(
            children: [
              if (widget.record.isScheduled) ...[
                TextButton(
                  onPressed: _saving ? null : () => _saveSchedule(null),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  child: const Text('Clear Schedule'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _saving || _selectedDate == null
                      ? null
                      : () => _saveSchedule(_selectedDate),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm Schedule',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _QuickDateButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickDateButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1565C0).withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

