import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_client.dart';

class TelaMenu extends StatefulWidget {
  const TelaMenu({super.key});

  @override
  State<TelaMenu> createState() => _TelaMenuState();
}

class _TelaMenuState extends State<TelaMenu> {
  final Dio _dio = ApiClient.dio;

  List<dynamic> _menuItems = [];
  bool _isLoading = true;
  bool _isApiOffline = false;
  String _selectedCategory = 'Todas';

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    setState(() {
      _isLoading = true;
      _isApiOffline = false;
    });
    try {
      String path = '/menu';
      if (_selectedCategory != 'Todas') {
        path += '?category=$_selectedCategory';
      }

      final response = await _dio.get(path);
      if (response.data is List) {
        setState(() {
          _menuItems = response.data;
          _isLoading = false;
          _isApiOffline = false;
        });
      }
    } on DioException catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isApiOffline = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isApiOffline = true;
        });
      }
    }
  }

  Future<void> _showItemFormDialog({Map<String, dynamic>? itemToEdit}) async {
    final isEditing = itemToEdit != null;
    final nameController = TextEditingController(text: itemToEdit?['name'] ?? '');
    final categoryController = TextEditingController(text: itemToEdit?['category'] ?? '');
    final priceController = TextEditingController(text: itemToEdit?['price']?.toString() ?? '');
    bool isAvaliable = itemToEdit?['isAvaliable'] ?? true;

    bool hasErrorName = false;
    bool hasErrorCategory = false;
    bool hasErrorPrice = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Animação de entrada suave (fade + scale leve)
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                // Pega a altura exata do teclado para empurrar o modal para cima sem esmagá-lo
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

                return AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    isEditing ? 'Editar Item' : 'Novo Item do Cardápio',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  content: AnimatedPadding(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 10 : 0),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameController,
                              autofocus: true,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: 'Nome do Item',
                                hintText: 'Ex: Refrigerante Lata',
                                errorText: hasErrorName ? 'Campo obrigatório' : null,
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: categoryController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Categoria',
                                hintText: 'Ex: Bebidas, Comidas',
                                errorText: hasErrorCategory ? 'Campo obrigatório' : null,
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Preço (R\$)',
                                hintText: '0,00',
                                errorText: hasErrorPrice ? 'Informe um preço válido' : null,
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SwitchListTile(
                                title: const Text('Disponível para venda', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                value: isAvaliable,
                                activeColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onChanged: (val) {
                                  HapticFeedback.lightImpact();
                                  setDialogState(() => isAvaliable = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  actions: [
                    if (isEditing)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          _confirmDelete(itemToEdit['id']);
                        },
                        child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Text('Cancelar', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final name = nameController.text.trim();
                        final category = categoryController.text.trim();
                        final priceText = priceController.text.trim().replaceAll(',', '.');

                        setDialogState(() {
                          hasErrorName = name.isEmpty;
                          hasErrorCategory = category.isEmpty;
                          hasErrorPrice = priceText.isEmpty || (double.tryParse(priceText) == null);
                        });

                        if (hasErrorName || hasErrorCategory || hasErrorPrice) {
                          return;
                        }

                        Navigator.pop(context);
                        await _submitItemData(
                          id: itemToEdit?['id'],
                          name: name,
                          category: category,
                          price: priceText,
                          isAvaliable: isAvaliable,
                          isEditing: isEditing,
                        );
                      },
                      child: Text(isEditing ? 'Salvar' : 'Criar', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item'),
        content: const Text('Tem certeza de que deseja remover este item do cardápio?'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              _deleteItem(id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitItemData({
    String? id,
    required String name,
    required String category,
    required String price,
    required bool isAvaliable,
    required bool isEditing,
  }) async {
    setState(() => _isLoading = true);
    try {
      final body = {
        'name': name,
        'category': category,
        'price': price,
        'isAvaliable': isAvaliable,
      };

      if (isEditing) {
        body['id'] = id!;
        await _dio.patch('/menu/$id', data: body);
      } else {
        await _dio.post('/menu', data: body);
      }

      await _fetchMenu();
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(e.response?.data?['message'] ?? 'Erro ao conectar com a API ao salvar item.');
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item, bool newValue) async {
    final id = item['id'];
    try {
      setState(() {
        item['isAvaliable'] = newValue;
      });

      await _dio.patch('/menu/$id', data: {
        'id': id,
        'name': item['name'],
        'category': item['category'],
        'price': item['price'],
        'isAvaliable': newValue,
      });
    } on DioException catch (e) {
      setState(() {
        item['isAvaliable'] = !newValue;
      });
      _showErrorDialog(e.response?.data?['message'] ?? 'Erro de conexão com a API.');
    }
  }

  Future<void> _deleteItem(String id) async {
    setState(() => _isLoading = true);
    try {
      await _dio.delete('/menu/$id', data: {});
      await _fetchMenu();
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(e.response?.data?['message'] ?? 'Erro ao deletar item.');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atenção'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ['Todas', 'Bebidas', 'Comidas', 'Sobremesas'];

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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cardápio',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Itens disponíveis para os garçons.',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                      ),
                      onSelected: (selected) {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedCategory = cat);
                        _fetchMenu();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _isApiOffline
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Conexão com a API desativada',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _fetchMenu();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
                  : _menuItems.isEmpty
                  ? const Center(child: Text('Nenhum item encontrado.'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isAvailable = item['isAvaliable'] ?? true;
                  final category = (item['category'] ?? '').toUpperCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showItemFormDialog(itemToEdit: item);
                      },
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['name'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? colorScheme.onSurface : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'R\$ ${(double.tryParse(item['price'].toString()) ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: isAvailable,
                            activeColor: colorScheme.primary,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              _toggleAvailability(item, val);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showItemFormDialog();
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}