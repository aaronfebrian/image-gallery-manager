import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_manager/utils/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';

class ImageDetailScreen extends StatefulWidget {
  final File imageFile;
  final String albumId;
  final Function onDelete;
  final Function onUpdate;

  const ImageDetailScreen({
    super.key,
    required this.imageFile,
    required this.albumId,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ImageDetailScreenState createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _showImageDetail = false;
  // ignore: prefer_final_fields
  double _rotationAngle = 0;
  String _croppedImagePath = '';

  void _toggleImageDetail() {
    setState(() {
      _showImageDetail = !_showImageDetail;
    });
  }

  Future<void> _saveRotation(double angle) async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // ignore: avoid_print
      print("Error getting SharedPreferences: $e");
      return;
    }
    await prefs.setDouble('rotationAngle', angle);
  }

  Future<String> _rotateImageFile(File imageFile, double angle) async {
    img.Image? image = img.decodeImage(await imageFile.readAsBytes());
    if (image != null) {
      img.Image rotatedImage = img.copyRotate(image, angle.toInt());
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String rotatedImagePath =
          '$tempPath/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(rotatedImagePath).writeAsBytesSync(img.encodeJpg(rotatedImage));
      return rotatedImagePath;
    } else {
      return imageFile.path;
    }
  }

  Future<void> _deleteImage(BuildContext context) async {
    await DatabaseHelper().deletePhotoFromAlbum(widget.imageFile.path);
    await widget.imageFile.delete();
    widget.onDelete();
    // ignore: use_build_context_synchronously
    Navigator.pop(context, true);
  }

  void _updateImage(String croppedImagePath) async {
    if (croppedImagePath.isNotEmpty) {
      setState(() {
        _croppedImagePath = croppedImagePath;
      });

      File croppedImageFile = File(croppedImagePath);
      String rotatedImageUrl =
          await _rotateImageFile(croppedImageFile, _rotationAngle);

      int result = await DatabaseHelper()
          .insertPhotoToAlbum(widget.albumId, rotatedImageUrl);
      if (result == 0) {
        widget.onUpdate();
      } else if (result == -1) {
      } else if (result == -2) {}

      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (context) => ImageDetailScreen(
            imageFile: croppedImageFile,
            albumId: widget.albumId,
            onDelete: () {
              widget.onDelete();
            },
            onUpdate: widget.onUpdate,
          ),
        ),
      );
    }
  }

  Future<void> _cropImage(BuildContext context) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: widget.imageFile.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        CropAspectRatioPreset.ratio3x2,
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9
      ],
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: const Color(0xFF1D1D1D),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Edit Image',
        ),
        WebUiSettings(
          context: context,
        ),
      ],
    );

    if (croppedFile != null) {
      _updateImage(croppedFile.path);
    }
  }

  @override
  void initState() {
    super.initState();
    // Mengambil sudut rotasi yang disimpan
    // _loadRotation();
  }

  @override
  void dispose() {
    _saveRotation(_rotationAngle);
    super.dispose();
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
          title: const Padding(
            padding: EdgeInsets.only(top: 20),
          ),
          backgroundColor: const Color(0xFF1D1D1D),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 90,
            child: Center(
              child: Image.file(File(_croppedImagePath.isNotEmpty
                  ? _croppedImagePath
                  : widget.imageFile.path)),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_showImageDetail) {
                _toggleImageDetail();
              }
            },
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showImageDetail ? 0.5 : 0.0,
              child: Container(
                color: Colors.black,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    IconButton(
                      onPressed: () {
                        _cropImage(context);
                      },
                      icon: const Icon(
                        Icons.edit,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(width: 16), // Ubah nilai dari 24 menjadi 16
                Column(
                  children: [
                    IconButton(
                      onPressed: () {
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
                                    _deleteImage(context);
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
                      icon: const Icon(
                        Icons.delete,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Delete', style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(width: 16), // Ubah nilai dari 24 menjadi 16
                Column(
                  children: [
                    PopupMenuButton(
                      itemBuilder: (BuildContext context) {
                        return [
                          const PopupMenuItem(
                            value: 'detail',
                            child: Text('Details'),
                          ),
                        ];
                      },
                      onSelected: (value) {
                        if (value == 'detail') {
                          _toggleImageDetail();
                        }
                      },
                      icon: const Icon(
                        Icons.more_vert,
                        size: 35,
                        color: Colors.white,
                      ),
                      offset: const Offset(0, -70),
                    ),
                    const SizedBox(height: 4),
                    const Text('More', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showImageDetail ? 0 : -300,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<Map<String, dynamic>>(
                        future: DatabaseHelper()
                            .getPhotoInfo(widget.imageFile.path),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          } else {
                            final info = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: info.entries.map((entry) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.key,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(entry.value.toString()),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1D1D1D),
    );
  }
}
