import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rfidparque/features/bracelets/presentation/screens/tela_gestao_pulseiras.dart';
import 'package:rfidparque/features/menu/presentation/screens/tela_menu.dart';
import '../../../sessions/presentation/screens/tela_checkin.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TelaCheckin(),
    const Center(child: Text('Tela de Sessões')),
    const TelaGestaoPulseiras(),
    const TelaMenu(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          HapticFeedback.lightImpact();
          if (_currentIndex == 2 && index != 2) {
            TelaGestaoPulseiras.resetarFluxo();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withOpacity(0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner, color: colorScheme.primary),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: const Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number, color: colorScheme.primary),
            label: 'Sessões',
          ),
          NavigationDestination(
            icon: const Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.add, color: colorScheme.primary),
            label: 'Cadastro Pu',
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu, color: colorScheme.primary),
            label: 'Cardápio',
          ),
        ],
      ),
    );
  }
}