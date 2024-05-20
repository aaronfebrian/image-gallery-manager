import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_manager/screens/album_detail_screen.dart';
import 'package:image_manager/utils/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _albumsFuture;
  PageController _pageController =
      PageController(initialPage: 0, viewportFraction: 1);

  @override
  void initState() {
    super.initState();
    _albumsFuture = _getAlbums();

    // Memulai animasi otomatis pada banner
    _startBannerAutoScroll();
  }

  void _startBannerAutoScroll() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_pageController.hasClients) {
        final int nextPage = (_pageController.page?.toInt() ?? 0) + 1;
        if (nextPage == 2) {
          _pageController.animateToPage(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        } else {
          _pageController.animateToPage(nextPage,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        }
        _startBannerAutoScroll();
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getAlbums() async {
    DatabaseHelper databaseHelper = DatabaseHelper();
    return databaseHelper.getAlbumsOrderedByTimestamp();
  }

  Future<String?> _getLatestImageForAlbum(String albumName) async {
    DatabaseHelper databaseHelper = DatabaseHelper();
    List<Map<String, dynamic>> photos =
        await databaseHelper.getPhotosForAlbum(albumName);
    if (photos.isNotEmpty) {
      return photos.last['url'];
    }
    return null;
  }

  void _deleteAlbum(int albumId) async {
    DatabaseHelper databaseHelper = DatabaseHelper();
    await databaseHelper.deleteAlbum(albumId);
    setState(() {
      _albumsFuture = _getAlbums();
    });
  }

  void _updateAlbums() async {
    setState(() {
      _albumsFuture = _getAlbums();
    });
  }

  Future<void> _editAlbumName(int albumId, String currentName) async {
    TextEditingController controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Album Name"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "New Album Name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  DatabaseHelper databaseHelper = DatabaseHelper();
                  await databaseHelper.updateAlbumName(albumId, newName);
                  setState(() {
                    _albumsFuture = _getAlbums();
                  });
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _deleteAlbumConfirmation(int albumId, String albumName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Album"),
          content:
              Text("Are you sure you want to delete the album '$albumName'?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deleteAlbum(albumId);
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

  void _showOptions(Map<String, dynamic> album) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showAlbumDetails(album);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _editAlbumName(album['id'], album['name']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteAlbumConfirmation(album['id'], album['name']);
              },
            ),
          ],
        );
      },
    );
  }

  void _showAlbumDetails(Map<String, dynamic> album) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Album Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Album Name: ${album['name']}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _formatTimestamp(album['timestamp']),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(int timestamp) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    return 'Created at: $formattedDate';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1D1D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(),
          AppBar(
            title: const Text(
              'My Albums',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 30,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _albumsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                } else {
                  List<Map<String, dynamic>> albums = snapshot.data ?? [];
                  if (albums.isEmpty) {
                    return Center(
                      child: Text(
                        'No albums available',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    );
                  }
                  return GridView.extent(
                    maxCrossAxisExtent: 200,
                    padding: const EdgeInsets.all(16),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: albums.map((album) {
                      return FutureBuilder<String?>(
                        future: _getLatestImageForAlbum(album['name']),
                        builder: (context, imageSnapshot) {
                          String? imageUrl = imageSnapshot.data;
                          return InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlbumDetailScreen(
                                    albumName: album['name'],
                                    onUpdate: _updateAlbums,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Container(
                                    color: Colors.grey[300],
                                    child: imageUrl != null
                                        ? AspectRatio(
                                            aspectRatio: 1,
                                            child: Image.file(File(imageUrl),
                                                fit: BoxFit.cover),
                                          )
                                        : const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.folder,
                                                  size: 60,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Empty',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      color: Colors.black54,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            album['name'],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: GestureDetector(
                                      onTap: () {
                                        _showOptions(album);
                                      },
                                      child: Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.more_vert,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/add_album').then((value) {
            if (value == true) {
              _updateAlbums();
            }
          });
        },
        label: const Text("Add Album", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: const Color(0xFFF59115),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBanner() {
    return SizedBox(
      height: 200,
      child: PageView(
        controller: _pageController,
        children: [
          Image.asset('assets/banner.png', fit: BoxFit.cover),
          Image.asset('assets/banner2.png', fit: BoxFit.cover),
        ],
        onPageChanged: (index) {
          setState(() {
            // Update state jika halaman berubah
          });
        },
      ),
    );
  }
}
