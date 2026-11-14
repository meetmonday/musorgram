import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../services/cache_service.dart';

class AvatarView extends StatelessWidget {
  const AvatarView({
    required this.name,
    required this.size,
    required this.baseUrl,
    this.avatarPath,
    super.key,
  });

  final String name;
  final double size;
  final String baseUrl;
  final String? avatarPath;

  static const List<Color> _colors = <Color>[
    Color(0xFFD9786A),
    Color(0xFFD7A64A),
    Color(0xFF6EAF76),
    Color(0xFF57A8A4),
    Color(0xFF5E99C8),
    Color(0xFF777FC4),
    Color(0xFFA676BA),
    Color(0xFFBE718E),
  ];

  @override
  Widget build(BuildContext context) {
    final String imageUrl = resolveMediaUrl(baseUrl, avatarPath);
    final Widget fallback = ColoredBox(
      color: _colors[colorIndex(name)],
      child: Center(
        child: Text(
          initials(name),
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );

    return Semantics(
      image: true,
      label: 'Аватар: $name',
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: imageUrl.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  cacheManager: mediaCacheManager,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  maxWidthDiskCache: 512,
                  fadeInDuration: const Duration(milliseconds: 120),
                  fadeOutDuration: const Duration(milliseconds: 80),
                  placeholder: (BuildContext context, String url) => fallback,
                  errorWidget: (
                    BuildContext context,
                    String url,
                    Object error,
                  ) => fallback,
                ),
        ),
      ),
    );
  }
}
