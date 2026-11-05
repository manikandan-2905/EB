library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/eb_record.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/curved_header.dart';
import '../widgets/record_card.dart';
import 'add_record_screen.dart';

enum ScheduleDateFilter { all, today, tomorrow, custom }

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;

  const HomeScreen({
    super.key,
    this.onNavigateToAdd,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Tab State: 0 = All Houses, 1 = Schedule ──────────────────────────────
  int _selectedTab = 0;

  // Data lists
  List<EbRecord> _allRecords = [];
  List<EbRecord> _scheduledRecords = [];
  bool _loading = false;
  String? _errorMessage;

  // Header GPS address
  String _currentLocationText = 'Detecting current location...';

  // Search State
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<EbRecord> _searchedAllRecords = [];
  List<EbRecord> _searchedScheduledRecords = [];

  // Schedule Tab Filter State
  ScheduleDateFilter _scheduleFilter = ScheduleDateFilter.all;
  DateTime? _customScheduleDate;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _detectCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Open Add / Register Record Screen ────────────────────────────────────
  Future<void> _openAddRecord() async {
    HapticFeedback.lightImpact();
    if (widget.onNavigateToAdd != null) {
      widget.onNavigateToAdd!();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddRecordScreen(
            onRecordSaved: () {
              _loadAllData();
            },
          ),
        ),
      );
      if (mounted) {
        _loadAllData();
      }
    }
  }

  // ── GPS Current Location Detector ─────────────────────────────────────────
  Future<void> _detectCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      final address = await LocationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      final tokens = address.split(', ');
      final shortArea = tokens.length > 2
          ? '${tokens[tokens.length - 3]}, ${tokens[tokens.length - 2]}'
          : address;

      if (mounted) {
        setState(() => _currentLocationText = shortArea);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentLocationText = 'Location ready (GPS Active)');
      }
    }
  }

  // ── Load All Data (Both All Houses & Scheduled for fast tab counts) ────────
  Future<void> _loadAllData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchLatestRecords(),
        ApiService.fetchScheduledRecords(),
      ]);

      if (mounted) {
        setState(() {
          _allRecords = results[0];
          _scheduledRecords = results[1];
          _applySearchFilter();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unexpected error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Search Handling ───────────────────────────────────────────────────────
  void _onSearchChanged(String text) {
    setState(() {
      _isSearching = text.trim().isNotEmpty;
      _applySearchFilter();
    });
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _searchedAllRecords = _allRecords;
      _searchedScheduledRecords = _scheduledRecords;
      return;
    }

    _searchedAllRecords = _allRecords.where((r) {
      return r.ebNumber.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          r.consumerName.toLowerCase().contains(query) ||
          r.landmarkNotes.toLowerCase().contains(query);
    }).toList();

    _searchedScheduledRecords = _scheduledRecords.where((r) {
      return r.ebNumber.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          r.consumerName.toLowerCase().contains(query) ||
          r.landmarkNotes.toLowerCase().contains(query);
    }).toList();
  }

  // ── Schedule Tab Date Filter Logic ────────────────────────────────────────
  List<EbRecord> _getFilteredScheduledRecords() {
    final base = _isSearching ? _searchedScheduledRecords : _scheduledRecords;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    switch (_scheduleFilter) {
      case ScheduleDateFilter.today:
        return base.where((r) {
          if (r.scheduledDate == null) return false;
          final d = r.scheduledDate!.toLocal();
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).toList();

      case ScheduleDateFilter.tomorrow:
        return base.where((r) {
          if (r.scheduledDate == null) return false;
          final d = r.scheduledDate!.toLocal();
          return d.year == tomorrow.year &&
              d.month == tomorrow.month &&
              d.day == tomorrow.day;
        }).toList();

      case ScheduleDateFilter.custom:
        if (_customScheduleDate == null) return base;
        final target = _customScheduleDate!;
        return base.where((r) {
          if (r.scheduledDate == null) return false;
          final d = r.scheduledDate!.toLocal();
          return d.year == target.year &&
              d.month == target.month &&
              d.day == target.day;
        }).toList();

      case ScheduleDateFilter.all:
        return base;
    }
  }

  // ── Group Scheduled Records Date-Wise ─────────────────────────────────────
  Map<String, ({DateTime date, List<EbRecord> items})> _groupScheduledDateWise(
    List<EbRecord> records,
  ) {
    // Sort chronologically
    final sorted = List<EbRecord>.from(records)
      ..sort((a, b) {
        if (a.scheduledDate == null && b.scheduledDate == null) return 0;
        if (a.scheduledDate == null) return 1;
        if (b.scheduledDate == null) return -1;
        return a.scheduledDate!.compareTo(b.scheduledDate!);
      });

    final Map<String, ({DateTime date, List<EbRecord> items})> groups = {};

    for (final rec in sorted) {
      if (rec.scheduledDate == null) continue;
      final local = rec.scheduledDate!.toLocal();
      final dayKey =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

      if (!groups.containsKey(dayKey)) {
        groups[dayKey] = (
          date: DateTime(local.year, local.month, local.day),
          items: <EbRecord>[],
        );
      }
      groups[dayKey]!.items.add(rec);
    }

    return groups;
  }

  // ── Pick Calendar Date for Schedule Filter ────────────────────────────────
  Future<void> _pickCalendarDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customScheduleDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
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
      setState(() {
        _customScheduleDate = picked;
        _scheduleFilter = ScheduleDateFilter.custom;
      });
    }
  }

  // ── Build Method ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final displayedAll =
        _isSearching ? _searchedAllRecords : _allRecords;
    final displayedScheduled = _getFilteredScheduledRecords();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Curved Top Header with Greeting, Location & Register Button ────
          CurvedHeader(
            greeting: 'Hi Mathavan 👋',
            currentLocation: _currentLocationText,
            onRefreshLocation: _detectCurrentLocation,
            trailing: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openAddRecord,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 19,
                        color: Color(0xFF0D47A1),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomChild: // Search Bar with Clean Light Styling
              Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: _selectedTab == 0
                    ? 'Search all houses, EB #, or address...'
                    : 'Search scheduled visits...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1565C0),
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        // ── 2 Main Tabs: "All Houses" & "Schedule" ───────────────────────────
        _buildTwoTabsBar(),

        // ── Tab Content Area ─────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1565C0),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Loading records...',
                        style: TextStyle(fontSize: 13.5, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadAllData,
                      color: const Color(0xFF1565C0),
                      child: _selectedTab == 0
                          ? _buildAllHousesTab(displayedAll)
                          : _buildScheduleTab(displayedScheduled),
                    ),
        ),
      ],
    ),
  );
  }

  // ── 2 Tabs Switcher Bar ───────────────────────────────────────────────────
  Widget _buildTwoTabsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Tab 1: All Houses
          Expanded(
            child: _TabButton(
              title: 'All Houses',
              icon: Icons.home_work_rounded,
              badgeCount: _allRecords.length,
              isSelected: _selectedTab == 0,
              onTap: () {
                if (_selectedTab != 0) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = 0);
                }
              },
            ),
          ),
          const SizedBox(width: 4),

          // Tab 2: Schedule
          Expanded(
            child: _TabButton(
              title: 'Schedule',
              icon: Icons.calendar_month_rounded,
              badgeCount: _scheduledRecords.length,
              isSelected: _selectedTab == 1,
              onTap: () {
                if (_selectedTab != 1) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = 1);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: All Houses View ────────────────────────────────────────────────
  Widget _buildAllHousesTab(List<EbRecord> records) {
    if (records.isEmpty) {
      return _buildEmptyState(
        isScheduleTab: false,
        title: _isSearching
            ? 'No houses match "${_searchController.text}"'
            : 'No EB Records Saved Yet',
        subtitle: _isSearching
            ? 'Try searching by a different EB number, consumer name, or address.'
            : 'Tap "Register" at the top right to register your first house with GPS coordinates.',
        buttonLabel: _isSearching ? 'Clear Search' : 'Register First House',
        onButtonPressed: () {
          if (_isSearching) {
            _searchController.clear();
            _onSearchChanged('');
          } else {
            _openAddRecord();
          }
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: records.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  _isSearching
                      ? 'Search Results (${records.length})'
                      : 'All Service Locations (${records.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                if (_isSearching)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final record = records[index - 1];
        return RecordCard(
          record: record,
          index: index - 1,
          onDeleted: _loadAllData,
          onScheduleUpdated: _loadAllData,
          onRecordUpdated: _loadAllData,
        );
      },
    );
  }

  // ── Tab 2: Schedule View (Date-Wise Grouped + Date Filter) ────────────────
  Widget _buildScheduleTab(List<EbRecord> records) {
    final grouped = _groupScheduledDateWise(records);

    return Column(
      children: [
        // Date Filter Pills
        _buildScheduleDateFilterBar(),

        // Content Area
        Expanded(
          child: records.isEmpty
              ? _buildEmptyState(
                  isScheduleTab: true,
                  title: _getScheduleEmptyTitle(),
                  subtitle: _getScheduleEmptySubtitle(),
                  buttonLabel: _scheduleFilter != ScheduleDateFilter.all
                      ? 'Show All Scheduled'
                      : 'Go to All Houses to Schedule',
                  onButtonPressed: () {
                    if (_scheduleFilter != ScheduleDateFilter.all) {
                      setState(() {
                        _scheduleFilter = ScheduleDateFilter.all;
                        _customScheduleDate = null;
                      });
                    } else {
                      setState(() => _selectedTab = 0);
                    }
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 2, bottom: 24),
                  itemCount: grouped.length,
                  itemBuilder: (context, groupIndex) {
                    final entry = grouped.values.elementAt(groupIndex);
                    final date = entry.date;
                    final items = entry.items;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header for this specific date
                        _buildDateSectionHeader(date, items.length),

                        // List of cards scheduled for this date
                        ...items.map(
                          (rec) => RecordCard(
                            record: rec,
                            onDeleted: _loadAllData,
                            onScheduleUpdated: _loadAllData,
                            onRecordUpdated: _loadAllData,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Date Filter Bar inside Schedule Tab ───────────────────────────────────
  Widget _buildScheduleDateFilterBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 1. All Dates
          _FilterChip(
            label: 'All Dates',
            icon: Icons.calendar_view_week_rounded,
            isSelected: _scheduleFilter == ScheduleDateFilter.all,
            onTap: () {
              setState(() {
                _scheduleFilter = ScheduleDateFilter.all;
                _customScheduleDate = null;
              });
            },
          ),
          const SizedBox(width: 8),

          // 2. Today
          _FilterChip(
            label: '⚡ Today',
            icon: Icons.today_rounded,
            isSelected: _scheduleFilter == ScheduleDateFilter.today,
            onTap: () {
              setState(() {
                _scheduleFilter = ScheduleDateFilter.today;
                _customScheduleDate = null;
              });
            },
          ),
          const SizedBox(width: 8),

          // 3. Tomorrow
          _FilterChip(
            label: '🌅 Tomorrow',
            icon: Icons.wb_sunny_outlined,
            isSelected: _scheduleFilter == ScheduleDateFilter.tomorrow,
            onTap: () {
              setState(() {
                _scheduleFilter = ScheduleDateFilter.tomorrow;
                _customScheduleDate = null;
              });
            },
          ),
          const SizedBox(width: 8),

          // 4. Custom Calendar Date
          _FilterChip(
            label: _scheduleFilter == ScheduleDateFilter.custom &&
                    _customScheduleDate != null
                ? DateFormat('dd MMM yyyy').format(_customScheduleDate!)
                : 'Pick Date 📅',
            icon: Icons.calendar_month_rounded,
            isSelected: _scheduleFilter == ScheduleDateFilter.custom,
            onTap: _pickCalendarDate,
          ),
        ],
      ),
    );
  }

  // ── Neat Date Section Header ──────────────────────────────────────────────
  Widget _buildDateSectionHeader(DateTime date, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isTomorrow = date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
    final isPast = date.isBefore(today);

    Color bg;
    Color border;
    Color iconColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    if (isToday) {
      bg = const Color(0xFFFEF3C7); // Light amber
      border = const Color(0xFFF59E0B);
      iconColor = const Color(0xFFD97706);
      textColor = const Color(0xFF92400E);
      icon = Icons.bolt_rounded;
      title = "Today's Schedule";
      subtitle = DateFormat('EEEE, dd MMM yyyy').format(date);
    } else if (isTomorrow) {
      bg = const Color(0xFFEFF6FF); // Light blue
      border = const Color(0xFF3B82F6);
      iconColor = const Color(0xFF2563EB);
      textColor = const Color(0xFF1E40AF);
      icon = Icons.wb_sunny_rounded;
      title = "Tomorrow's Schedule";
      subtitle = DateFormat('EEEE, dd MMM yyyy').format(date);
    } else if (isPast) {
      bg = const Color(0xFFFEE2E2); // Light red/rose
      border = const Color(0xFFEF4444);
      iconColor = const Color(0xFFDC2626);
      textColor = const Color(0xFF991B1B);
      icon = Icons.history_rounded;
      title = 'Past Scheduled Visit';
      subtitle = DateFormat('EEEE, dd MMM yyyy').format(date);
    } else {
      bg = const Color(0xFFF1F5F9); // Crisp slate
      border = const Color(0xFF94A3B8);
      iconColor = const Color(0xFF475569);
      textColor = const Color(0xFF1E293B);
      icon = Icons.calendar_month_rounded;
      title = DateFormat('EEEE, dd MMM yyyy').format(date);
      subtitle = 'Upcoming House Visit';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: border.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$count ${count == 1 ? 'House' : 'Houses'}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State View ──────────────────────────────────────────────────────
  Widget _buildEmptyState({
    required bool isScheduleTab,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onButtonPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isScheduleTab
                    ? Icons.event_busy_rounded
                    : Icons.location_off_rounded,
                size: 52,
                color: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onButtonPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                isScheduleTab
                    ? Icons.calendar_month_rounded
                    : Icons.add_location_alt_rounded,
                size: 18,
              ),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error View ────────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadAllData,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _getScheduleEmptyTitle() {
    if (_isSearching) {
      return 'No scheduled visits match "${_searchController.text}"';
    }
    switch (_scheduleFilter) {
      case ScheduleDateFilter.today:
        return 'No Houses Scheduled for Today';
      case ScheduleDateFilter.tomorrow:
        return 'No Houses Scheduled for Tomorrow';
      case ScheduleDateFilter.custom:
        return _customScheduleDate != null
            ? 'No Visits on ${DateFormat('dd MMM yyyy').format(_customScheduleDate!)}'
            : 'No Visits on Selected Date';
      case ScheduleDateFilter.all:
        return 'No Scheduled Visits Found';
    }
  }

  String _getScheduleEmptySubtitle() {
    if (_scheduleFilter != ScheduleDateFilter.all) {
      return 'Switch back to "All Dates" or tap the calendar icon on any house card in the "All Houses" tab to schedule.';
    }
    return 'Tap the calendar icon on any house card in the "All Houses" tab to plan your visit date.';
  }
}

// ── Segmented Control Tab Button ────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final int badgeCount;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.badgeCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Horizontal Date Filter Chip ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1565C0)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1565C0).withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
