import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image/image.dart' as img;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();
  static const String tableAlbums = 'albums';
  static const String columnTimestamp = 'timestamp';

  static DatabaseHelper get instance => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'databaseimager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE albums(
            id INTEGER PRIMARY KEY,
            name TEXT,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE photos(
            id INTEGER PRIMARY KEY,
            album_id INTEGER,
            url TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertAlbum(String name) async {
    final db = await database;
    int timestamp = DateTime.now()
        .millisecondsSinceEpoch;
    return await db.insert(
      'albums',
      {
        'name': name,
        'timestamp': timestamp
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertPhoto(int albumId, String url) async {
    final db = await database;

    List<Map<String, dynamic>> existingPhotos = await db.query(
      'photos',
      where: 'album_id = ? AND url = ?',
      whereArgs: [albumId, url],
    );

    if (existingPhotos.isNotEmpty) {
      return -1;
    }

    int timestamp =
        DateTime.now().millisecondsSinceEpoch; // mengambil timestamp saat upload image
    return await db.insert(
      'photos',
      {
        'album_id': albumId,
        'url': url,
        'timestamp': timestamp // stored timestamp
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAlbums() async {
    final db = await database;
    return await db.query('albums');
  }

  Future<List<Map<String, dynamic>>> getPhotos(int albumId) async {
    final db = await database;
    return await db
        .query('photos', where: 'album_id = ?', whereArgs: [albumId]);
  }

  Future<int> updatePhoto(String url, String newUrl) async {
    final db = await database;
    return await db.update(
      'photos',
      {'url': newUrl},
      where: 'url = ?',
      whereArgs: [url],
    );
  }

  Future<int> deletePhoto(int id) async {
    final db = await database;
    return await db.delete(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertPhotoToAlbum(String albumName, String url) async {
    final db = await database;
    List<Map<String, dynamic>> albums = await db.query(
      'albums',
      where: 'name = ?',
      whereArgs: [albumName],
    );
    if (albums.isEmpty) {
      return -1;
    }
    int albumId = albums.first['id'];
    return await db.insert(
      'photos',
      {'album_id': albumId, 'url': url},
    );
  }

  Future<int> deleteAlbum(int albumId) async {
    final db = await database;
    await db.delete('photos', where: 'album_id = ?', whereArgs: [albumId]);
    return await db.delete('albums', where: 'id = ?', whereArgs: [albumId]);
  }

  Future<int> deletePhotoFromAlbum(String photoUrl) async {
    final db = await database;
    return await db.delete(
      'photos',
      where: 'url = ?',
      whereArgs: [photoUrl],
    );
  }

  Future<int> updateAlbumName(int albumId, String newName) async {
    final db = await database;
    return await db.update(
      'albums',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [albumId],
    );
  }

  Future<List<Map<String, dynamic>>> getPhotosForAlbum(String albumName) async {
    final db = await database;
    // Retrieve album id based on albumName
    List<Map<String, dynamic>> albums = await db.query(
      'albums',
      where: 'name = ?',
      whereArgs: [albumName],
    );
    if (albums.isEmpty) {
      return []; // No album found with the given name
    }
    int albumId = albums.first['id'];
    // Retrieve photos for the given albumId
    return await db
        .query('photos', where: 'album_id = ?', whereArgs: [albumId]);
  }

  Future<Map<String, dynamic>> getPhotoInfo(String photoUrl) async {
    // mengambil path file name
    String fileName = basename(photoUrl);
    // mengambil waktu modifikasi
    File file = File(photoUrl);
    DateTime lastModified = await file.lastModified();
    // dimensi image
    img.Image? image = img.decodeImage(await file.readAsBytes());
    int? width = image?.width;
    int? height = image?.height;
    // ukuran image
    int sizeInBytes = await file.length();
    double sizeInKB = sizeInBytes / 1024;
    String size;
    if (sizeInKB > 1024) {
      double sizeInMB = sizeInKB / 1024;
      size = '${sizeInMB.toStringAsFixed(2)} MB';
    } else {
      size = '${sizeInKB.toStringAsFixed(2)} KB';
    }

    return {
      'Name': fileName,
      'Last Modified': lastModified.toString(),
      'Dimensions': '$width x $height',
      'Size': size,
    };
  }

  Future<List<Map<String, dynamic>>> getAlbumsOrderedByTimestamp() async {
    final Database db = await instance.database;
    return await db.query(
      tableAlbums,
      orderBy: '$columnTimestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPhotosForAlbumOrderedByTimestamp(
    String albumName) async {
    final db = await database;
    List<Map<String, dynamic>> albums = await db.query(
      'albums',
      where: 'name = ?',
      whereArgs: [albumName],
    );
    if (albums.isEmpty) {
      return [];
    }
    int albumId = albums.first['id'];
    return await db.query('photos',
        where: 'album_id = ?', whereArgs: [albumId], orderBy: 'timestamp DESC');
  }
}
