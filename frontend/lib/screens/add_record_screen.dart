library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/eb_record.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/curved_header.dart';
import '../widgets/eb_number_formatter.dart';

class AddRecordScreen extends StatefulWidget {
  final EbRecord? recordToEdit;
  final VoidCallback? onRecordSaved;

  const AddRecordScreen({
    super.key,
    this.recordToEdit,
    this.onRecordSaved,
  });

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ebNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _consumerNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _notesController = TextEditingController();

  Position? _position;
  bool _fetchingLocation = false;
  bool _saving = false;

  DateTime? _scheduledDate;

  bool get isEditMode => widget.recordToEdit != null;

  // Uniqueness check state
  bool _isCheckingEb = false;
  bool? _isEbDuplicate;
  String? _ebValidationMessage;
  Timer? _ebDebounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.recordToEdit != null) {
      final rec = widget.recordToEdit!;
      _ebNumberController.text = rec.ebNumber;
      _consumerNameController.text = rec.consumerName;
      _mobileController.text = rec.mobileNumber;
      _addressController.text = rec.address;
      _notesController.text = rec.landmarkNotes;
      _scheduledDate = rec.scheduledDate;
      _position = Position(
        latitude: rec.latitude,
        longitude: rec.longitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  @override
  void dispose() {
    _ebDebounceTimer?.cancel();
    _ebNumberController.dispose();
    _addressController.dispose();
    _consumerNameController.dispose();
    _mobileController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Real-time EB uniqueness check ──────────────────────────────────────────
  void _onEbChanged(String value) {
    _ebDebounceTimer?.cancel();
    final clean = value.trim();

    if (clean.length < 5) {
      setState(() {
        _isCheckingEb = false;
        _isEbDuplicate = null;
        _ebValidationMessage = null;
      });
      return;
    }

    _ebDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCheckingEb = true);

      final exists = await ApiService.checkEbExists(clean);

      if (mounted) {
        setState(() {
          _isCheckingEb = false;
          _isEbDuplicate = exists;
          _ebValidationMessage = exists
              ? '❌ This EB Number is already registered! Duplicate not allowed.'
              : '✓ EB Number is available';
        });
      }
    });
  }

  // ── Auto-fetch GPS + Reverse Geocode address ───────────────────────────────
  Future<void> _fetchLocationAndAddress() async {
    HapticFeedback.mediumImpact();
    setState(() => _fetchingLocation = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      _position = pos;

      final address = await LocationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      if (mounted) {
        setState(() {
          _addressController.text = address;
          _fetchingLocation = false;
        });
        HapticFeedback.lightImpact();
        _showSnack('Current address fetched successfully!', isError: false);
      }
    } on LocationException catch (e) {
      if (mounted) {
        setState(() => _fetchingLocation = false);
        _showSnack(e.message, isError: true);
        if (e.isPermanentlyDenied) {
          _showOpenSettingsDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingLocation = false);
        _showSnack('Could not fetch address: ${e.toString()}', isError: true);
      }
    }
  }

  void _clearAddress() {
    HapticFeedback.selectionClick();
    setState(() {
      _addressController.clear();
      _position = null;
    });
  }

  Future<void> _pickScheduleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
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
      setState(() => _scheduledDate = picked);
    }
  }

  // ── Save / Update Record ───────────────────────────────────────────────────
  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isEditMode && _isEbDuplicate == true) {
      HapticFeedback.heavyImpact();
      _showSnack(
        'Duplicate EB Number! Please enter a unique EB number.',
        isError: true,
      );
      return;
    }

    if (_position == null || _addressController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showSnack('Please fetch or enter the service address first.', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final record = EbRecord(
        id: widget.recordToEdit?.id,
        ebNumber: _ebNumberController.text.trim(),
        consumerName: _consumerNameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        landmarkNotes: _notesController.text.trim(),
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        address: _addressController.text.trim(),
        scheduledDate: _scheduledDate,
        visitStatus: widget.recordToEdit?.visitStatus ?? (_scheduledDate != null ? 'Pending' : 'Pending'),
      );

      if (isEditMode) {
        if (widget.recordToEdit?.id == null) {
          throw const ApiException('Invalid record ID for update.');
        }
        await ApiService.updateRecord(widget.recordToEdit!.id!, record);
        HapticFeedback.mediumImpact();
        _showSnack('EB Record updated successfully!');
      } else {
        await ApiService.saveRecord(record);
        HapticFeedback.mediumImpact();
        _showSnack('EB Record registered successfully!');
        _resetForm();
      }

      widget.onRecordSaved?.call();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Unexpected error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _ebNumberController.clear();
    _addressController.clear();
    _consumerNameController.clear();
    _mobileController.clear();
    _notesController.clear();
    setState(() {
      _position = null;
      _fetchingLocation = false;
      _isCheckingEb = false;
      _isEbDuplicate = null;
      _ebValidationMessage = null;
      _scheduledDate = null;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF0F766E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_disabled_rounded,
                color: Colors.orange, size: 26),
            SizedBox(width: 10),
            Text('Location Permission'),
          ],
        ),
        content: const Text(
          'Location permission is permanently denied. '
          'Please enable Location in your device settings to tag EB service meters.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Curved Top Header ───────────────────────────────────────────────
          CurvedHeader(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                tooltip: 'Back to records',
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            greeting: isEditMode ? 'Edit Consumer' : 'New Service Meter',
            currentLocation: isEditMode
                ? 'Update consumer details & address'
                : 'Fill consumer & address details',
            trailing: isEditMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: 'Clear form',
                    onPressed: _resetForm,
                  ),
          ),

          // ── Form Content (Clean Light Card Design) ─────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Registration Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. EB Number Field (xx-xxx-xxx-xxx + Unique Check) ─
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'EB Consumer Number *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (isEditMode)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 11,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Unique (Locked)',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ebNumberController,
                          readOnly: isEditMode,
                          keyboardType: TextInputType.number,
                          inputFormatters: isEditMode
                              ? null
                              : [
                                  FilteringTextInputFormatter.digitsOnly,
                                  EbNumberInputFormatter(),
                                ],
                          onChanged: isEditMode ? null : _onEbChanged,
                          decoration: InputDecoration(
                            hintText: 'xx-xxx-xxx-xxx (e.g. 07-123-004-567)',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade400,
                            ),
                            helperText: isEditMode
                                ? 'EB number is unique and cannot be modified.'
                                : null,
                            helperStyle: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                            prefixIcon: Icon(
                              isEditMode ? Icons.lock_rounded : Icons.pin_rounded,
                              color: isEditMode
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF1565C0),
                            ),
                            suffixIcon: isEditMode
                                ? null
                                : (_isCheckingEb
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                      )
                                    : (_isEbDuplicate != null
                                        ? Icon(
                                            _isEbDuplicate!
                                                ? Icons.cancel_rounded
                                                : Icons.check_circle_rounded,
                                            color: _isEbDuplicate!
                                                ? Colors.red
                                                : Colors.green,
                                          )
                                        : null)),
                            filled: true,
                            fillColor: isEditMode
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _isEbDuplicate == true
                                    ? Colors.red
                                    : const Color(0xFF1565C0),
                                width: 1.8,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (isEditMode) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'EB Number is required.';
                            }
                            if (value.trim().length < 5) {
                              return 'Please enter a valid EB Number.';
                            }
                            if (_isEbDuplicate == true) {
                              return 'EB Number already registered! Duplicate not allowed.';
                            }
                            return null;
                          },
                        ),

                        // Real-time uniqueness feedback label
                        if (!isEditMode && _ebValidationMessage != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              _ebValidationMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isEbDuplicate == true
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── 2. Address Field (Tap to Fetch + Get / Clear Text) ──
                        const Text(
                          'Current Service Address *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tap field automatically fetches address
                        InkWell(
                          onTap: _fetchingLocation ? null : _fetchLocationAndAddress,
                          borderRadius: BorderRadius.circular(14),
                          child: IgnorePointer(
                            ignoring: _fetchingLocation,
                            child: TextFormField(
                              controller: _addressController,
                              maxLines: 3,
                              onTap: () {
                                if (_addressController.text.trim().isEmpty &&
                                    !_fetchingLocation) {
                                  _fetchLocationAndAddress();
                                }
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Tap here to automatically fetch current address via GPS...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 30),
                                  child: Icon(
                                    Icons.home_work_rounded,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                                suffixIcon: _fetchingLocation
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1565C0),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please fetch or enter the service address.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Left Side: "Get Address" | Right Side: "Clear"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left action: Get address text
                            InkWell(
                              onTap: _fetchingLocation ? null : _fetchLocationAndAddress,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.near_me_rounded,
                                      size: 15,
                                      color: _fetchingLocation
                                          ? Colors.grey
                                          : const Color(0xFF1565C0),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _fetchingLocation
                                          ? 'Fetching GPS Address...'
                                          : 'Get Current Address',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _fetchingLocation
                                            ? Colors.grey
                                            : const Color(0xFF1565C0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Right action: Clear text
                            InkWell(
                              onTap: _clearAddress,
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.clear_rounded,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Optional Coordinate Info Badge
                        if (_position != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 14, color: Colors.green.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'GPS: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)} (±${_position!.accuracy.toStringAsFixed(1)}m)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── 3. Consumer Name (Optional) ──────────────────────────
                        const Text(
                          'Consumer Name (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _consumerNameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Ramu / Temple / Agriculture Motor',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFF64748B),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF1565C0),
                                width: 1.8,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 20),

                        // ── 4. Consumer Mobile Number (Optional) ─────────────────
                        const Text(
                          'Consumer Mobile Number (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            hintText: 'e.g. 9876543210 (10 digits)',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: const Icon(
                              Icons.phone_android_rounded,
                              color: Color(0xFF1565C0),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF1565C0),
                                width: 1.8,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != null &&
                                value.trim().isNotEmpty &&
                                value.trim().length < 10) {
                              return 'Please enter a valid 10-digit mobile number.';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 20),

                        // ── 5. Landmark / Description (Optional) ─────────────────
                        const Text(
                          'Landmark / Description (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Near blue transformer, 2nd house in lane',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Icon(
                                Icons.place_outlined,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF1565C0),
                                width: 1.8,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                        ),

                        const SizedBox(height: 20),

                        // ── 5. Schedule Visit Date (Optional) ────────────────────
                        const Text(
                          'Schedule Visit (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _ScheduleChip(
                                label: 'None',
                                icon: Icons.block_rounded,
                                isSelected: _scheduledDate == null,
                                onTap: () => setState(() => _scheduledDate = null),
                              ),
                              const SizedBox(width: 8),
                              _ScheduleChip(
                                label: '📅 Tomorrow',
                                icon: Icons.wb_sunny_outlined,
                                isSelected: _isSameDay(_scheduledDate, tomorrow),
                                onTap: () =>
                                    setState(() => _scheduledDate = tomorrow),
                              ),
                              const SizedBox(width: 8),
                              _ScheduleChip(
                                label: _scheduledDate != null &&
                                        !_isSameDay(_scheduledDate, tomorrow)
                                    ? DateFormat('dd MMM').format(_scheduledDate!)
                                    : 'Pick Date 📅',
                                icon: Icons.event_note_rounded,
                                isSelected: _scheduledDate != null &&
                                    !_isSameDay(_scheduledDate, tomorrow),
                                onTap: _pickScheduleDate,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Submit Button ──────────────────────────────────────────
                  InkWell(
                    onTap: _saving || (!isEditMode && _isEbDuplicate == true)
                        ? null
                        : _saveRecord,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: (!isEditMode && _isEbDuplicate == true)
                            ? LinearGradient(
                                colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade500,
                                ],
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF0F3A78),
                                  Color(0xFF1565C0),
                                  Color(0xFF1E88E5),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_saving) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isEditMode
                                  ? 'Updating Record...'
                                  : 'Registering Record...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              isEditMode
                                  ? Icons.check_circle_rounded
                                  : Icons.app_registration_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isEditMode
                                  ? 'Update EB Record'
                                  : 'Register EB Record',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }
}

class _ScheduleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScheduleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1565C0).withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
