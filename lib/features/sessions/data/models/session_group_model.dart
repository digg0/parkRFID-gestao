class SessionGroupModel {
  final String id;
  final String responsibleCpf;
  final String responsiblePhoneNumber;

  SessionGroupModel({
    required this.id,
    required this.responsibleCpf,
    required this.responsiblePhoneNumber,
  });


  factory SessionGroupModel.fromJson(Map<String, dynamic> json) {
    return SessionGroupModel(
      id: json['id'] ?? '',
      responsibleCpf: json['responsibleCpf'] ?? '',
      responsiblePhoneNumber: json['responsiblePhoneNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'responsibleCpf': responsibleCpf,
      'responsiblePhoneNumber': responsiblePhoneNumber,
    };
  }
}