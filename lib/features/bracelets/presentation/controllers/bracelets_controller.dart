import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../../../../core/api/api_client.dart';

class BraceletsController extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> checkNfcSupport() async {
    try {
      await NfcManager.instance.isAvailable();
    } catch (_) {}
  }

  Future<bool> checkIfBraceletExists(String uid) async {
    try {
      final response = await ApiClient.dio.get('/bracelets/$uid');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  Future<String?> registerBracelet(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      await ApiClient.dio.post('/bracelets/', data: {'uid_rfid': uid});
      _isLoading = false;
      notifyListeners();
      return null;
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();


      final responseData = e.response?.data;
      if (responseData is Map && responseData.containsKey('message')) {
        return responseData['message'].toString();
      }

      if (e.response?.statusCode == 409) {
        return 'Esta pulseira já está cadastrada no sistema.';
      }

      return 'Erro ao cadastrar pulseira. Tente novamente.';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Erro de conexão com o servidor.';
    }
  }

  Future<String?> deleteBracelet(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final cleanDio = Dio(BaseOptions(baseUrl: ApiClient.dio.options.baseUrl));
      await cleanDio.delete(
        '/bracelets/$uid',
        options: Options(headers: {}),
      );

      _isLoading = false;
      notifyListeners();
      return null;
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();

      final responseData = e.response?.data;
      if (responseData is Map && responseData.containsKey('message')) {
        return responseData['message'].toString();
      }

      if (e.response?.statusCode == 404) {
        return 'Esta pulseira não está cadastrada no sistema.';
      }

      return 'Erro ao apagar pulseira. Tente novamente.';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Erro de conexão com o servidor.';
    }
  }

  void startNfcScan(Function(String uid) onScanned) async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        debugPrint('NFC não está disponível ou desligado no aparelho.');
        return;
      }

      await NfcManager.instance.stopSession().catchError((_) {});

      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          final tagId = _extractTagId(tag);

          if (tagId != null && tagId.isNotEmpty) {
            debugPrint('🔥 UID extraído com sucesso: $tagId');
            stopNfc();
            onScanned(tagId);
          } else {
            debugPrint('Cartão detectado, mas não foi possível extrair o ID: ${tag.data}');
          }
        },
      );
    } catch (e) {
      debugPrint('Erro ao iniciar sessão NFC: $e');
    }
  }

  String? _extractTagId(NfcTag tag) {
    try {
      final rawData = tag.data;

      if (rawData is Map) {
        return _extractFromMap(rawData);
      }

      try {
        final dynamic dynamicData = tag.data;

        if (dynamicData.id != null) {
          final idBytes = List<int>.from(dynamicData.id);
          return _bytesToHex(idBytes);
        }
        if (dynamicData.identifier != null) {
          final idBytes = List<int>.from(dynamicData.identifier);
          return _bytesToHex(idBytes);
        }
      } catch (_) {}

      try {
        final possibleKeys = [
          'nfca',
          'mifareclassic',
          'mifare',
          'isodep',
          'ndef',
          'nfcb',
          'nfcf',
          'nfcv'
        ];

        for (final key in possibleKeys) {
          try {
            final techData = (tag.data as dynamic)[key];
            if (techData != null) {
              if (techData['identifier'] != null) {
                return _bytesToHex(List<int>.from(techData['identifier']));
              }
              if (techData.identifier != null) {
                return _bytesToHex(List<int>.from(techData.identifier));
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  String? _extractFromMap(Map data) {
    for (final tech in [
      'nfca',
      'mifareclassic',
      'mifareultralight',
      'mifare',
      'isodep',
      'ndef',
      'nfcb',
      'nfcf',
      'nfcv'
    ]) {
      if (data.containsKey(tech) && data[tech] is Map) {
        final techMap = data[tech] as Map;
        if (techMap.containsKey('identifier') &&
            techMap['identifier'] is List) {
          return _bytesToHex(List<int>.from(techMap['identifier']));
        }
      }
    }
    return null;
  }

  void stopNfc() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
  }
}