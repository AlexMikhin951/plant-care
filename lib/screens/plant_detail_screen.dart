import 'dart:convert';
import 'dart:async';
import 'dart:io' as io show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // Для работы с байтами (веб)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/plant.dart';
import '../services/condition_service.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PlantAction {
  watering,
  fertilizing,
  pruning,
  repotting,
  misting,
  cleaningLeaves,
  pestControl,
  staking,
  lightAdjustment,
  temperatureAdjustment,
}

extension PlantActionExt on PlantAction {
  String get name {
    switch (this) {
      case PlantAction.watering:
        return "Полив";
      case PlantAction.fertilizing:
        return "Удобрение";
      case PlantAction.pruning:
        return "Обрезка";
      case PlantAction.repotting:
        return "Пересадка";
      case PlantAction.misting:
        return "Опрыскивание";
      case PlantAction.cleaningLeaves:
        return "Протирка листьев";
      case PlantAction.pestControl:
        return "Борьба с вредителями";
      case PlantAction.staking:
        return "Подвязка";
      case PlantAction.lightAdjustment:
        return "Регулировка света";
      case PlantAction.temperatureAdjustment:
        return "Регулировка температуры";
    }
  }

  IconData get icon {
    switch (this) {
      case PlantAction.watering:
        return Icons.water_drop;
      case PlantAction.fertilizing:
        return Icons.local_florist;
      case PlantAction.pruning:
        return Icons.content_cut;
      case PlantAction.repotting:
        return Icons.podcasts;
      case PlantAction.misting:
        return Icons.grain;
      case PlantAction.cleaningLeaves:
        return Icons.cleaning_services;
      case PlantAction.pestControl:
        return Icons.bug_report;
      case PlantAction.staking:
        return Icons.support;
      case PlantAction.lightAdjustment:
        return Icons.wb_sunny;
      case PlantAction.temperatureAdjustment:
        return Icons.thermostat;
    }
  }

  Color get color {
    switch (this) {
      case PlantAction.watering:
        return Colors.blue;
      case PlantAction.fertilizing:
        return Colors.green;
      case PlantAction.pruning:
        return Colors.brown;
      case PlantAction.repotting:
        return Colors.orange;
      case PlantAction.misting:
        return Colors.cyan;
      case PlantAction.cleaningLeaves:
        return Colors.teal;
      case PlantAction.pestControl:
        return Colors.red;
      case PlantAction.staking:
        return Colors.purple;
      case PlantAction.lightAdjustment:
        return Colors.yellow;
      case PlantAction.temperatureAdjustment:
        return Colors.pink;
    }
  }
}

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
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

class EditableBlock extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const EditableBlock({
    super.key,
    required this.title,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<EditableBlock> createState() => _EditableBlockState();
}

class _EditableBlockState extends State<EditableBlock> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _isEditing
                    ? TextField(
                        controller: widget.controller,
                        autofocus: true,
                        maxLines: null,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            widget.onChanged(), // ⬅️ авто-сохранение
                        onSubmitted: (_) {
                          setState(() => _isEditing = false);
                          widget.onChanged(); // ⬅️ финальное сохранение
                        },
                      )
                    : Text(
                        widget.controller.text.isEmpty
                            ? "Нет текста"
                            : widget.controller.text,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                onPressed: () {
                  setState(() => _isEditing = !_isEditing);
                  if (!_isEditing) {
                    widget
                        .onChanged(); // ⬅️ сохраним при выходе из режима редактирования
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  final ImagePicker _picker = ImagePicker();

  final List<XFile> _images = [];
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _careController;
  late TextEditingController _tipsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _descriptionController = TextEditingController(
      text: widget.plant.description,
    );
    _careController = TextEditingController(
      text: widget.plant.careInstructions,
    );
    _tipsController = TextEditingController(text: widget.plant.careTips);

    if (widget.plant.imagePaths.isNotEmpty) {
      for (var path in widget.plant.imagePaths) {
        if (kIsWeb) {
          // 🌐 Web — просто добавляем путь
          _images.add(XFile(path));
        } else {
          // 📱 Мобильные платформы — проверяем реальный файл
          final file = io.File(path);
          if (file.existsSync()) {
            _images.add(XFile(file.path));
          }
        }
      }
    }
  }

  Future<void> _savePlant() async {
    // 1. Проверяем, вошел ли пользователь в систему
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: Пользователь не авторизован')),
      );
      return;
    }

    widget.plant.name = _nameController.text;
    widget.plant.description = _descriptionController.text;
    widget.plant.careInstructions = _careController.text;
    widget.plant.careTips = _tipsController.text;

    // 🔹 Загружаем изображения в Firebase Storage
    List<String> uploadedUrls = [];
    for (var img in _images) {
      if (img.path.startsWith('http')) {
        uploadedUrls.add(img.path);
      } else {
        // Сохраняем фото в папку пользователя: plants/{userId}/{plantId}/...
        final ref = FirebaseStorage.instance.ref().child(
          'plants/${user.uid}/${widget.plant.id}/${DateTime.now().millisecondsSinceEpoch}',
        );

        if (kIsWeb) {
          final bytes = await img.readAsBytes();
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          final file = io.File(img.path);
          if (!file.existsSync()) continue;
          await ref.putFile(file);
        }
        final url = await ref.getDownloadURL();
        uploadedUrls.add(url);
      }
    }

    widget.plant.imagePaths = uploadedUrls;

    // 🔹 Сохраняем локально через SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final plantsJson = prefs.getStringList('plants') ?? [];
    List<Plant> plants = plantsJson
        .map((e) => Plant.fromJson(jsonDecode(e)))
        .toList();
    final index = plants.indexWhere((p) => p.id == widget.plant.id);
    if (index >= 0) {
      plants[index] = widget.plant;
    } else {
      plants.add(widget.plant);
    }
    await prefs.setStringList(
      'plants',
      plants.map((p) => jsonEncode(p.toJson())).toList(),
    );

    // 🔹 Сохраняем в Firebase Firestore (СВЯЗАННАЯ СТРУКТУРУРА) 🔥
    await FirebaseFirestore.instance
        .collection('users') // Коллекция пользователей
        .doc(user.uid) // ID конкретного пользователя
        .collection('plants') // Подколлекция его растений
        .doc(widget.plant.id) // ID растения
        .set(widget.plant.toJson());

    if (!mounted) return;
    Navigator.pop(context, widget.plant);
  }

  Future<void> _savePlantsSilent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔹 Сохраняем локально
    final prefs = await SharedPreferences.getInstance();
    final plantsJson = prefs.getStringList('plants') ?? [];
    List<Plant> plants = plantsJson
        .map((e) => Plant.fromJson(jsonDecode(e)))
        .toList();
    final index = plants.indexWhere((p) => p.id == widget.plant.id);
    if (index >= 0) {
      plants[index] = widget.plant;
    } else {
      plants.add(widget.plant);
    }
    await prefs.setStringList(
      'plants',
      plants.map((p) => jsonEncode(p.toJson())).toList(),
    );

    // 🔹 Сохраняем в Firebase Firestore (СВЯЗАННАЯ СТРУКТУРУРА) 🔥
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(widget.plant.id)
        .set(widget.plant.toJson());
  }

  List<Widget> _getEventIcons(DateTime day) {
    List<Widget> icons = [];
    if (widget.plant.wateringDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.water_drop, color: Colors.blue, size: 16));
    }
    if (widget.plant.fertilizingDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.local_florist, color: Colors.green, size: 16));
    }
    if (widget.plant.pruningDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.content_cut, color: Colors.brown, size: 16));
    }
    if (widget.plant.repottingDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.podcasts, color: Colors.orange, size: 16));
    }
    if (widget.plant.mistingDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.grain, color: Colors.cyan, size: 16));
    }
    if (widget.plant.cleaningLeavesDates.any((d) => isSameDay(d, day))) {
      icons.add(
        const Icon(Icons.cleaning_services, color: Colors.teal, size: 16),
      );
    }
    if (widget.plant.pestControlDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.bug_report, color: Colors.red, size: 16));
    }
    if (widget.plant.stakingDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.support, color: Colors.purple, size: 16));
    }
    if (widget.plant.lightAdjustmentDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.wb_sunny, color: Colors.yellow, size: 16));
    }
    if (widget.plant.temperatureAdjustmentDates.any((d) => isSameDay(d, day))) {
      icons.add(const Icon(Icons.thermostat, color: Colors.pink, size: 16));
    }
    if (icons.length > 2) {
      return [
        icons[0],
        icons[1],
        const Text(
          '...',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ];
    }
    return icons;
  }

  // 🌐 WEB FIX: уведомления безопасно отключены для веб
  void _addAction(DateTime dateTime, PlantAction action) async {
    setState(() {
      switch (action) {
        case PlantAction.watering:
          widget.plant.wateringDates.add(dateTime);
          break;
        case PlantAction.fertilizing:
          widget.plant.fertilizingDates.add(dateTime);
          break;
        case PlantAction.pruning:
          widget.plant.pruningDates.add(dateTime);
          break;
        case PlantAction.repotting:
          widget.plant.repottingDates.add(dateTime);
          break;
        case PlantAction.misting:
          widget.plant.mistingDates.add(dateTime);
          break;
        case PlantAction.cleaningLeaves:
          widget.plant.cleaningLeavesDates.add(dateTime);
          break;
        case PlantAction.pestControl:
          widget.plant.pestControlDates.add(dateTime);
          break;
        case PlantAction.staking:
          widget.plant.stakingDates.add(dateTime);
          break;
        case PlantAction.lightAdjustment:
          widget.plant.lightAdjustmentDates.add(dateTime);
          break;
        case PlantAction.temperatureAdjustment:
          widget.plant.temperatureAdjustmentDates.add(dateTime);
          break;
      }
    });

    await _savePlantsSilent();

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ Действие '${action.name}' добавлено (${dateTime.day}.${dateTime.month})",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final title = "Напоминание: ${action.name.toLowerCase()}";
      final body =
          "Пора выполнить действие '${action.name}' для растения '${widget.plant.name}'.";
      await NotificationService().scheduleNotification(
        title: title,
        body: body,
        scheduledDate: dateTime,
      );
    }
  }

  void _showDayActions(DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final List<Widget> actionWidgets = [];

          for (var action in PlantAction.values) {
            List<DateTime> dates;
            switch (action) {
              case PlantAction.watering:
                dates = widget.plant.wateringDates;
                break;
              case PlantAction.fertilizing:
                dates = widget.plant.fertilizingDates;
                break;
              case PlantAction.pruning:
                dates = widget.plant.pruningDates;
                break;
              case PlantAction.repotting:
                dates = widget.plant.repottingDates;
                break;
              case PlantAction.misting:
                dates = widget.plant.mistingDates;
                break;
              case PlantAction.cleaningLeaves:
                dates = widget.plant.cleaningLeavesDates;
                break;
              case PlantAction.pestControl:
                dates = widget.plant.pestControlDates;
                break;
              case PlantAction.staking:
                dates = widget.plant.stakingDates;
                break;
              case PlantAction.lightAdjustment:
                dates = widget.plant.lightAdjustmentDates;
                break;
              case PlantAction.temperatureAdjustment:
                dates = widget.plant.temperatureAdjustmentDates;
                break;
            }

            final dayDates = dates.where((d) => isSameDay(d, day)).toList();

            for (var d in dayDates) {
              final repeat = 1;
              actionWidgets.add(
                ListTile(
                  leading: Icon(action.icon, color: action.color),
                  title: Text(
                    "${action.name} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}"
                    "${repeat > 1 ? " (повтор каждые $repeat дн.)" : ""}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setModalState(() {
                        dates.remove(d);
                      });
                    },
                  ),
                ),
              );
            }
          }

          return GlobalSafeArea(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Действия на ${day.day}.${day.month}.${day.year}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ...actionWidgets,
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Добавить новое действие"),
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddAction(day);
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
        },
      ),
    );
  }

  void _showAddAction(DateTime day) {
    PlantAction? selectedAction;
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final TextEditingController repeatController = TextEditingController(
      text: "1",
    );
    bool noRepeat = false;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Добавить действие",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                DropdownButton<PlantAction>(
                  value: selectedAction,
                  hint: const Text("Выберите действие"),
                  isExpanded: true,
                  items: PlantAction.values.map((action) {
                    return DropdownMenuItem(
                      value: action,
                      child: Row(
                        children: [
                          Icon(action.icon, color: action.color),
                          const SizedBox(width: 8),
                          Text(action.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (action) {
                    setModalState(() => selectedAction = action);
                  },
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Время: "),
                    TextButton(
                      child: Text(
                        "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: noRepeat,
                      onChanged: (val) {
                        setModalState(() => noRepeat = val ?? false);
                      },
                    ),
                    const Text("Не повторять"),
                  ],
                ),
                if (!noRepeat)
                  Row(
                    children: [
                      const Text("Повторять раз в "),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: repeatController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("дней"),
                    ],
                  ),

                const SizedBox(height: 24),

                Center(
                  child: ElevatedButton(
                    onPressed: selectedAction == null
                        ? null
                        : () {
                            int repeatDays = noRepeat
                                ? 0
                                : int.tryParse(repeatController.text) ?? 1;
                            DateTime taskDate = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );

                            if (noRepeat) {
                              _addAction(taskDate, selectedAction!);
                            } else {
                              for (int i = 0; i < 365; i += repeatDays) {
                                final repeatedDate = taskDate.add(
                                  Duration(days: i),
                                );
                                _addAction(repeatedDate, selectedAction!);
                              }
                            }

                            Navigator.pop(context);
                            _showDayActions(day); // обновляем список действий
                          },
                    child: const Text("Добавить"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🌐 WEB FIX: выбор изображения без File
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      // Веб возвращает blob URL, мобильный — путь к файлу
      final imagePath = kIsWeb ? picked.path : picked.path;
      _images.add(picked);
      widget.plant.imagePaths.add(imagePath);
    });

    await _savePlantsSilent();
  }

  Widget _buildImageCarousel(double height) {
    final PageController pageController = PageController();
    int currentIndex = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        final hasImages = widget.plant.imagePaths.isNotEmpty;

        final imageWidgets = hasImages
            ? widget.plant.imagePaths.map((path) {
                if (kIsWeb) {
                  // 🌐 Web — blob:, data:, http: или base64 URL
                  return Image.network(
                    path,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 64,
                      ),
                    ),
                  );
                } else {
                  // 📱 Mobile — локальные файлы
                  final file = io.File(path);
                  if (!file.existsSync()) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 64,
                      ),
                    );
                  }
                  return Image.file(
                    file,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    width: double.infinity,
                    height: double.infinity,
                  );
                }
              }).toList()
            : [
                const Center(
                  child: Icon(Icons.image, size: 80, color: Colors.grey),
                ),
              ];

        return Column(
          children: [
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  PageView(
                    controller: pageController,
                    onPageChanged: (index) =>
                        setState(() => currentIndex = index),
                    children: imageWidgets,
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: FloatingActionButton(
                      heroTag: "gallery_btn",
                      mini: true,
                      backgroundColor: Colors.green,
                      onPressed: () => _pickImage(ImageSource.gallery),
                      child: const Icon(Icons.photo_library),
                    ),
                  ),
                  if (!kIsWeb) // 🌐 Камера недоступна на Web
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: FloatingActionButton(
                        heroTag: "camera_btn",
                        mini: true,
                        backgroundColor: Colors.blue,
                        onPressed: () => _pickImage(ImageSource.camera),
                        child: const Icon(Icons.camera_alt),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (hasImages)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.plant.imagePaths.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentIndex == index ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildConditionRow() {
    String getConditionImage(int condition) {
      if (condition < 0) return 'assets/images/question.png';
      if (condition <= 30) return 'assets/images/0.png';
      if (condition <= 50) return 'assets/images/30.png';
      if (condition <= 70) return 'assets/images/70.png';
      return 'assets/images/100.png';
    }

    // Универсальная версия: принимает File, XFile или String (путь/blob)
    Future<void> _evaluateConditionWithLoading([dynamic image]) async {
      bool isDialogOpen = true;
      Timer? timer;

      // Показываем диалог с анимацией точек (как в оригинале)
      final dialogFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String dots = '';
          return StatefulBuilder(
            builder: (dialogContext, innerSetState) {
              if (timer == null) {
                timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
                  if (!isDialogOpen) {
                    timer?.cancel();
                    return;
                  }
                  try {
                    innerSetState(() {
                      dots = dots.length < 3 ? dots + '.' : '';
                    });
                  } catch (_) {}
                });
              }

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
                          'assets/images/loading_1.png',
                          width: 250,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Рассматриваем ваше растение',
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

      // Убедимся, что таймер отменится когда диалог закроется
      dialogFuture.whenComplete(() {
        isDialogOpen = false;
        timer?.cancel();
        timer = null;
      });

      try {
        // 1) Получаем строковый путь из входного параметра (поддерживаем File, XFile, String)
        String? incomingPath;
        try {
          if (image == null) {
            incomingPath = null;
          } else if (image is String) {
            incomingPath = image as String;
          } else {
            // Если это File (dart:io) или XFile (image_picker), оба имеют .path
            final p = (image as dynamic).path;
            if (p is String && p.isNotEmpty) incomingPath = p;
          }
        } catch (e) {
          incomingPath = null;
        }

        // 2) Если путь валидный — добавим в plant.imagePaths (без дублирования)
        if (incomingPath != null && incomingPath.isNotEmpty) {
          if (widget.plant.imagePaths.isEmpty ||
              widget.plant.imagePaths.last != incomingPath) {
            widget.plant.imagePaths.add(incomingPath);
          }
        }

        // 3) Вызов сервиса анализа состояния (как в оригинале)
        final updatedPlant = await ConditionService.evaluateAndSaveCondition(
          plant: widget.plant,
        );

        if (!mounted) return;

        // 4) Обновляем состояние UI
        setState(() {
          widget.plant.condition = updatedPlant.condition;
        });

        // 5) Сохраняем локально
        await _savePlantsSilent();

        if (!mounted) return;

        // 6) Показываем результат
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🌿 Состояние растения: ${updatedPlant.condition} из 100',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e, stack) {
        debugPrint("⚠️ Ошибка при анализе состояния растения: $e");
        debugPrintStack(stackTrace: stack);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Ошибка при анализе состояния: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        // 7) Закрываем диалог и останавливаем таймер
        isDialogOpen = false;
        timer?.cancel();
        timer = null;
        if (mounted) {
          try {
            Navigator.of(context).pop();
          } catch (_) {}
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (context) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      return SizedBox(
                        height: screenHeight * 0.5,
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!kIsWeb) // 🚫 Камера не работает на Web
                                ListTile(
                                  leading: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.green,
                                  ),
                                  title: const Text('Сделать новое фото'),
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? photo = await picker.pickImage(
                                      source: ImageSource.camera,
                                      maxWidth: 1024,
                                    );
                                    if (photo != null) {
                                      setState(() {
                                        widget.plant.imagePaths.add(photo.path);
                                      });

                                      // ✅ Передаём напрямую XFile
                                      await _evaluateConditionWithLoading(
                                        photo,
                                      );
                                    }
                                  },
                                ),
                              if (!kIsWeb) const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.image,
                                  color: Colors.lightGreen,
                                ),
                                title: const Text('Отправить последнее фото'),
                                onTap: () async {
                                  Navigator.of(context).pop();

                                  if (widget.plant.imagePaths.isNotEmpty) {
                                    final lastPath =
                                        widget.plant.imagePaths.last;

                                    // ✅ Передаём путь (String), а не File()
                                    await _evaluateConditionWithLoading(
                                      lastPath,
                                    );
                                  } else {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '⚠️ У растения нет сохранённых фото',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Image.asset(
                        'assets/images/condition.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Оценить состояние',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Нажмите, чтобы обновить',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 2,
              height: 180,
              color: Colors.green,
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Текущее состояние:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: SizedBox(
                      key: ValueKey(widget.plant.condition),
                      width: 195,
                      height: 195,
                      child: Image.asset(
                        getConditionImage(widget.plant.condition),
                        fit: BoxFit.contain,
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton.icon(
              onPressed: _savePlant,
              icon: const Icon(Icons.save),
              label: const Text("Сохранить"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildImageCarousel(screenHeight * 0.33),
                    const SizedBox(height: 12),
                    _buildConditionRow(),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: ExpansionTile(
                        title: const Text(
                          "Сведения о растении",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        collapsedBackgroundColor: Colors.white.withOpacity(0.8),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        childrenPadding: const EdgeInsets.all(8),
                        children: [
                          EditableBlock(
                            title: "Название",
                            controller: _nameController,
                            onChanged: () {
                              widget.plant.name = _nameController.text;
                              _savePlantsSilent();
                            },
                          ),
                          const SizedBox(height: 8),
                          EditableBlock(
                            title: "Описание",
                            controller: _descriptionController,
                            onChanged: () {
                              widget.plant.description =
                                  _descriptionController.text;
                              _savePlantsSilent();
                            },
                          ),
                          const SizedBox(height: 8),
                          EditableBlock(
                            title: "Уход",
                            controller: _careController,
                            onChanged: () {
                              widget.plant.careInstructions =
                                  _careController.text;
                              _savePlantsSilent();
                            },
                          ),
                          const SizedBox(height: 8),
                          EditableBlock(
                            title: "Советы",
                            controller: _tipsController,
                            onChanged: () {
                              widget.plant.careTips = _tipsController.text;
                              _savePlantsSilent();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
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
                          eventLoader: (day) => _getEventIcons(day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() => _focusedDay = focusedDay);
                            _showDayActions(selectedDay);
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              final icons = _getEventIcons(day);
                              if (icons.isEmpty) return const SizedBox();
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: icons.map((icon) {
                                  if (icon is Icon) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2.0,
                                      ),
                                      child: Icon(
                                        icon.icon,
                                        color: icon.color,
                                        size: 16,
                                      ),
                                    );
                                  }
                                  return icon;
                                }).toList(),
                              );
                            },
                          ),
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
