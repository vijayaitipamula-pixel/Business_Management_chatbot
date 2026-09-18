import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chatbot_ai_service.dart';
import '../services/chatbot_engine_service.dart';
import '../services/chatbot_local_data_service.dart';
import '../services/chatbot_voice_service.dart';
import '../widgets/assistant_orb.dart';
import '../widgets/chat_message_card.dart';

class CubeforeAssistantScreen extends StatefulWidget {
  const CubeforeAssistantScreen({super.key, this.aiService});
  // The caller owns an injected service; the screen owns its default service.
  final ChatbotAiService? aiService;
  @override
  State<CubeforeAssistantScreen> createState() =>
      _CubeforeAssistantScreenState();
}

class _CubeforeAssistantScreenState extends State<CubeforeAssistantScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _optionsScrollController = ScrollController();
  final _localDataService = ChatbotLocalDataService();
  late final _engineService = ChatbotEngineService(_localDataService);
  late final _aiService = widget.aiService ?? ChatbotAiService();
  late final _voiceService = ChatbotVoiceService(
    onListeningChanged: (listening) {
      if (!mounted) return;
      setState(() {
        _isListening = listening;
        if (!_busy) {
          _phase = listening ? AssistantPhase.listening : AssistantPhase.idle;
        }
      });
    },
    onTranscript: (text) {
      if (mounted) _controller.text = text;
    },
  );
  final List<ChatMessage> _messages = [];
  AssistantPhase _phase = AssistantPhase.idle;
  bool _busy = false;
  bool _isListening = false;
  bool _voiceBusy = false;
  String _streamingText = '';
  String? _error;
  List<ChatMessage>? _retryHistory;
  int? _replacementIndex;
  Timer? _completionTimer;
  StreamSubscription<String>? _responseSubscription;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    _focusNode.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (!mounted) return;
    setState(() {
      if (!_busy && !_isListening && _error == null) {
        _phase = _controller.text.isEmpty
            ? AssistantPhase.idle
            : AssistantPhase.typing;
      }
    });
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _responseSubscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _optionsScrollController.dispose();
    _voiceService.dispose();
    if (widget.aiService == null) _aiService.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    if (!force &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter > 160) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _resetOptions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _optionsScrollController.hasClients) {
        _optionsScrollController.jumpTo(0);
      }
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy || _isListening) return;
    _controller.clear();
    _submit(text);
  }

  void _submit(String text, {String? action, bool voice = false}) {
    if (_busy || _isListening) return;
    _completionTimer?.cancel();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _busy = true;
      _error = null;
      _retryHistory = null;
      _streamingText = '';
      _phase = AssistantPhase.thinking;
    });
    _scrollToBottom(force: true);
    try {
      final reply = action != null
          ? _engineService.handleAction(action)
          : voice
          ? _engineService.handleVoiceCommand(text)
          : _engineService.handleUserMessage(text);
      _resetOptions();
      if (reply == ChatbotEngineService.unsupportedMessage &&
          _aiService.isConfigured) {
        _startAi(List.of(_messages));
      } else {
        _finishReply(reply);
      }
    } catch (_) {
      _showError(
        'Could not complete this action. Check the conversation before trying again.',
      );
    }
  }

  void _startAi(List<ChatMessage> history, {int? replaceIndex}) {
    _replacementIndex = replaceIndex;
    _retryHistory = List.of(history);
    setState(() {
      _busy = true;
      _error = null;
      _streamingText = '';
      _phase = AssistantPhase.thinking;
    });
    _responseSubscription = _aiService
        .respond(
          history,
          'Unverified local sample data, not a live business database.\n'
          '${_localDataService.getTodaySummary()}\n${_localDataService.getMonthSummary()}',
        )
        .listen(
          (delta) {
            if (!mounted) return;
            setState(() {
              _phase = AssistantPhase.generating;
              _streamingText += delta;
            });
            _scrollToBottom();
          },
          onError: (Object error) {
            if (mounted) {
              _showError(
                error is AssistantRequestException
                    ? error.message
                    : 'Could not reach the assistant. Please retry.',
              );
            }
          },
          onDone: () {
            if (mounted && _error == null) {
              _finishReply(_streamingText, isAi: true);
            }
          },
          cancelOnError: true,
        );
  }

  void _finishReply(String text, {bool isAi = false}) {
    setState(() {
      final message = ChatMessage(text: text, isUser: false, isAi: isAi);
      if (isAi && _replacementIndex != null) {
        _messages[_replacementIndex!] = message;
      } else {
        _messages.add(message);
      }
      _replacementIndex = null;
      _streamingText = '';
      _busy = false;
      _phase = AssistantPhase.completed;
    });
    _scrollToBottom();
    _completionTimer?.cancel();
    _completionTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_busy && !_isListening && _error == null) {
        _onInputChanged();
      }
    });
  }

  void _showError(String error) {
    setState(() {
      _busy = false;
      _error = error;
      _phase = AssistantPhase.error;
    });
    _scrollToBottom(force: true);
  }

  Future<void> _handleVoiceListen() async {
    if (_busy || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    try {
      if (_isListening) {
        await _voiceService.stopListening();
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _phase = AssistantPhase.idle;
        });
        final text = _voiceService.lastWords.trim();
        _controller.clear();
        if (text.isNotEmpty) _submit(text, voice: true);
      } else {
        await _voiceService.startListening();
        if (!mounted) return;
        if (!_voiceService.isListening) {
          _showError(
            'Microphone unavailable. Check microphone permissions or type your message.',
          );
        } else {
          setState(() {
            _isListening = true;
            _error = null;
            _phase = AssistantPhase.listening;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        _isListening = false;
        _showError(
          'Voice input stopped. Please try again or type your message.',
        );
      }
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  String get _status => switch (_phase) {
    AssistantPhase.thinking => 'Thinking…',
    AssistantPhase.generating => 'Writing a response…',
    AssistantPhase.listening => 'Listening • tap the mic to finish',
    AssistantPhase.error => 'Let’s try that again',
    AssistantPhase.completed => 'Ready for your next step',
    AssistantPhase.typing => 'Ready when you are',
    AssistantPhase.idle => 'Your business, a little clearer',
  };

  Widget _buildHeader() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          AssistantOrb(phase: _phase, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CubeFore AI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _status,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Main menu',
            onPressed: _busy || _isListening
                ? null
                : () => _submit('Main menu', action: 'main_menu'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    final colors = Theme.of(context).colorScheme;
    final suggestions = <(IconData, String, String)>[
      (Icons.insights_outlined, 'See today’s overview', 'Today summary'),
      (
        Icons.payments_outlined,
        'Review today’s expenses',
        'Show today expense',
      ),
      (
        Icons.calendar_month_outlined,
        'Summarize this month',
        'This month summary',
      ),
      (Icons.add_chart_outlined, 'Record a business expense', 'Add expense'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AssistantOrb(phase: _phase, size: 116),
          const SizedBox(height: 20),
          Text(
            _engineService.getWelcomeMessage(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your intelligent business assistant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: suggestions.indexed
                  .map(
                    (entry) => SizedBox(
                      width: constraints.maxWidth >= 480
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : Duration(milliseconds: 220 + entry.$1 * 50),
                        builder: (context, value, child) =>
                            Opacity(opacity: value, child: child),
                        child: Card.outlined(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _busy || _isListening
                                ? null
                                : () => _submit(entry.$2.$3),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.$2.$1,
                                    color: colors.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.$2.$2,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.north_east_rounded,
                                    size: 16,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Business summaries use local sample data.\nMessages and transactions last for this session.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _scrollOptions(int direction) {
    if (!_optionsScrollController.hasClients) return;
    final position = _optionsScrollController.position;
    _optionsScrollController.animateTo(
      (position.pixels + direction * position.viewportDimension * 0.8)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildQuickOptions() {
    final colors = Theme.of(context).colorScheme;
    return Row(
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
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: _engineService
                    .getCurrentOptions()
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(option.label),
                          backgroundColor: colors.surface,
                          side: BorderSide(color: colors.outlineVariant),
                          onPressed: _busy || _isListening
                              ? null
                              : () => _submit(
                                  option.label,
                                  action: option.action,
                                ),
                        ),
                      ),
                    )
                    .toList(),
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
    );
  }

  Widget _buildInputBar() {
    final colors = Theme.of(context).colorScheme;
    final canSend =
        _controller.text.trim().isNotEmpty && !_busy && !_isListening;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _focusNode.hasFocus ? colors.primary : colors.outlineVariant,
          width: _focusNode.hasFocus ? 1.5 : 1,
        ),
        boxShadow: [
          if (_focusNode.hasFocus)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: _isListening ? 'Finish voice input' : 'Start voice input',
            onPressed: _busy || _voiceBusy ? null : _handleVoiceListen,
            color: _isListening ? colors.error : colors.onSurfaceVariant,
            icon: Icon(
              _isListening
                  ? Icons.stop_circle_outlined
                  : Icons.mic_none_rounded,
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.18,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                enabled: !_isListening,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Ask CubeFore…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: canSend ? colors.primary : colors.surfaceContainerHighest,
            ),
            child: IconButton(
              tooltip: 'Send message',
              onPressed: canSend ? _handleSend : null,
              color: colors.onPrimary,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_busy)
            Row(
              children: [
                AssistantOrb(phase: _phase, size: 36),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(_status, style: TextStyle(color: colors.primary)),
                ),
              ],
            ),
          if (_streamingText.isNotEmpty)
            SelectableText(_streamingText, style: const TextStyle(height: 1.6)),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                  if (_retryHistory != null)
                    TextButton.icon(
                      onPressed: () => _startAi(
                        _retryHistory!,
                        replaceIndex: _replacementIndex,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry response'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: _messages.isEmpty ? 1 : _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (_messages.isEmpty) {
                        return Column(
                          children: [
                            _buildWelcome(),
                            if (_error != null) _buildActivity(),
                          ],
                        );
                      }
                      if (index == _messages.length) return _buildActivity();
                      final message = _messages[index];
                      return ChatMessageCard(
                        key: ObjectKey(message),
                        message: message,
                        onRegenerate:
                            message.isAi &&
                                index == _messages.length - 1 &&
                                !_busy &&
                                !_isListening
                            ? () => _startAi(
                                _messages.take(index).toList(),
                                replaceIndex: index,
                              )
                            : null,
                      );
                    },
                  ),
                ),
                _buildQuickOptions(),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
