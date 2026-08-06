import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelaMenu extends StatefulWidget {
  const TelaMenu({super.key});

  @override
  State<TelaMenu> createState() => _TelaMenuState();
}

class _TelaMenuState extends State<TelaMenu> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.1.7:3333',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  List<dynamic> _menuItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todas';

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    setState(() => _isLoading = true);
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
        });
      }
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(e.response?.data?['message'] ?? 'Erro ao carregar cardápio.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Erro inesperado: $e');
    }
  }

  Future<void> _showItemFormDialog({Map<String, dynamic>? itemToEdit}) async {
    final isEditing = itemToEdit != null;
    final nameController = TextEditingController(text: itemToEdit?['name'] ?? '');
    final categoryController = TextEditingController(text: itemToEdit?['category'] ?? '');
    final priceController = TextEditingController(text: itemToEdit?['price']?.toString() ?? '');
    bool isAvaliable = itemToEdit?['isAvaliable'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Item' : 'Novo Item do Cardápio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome do Item'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Categoria (ex: Bebidas, Comidas)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Preço (ex: 7,00)'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Disponível'),
                  value: isAvaliable,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    setDialogState(() => isAvaliable = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _confirmDelete(itemToEdit['id']);
                },
                child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final name = nameController.text.trim();
                final category = categoryController.text.trim();
                final price = priceController.text.trim();

                if (name.isEmpty || category.isEmpty || price.isEmpty) {
                  _showErrorDialog('Preencha todos os campos obrigatórios.');
                  return;
                }

                Navigator.pop(context);
                await _submitItemData(
                  id: itemToEdit?['id'],
                  name: name,
                  category: category,
                  price: price,
                  isAvaliable: isAvaliable,
                  isEditing: isEditing,
                );
              },
              child: Text(isEditing ? 'Salvar' : 'Criar'),
            ),
          ],
        ),
      ),
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
      _showErrorDialog(e.response?.data?['message'] ?? 'Erro ao salvar item.');
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
      _showErrorDialog(e.response?.data?['message'] ?? 'Erro ao atualizar disponibilidade.');
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