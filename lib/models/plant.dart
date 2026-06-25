class Plant {
  String id; // 🔑 уникальный идентификатор
  String name;
  String description;
  String careInstructions;
  String careTips;
  List<String> imagePaths; // несколько фото вместо одного

  // Новое поле
  int condition; // числовая оценка состояния (-100 по умолчанию)

  // Списки дат для каждого действия
  List<DateTime> wateringDates;
  List<DateTime> fertilizingDates;
  List<DateTime> pruningDates;
  List<DateTime> repottingDates;
  List<DateTime> mistingDates;
  List<DateTime> cleaningLeavesDates;
  List<DateTime> pestControlDates;
  List<DateTime> stakingDates;
  List<DateTime> lightAdjustmentDates;
  List<DateTime> temperatureAdjustmentDates;

  // Списки ID для уведомлений
  List<int> wateringIds;
  List<int> fertilizingIds;
  List<int> pruningIds;
  List<int> repottingIds;
  List<int> mistingIds;
  List<int> cleaningLeavesIds;
  List<int> pestControlIds;
  List<int> stakingIds;
  List<int> lightAdjustmentIds;
  List<int> temperatureAdjustmentIds;

  Plant({
    String? id,
    required this.name,
    required this.description,
    required this.careInstructions,
    required this.careTips,
    this.condition = -100, // по умолчанию растение не оценено
    List<String>? imagePaths,
    List<DateTime>? wateringDates,
    List<DateTime>? fertilizingDates,
    List<DateTime>? pruningDates,
    List<DateTime>? repottingDates,
    List<DateTime>? mistingDates,
    List<DateTime>? cleaningLeavesDates,
    List<DateTime>? pestControlDates,
    List<DateTime>? stakingDates,
    List<DateTime>? lightAdjustmentDates,
    List<DateTime>? temperatureAdjustmentDates,
    List<int>? wateringIds,
    List<int>? fertilizingIds,
    List<int>? pruningIds,
    List<int>? repottingIds,
    List<int>? mistingIds,
    List<int>? cleaningLeavesIds,
    List<int>? pestControlIds,
    List<int>? stakingIds,
    List<int>? lightAdjustmentIds,
    List<int>? temperatureAdjustmentIds,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       imagePaths = imagePaths ?? [],
       wateringDates = wateringDates ?? [],
       fertilizingDates = fertilizingDates ?? [],
       pruningDates = pruningDates ?? [],
       repottingDates = repottingDates ?? [],
       mistingDates = mistingDates ?? [],
       cleaningLeavesDates = cleaningLeavesDates ?? [],
       pestControlDates = pestControlDates ?? [],
       stakingDates = stakingDates ?? [],
       lightAdjustmentDates = lightAdjustmentDates ?? [],
       temperatureAdjustmentDates = temperatureAdjustmentDates ?? [],
       wateringIds = wateringIds ?? [],
       fertilizingIds = fertilizingIds ?? [],
       pruningIds = pruningIds ?? [],
       repottingIds = repottingIds ?? [],
       mistingIds = mistingIds ?? [],
       cleaningLeavesIds = cleaningLeavesIds ?? [],
       pestControlIds = pestControlIds ?? [],
       stakingIds = stakingIds ?? [],
       lightAdjustmentIds = lightAdjustmentIds ?? [],
       temperatureAdjustmentIds = temperatureAdjustmentIds ?? [];

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "description": description,
    "careInstructions": careInstructions,
    "careTips": careTips,
    "condition": condition, // сохраняем состояние
    "imagePaths": imagePaths,
    "wateringDates": wateringDates.map((d) => d.toIso8601String()).toList(),
    "fertilizingDates": fertilizingDates
        .map((d) => d.toIso8601String())
        .toList(),
    "pruningDates": pruningDates.map((d) => d.toIso8601String()).toList(),
    "repottingDates": repottingDates.map((d) => d.toIso8601String()).toList(),
    "mistingDates": mistingDates.map((d) => d.toIso8601String()).toList(),
    "cleaningLeavesDates": cleaningLeavesDates
        .map((d) => d.toIso8601String())
        .toList(),
    "pestControlDates": pestControlDates
        .map((d) => d.toIso8601String())
        .toList(),
    "stakingDates": stakingDates.map((d) => d.toIso8601String()).toList(),
    "lightAdjustmentDates": lightAdjustmentDates
        .map((d) => d.toIso8601String())
        .toList(),
    "temperatureAdjustmentDates": temperatureAdjustmentDates
        .map((d) => d.toIso8601String())
        .toList(),

    // Сохранение ID уведомлений
    "wateringIds": wateringIds,
    "fertilizingIds": fertilizingIds,
    "pruningIds": pruningIds,
    "repottingIds": repottingIds,
    "mistingIds": mistingIds,
    "cleaningLeavesIds": cleaningLeavesIds,
    "pestControlIds": pestControlIds,
    "stakingIds": stakingIds,
    "lightAdjustmentIds": lightAdjustmentIds,
    "temperatureAdjustmentIds": temperatureAdjustmentIds,
  };

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
    id: json["id"],
    name: json["name"] ?? "",
    description: json["description"] ?? "",
    careInstructions: json["careInstructions"] ?? "",
    careTips: json["careTips"] ?? "",
    condition: json["condition"] ?? -100, // восстанавливаем состояние
    imagePaths:
        (json["imagePaths"] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    wateringDates:
        (json["wateringDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    fertilizingDates:
        (json["fertilizingDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    pruningDates:
        (json["pruningDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    repottingDates:
        (json["repottingDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    mistingDates:
        (json["mistingDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    cleaningLeavesDates:
        (json["cleaningLeavesDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    pestControlDates:
        (json["pestControlDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    stakingDates:
        (json["stakingDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    lightAdjustmentDates:
        (json["lightAdjustmentDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],
    temperatureAdjustmentDates:
        (json["temperatureAdjustmentDates"] as List<dynamic>?)
            ?.map((d) => DateTime.parse(d))
            .toList() ??
        [],

    // Восстановление ID уведомлений
    wateringIds:
        (json["wateringIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    fertilizingIds:
        (json["fertilizingIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    pruningIds:
        (json["pruningIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    repottingIds:
        (json["repottingIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    mistingIds:
        (json["mistingIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    cleaningLeavesIds:
        (json["cleaningLeavesIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    pestControlIds:
        (json["pestControlIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    stakingIds:
        (json["stakingIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    lightAdjustmentIds:
        (json["lightAdjustmentIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
    temperatureAdjustmentIds:
        (json["temperatureAdjustmentIds"] as List<dynamic>?)
            ?.map((id) => id as int)
            .toList() ??
        [],
  );
}
