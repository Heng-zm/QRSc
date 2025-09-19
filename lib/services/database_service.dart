import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ScanResult {
  final int? id;
  final String content;
  final String format;
  final DateTime timestamp;
  final String? title;
  final bool isFavorite;

  ScanResult({
    this.id,
    required this.content,
    required this.format,
    required this.timestamp,
    this.title,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'format': format,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'title': title,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      id: map['id'],
      content: map['content'],
      format: map['format'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      title: map['title'],
      isFavorite: map['isFavorite'] == 1,
    );
  }

  ScanResult copyWith({
    int? id,
    String? content,
    String? format,
    DateTime? timestamp,
    String? title,
    bool? isFavorite,
  }) {
    return ScanResult(
      id: id ?? this.id,
      content: content ?? this.content,
      format: format ?? this.format,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  bool _isInitializing = false;
  final List<Completer<Database>> _initCompleters = [];

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    // Handle concurrent initialization requests
    if (_isInitializing) {
      final completer = Completer<Database>();
      _initCompleters.add(completer);
      return completer.future;
    }
    
    _isInitializing = true;
    try {
      _database = await _initDatabase();
      
      // Complete all waiting requests
      for (final completer in _initCompleters) {
        if (!completer.isCompleted) {
          completer.complete(_database!);
        }
      }
      _initCompleters.clear();
      
      return _database!;
    } catch (e) {
      // Complete all waiting requests with error
      for (final completer in _initCompleters) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
      _initCompleters.clear();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on web');
    }

    String path = join(await getDatabasesPath(), 'scan_history.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scan_results(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        format TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        title TEXT,
        isFavorite INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE scan_results ADD COLUMN title TEXT');
      await db.execute('ALTER TABLE scan_results ADD COLUMN isFavorite INTEGER DEFAULT 0');
    }
  }

  Future<int> insertScanResult(ScanResult result) async {
    if (kIsWeb) return 0; // Fallback for web
    
    try {
      final db = await database;
      
      // Check for duplicates based on content and timestamp
      final duplicates = await db.query(
        'scan_results',
        where: 'content = ? AND timestamp = ?',
        whereArgs: [result.content, result.timestamp.millisecondsSinceEpoch],
        limit: 1,
      );
      
      if (duplicates.isNotEmpty) {
        debugPrint('Duplicate scan result found, not inserting');
        return duplicates.first['id'] as int;
      }
      
      return await db.insert(
        'scan_results', 
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      debugPrint('Error inserting scan result: $e');
      debugPrint('Stack trace: $stackTrace');
      return 0;
    }
  }

  Future<List<ScanResult>> getAllScanResults({int? limit, int? offset}) async {
    if (kIsWeb) return []; // Fallback for web
    
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scan_results',
        orderBy: 'timestamp DESC',
        limit: limit ?? 100, // Default limit to prevent memory issues
        offset: offset ?? 0,
      );
      
      return List.generate(maps.length, (i) {
        try {
          return ScanResult.fromMap(maps[i]);
        } catch (e) {
          debugPrint('Error parsing scan result at index $i: $e');
          return null;
        }
      }).whereType<ScanResult>().toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting scan results: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<ScanResult>> getFavoriteScanResults() async {
    if (kIsWeb) return []; // Fallback for web
    
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scan_results',
        where: 'isFavorite = ?',
        whereArgs: [1],
        orderBy: 'timestamp DESC',
      );
      return List.generate(maps.length, (i) => ScanResult.fromMap(maps[i]));
    } catch (e) {
      print('Error getting favorite scan results: $e');
      return [];
    }
  }

  Future<int> updateScanResult(ScanResult result) async {
    if (kIsWeb) return 0; // Fallback for web
    
    try {
      final db = await database;
      return await db.update(
        'scan_results',
        result.toMap(),
        where: 'id = ?',
        whereArgs: [result.id],
      );
    } catch (e) {
      print('Error updating scan result: $e');
      return 0;
    }
  }

  Future<int> deleteScanResult(int id) async {
    if (kIsWeb) return 0; // Fallback for web
    
    try {
      final db = await database;
      return await db.delete(
        'scan_results',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting scan result: $e');
      return 0;
    }
  }

  Future<int> clearAllScanResults() async {
    if (kIsWeb) return 0; // Fallback for web
    
    try {
      final db = await database;
      return await db.delete('scan_results');
    } catch (e) {
      print('Error clearing scan results: $e');
      return 0;
    }
  }

  Future<List<ScanResult>> searchScanResults(String query) async {
    if (kIsWeb) return []; // Fallback for web
    
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scan_results',
        where: 'content LIKE ? OR title LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'timestamp DESC',
      );
      return List.generate(maps.length, (i) => ScanResult.fromMap(maps[i]));
    } catch (e) {
      print('Error searching scan results: $e');
      return [];
    }
  }

  // Database maintenance methods
  Future<void> vacuum() async {
    if (kIsWeb) return;
    
    try {
      final db = await database;
      await db.execute('VACUUM');
      debugPrint('Database vacuum completed');
    } catch (e, stackTrace) {
      debugPrint('Error running vacuum: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  Future<void> cleanupOldResults({int daysOld = 90}) async {
    if (kIsWeb) return;
    
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final deletedCount = await db.delete(
        'scan_results',
        where: 'timestamp < ? AND isFavorite = 0',
        whereArgs: [cutoffDate.millisecondsSinceEpoch],
      );
      
      debugPrint('Cleaned up $deletedCount old scan results');
      
      // Run vacuum after cleanup
      if (deletedCount > 0) {
        await vacuum();
      }
    } catch (e, stackTrace) {
      debugPrint('Error cleaning up old results: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  Future<Map<String, int>> getStatistics() async {
    if (kIsWeb) return {'total': 0, 'favorites': 0, 'thisWeek': 0};
    
    try {
      final db = await database;
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Get total count
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM scan_results');
      final total = (totalResult.first['count'] as int?) ?? 0;
      
      // Get favorites count
      final favoritesResult = await db.rawQuery('SELECT COUNT(*) as count FROM scan_results WHERE isFavorite = 1');
      final favorites = (favoritesResult.first['count'] as int?) ?? 0;
      
      // Get this week's count
      final weekResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scan_results WHERE timestamp >= ?',
        [weekAgo.millisecondsSinceEpoch],
      );
      final thisWeek = (weekResult.first['count'] as int?) ?? 0;
      
      return {
        'total': total,
        'favorites': favorites,
        'thisWeek': thisWeek,
      };
    } catch (e, stackTrace) {
      debugPrint('Error getting statistics: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'total': 0, 'favorites': 0, 'thisWeek': 0};
    }
  }

  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Clear any pending completers
      for (final completer in _initCompleters) {
        if (!completer.isCompleted) {
          completer.completeError('Database service closed');
        }
      }
      _initCompleters.clear();
      _isInitializing = false;
    } catch (e, stackTrace) {
      debugPrint('Error closing database: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
