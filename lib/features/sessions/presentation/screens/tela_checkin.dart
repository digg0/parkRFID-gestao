import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class TelaCheckin extends StatefulWidget {
  const TelaCheckin({super.key});

  @override
  State<TelaCheckin> createState() => _TelaCheckinState();
}

typedef TelaCheckinMobile = TelaCheckin;

class _TelaCheckinState extends State<TelaCheckin> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.1.7:3333',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _manualTagController = TextEditingController();

  bool _isGroupActive = false;
  String _selectedType = 'NORMAL';
  bool _isLoading = false;
  bool _isNfcActive = false;

  final List<Map<String, String>> _readBracelets = [];

  @override
  void dispose() {
    _stopNfcSession();
    _cpfController.dispose();
    _phoneController.dispose();
    _manualTagController.dispose();
    super.dispose();
  }

  Future<void> _startNfcSession() async {
    final bool isAvailable = await NfcManager.instance.isAvailable();

    if (!isAvailable) {
      _showErrorDialog('NFC indisponível ou desativado neste aparelho.');
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
            _registerBracelet(tagId);
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
    NfcManager.instance.stopSession();
    if (mounted) {
      setState(() => _isNfcActive = false);
    }
  }

  String? _extractTagId(NfcTag tag) {
    final rawData = tag.data;
    List<int>? identifier;

    if (rawData is Map) {
      for (final tech in ['nfca', 'mifare', 'isodep', 'ndef', 'nfcb', 'nfcf', 'nfcv']) {
        if (rawData.containsKey(tech) && rawData[tech] is Map) {
          final techMap = rawData[tech] as Map;
          if (techMap.containsKey('identifier') && techMap['identifier'] is List) {
            identifier = List<int>.from(techMap['identifier']);
            break;
          }
        }
      }
    }

    if (identifier != null && identifier.isNotEmpty) {
      return identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    }
    return null;
  }

  void _handleCreateGroup() {
    if (_cpfController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      _showErrorDialog('Preencha o CPF e o Telefone do responsável.');
      return;
    }

    setState(() {
      _isGroupActive = true;
    });

    _startNfcSession();
  }

  void _registerBracelet(String braceletId) {
    final cleanId = braceletId.trim().toUpperCase();
    if (cleanId.isEmpty) return;

    final alreadyRead = _readBracelets.any((b) => b['braceletId'] == cleanId);
    if (alreadyRead) {
      _showErrorDialog('Pulseira ($cleanId) já foi adicionada neste grupo!');
      return;
    }

    final isLeader = _readBracelets.isEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _readBracelets.add({
          'braceletId': cleanId,
          'type': _selectedType,
          'isLeader': isLeader ? 'true' : 'false',
        });
        _manualTagController.clear();
      });
    });
  }

  void _removeBracelet(int index) {
    setState(() {
      _readBracelets.removeAt(index);
      if (_readBracelets.isNotEmpty && !_readBracelets.any((b) => b['isLeader'] == 'true')) {
        _readBracelets[0]['isLeader'] = 'true';
      }
    });
  }

  Future<void> _finishCheckin() async {
    if (_readBracelets.isEmpty) {
      _showErrorDialog('Nenhuma pulseira foi registrada no grupo.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final groupResponse = await _dio.post('/sessions/checkin/group', data: {
        'responsibleCpf': _cpfController.text.trim(),
        'responsiblePhoneNumber': _phoneController.text.trim(),
      });

      dynamic realGroupId;
      if (groupResponse.data is Map) {
        final map = groupResponse.data as Map;
        realGroupId = map['id'] ?? map['groupId'] ?? map['sessionGroupId'] ?? map['sessionGroup']?['id'] ?? map['data']?['id'];
      } else if (groupResponse.data is String) {
        realGroupId = groupResponse.data;
      }

      if (realGroupId == null) {
        throw Exception('Não foi possível obter o ID do grupo criado.');
      }

      for (final bracelet in _readBracelets) {
        await _dio.post('/sessions/checkin', data: {
          'braceletId': bracelet['braceletId'],
          'sessionGroupId': realGroupId.toString(),
          'sessionType': bracelet['type'],
          'isLeader': bracelet['isLeader'] == 'true',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Check-in finalizado com sucesso!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _resetFlow();
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Erro ao finalizar check-in';
      _showErrorDialog(message);
    } catch (e) {
      _showErrorDialog('Erro ao finalizar check-in: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showManualEntryDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Digitar código da pulseira', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _manualTagController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: A1B2C3D4',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_manualTagController.text.isNotEmpty) {
                _registerBracelet(_manualTagController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final theme = Theme.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Atenção', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    });
  }

  void _resetFlow() {
    _stopNfcSession();
    setState(() {
      _isGroupActive = false;
      _readBracelets.clear();
      _cpfController.clear();
      _phoneController.clear();
      _manualTagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),


            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-in de pulseiras',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crie o grupo e leia as pulseiras dos visitantes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!_isGroupActive) ...[
                      // CARD FORMULÁRIO "NOVO CHECK-IN"
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              'CPF do responsável',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _cpfController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '000.000.000-0',
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Telefone',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '(00) 00000-0000',
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _handleCreateGroup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('+ ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('Criar grupo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(radius: 4, backgroundColor: Colors.lightGreenAccent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Grupo aberto',
                                        style: TextStyle(
                                          color: colorScheme.onPrimaryContainer,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: _resetFlow,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: colorScheme.error, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(color: colorScheme.error, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CPF',
                                      style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _cpfController.text,
                                      style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 32),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TELEFONE',
                                      style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _phoneController.text,
                                      style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),


                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedType = 'NORMAL'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedType == 'NORMAL' ? colorScheme.surface : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedType == 'NORMAL'
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(radius: 4, backgroundColor: _selectedType == 'NORMAL' ? colorScheme.primary : Colors.transparent),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Normal',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedType == 'NORMAL' ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedType = 'KID'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedType == 'KID' ? colorScheme.surface : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedType == 'KID'
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(radius: 4, backgroundColor: _selectedType == 'KID' ? colorScheme.primary : Colors.transparent),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Kid',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedType == 'KID' ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),


                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.nfc_rounded, color: colorScheme.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _readBracelets.isEmpty
                                    ? 'Leitor NFC ativo — Aproxime a pulseira do LÍDER'
                                    : 'Leitor NFC ativo — Aproxime a próxima pulseira',
                                style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_isNfcActive)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),


                      Center(
                        child: TextButton.icon(
                          onPressed: _showManualEntryDialog,
                          icon: Icon(Icons.keyboard_outlined, color: colorScheme.primary, size: 18),
                          label: Text(
                            'Digitar código manualmente',
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pulseiras lidas',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_readBracelets.length}',
                                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_readBracelets.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Nenhuma pulseira lida ainda.',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  for (int i = 0; i < _readBracelets.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 8),
                                    Builder(
                                      builder: (context) {
                                        final item = _readBracelets[i];
                                        final isLeader = item['isLeader'] == 'true';

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: isLeader ? Colors.amber.shade50 : colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(10),
                                            border: isLeader ? Border.all(color: Colors.amber.shade300) : null,
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            leading: Icon(
                                              isLeader ? Icons.stars_rounded : Icons.style_rounded,
                                              color: isLeader ? Colors.amber.shade800 : colorScheme.primary,
                                              size: 24,
                                            ),
                                            title: Row(
                                              children: [
                                                Text(
                                                  item['braceletId'] ?? '',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                if (isLeader) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade200,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'LÍDER',
                                                      style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            subtitle: Text('Tipo: ${item['type']}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                            trailing: GestureDetector(
                                              onTap: () => _removeBracelet(i),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.errorContainer,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  color: colorScheme.error,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ]
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),


                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_readBracelets.isEmpty || _isLoading) ? null : _finishCheckin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            disabledBackgroundColor: colorScheme.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2))
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 20),
                              SizedBox(width: 8),
                              Text('Finalizar check-in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
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
    );
  }
}