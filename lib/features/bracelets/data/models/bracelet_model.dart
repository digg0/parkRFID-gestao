class BraceletModel {
  final String uidRfid;

  BraceletModel({required this.uidRfid});

  factory BraceletModel.fromJson(Map<String, dynamic> json) {
    return BraceletModel(
      uidRfid: json['uid_rfid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid_rfid': uidRfid,
    };
  }
}