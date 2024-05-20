import 'package:flutter/material.dart';
import 'package:image_manager/utils/database_helper.dart';

class AddAlbumScreen extends StatelessWidget {
  final TextEditingController _albumNameController = TextEditingController();

  AddAlbumScreen({super.key});

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
            child: Text(
              'Add Album',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: const Color(0xFF1D1D1D),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _albumNameController,
                decoration: const InputDecoration(
                  labelText: 'Album Name',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                _saveAlbum(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59115),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF1D1D1D),
    );
  }

  void _saveAlbum(BuildContext context) async {
    String albumName = _albumNameController.text.trim();
    if (albumName.isNotEmpty) {
      DatabaseHelper databaseHelper = DatabaseHelper();
      await databaseHelper.insertAlbum(albumName);
      // ignore: use_build_context_synchronously
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Please enter an album name',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
      ));
    }
  }
}
