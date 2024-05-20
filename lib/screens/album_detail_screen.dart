// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_manager/utils/database_helper.dart';
import 'package:image_manager/screens/image_detail_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final Function onUpdate;
  const AlbumDetailScreen(
      {super.key, required this.albumName, required this.onUpdate});

  @override
  // ignore: library_private_types_in_public_api
  _AlbumDetailScreenState createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<File> _uploadedImages = [];
  bool _isAllSelected = false;

  Future<void> _reloadImages() async {
    await _loadImagesFromAlbumDirectory();
    setState(() {});
  }

  Future<void> _addImage(BuildContext context) async {
    final picker = ImagePicker();
    // ignore: deprecated_member_use
    final pickedImage = await picker.getImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      final imageFile = File(pickedImage.path);
      setState(() {
        _uploadedImages.insert(0, imageFile);
      });
      await _saveImagesToAlbumDirectory(imageFile);
      await _reloadImages();
    }
  }

  Future<void> _deleteImage(File imageFile) async {
    if (!mounted) return;
    if (imageFile.existsSync()) {
      await imageFile.delete();
    } else {
      print("File not found: ${imageFile.path}");
    }
    await DatabaseHelper().deletePhotoFromAlbum(imageFile.path);
    setState(() {
      _uploadedImages.remove(imageFile);
    });
    await _reloadImages();
  }

  Future<void> _deleteAllImages() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete All Images"),
          content: const Text("Are you sure you want to delete all images?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                List<File> copiedImages = List.from(_uploadedImages);
                for (var imageFile in copiedImages) {
                  await _deleteImage(imageFile);
                }
                setState(() {
                  _uploadedImages.clear();
                  _isAllSelected = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveImagesToAlbumDirectory(File image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final albumDir = Directory('${appDir.path}/${widget.albumName}');
    await albumDir.create(recursive: true);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = await image.copy('${albumDir.path}/$fileName');
    await DatabaseHelper()
        .insertPhotoToAlbum(widget.albumName, savedImage.path);
  }

  Future<void> _loadImagesFromAlbumDirectory() async {
    final photos = await DatabaseHelper()
        .getPhotosForAlbumOrderedByTimestamp(widget.albumName);
    List<File> images = [];
    for (final photo in photos.reversed) {
      images.add(File(photo['url']));
    }
    setState(() {
      _uploadedImages = images;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadImagesFromAlbumDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(top: 15, left: 10),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                size: 30,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              widget.albumName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 30,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: const Color(0xFF1D1D1D),
          actions: [
            if (_uploadedImages
                .isNotEmpty) // Menampilkan tombol hanya jika ada gambar di album
              Padding(
                padding: const EdgeInsets.only(top: 15, right: 10),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isAllSelected = !_isAllSelected;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                      _isAllSelected
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.1),
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                  ),
                  child: Text(
                    _isAllSelected ? 'Deselect All' : 'Select All',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: _uploadedImages.isEmpty
          ? Center(
              child: Text(
                "No images uploaded",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            )
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _uploadedImages.length,
              // Inside GridView.builder
              itemBuilder: (context, index) {
                final file = _uploadedImages[index];
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final dynamic result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageDetailScreen(
                              imageFile: file,
                              albumId: widget.albumName,
                              onDelete: () {
                                _deleteImage(file);
                              },
                              onUpdate: widget.onUpdate,
                            ),
                          ),
                        );
                        if (result != null && result is List<String>) {
                          setState(() {
                            _uploadedImages.remove(file);
                            _uploadedImages.add(File(result[0]));
                            _uploadedImages.add(File(result[1]));
                          });
                          widget.onUpdate();
                        }
                      },
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1 / 1,
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (_isAllSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_isAllSelected)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Delete Image"),
                                    content: const Text(
                                        "Are you sure you want to delete this image?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _deleteImage(file);
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      floatingActionButton: _isAllSelected
          ? FloatingActionButton.extended(
              onPressed: _deleteAllImages,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.delete_forever),
              label: const Text("Delete All"),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide.none,
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () => _addImage(context),
              backgroundColor: const Color(0xFFF59115),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text("Add Image"),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide.none,
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      backgroundColor: const Color(0xFF1D1D1D),
    );
  }
}
