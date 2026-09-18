class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isAi;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isAi = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}
