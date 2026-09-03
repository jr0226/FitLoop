import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/local_food_image_service.dart';

/// Renders a food image from local device storage (via [imageHash]),
/// or falls back to network loading (via [imageUrl]) for legacy records.
///
/// If neither is available or the image file is missing, displays [placeholder]
/// or a themed fallback icon.
class FoodImageDisplay extends StatelessWidget {
  final String? imageHash;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FoodImageDisplay({
    super.key,
    this.imageHash,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    // 1. Prefer on-device local storage via imageHash
    if (imageHash != null && imageHash!.isNotEmpty) {
      final immediateFile = LocalFoodImageService.instance.getImageFileImmediate(imageHash!);
      if (immediateFile != null) {
        content = Image.file(
          immediateFile,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
        );
      } else {
        content = FutureBuilder<File?>(
          future: LocalFoodImageService.instance.getImageFile(imageHash!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
              return Image.file(
                snapshot.data!,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: width,
                height: height,
                color: Colors.grey.shade100,
              );
            }
            // If local file is missing, check if legacy network URL exists
            if (imageUrl != null && imageUrl!.isNotEmpty) {
              return _buildNetworkImage(imageUrl!);
            }
            return _buildPlaceholder();
          },
        );
      }
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      // 2. Fallback to legacy cloud network image
      content = _buildNetworkImage(imageUrl!);
    } else {
      content = _buildPlaceholder();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }
    return content;
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Colors.teal, strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
    );
  }

  Widget _buildErrorFallback() {
    if (errorWidget != null) return errorWidget!;
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey.shade400),
    );
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;
    return Container(
      width: width,
      height: height,
      color: Colors.teal.shade50,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, size: 20, color: Colors.teal.shade700),
    );
  }
}
