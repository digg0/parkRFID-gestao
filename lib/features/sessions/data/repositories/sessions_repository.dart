import 'package:dio/dio.dart';
import '../models/session_group_model.dart';
import '../models/session_model.dart';

class SessionsRepository {
  final Dio _dio;

  SessionsRepository(this._dio);


  Future<SessionGroupModel> createGroup({
    required String responsibleCpf,
    required String responsiblePhoneNumber,
  }) async {
    try {
      final response = await _dio.post(
        '/sessions/checkin/group',
        data: {
          'responsibleCpf': responsibleCpf,
          'responsiblePhoneNumber': responsiblePhoneNumber,
        },
      );


      final groupData = response.data['sessionGroup'];
      return SessionGroupModel.fromJson(groupData);
    } on DioException catch (e) {

      throw _handleError(e, 'Erro ao criar grupo do responsável.');
    }
  }


  Future<SessionModel> checkinBracelet({
    required String braceletId,
    required String sessionGroupId,
    String sessionType = 'NORMAL',
  }) async {
    try {
      final response = await _dio.post(
        '/sessions/checkin',
        data: {
          'braceletId': braceletId,
          'sessionGroupId': sessionGroupId,
          'sessionType': sessionType,
        },
      );


      final sessionData = response.data['session'];
      return SessionModel.fromJson(sessionData);
    } on DioException catch (e) {
      throw _handleError(e, 'Erro ao vincular pulseira.');
    }
  }


  Future<bool> authorizeBracelet(String braceletId) async {
    try {
      final response = await _dio.post('/sessions/$braceletId/authorize');


      return response.data['allowed'] ?? false;
    } on DioException catch (e) {
      throw _handleError(e, 'Pulseira não autorizada ou inválida.');
    }
  }


  Future<String> closeSession(String braceletId) async {
    try {
      final response = await _dio.post('/sessions/$braceletId/close');


      return response.data['message'] ?? 'Sessão encerrada com sucesso.';
    } on DioException catch (e) {
      throw _handleError(e, 'Erro ao encerrar sessão da pulseira.');
    }
  }


  Exception _handleError(DioException e, String defaultMessage) {
    if (e.response?.data != null && e.response?.data is Map) {
      final apiMessage = e.response?.data['message'];
      if (apiMessage != null && apiMessage.toString().isNotEmpty) {
        return Exception(apiMessage);
      }
    }
    return Exception(defaultMessage);
  }
}