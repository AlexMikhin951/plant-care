import 'plant_detail_screen.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plant.dart';
import '../services/ai_service.dart';
import 'my_plants_screen.dart';
import 'dart:async';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

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

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final List<Plant> plants = [];
  final AIService aiService = AIService();
  final ImagePicker picker = ImagePicker();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadPlants();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    loadPlants();
  }

  Future<void> loadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final plantsJson = prefs.getStringList('plants') ?? [];
    setState(() {
      plants.clear();
      plants.addAll(plantsJson.map((p) => Plant.fromJson(jsonDecode(p))));
    });
  }

  // Вспомогательный метод для безопасного отображения фото (решает проблему _Namespace)
  Widget _buildPlantLeading(String? path) {
    if (path == null || path.isEmpty) {
      return Image.asset(
        'assets/images/photo.png',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      );
    }

    if (kIsWeb || path.startsWith('data:image') || path.length > 1000) {
      try {
        return Image.memory(
          base64Decode(path.contains(',') ? path.split(',').last : path),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/photo.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return Image.asset(
          'assets/images/photo.png',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        );
      }
    } else {
      return File(path).existsSync()
          ? Image.file(File(path), width: 40, height: 40, fit: BoxFit.cover)
          : Image.asset(
              'assets/images/photo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            );
    }
  }

  Future<void> _addPlantFromCamera() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📷 Камера недоступна в веб-версии'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) await _processImage(image);
  }

  Future<void> _addPlantFromGallery() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) await _processImage(image);
  }

  Future<void> _processImage(XFile image) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String dots = '';
        Timer? timer;
        return StatefulBuilder(
          builder: (context, setState) {
            timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
              if (context.mounted)
                setState(() {
                  dots = dots.length < 3 ? dots + '.' : '';
                });
            });
            return WillPopScope(
              onWillPop: () async => false,
              child: Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/loading.png',
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Ищем растение в наших базах данных',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dots,
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.black,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final plant = await aiService.recognizePlantWithGemini(
        imagePath: image.path,
        imageBytesWeb: bytes,
      );

      if (plant.imagePaths.isEmpty) {
        plant.imagePaths.add(kIsWeb ? base64Image : image.path);
      }

      setState(() {
        plants.add(plant);
      });
      await savePlants();
    } catch (e) {
      debugPrint("⚠️ Ошибка: $e");
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> savePlants() async {
    final prefs = await SharedPreferences.getInstance();
    final plantsJson = plants.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('plants', plantsJson);
  }

  List<Widget> _getEventIconsForDay(DateTime day) {
    List<Widget> icons = [];
    for (var plant in plants) {
      if (plant.wateringDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.water_drop, color: Colors.blue, size: 16));
      if (plant.fertilizingDates.any((d) => isSameDay(d, day)))
        icons.add(
          const Icon(Icons.local_florist, color: Colors.green, size: 16),
        );
      if (plant.pruningDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.content_cut, color: Colors.brown, size: 16));
      if (plant.repottingDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.podcasts, color: Colors.orange, size: 16));
      if (plant.mistingDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.grain, color: Colors.cyan, size: 16));
      if (plant.cleaningLeavesDates.any((d) => isSameDay(d, day)))
        icons.add(
          const Icon(Icons.cleaning_services, color: Colors.teal, size: 16),
        );
      if (plant.pestControlDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.bug_report, color: Colors.red, size: 16));
      if (plant.stakingDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.support, color: Colors.purple, size: 16));
      if (plant.lightAdjustmentDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.wb_sunny, color: Colors.yellow, size: 16));
      if (plant.temperatureAdjustmentDates.any((d) => isSameDay(d, day)))
        icons.add(const Icon(Icons.thermostat, color: Colors.pink, size: 16));
    }
    return icons;
  }

  void _showDayPlants(DateTime day) {
    List<Map<String, dynamic>> tasks = [];
    for (var plant in plants) {
      void addTasks(
        List<DateTime> dates,
        String actionName,
        IconData icon,
        Color color,
      ) {
        for (var d in dates.where((d) => isSameDay(d, day))) {
          tasks.add({
            'plant': plant,
            'name': actionName,
            'time': d,
            'icon': icon,
            'color': color,
          });
        }
      }

      addTasks(plant.wateringDates, "Полив", Icons.water_drop, Colors.blue);
      addTasks(
        plant.fertilizingDates,
        "Удобрение",
        Icons.local_florist,
        Colors.green,
      );
      addTasks(plant.pruningDates, "Обрезка", Icons.content_cut, Colors.brown);
      addTasks(
        plant.repottingDates,
        "Пересадка",
        Icons.podcasts,
        Colors.orange,
      );
      addTasks(plant.mistingDates, "Опрыскивание", Icons.grain, Colors.cyan);
      addTasks(
        plant.cleaningLeavesDates,
        "Протирка листьев",
        Icons.cleaning_services,
        Colors.teal,
      );
      addTasks(
        plant.pestControlDates,
        "Борьба с вредителями",
        Icons.bug_report,
        Colors.red,
      );
      addTasks(plant.stakingDates, "Подвязка", Icons.support, Colors.purple);
      addTasks(
        plant.lightAdjustmentDates,
        "Регулировка света",
        Icons.wb_sunny,
        Colors.yellow,
      );
      addTasks(
        plant.temperatureAdjustmentDates,
        "Регулировка температуры",
        Icons.thermostat,
        Colors.pink,
      );
    }

    tasks.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Задачи на ${day.day}.${day.month}.${day.year}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: tasks.map((task) {
                  final plant = task['plant'] as Plant;
                  final String? previewPath = plant.imagePaths.isNotEmpty
                      ? plant.imagePaths.first
                      : null;

                  return ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantDetailScreen(plant: plant),
                      ),
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildPlantLeading(previewPath),
                    ),
                    title: Text("${plant.name} - ${task['name']}"),
                    subtitle: Text(
                      "${(task['time'] as DateTime).hour.toString().padLeft(2, '0')}:${(task['time'] as DateTime).minute.toString().padLeft(2, '0')}",
                    ),
                    trailing: Icon(
                      task['icon'] as IconData,
                      color: task['color'] as Color,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight),
                child: Column(
                  children: [
                    ClipRRect(
                      child: Image.asset(
                        'assets/images/menu_icon.png',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: CalendarFormat.month,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _focusedDay = focusedDay;
                            });
                            _showDayPlants(selectedDay);
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              final icons = _getEventIconsForDay(day);
                              if (icons.isEmpty) return const SizedBox();
                              List<Widget> displayedIcons = [];
                              int maxIcons = 2;
                              for (
                                int i = 0;
                                i < icons.length && i < maxIcons;
                                i++
                              ) {
                                displayedIcons.add(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: icons[i],
                                  ),
                                );
                              }
                              if (icons.length > maxIcons)
                                displayedIcons.add(
                                  const Text(
                                    "...",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: displayedIcons,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: Colors.black26,
                            elevation: 3,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MyPlantsScreen(plants: plants),
                              ),
                            );
                            loadPlants();
                          },
                          child: const Text(
                            "Мои растения",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          icon: const Icon(
                            Icons.auto_awesome,
                            size: 24,
                            color: Colors.black87,
                          ),
                          label: const Text(
                            "Добавить растение с помощью AI",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white.withOpacity(0.95),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (context) => FractionallySizedBox(
                                heightFactor: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[400],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_library,
                                          size: 28,
                                        ),
                                        title: const Text(
                                          "Выбрать из галереи",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addPlantFromGallery();
                                        },
                                      ),
                                      const Divider(),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.camera_alt,
                                          size: 28,
                                        ),
                                        title: const Text(
                                          "Сделать фото",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addPlantFromCamera();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
