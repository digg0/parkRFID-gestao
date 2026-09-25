import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';


class BraceletsRepository {
  final Dio _dio;

  BraceletsRepository({Dio? dio}) : _dio = dio ?? ApiClient.dio;


  Future<void> registerBracelet(String uidRfid) async {
    await _dio.post(
      '/bracelets',
      data: {
        'uid_rfid': uidRfid,
      },
    );
  }


  Future<void> deleteBracelet(String uidRfid) async {
    await _dio.delete(
      '/bracelets/$uidRfid',
      data: {},
    );
  }

  Future<void> getBracelet(String uidRfid) async {
    await _dio.get('/bracelets/$uidRfid');
  }
}