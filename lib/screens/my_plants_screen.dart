import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import 'plant_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 🔹 Глобальный SafeArea с фоном
class GlobalSafeArea extends StatelessWidget {
  final Widget child;
  final Widget? background;

  const GlobalSafeArea({super.key, required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Stack(
      children: [
        if (background != null) Positioned.fill(child: background!),
        Padding(
          padding: EdgeInsets.only(
            top: padding.top,
            bottom: padding.bottom,
            left: 0,
            right: 0,
          ),
          child: child,
        ),
      ],
    );
  }
}

class MyPlantsScreen extends StatefulWidget {
  final List<Plant> plants;

  const MyPlantsScreen({super.key, required this.plants});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  List<Plant> displayedPlants = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    displayedPlants = List.from(widget.plants);
  }

  void _filterPlants(String query) {
    setState(() {
      searchQuery = query;
      displayedPlants = widget.plants
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _savePlants() async {
    final prefs = await SharedPreferences.getInstance();
    final plantsJson = widget.plants
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    await prefs.setStringList('plants', plantsJson);
  }

  void _openPlantDetail({Plant? plant}) async {
    final result = await Navigator.push<Plant?>(
      context,
      MaterialPageRoute(
        builder: (_) => PlantDetailScreen(
          plant:
              plant ??
              Plant(
                name: '',
                description: '',
                careInstructions: '',
                careTips: '',
                imagePaths: [],
              ),
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        final index = widget.plants.indexWhere((p) => p.name == result.name);
        if (index >= 0) {
          widget.plants[index] = result;
        } else {
          widget.plants.add(result);
        }
        displayedPlants = List.from(widget.plants);
      });

      await _savePlants();
    }
  }

  void _deletePlant(Plant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удаление растения"),
        content: const Text("Вы уверены, что хотите удалить растение?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.plants.remove(plant);
        displayedPlants.remove(plant);
      });
      await _savePlants();
    }
  }

  Widget _buildPlantImage(Plant plant) {
    // Для веб используем только контейнер с иконкой
    if (kIsWeb || plant.imagePaths.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        color: Colors.grey[300],
        child: const Icon(Icons.local_florist),
      );
    }

    // Для мобильных проверяем File
    final path = plant.imagePaths.first;
    return File(path).existsSync()
        ? Image.file(File(path), width: 60, height: 60, fit: BoxFit.cover)
        : Container(
            width: 60,
            height: 60,
            color: Colors.grey[300],
            child: const Icon(Icons.local_florist),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlobalSafeArea(
        background: Image.asset(
          'assets/images/background.png',
          fit: BoxFit.cover,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/my_plants.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Поиск растений...",
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white70,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _filterPlants,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    children: [
                      ...displayedPlants.map((plant) {
                        return GestureDetector(
                          onTap: () => _openPlantDetail(plant: plant),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(230, 255, 255, 255),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildPlantImage(plant),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plant.name.isNotEmpty
                                              ? plant.name
                                              : "Без названия",
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          plant.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deletePlant(plant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Center(
                        child: _AddPlantButton(onTap: () => _openPlantDetail()),
                      ),
                      const SizedBox(height: 20),
                    ],
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

// 🔹 Кнопка добавления растения с белым прозрачным фоном (вместо картинки)
class _AddPlantButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlantButton({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 28, color: Colors.black87),
                SizedBox(width: 8),
                Text(
                  "Добавить растение",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
