enum MessageStatus { sending, sent, delivered, read }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    required this.status,
  });
}

class ChatRoom {
  final String roomId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? cropTopic;

  const ChatRoom({
    required this.roomId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.cropTopic,
  });

  static List<ChatRoom> get mockRooms => [
        ChatRoom(roomId: 'r1', otherUserId: 'b1', otherUserName: 'Rajesh Gupta', otherUserRole: 'Buyer', lastMessage: 'What is your asking price for tomatoes?', lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)), unreadCount: 2, cropTopic: 'Tomato'),
        ChatRoom(roomId: 'r2', otherUserId: 'b2', otherUserName: 'Priya Exports', otherUserRole: 'Exporter', lastMessage: 'We can offer ₹1800/qtl for Grade A onions', lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)), unreadCount: 0, cropTopic: 'Onion'),
        ChatRoom(roomId: 'r3', otherUserId: 'b3', otherUserName: 'FreshMart Ltd', otherUserRole: 'Retailer', lastMessage: 'Interested in 50 quintals of wheat', lastMessageTime: DateTime.now().subtract(const Duration(days: 1)), unreadCount: 1, cropTopic: 'Wheat'),
      ];

  static List<ChatMessage> mockMessages(String myId) => [
        ChatMessage(id: 'm1', senderId: 'b1', text: 'Hello! I saw your listing for tomatoes.', timestamp: DateTime.now().subtract(const Duration(minutes: 30)), isRead: true, status: MessageStatus.read),
        ChatMessage(id: 'm2', senderId: myId, text: 'Yes, I have 20 quintals available.', timestamp: DateTime.now().subtract(const Duration(minutes: 28)), isRead: true, status: MessageStatus.read),
        ChatMessage(id: 'm3', senderId: 'b1', text: 'What grade are they? Grade A or B?', timestamp: DateTime.now().subtract(const Duration(minutes: 25)), isRead: true, status: MessageStatus.read),
        ChatMessage(id: 'm4', senderId: myId, text: 'Mostly Grade A. Freshly harvested yesterday.', timestamp: DateTime.now().subtract(const Duration(minutes: 22)), isRead: true, status: MessageStatus.read),
        ChatMessage(id: 'm5', senderId: 'b1', text: 'What is your asking price for tomatoes?', timestamp: DateTime.now().subtract(const Duration(minutes: 5)), isRead: false, status: MessageStatus.delivered),
      ];
}
