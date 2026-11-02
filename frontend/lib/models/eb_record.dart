library;

class EbRecord {
  final String? id;
  final String ebNumber;
  final String consumerName;
  final String landmarkNotes;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime? scheduledDate;
  final String visitStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EbRecord({
    this.id,
    required this.ebNumber,
    this.consumerName = '',
    this.landmarkNotes = '',
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.scheduledDate,
    this.visitStatus = 'Pending',
    this.createdAt,
    this.updatedAt,
  });

  // ── Helper Getters for Scheduling ──────────────────────────────────────────
  bool get isScheduled => scheduledDate != null;

  bool get isToday {
    if (scheduledDate == null) return false;
    final now = DateTime.now();
    final s = scheduledDate!.toLocal();
    return s.year == now.year && s.month == now.month && s.day == now.day;
  }

  bool get isTomorrow {
    if (scheduledDate == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final s = scheduledDate!.toLocal();
    return s.year == tomorrow.year &&
        s.month == tomorrow.month &&
        s.day == tomorrow.day;
  }

  // ── Deserialise from JSON (API response) ──────────────────────────────────
  factory EbRecord.fromJson(Map<String, dynamic> json) {
    final coords = json['location']?['coordinates'] as List<dynamic>?;
    final lng = (coords != null && coords.length == 2)
        ? (coords[0] as num).toDouble()
        : 0.0;
    final lat = (coords != null && coords.length == 2)
        ? (coords[1] as num).toDouble()
        : 0.0;

    return EbRecord(
      id: json['_id'] as String?,
      ebNumber: json['ebNumber'] as String? ?? '',
      consumerName: json['consumerName'] as String? ?? '',
      landmarkNotes: json['landmarkNotes'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      address: json['address'] as String? ?? '',
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      visitStatus: json['visitStatus'] as String? ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  // ── Serialise to JSON (for POST request body) ─────────────────────────────
  Map<String, dynamic> toJson() => {
        'ebNumber': ebNumber,
        'consumerName': consumerName,
        'landmarkNotes': landmarkNotes,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        if (scheduledDate != null)
          'scheduledDate': scheduledDate!.toIso8601String(),
        'visitStatus': visitStatus,
      };

  @override
  String toString() =>
      'EbRecord(ebNumber: $ebNumber, lat: $latitude, lng: $longitude, scheduled: $scheduledDate)';
}
