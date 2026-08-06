class SessionModel {
  final String id;
  final String braceletId;
  final String sessionType;
  final String? checkoutDate;
  final String checkinDate;
  final String status;
  final String total;
  final String sessionsGroupId;

  SessionModel({
    required this.id,
    required this.braceletId,
    required this.sessionType,
    this.checkoutDate,
    required this.checkinDate,
    required this.status,
    required this.total,
    required this.sessionsGroupId,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      braceletId: json['braceletId'] ?? '',
      sessionType: json['sessionType'] ?? 'NORMAL',
      checkoutDate: json['checkoutDate'],
      checkinDate: json['checkinDate'] ?? '',
      status: json['status'] ?? '',
      total: json['total'] ?? '0.00',
      sessionsGroupId: json['sessionsGroupId'] ?? json['sessionGroupId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'braceletId': braceletId,
      'sessionType': sessionType,
      'checkoutDate': checkoutDate,
      'checkinDate': checkinDate,
      'status': status,
      'total': total,
      'sessionsGroupId': sessionsGroupId,
    };
  }
}