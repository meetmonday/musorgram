import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../../services/cache_service.dart';
import '../../state/musorgram_controller.dart';
import '../chat_info_page.dart';
import 'avatar.dart';
import 'wallpaper.dart';

class EmptyConversation extends StatelessWidget {
  const EmptyConversation({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppPalette palette = context.appPalette;
    return Wallpaper(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: palette.header.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: palette.onHeader,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Выберите чат',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'или начните новый разговор кнопкой слева',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPane extends StatefulWidget {
  const ChatPane({
    required this.controller,
    required this.baseUrl,
    required this.compact,
    required this.onBack,
    super.key,
  });

  final MusorgramController controller;
  final String baseUrl;
  final bool compact;
  final VoidCallback onBack;

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final ScrollController _scrollController = ScrollController();
  String _previousChatKey = '';
  int _previousMessageCount = 0;
  bool _previousLoading = false;

  @override
  void initState() {
    super.initState();
    _captureState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(ChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _captureState();
    }
  }

  void _captureState() {
    _previousChatKey = widget.controller.current?.address.key ?? '';
    _previousMessageCount = widget.controller.messages.length;
    _previousLoading = widget.controller.chatLoading;
  }

  void _onControllerChanged() {
    final String key = widget.controller.current?.address.key ?? '';
    final int count = widget.controller.messages.length;
    final bool loading = widget.controller.chatLoading;
    final bool changedChat = key != _previousChatKey;
    final bool finishedLoading = _previousLoading && !loading;
    final bool nearBottom =
        !_scrollController.hasClients || _scrollController.offset < 70;
    final bool receivedMessage = count > _previousMessageCount;
    _previousChatKey = key;
    _previousMessageCount = count;
    _previousLoading = loading;

    if (changedChat || finishedLoading || (receivedMessage && nearBottom)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ConversationTarget? target = widget.controller.current;
    if (target == null) {
      return const EmptyConversation();
    }
    return Column(
      children: <Widget>[
        _ChatHeader(
          controller: widget.controller,
          baseUrl: widget.baseUrl,
          compact: widget.compact,
          onBack: widget.onBack,
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Wallpaper(
                  child: _MessageList(
                    controller: widget.controller,
                    baseUrl: widget.baseUrl,
                    scrollController: _scrollController,
                  ),
                ),
              ),
              if (widget.controller.chatLoading)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _MessageComposer(
          key: ValueKey<String>(target.address.key),
          controller: widget.controller,
          compact: widget.compact,
          onSent: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.controller,
    required this.baseUrl,
    required this.compact,
    required this.onBack,
  });

  final MusorgramController controller;
  final String baseUrl;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.appPalette;
    final ConversationTarget target = controller.current!;
    void openInfo() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatInfoPage(controller: controller, baseUrl: baseUrl),
        ),
      );
    }

    return ColoredBox(
      color: palette.header,
      child: SizedBox(
        height: 58,
        child: Row(
          children: <Widget>[
            if (compact)
              IconButton(
                tooltip: 'К списку чатов',
                onPressed: onBack,
                color: palette.onHeader,
                splashRadius: 20,
                icon: const Icon(Icons.arrow_back, size: 21),
              )
            else
              const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: openInfo,
                child: Row(
                  children: <Widget>[
                    AvatarView(
                      name: controller.currentTitle,
                      size: 39,
                      baseUrl: baseUrl,
                      avatarPath: target.avatarUrl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            controller.currentTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.onHeader,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            controller.currentSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.headerMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Информация о чате',
              onPressed: openInfo,
              color: palette.onHeader,
              splashRadius: 20,
              icon: const Icon(Icons.more_vert, size: 21),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.baseUrl,
    required this.scrollController,
  });

  final MusorgramController controller;
  final String baseUrl;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Widget> chronological = <Widget>[];
    String previousDay = '';
    if (controller.hasOlder) {
      chronological.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: TextButton(
              onPressed: controller.olderLoading ? null : controller.loadOlder,
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
                backgroundColor: colors.surface.withValues(alpha: 0.9),
                disabledForegroundColor: colors.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                minimumSize: const Size(0, 27),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              child: controller.olderLoading
                  ? const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.7),
                    )
                  : const Text(
                      'Загрузить предыдущие сообщения',
                      style: TextStyle(fontSize: 10),
                    ),
            ),
          ),
        ),
      );
    }

    for (final MessageItem message in controller.messages) {
      final String day = formatDay(message.createdAt);
      if (day.isNotEmpty && day != previousDay) {
        chronological.add(_DateSeparator(label: day));
        previousDay = day;
      }
      chronological.add(
        _MessageBubble(
          message: message,
          baseUrl: baseUrl,
          token: controller.api.token,
          isGroup: controller.current?.address.kind == ChatKind.group,
          readThroughId: controller.readThroughId,
        ),
      );
    }

    return Scrollbar(
      controller: scrollController,
      child: ListView(
        controller: scrollController,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(22, 13, 22, 12),
        children: chronological.reversed.toList(growable: false),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.baseUrl,
    required this.token,
    required this.isGroup,
    required this.readThroughId,
  });

  final MessageItem message;
  final String baseUrl;
  final String token;
  final bool isGroup;
  final int readThroughId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Color> senderColors = theme.brightness == Brightness.dark
        ? _darkSenderColors
        : _lightSenderColors;
    final bool own = message.own;
    final double maxBubbleWidth = (MediaQuery.sizeOf(context).width * 0.78)
        .clamp(72.0, 520.0);
    String meta = formatClock(message.createdAt);
    if (message.pending) {
      meta = '$meta  ◷'.trim();
    } else if (own) {
      final bool read =
          message.readAt != null || (!isGroup && message.id <= readThroughId);
      meta = '$meta  ${read ? '✓✓' : '✓'}'.trim();
    }

    return Opacity(
      opacity: message.pending ? 0.62 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: own
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (isGroup && !own) ...<Widget>[
              AvatarView(
                name: message.authorName,
                size: 28,
                baseUrl: baseUrl,
                avatarPath: message.senderAvatarUrl,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 72,
                  maxWidth: maxBubbleWidth,
                ),
                child: message.hasImages
                    ? SizedBox(
                        width: maxBubbleWidth.clamp(180.0, 360.0),
                        child: _bubble(
                          context,
                          own: own,
                          meta: meta,
                          senderColors: senderColors,
                        ),
                      )
                    : IntrinsicWidth(
                        child: _bubble(
                          context,
                          own: own,
                          meta: meta,
                          senderColors: senderColors,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(
    BuildContext context, {
    required bool own,
    required String meta,
    required List<Color> senderColors,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppPalette palette = context.appPalette;
    final double horizontalPadding = message.hasImages ? 4 : 9;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: own ? palette.outgoingMessage : palette.incomingMessage,
        borderRadius: BorderRadius.circular(4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.42 : 0.22,
            ),
            offset: const Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          message.hasImages ? 4 : 6,
          horizontalPadding,
          5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isGroup && !own)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  message.hasImages ? 5 : 0,
                  message.hasImages ? 2 : 0,
                  message.hasImages ? 5 : 0,
                  2,
                ),
                child: Text(
                  message.authorName,
                  style: TextStyle(
                    color: senderColors[colorIndex(message.authorName)],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (message.hasImages) ...<Widget>[
              _MessageAlbum(
                images: message.images,
                baseUrl: baseUrl,
                token: token,
              ),
              if (message.body.isNotEmpty) const SizedBox(height: 5),
            ],
            if (message.body.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: message.hasImages ? 5 : 0,
                ),
                child: SelectableText(
                  message.body,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    height: 1.24,
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: message.hasImages ? 5 : 0,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  meta,
                  style: TextStyle(
                    color: own ? palette.outgoingMeta : palette.incomingMeta,
                    fontSize: 9,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageAlbum extends StatelessWidget {
  const _MessageAlbum({
    required this.images,
    required this.baseUrl,
    required this.token,
  });

  final List<MessageImage> images;
  final String baseUrl;
  final String token;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      final MessageImage image = images.single;
      final double ratio = image.width != null && image.height != null
          ? (image.width! / image.height!).clamp(0.75, 1.8)
          : 1.25;
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: AspectRatio(
          aspectRatio: ratio,
          child: _MessageImageTile(
            image: image,
            baseUrl: baseUrl,
            token: token,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double halfWidth = (constraints.maxWidth - 2) / 2;
          return Wrap(
            spacing: 2,
            runSpacing: 2,
            children: <Widget>[
              for (int index = 0; index < images.length; index += 1)
                SizedBox(
                  width: index == images.length - 1 && images.length.isOdd
                      ? constraints.maxWidth
                      : halfWidth,
                  height: 112,
                  child: _MessageImageTile(
                    image: images[index],
                    baseUrl: baseUrl,
                    token: token,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageImageTile extends StatelessWidget {
  const _MessageImageTile({
    required this.image,
    required this.baseUrl,
    required this.token,
  });

  final MessageImage image;
  final String baseUrl;
  final String token;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget fallback = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
    );
    return Semantics(
      button: true,
      image: true,
      label: 'Открыть изображение',
      child: Material(
        color: colors.surfaceContainerHighest,
        child: InkWell(
          onTap: () => _openFullScreen(context),
          child: _imageWidget(context, fit: BoxFit.cover, fallback: fallback),
        ),
      ),
    );
  }

  Widget _imageWidget(
    BuildContext context, {
    required BoxFit fit,
    required Widget fallback,
    bool useOriginal = false,
  }) {
    final String? localPath = image.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final String url = resolveMediaUrl(
      baseUrl,
      useOriginal ? image.url : image.previewUrl,
    );
    if (url.isEmpty) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: authenticatedMediaCacheKey(url, token),
      httpHeaders: <String, String>{'Authorization': 'Bearer $token'},
      cacheManager: mediaCacheManager,
      fit: fit,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
        ),
      ),
      errorWidget: (_, _, _) => fallback,
    );
  }

  void _openFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: _imageWidget(
                      dialogContext,
                      fit: BoxFit.contain,
                      useOriginal: true,
                      fallback: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Закрыть',
                  color: Colors.white,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const List<Color> _lightSenderColors = <Color>[
  Color(0xFFB55E52),
  Color(0xFF9B751F),
  Color(0xFF468B51),
  Color(0xFF377F7B),
  Color(0xFF477FA8),
  Color(0xFF6269AA),
  Color(0xFF8D5DA0),
  Color(0xFFA25070),
];

const List<Color> _darkSenderColors = <Color>[
  Color(0xFFF08A7C),
  Color(0xFFDDB35D),
  Color(0xFF7BC789),
  Color(0xFF65C3BE),
  Color(0xFF70AEDD),
  Color(0xFF939BDF),
  Color(0xFFC08AD4),
  Color(0xFFD982A3),
];

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.controller,
    required this.compact,
    required this.onSent,
    super.key,
  });

  final MusorgramController controller;
  final bool compact;
  final VoidCallback onSent;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<OutgoingImage> _images = <OutgoingImage>[];
  bool _sending = false;

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _hasContent => _hasText || _images.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_textChanged);
  }

  void _textChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickImages() async {
    if (_sending || _images.length >= maxMessageImages) {
      return;
    }
    const XTypeGroup imageTypes = XTypeGroup(
      label: 'Изображения',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'gif'],
      mimeTypes: <String>['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
    );
    List<XFile> picked;
    try {
      picked = await openFiles(
        acceptedTypeGroups: const <XTypeGroup>[imageTypes],
      );
    } on Object {
      widget.controller.showError('Не удалось открыть выбор изображений');
      return;
    }
    if (!mounted || picked.isEmpty) {
      return;
    }

    final int available = maxMessageImages - _images.length;
    final int currentBytes = _images.fold<int>(
      0,
      (int total, OutgoingImage image) => total + image.sizeBytes,
    );
    int acceptedBytes = currentBytes;
    final Set<String> existingPaths = _images
        .map((OutgoingImage image) => image.path)
        .toSet();
    final List<OutgoingImage> accepted = <OutgoingImage>[];
    String? validationError;
    for (final XFile file in picked.take(available)) {
      final String mimeType = _imageMimeType(file);
      if (file.path.isEmpty || !supportedMessageImageTypes.contains(mimeType)) {
        validationError = 'Можно отправлять только JPEG, PNG, WebP и GIF';
        continue;
      }
      if (existingPaths.contains(file.path)) {
        continue;
      }
      final int size;
      try {
        size = await file.length();
      } on Object {
        validationError = 'Не удалось прочитать выбранное изображение';
        continue;
      }
      if (size > maxMessageImageBytes) {
        validationError = 'Размер одного изображения не должен превышать 20 МБ';
        continue;
      }
      if (acceptedBytes + size > maxMessageImagesTotalBytes) {
        validationError = 'Общий размер изображений не должен превышать 50 МБ';
        continue;
      }
      accepted.add(
        OutgoingImage(
          path: file.path,
          name: file.name,
          mimeType: mimeType,
          sizeBytes: size,
        ),
      );
      existingPaths.add(file.path);
      acceptedBytes += size;
    }
    if (picked.length > available) {
      validationError = 'К одному сообщению можно прикрепить до 10 изображений';
    }
    if (!mounted) {
      return;
    }
    if (accepted.isNotEmpty) {
      setState(() => _images.addAll(accepted));
      _focusNode.requestFocus();
    }
    if (validationError != null) {
      widget.controller.showError(validationError);
    }
  }

  String _imageMimeType(XFile file) {
    final String supplied = file.mimeType?.toLowerCase() ?? '';
    if (supplied == 'image/jpg') {
      return 'image/jpeg';
    }
    if (supportedMessageImageTypes.contains(supplied)) {
      return supplied;
    }
    final String extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => '',
    };
  }

  Future<void> _send() async {
    if (!_hasContent || _sending || widget.controller.chatLoading) {
      return;
    }
    final String body = _textController.text.trim();
    final List<OutgoingImage> images = List<OutgoingImage>.from(_images);
    _textController.clear();
    setState(() {
      _images.clear();
      _sending = true;
    });
    widget.onSent();
    final bool sent = await widget.controller.sendMessage(body, images: images);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (!sent) {
      _textController.text = body;
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
      setState(() => _images.addAll(images));
      _focusNode.requestFocus();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_textChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool enabled =
        _hasContent &&
        !_sending &&
        !widget.controller.chatLoading &&
        widget.controller.current != null;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_images.isNotEmpty) ...<Widget>[
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 5),
                itemBuilder: (BuildContext context, int index) {
                  final OutgoingImage image = _images[index];
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox.square(
                          dimension: 58,
                          child: Image.file(
                            File(image.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colors.surfaceContainerHighest,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Tooltip(
                          message: 'Убрать изображение',
                          child: InkWell(
                            onTap: _sending
                                ? null
                                : () => setState(() => _images.removeAt(index)),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: _images.length >= maxMessageImages
                    ? 'Прикреплено 10 изображений'
                    : 'Прикрепить изображения',
                onPressed:
                    _sending ||
                        widget.controller.chatLoading ||
                        _images.length >= maxMessageImages
                    ? null
                    : _pickImages,
                color: colors.onSurfaceVariant,
                splashRadius: 19,
                icon: const Icon(Icons.attach_file, size: 22),
              ),
              Expanded(
                child: Focus(
                  onKeyEvent: _handleKey,
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: !widget.controller.chatLoading && !_sending,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(4000),
                    ],
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: _images.isEmpty
                          ? 'Написать сообщение…'
                          : 'Добавить подпись…',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.35,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(6, 11, 10, 10),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.outline),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.outline),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: enabled ? _send : null,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  disabledForegroundColor: theme.disabledColor,
                  minimumSize: Size(widget.compact ? 48 : 94, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: _sending
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : widget.compact
                    ? const Icon(Icons.send, size: 21)
                    : const Text(
                        'ОТПРАВИТЬ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
