import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FullscreenImageView extends StatelessWidget {
  final String imagePath;
  final String title;

  const FullscreenImageView({
    super.key,
    required this.imagePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          clipBehavior: Clip.none,
          maxScale: 4.0,
          child: Hero(
            tag: imagePath,
            child: kIsWeb
                ? Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image, color: Colors.grey, size: 64),
        SizedBox(height: 16),
        Text(
          'Could not load image',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
