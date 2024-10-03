import 'package:sembast/sembast.dart';

class Template {
  Template({required this.y, required this.name, required this.lock});

  final int y;
  final String name;
  final String lock;

  Map<String, Object?> get toSembast => {
        "y": y,
        "name": name,
        "lock": lock,
      };
}

final templatesStore = intMapStoreFactory.store("templates");
