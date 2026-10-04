import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

abstract class SchoolStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

/// Only fictional demo data is cached. Live school records remain server-authorized.
class LocalSchoolStorage implements SchoolStorage {
  Database? _database;
  Future<Database> get database async => _database ??= await openDatabase(
    '${await getDatabasesPath()}/schoolsphere_demo.db',
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE snapshot (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
    ),
  );
  @override
  Future<Map<String, dynamic>?> read() async {
    String? raw;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      raw = (await SharedPreferences.getInstance()).getString(
        'schoolsphere_demo_v1',
      );
    } else {
      final rows = await (await database).query('snapshot', where: 'id = 1');
      raw = rows.isEmpty ? null : rows.first['payload'] as String;
    }
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    final raw = jsonEncode(value);
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      final saved = await (await SharedPreferences.getInstance()).setString(
        'schoolsphere_demo_v1',
        raw,
      );
      if (!saved) throw StateError('Could not save changes to this device.');
    } else {
      await (await database).insert('snapshot', {
        'id': 1,
        'payload': raw,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

class MemorySchoolStorage implements SchoolStorage {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    this.value = jsonDecode(jsonEncode(value));
  }
}
