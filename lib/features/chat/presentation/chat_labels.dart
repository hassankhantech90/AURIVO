import '../domain/entities/conversation.dart';

/// Display title for a conversation. The subject captures the seller store name
/// at creation (the counterpart profile is not readable under RLS), so it is the
/// most meaningful label; falls back to a type-based label.
String conversationTitle(Conversation conversation) {
  final subject = conversation.subject?.trim();
  if (subject != null && subject.isNotEmpty) return subject;
  return switch (conversation.conversationType) {
    'order' => 'Order conversation',
    'rfq' => 'Quote request',
    'support' => 'Support',
    _ => 'Conversation',
  };
}

/// A short line describing the business context a conversation is scoped to.
String conversationContextLabel(Conversation conversation) {
  return switch (conversation.conversationType) {
    'order' => 'About an order',
    'rfq' => 'About a quote request',
    'support' => 'Support conversation',
    _ => 'Direct message',
  };
}
