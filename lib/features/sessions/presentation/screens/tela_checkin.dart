import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../../../core/api/api_client.dart';
import '../../../bracelets/presentation/screens/nfc_radar_pulse.dart';


class MaskedTextInputFormatter extends TextInputFormatter {
  final String mask;
  final String separator;

  MaskedTextInputFormatter({required this.mask, required this.separator});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isNotEmpty) {
      if (newValue.text.length > oldValue.text.length) {
        if (newValue.text.length > mask.length) return oldValue;
      }
    }

    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String result = '';
    int currentIndex = 0;

    for (int i = 0; i < mask.length; i++) {
      if (currentIndex >= text.length) break;
      if (mask[i] == '0') {
        result += text[currentIndex];
        currentIndex++;
      } else {
        result += mask[i];
      }
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class TelaCheckin extends StatefulWidget {
  final ValueChanged<bool>? onNavbarVisibilityChanged;

  const TelaCheckin({super.key, this.onNavbarVisibilityChanged});

  static void Function()? _resetCallback;

  static void resetarFluxo() {
    _resetCallback?.call();
  }

  @override
  State<TelaCheckin> createState() => _TelaCheckinState();
}

class _TelaCheckinState extends State<TelaCheckin> with SingleTickerProviderStateMixin {
  final Dio _dio = ApiClient.dio;

  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _manualTagController = TextEditingController();

  int _step = 0;
  String? _currentScannedUid;
  String _selectedType = 'NORMAL';
  bool _isLoading = false;
  bool _isNfcActive = false;

  final List<Map<String, String>> _readBracelets = [];
  Map<String, dynamic>? _lastSuccessData;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    TelaCheckin._resetCallback = _resetToMenu;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    TelaCheckin._resetCallback = null;
    _animController.dispose();
    _stopNfcSession();
    _cpfController.dispose();
    _phoneController.dispose();
    _manualTagController.dispose();
    super.dispose();
  }

  void _changeStep(int newStep) {
    HapticFeedback.lightImpact();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _step = newStep);
        _animController.forward();
      }
    });
  }

  void _updateNavbarVisibility(bool visible) {
    if (widget.onNavbarVisibilityChanged != null) {
      widget.onNavbarVisibilityChanged!(visible);
    }
  }

  void _resetToMenu() {
    if (!mounted) return;
    _stopNfcSession();
    HapticFeedback.mediumImpact();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _step = 0;
          _currentScannedUid = null;
          _readBracelets.clear();
          _cpfController.clear();
          _phoneController.clear();
          _manualTagController.clear();
          _lastSuccessData = null;
        });
        _animController.forward();
      }
    });
    _updateNavbarVisibility(true);
  }

  Future<void> _startNfcSession() async {
    final bool isAvailable = await NfcManager.instance.isAvailable();

    if (!isAvailable) {
      if (mounted) setState(() => _isNfcActive = false);
      _showErrorDialog('NFC indisponível ou desativado neste aparelho. Utilize a digitação manual de código.');
      return;
    }

    if (mounted) setState(() => _isNfcActive = true);

    try {
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          final tagId = _extractTagId(tag);
          if (!mounted) return;

          if (tagId != null && tagId.isNotEmpty) {
            _handleTagDiscovered(tagId);
          } else {
            _showErrorDialog('Não foi possível extrair o ID desta tag NFC.');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isNfcActive = false);
        _showErrorDialog('Erro ao iniciar leitor NFC: $e');
      }
    }
  }

  void _stopNfcSession() {
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    if (mounted) setState(() => _isNfcActive = false);
  }

  void _handleTagDiscovered(String tagId) {
    final cleanId = tagId.trim().toUpperCase();
    if (cleanId.isEmpty) return;

    final alreadyRead = _readBracelets.any((b) => b['braceletId'] == cleanId);
    if (alreadyRead) {
      HapticFeedback.heavyImpact();
      _showErrorDialog('Pulseira ($cleanId) já foi adicionada neste grupo!');
      return;
    }

    HapticFeedback.heavyImpact();
    _stopNfcSession();
    setState(() {
      _currentScannedUid = cleanId;
      _selectedType = 'NORMAL';
    });
    _changeStep(3);
  }

  String? _extractTagId(NfcTag tag) {
    try {
      final rawData = tag.data;
      if (rawData is Map) return _extractFromMap(rawData);
      try {
        final dynamic dynamicData = tag.data;
        if (dynamicData.id != null) return _bytesToHex(List<int>.from(dynamicData.id));
        if (dynamicData.identifier != null) return _bytesToHex(List<int>.from(dynamicData.identifier));
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  String? _extractFromMap(Map data) {
    for (final tech in ['nfca', 'mifareclassic', 'mifareultralight', 'mifare', 'isodep', 'ndef', 'nfcb', 'nfcf', 'nfcv']) {
      if (data.containsKey(tech) && data[tech] is Map) {
        final techMap = data[tech] as Map;
        if (techMap.containsKey('identifier') && techMap['identifier'] is List) {
          return _bytesToHex(List<int>.from(techMap['identifier']));
        }
      }
    }
    return null;
  }

  void _proceedToNfcReading() {
    final cleanCpf = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanCpf.length != 11) {
      HapticFeedback.heavyImpact();
      _showErrorDialog('O CPF deve conter exatamente 11 dígitos.');
      return;
    }
    if (cleanPhone.length < 10) {
      HapticFeedback.heavyImpact();
      _showErrorDialog('Informe um telefone válido com DDD.');
      return;
    }

    _changeStep(2);
    _startNfcSession();
  }

  void _addCurrentBraceletToGroup() {
    if (_currentScannedUid == null) return;

    final isLeader = _readBracelets.isEmpty;
    setState(() {
      _readBracelets.add({
        'braceletId': _currentScannedUid!,
        'type': _selectedType,
        'isLeader': isLeader ? 'true' : 'false',
      });
      _currentScannedUid = null;
    });
    _changeStep(4);
  }

  void _removeBracelet(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _readBracelets.removeAt(index);
      if (_readBracelets.isNotEmpty && !_readBracelets.any((b) => b['isLeader'] == 'true')) {
        _readBracelets[0]['isLeader'] = 'true';
      }
    });
  }

  Future<void> _finishCheckin() async {
    if (_readBracelets.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorDialog('Nenhuma pulseira foi registrada no grupo.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    String? createdGroupId;

    try {
      final cleanCpf = _cpfController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');


      final groupResponse = await _dio.post('/sessions/checkin/group', data: {
        'responsibleCpf': cleanCpf,
        'responsiblePhoneNumber': cleanPhone,
      });


      if (groupResponse.statusCode == 200 || groupResponse.statusCode == 201) {
        if (groupResponse.data is Map && groupResponse.data['sessionGroup'] != null) {
          createdGroupId = groupResponse.data['sessionGroup']['id']?.toString();
        }
      }

      if (createdGroupId == null || createdGroupId.isEmpty) {
        throw Exception('Não foi possível obter o ID do grupo criado.');
      }


      for (final bracelet in _readBracelets) {
        await _dio.post('/sessions/checkin', data: {
          'braceletId': bracelet['braceletId'],
          'sessionGroupId': createdGroupId,
          'sessionType': bracelet['type'], // 'NORMAL' ou 'KID'
        });
      }


      _completeSuccess();

    } on DioException catch (e) {
      HapticFeedback.heavyImpact();

      final responseData = e.response?.data;
      String message = 'Erro ao realizar check-in.';

      if (responseData is Map && responseData.containsKey('message')) {
        message = responseData['message'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }

      _showErrorDialog(message);
    } catch (e) {
      HapticFeedback.heavyImpact();
      _showErrorDialog('Erro ao finalizar check-in: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _completeSuccess() {
    if (mounted) {
      setState(() {
        _lastSuccessData = {
          'cpf': _cpfController.text.trim(),
          'phone': _phoneController.text.trim(),
          'count': _readBracelets.length.toString(),
          'time': TimeOfDay.now().format(context),
        };
      });
      _changeStep(5);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atenção', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          HapticFeedback.lightImpact();
          if (_step == 1) {
            _resetToMenu();
          } else if (_step == 2) {
            _stopNfcSession();
            _changeStep(1);
          } else if (_step == 3) {
            _changeStep(2);
            _startNfcSession();
          } else if (_step == 4) {
            _changeStep(1);
          } else {
            _resetToMenu();
          }
        }
      },
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 1:
        return _buildTela1Formulario();
      case 2:
        return _buildTela2LeituraNfc();
      case 3:
        return _buildTela3TipoPulseira();
      case 4:
        return _buildTela4Grupo();
      case 5:
        return _buildTela5Sucesso();
      case 0:
      default:
        return _buildTela0Menu();
    }
  }

  Widget _buildTela0Menu() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: colorScheme.primary,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Image.asset('assets/images/logo.png', height: 50, fit: BoxFit.contain),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text('Gerenciamento', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Selecione uma opção para iniciar', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  const SizedBox(height: 28),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _updateNavbarVisibility(false);
                      _changeStep(1);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Novo check-in',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vincular responsável e pulseiras',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary.withOpacity(0.85),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colorScheme.onPrimary, size: 26),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTela1Formulario() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: colorScheme.primary,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      onPressed: _resetToMenu, 
                    ),
                  ),
                  Image.asset('assets/images/logo.png', height: 45, fit: BoxFit.contain),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Novo check-in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Identificação do responsável', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    const SizedBox(height: 32),
                    const Text('CPF DO RESPONSÁVEL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        MaskedTextInputFormatter(mask: '000.000.000-00', separator: '.'),
                      ],
                      decoration: InputDecoration(
                        hintText: '000.000.000-00',
                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('TELEFONE (WHATSAPP)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        MaskedTextInputFormatter(mask: '(00) 00000-0000', separator: ' '),
                      ],
                      decoration: InputDecoration(
                        hintText: '(88) 90000-0000',
                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Esses dados identificam o grupo e servem para contato se necessário. As pulseiras continuam anônimas.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _proceedToNfcReading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Continuar para leitura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTela2LeituraNfc() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B7BB9), Color(0xFF102847)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _stopNfcSession();
                        _changeStep(1);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Leitura RFID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _handleTagDiscovered('SIM-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'),
                child: Transform.scale(
                  scale: 1.1,
                  child: const NfcRadarPulse(),
                ),
              ),
              const SizedBox(height: 40),
              const Text('Aproxime a pulseira', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  _isNfcActive ? 'Toque no anel ou aproxime a tag física' : 'NFC inativo. Toque no anel para simular leitura.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              if (_readBracelets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _changeStep(4);
                      },
                      child: const Text('Ver pulseiras do grupo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTela3TipoPulseira() {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF102847),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _changeStep(2);
                        _startNfcSession();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leitura RFID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('Pulseira identificada', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pulseira ${_currentScannedUid ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 4),
                                  const Text('Nova leitura · vincular ao grupo', style: TextStyle(color: Colors.black54, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('REGISTRAR ESTA PULSEIRA COMO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Normal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              )),
                              selected: _selectedType == 'NORMAL',
                              onSelected: (val) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedType = 'NORMAL');
                              },
                              selectedColor: const Color(0xFFE3F2FD),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _selectedType == 'NORMAL' ? Colors.blue : Colors.grey.shade300, width: 2)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Kid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              )),
                              selected: _selectedType == 'KID',
                              onSelected: (val) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedType = 'KID');
                              },
                              selectedColor: const Color(0xFFE3F2FD),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _selectedType == 'KID' ? Colors.blue : Colors.grey.shade300, width: 2)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _addCurrentBraceletToGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Adicionar ao grupo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTela4Grupo() {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF102847),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _changeStep(1);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Grupo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('Responsável ${_cpfController.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    Text('${_readBracelets.length} pulseiras no grupo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 20),
                    ..._readBracelets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final b = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: const Text('PS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15)),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b['braceletId'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(b['type'] == 'KID' ? 'Infantil / Kid' : 'Adulto / Normal', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _removeBracelet(index),
                              child: const Text('remover', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.blue.shade200, width: 2),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _changeStep(2);
                        _startNfcSession();
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text('Ler mais uma pulseira', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _finishCheckin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Finalizar check-in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTela5Sucesso() {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('Check-in realizado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text('Grupo liberado às ${_lastSuccessData?['time'] ?? ""}', style: const TextStyle(color: Colors.black54, fontSize: 15)),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Responsável', style: TextStyle(color: Colors.black54, fontSize: 15)),
                          Text(_lastSuccessData?['cpf'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Telefone', style: TextStyle(color: Colors.black54, fontSize: 15)),
                          Text(_lastSuccessData?['phone'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pulseiras', style: TextStyle(color: Colors.black54, fontSize: 15)),
                          Text(_lastSuccessData?['count'] ?? '0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _resetToMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Novo check-in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}