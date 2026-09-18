import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_option.dart';
import '../services/chatbot_engine_service.dart';
import '../services/chatbot_local_data_service.dart';
import '../services/chatbot_voice_service.dart';

class CubeforeAssistantScreen extends StatefulWidget {
  const CubeforeAssistantScreen({super.key});

  @override
  State<CubeforeAssistantScreen> createState() =>
      _CubeforeAssistantScreenState();
}

class _CubeforeAssistantScreenState extends State<CubeforeAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _optionsScrollController = ScrollController();

  late final ChatbotLocalDataService _localDataService;
  late final ChatbotEngineService _engineService;
  late final ChatbotVoiceService _voiceService;

  final List<ChatMessage> _messages = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    _localDataService = ChatbotLocalDataService();
    _engineService = ChatbotEngineService(_localDataService);
    _voiceService = ChatbotVoiceService();

    _messages.add(
      ChatMessage(text: _engineService.getWelcomeMessage(), isUser: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _optionsScrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });

    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });

    _scrollToBottom();
  }

  void _handleSend() {
    final String text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    _controller.clear();
    _addUserMessage(text);

    final String reply = _engineService.handleUserMessage(text);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _addBotMessage(reply);
    });
  }

  void _handleOption(ChatOption option) {
    _addUserMessage(option.label);

    final String reply = _engineService.handleAction(option.action);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _addBotMessage(reply);
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleVoiceListen() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });

      final recognizedText = _voiceService.lastWords;
      if (recognizedText.isNotEmpty) {
        _controller.text = recognizedText;
        _addUserMessage(recognizedText);

        final String reply = _engineService.handleVoiceCommand(recognizedText);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          _addBotMessage(reply);
          setState(() {});
        });
      }

      return;
    }

    final available = await _voiceService.initializeVoice();
    if (!available) {
      _addBotMessage(
        'Voice recognition is not available on this device. You can type the transaction manually.',
      );
      return;
    }

    await _voiceService.startListening();
    setState(() {
      _isListening = true;
    });
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final Alignment alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final Color bgColor = message.isUser
        ? const Color(0xFF16A085)
        : const Color(0xFFF1F5F9);

    final Color textColor = message.isUser
        ? Colors.white
        : const Color(0xFF1E293B);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 14.5, height: 1.35),
        ),
      ),
    );
  }

  void _scrollOptions(int direction) {
    if (!_optionsScrollController.hasClients) return;

    final position = _optionsScrollController.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.8)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    _optionsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildQuickOptions() {
    final List<ChatOption> options = _engineService.getCurrentOptions();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous options',
            onPressed: () => _scrollOptions(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Scrollbar(
              controller: _optionsScrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _optionsScrollController,
                padding: const EdgeInsets.only(bottom: 10),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: options.map((ChatOption option) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(option.label),
                        backgroundColor: const Color(0xFFEFFDF8),
                        side: const BorderSide(color: Color(0xFF99F6E4)),
                        labelStyle: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                        onPressed: () => _handleOption(option),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next options',
            onPressed: () => _scrollOptions(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _isListening
                ? const Color(0xFFEF4444)
                : const Color(0xFF14B8A6),
            child: IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none_rounded,
                color: Colors.white,
              ),
              onPressed: _handleVoiceListen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Ask Cubefore Assistant...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF14B8A6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF14B8A6),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _handleSend,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy_rounded, color: Color(0xFF0F766E)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cubefore Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                final String reply = _engineService.handleAction('main_menu');
                _addBotMessage(reply);
              },
              icon: const Icon(Icons.home_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildQuickOptions(),
          _buildInputBar(),
        ],
      ),
    );
  }
}
