import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/bracelets_controller.dart';
import 'nfc_radar_pulse.dart';

final GlobalKey<_TelaGestaoPulseirasContentState> gestaoPulseirasKey = GlobalKey();

class TelaGestaoPulseiras extends StatelessWidget {
  const TelaGestaoPulseiras({super.key});

  static void resetarFluxo() {
    gestaoPulseirasKey.currentState?._resetFlow();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BraceletsController(),
      child: _TelaGestaoPulseirasContent(key: gestaoPulseirasKey),
    );
  }
}

class _TelaGestaoPulseirasContent extends StatefulWidget {
  const _TelaGestaoPulseirasContent({super.key});

  @override
  State<_TelaGestaoPulseirasContent> createState() => _TelaGestaoPulseirasContentState();
}

class _TelaGestaoPulseirasContentState extends State<_TelaGestaoPulseirasContent> {
  int _step = 1;
  String? _scannedUid;
  bool _isDeleteMode = false;
  bool _isCheckingStatus = false;
  String? _localErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BraceletsController>().checkNfcSupport();
      }
    });
  }

  void _startScanning(bool deleteMode) {
    setState(() {
      _isDeleteMode = deleteMode;
      _step = 2;
      _scannedUid = null;
      _localErrorMessage = null;
      _isCheckingStatus = false;
    });

    final controller = context.read<BraceletsController>();

    controller.startNfcScan((uid) async {
      if (_scannedUid != null) return;

      setState(() {
        _scannedUid = uid;
        _step = 3;
        _localErrorMessage = null;
        _isCheckingStatus = false;
      });
    });
  }

  Future<void> _restartScanning() async {
    final controller = context.read<BraceletsController>();
    try { controller.stopNfc(); } catch (_) {}

    setState(() {
      _step = 2;
      _scannedUid = null;
      _localErrorMessage = null;
      _isCheckingStatus = false;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    controller.startNfcScan((uid) async {
      if (_scannedUid != null) return;
      setState(() {
        _scannedUid = uid;
        _step = 3;
        _localErrorMessage = null;
        _isCheckingStatus = false;
      });
    });
  }

  void _resetFlow() {
    try {
      context.read<BraceletsController>().stopNfc();
    } catch (_) {}

    if (mounted && _step != 1) {
      setState(() {
        _step = 1;
        _scannedUid = null;
        _isDeleteMode = false;
        _isCheckingStatus = false;
        _localErrorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: _step == 1,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _step > 1) {
            _resetFlow();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 2:
        return _buildTela2Leitura();
      case 3:
        return _buildTela3Resultado();
      case 1:
      default:
        return _buildTela1Home();
    }
  }

  Widget _buildTela1Home() {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestão de Pulseiras',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Controle de acesso e vinculação via NFC.',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _buildHomeCard(
                      title: 'Cadastrar Pulseira',
                      subtitle: 'Aproxime uma nova pulseira para registrar o seu uso no sistema.',
                      icon: Icons.add_circle_outline_rounded,
                      primaryColor: colorScheme.primary,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _startScanning(false);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildHomeCard(
                      title: 'Apagar Pulseira',
                      subtitle: 'Aproxime uma pulseira existente para removê-la completamente do sistema.',
                      icon: Icons.remove_circle_outline_rounded,
                      primaryColor: Colors.redAccent,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _startScanning(true);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTela2Leitura() {
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _resetFlow,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDeleteMode ? 'Apagar pulseira' : 'Cadastrar pulseira',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const NfcRadarPulse(),
            const SizedBox(height: 40),
            const Text(
              'Aproxime a pulseira',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTela3Resultado() {
    final controller = context.watch<BraceletsController>();

    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _resetFlow,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDeleteMode ? 'Apagar pulseira' : 'Cadastrar pulseira',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isCheckingStatus
                            ? const Color(0xFFFFF8E1)
                            : (_localErrorMessage != null
                            ? const Color(0xFFFFEBEE)
                            : (_isDeleteMode ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9))),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCheckingStatus
                                ? Icons.hourglass_top_rounded
                                : (_localErrorMessage != null
                                ? Icons.error_outline_rounded
                                : (_isDeleteMode ? Icons.delete_outline_rounded : Icons.check_circle_rounded)),
                            color: _isCheckingStatus
                                ? const Color(0xFFF57F17)
                                : (_localErrorMessage != null
                                ? const Color(0xFFC62828)
                                : (_isDeleteMode ? const Color(0xFFC62828) : const Color(0xFF2E7D32))),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isCheckingStatus
                                ? 'Verificando status...'
                                : (_localErrorMessage != null
                                ? 'Já cadastrada'
                                : (_isDeleteMode ? 'Pronta para remoção' : 'Pronta para cadastro')),
                            style: TextStyle(
                              color: _isCheckingStatus
                                  ? const Color(0xFFF57F17)
                                  : (_localErrorMessage != null
                                  ? const Color(0xFFC62828)
                                  : (_isDeleteMode ? const Color(0xFFC62828) : const Color(0xFF2E7D32))),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                          child: const Icon(Icons.nfc_rounded, color: Color(0xFF1E88E5), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PULSEIRA / TAG',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _scannedUid ?? 'N/A',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_localErrorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _localErrorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _isDeleteMode
                        ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 2),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: controller.isLoading
                          ? null
                          : () async {
                        if (_scannedUid == null) return;


                        final errorMessage = await controller.deleteBracelet(_scannedUid!);

                        if (!mounted) return;

                        if (errorMessage == null) {

                          _restartScanning();
                        } else {

                          setState(() {
                            _localErrorMessage = errorMessage;
                          });
                        }
                      },
                      child: controller.isLoading
                          ? const CircularProgressIndicator(color: Colors.redAccent)
                          : const Text(
                        'Confirmar exclusão',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                    )
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: controller.isLoading
                          ? null
                          : () async {
                        if (_scannedUid == null) return;

                        final errorMessage = await controller.registerBracelet(_scannedUid!);

                        if (!mounted) return;

                        if (errorMessage == null) {
                          _restartScanning();
                        } else {
                          setState(() {
                            _localErrorMessage = errorMessage;
                          });
                        }
                      },
                      child: controller.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Confirmar cadastro',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _resetFlow,
                      child: const Text(
                        'Voltar ao menu',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}