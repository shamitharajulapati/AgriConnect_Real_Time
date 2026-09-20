import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/crop_names.dart';
import '../../../services/providers.dart';
import '../models/chat_models.dart';
import 'package:intl/intl.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  static const _myId = 'me';
  final List<File> _attachedImages = [];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(chatMessagesProvider(widget.roomId).notifier).send(text);
    _msgCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.roomId));
    // Auto-scroll when new message arrives
    ref.listen(chatMessagesProvider(widget.roomId), (_, __) => _scrollToBottom());

    final isTyping = messages.isNotEmpty && messages.last.senderId != _myId ? false : messages.length > 3;
    final s = ref.watch(appStringsProvider);
    final lang = s.lang;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(localCropName('Rajesh Gupta', lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${localCropName("Buyer", lang)} · ${localCropName("Online", lang)}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        // Chat info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.primary.withValues(alpha: 0.06),
          child: Row(children: [
            const Icon(Icons.grass, color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text('${localCropName("Tomato", lang)} · Grade A', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ]),
        ),
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final msg = messages[i];
              final isMe = msg.senderId == _myId;
              return _Bubble(message: msg, isMe: isMe)
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: isMe ? 0.08 : -0.08);
            },
          ),
        ),
        // Typing indicator
        if (isTyping)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TypingBubble(),
            ),
          ),
        // Input bar
        // Show attached image preview
        if (_attachedImages.isNotEmpty)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _attachedImages.map((f) => Stack(
                children: [
                  Container(
                    width: 70, height: 70, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(f), fit: BoxFit.cover)),
                  ),
                  Positioned(top: 0, right: 8, child: GestureDetector(
                    onTap: () => setState(() => _attachedImages.remove(f)),
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                  )),
                ],
              )).toList(),
            ),
          ),
        _InputBar(controller: _msgCtrl, onSend: () {
          if (_attachedImages.isNotEmpty) {
            // Send images as messages
            for (final img in _attachedImages) {
              ref.read(chatMessagesProvider(widget.roomId).notifier).send('📷 Photo sent');
            }
            setState(() => _attachedImages.clear());
          }
          _send();
        }, onAttach: (file) => setState(() => _attachedImages.add(file))),
      ]),
    );
  }
}

class _Bubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  const _Bubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLangProvider);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4)],
        ),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Text(translateMessage(message.text, lang), style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(DateFormat.jm().format(message.timestamp), style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : AppColors.textSecondary)),
            if (isMe) ...[
              const SizedBox(width: 4),
              Icon(message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                  size: 12, color: message.status == MessageStatus.read ? Colors.lightBlueAccent : Colors.white60),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]),
    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = (_c.value + i / 3) % 1.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 7, height: 7 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 5,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.5 + t * 0.5), borderRadius: BorderRadius.circular(4)),
        );
      },
    ))),
  );
}

class _InputBar extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(File) onAttach;
  const _InputBar({required this.controller, required this.onSend, required this.onAttach});

  void _showAttachOptions(BuildContext context) async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) onAttach(File(img.path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))]),
    child: SafeArea(
      child: Row(children: [
        IconButton(icon: const Icon(Icons.attach_file, color: AppColors.textSecondary), onPressed: () => _showAttachOptions(context), padding: EdgeInsets.zero),
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1, maxLines: 4,
            decoration: InputDecoration(
              hintText: s.chatType,
              hintStyle: const TextStyle(color: AppColors.textHint),
              filled: true, fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    ),
    );
  }
}
