import 'package:flutter/material.dart';
import '../models/faq_item.dart';
import '../services/faq_service.dart';
import '../services/ai_service.dart';

/// A chat message representing either a user prompt or assistant response.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final FaqItem? matchedFaq;
  final bool isSafetyNotice;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.matchedFaq,
    this.isSafetyNotice = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// In-app Help & FAQ Chatbot Assistant for FitLoop users.
class FaqChatbotScreen extends StatefulWidget {
  const FaqChatbotScreen({super.key});

  @override
  State<FaqChatbotScreen> createState() => _FaqChatbotScreenState();
}

class _FaqChatbotScreenState extends State<FaqChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;

  // Selected category filter for browsing FAQs
  FaqCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Initial bot greeting
    _messages.add(
      ChatMessage(
        text:
            "Hi! I'm the FitLoop Assistant. Ask me about food scanning, workouts, progress, reminders, reports, or settings.",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty || _isProcessing) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isProcessing = true;
    });
    _scrollToBottom();

    // FAQ-first matching, falling back to Gemini 3.8 Flash for unmatched queries
    Future.delayed(const Duration(milliseconds: 100), () async {
      final searchResult = FaqService.search(text);

      String answerText = searchResult.answer;
      bool isSafety = searchResult.isSafetyWarning;
      FaqItem? match = searchResult.bestMatch;

      // If local keyword matching did not yield a confident answer and it's not a direct medical safety keyword,
      // invoke the Gemini 3.8 Flash FAQ fallback
      if (!searchResult.isConfident && !searchResult.isSafetyWarning) {
        try {
          final aiResult = await AiService.getFaqFallback(question: text);
          if (aiResult != null &&
              aiResult['answer'] != null &&
              aiResult['answer'].toString().trim().isNotEmpty) {
            answerText = aiResult['answer'].toString().trim();
            if (aiResult['isMedicalNotice'] == true) {
              isSafety = true;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: answerText,
            isUser: false,
            matchedFaq: match,
            isSafetyNotice: isSafety,
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear Chat History?"),
        content: const Text("This will reset the conversation with the FitLoop Assistant."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text:
                        "Hi! I'm the FitLoop Assistant. Ask me about food scanning, workouts, progress, reminders, reports, or settings.",
                    isUser: false,
                  ),
                );
              });
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(Icons.smart_toy_rounded, color: Colors.teal, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "FitLoop Assistant",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Instant Help & FAQ",
                    style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: "Reset Chat",
            onPressed: _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Quick-Browse Bar
            _buildCategoryFilterBar(),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _messages.length + (_isProcessing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _buildMessageBubble(_messages[index]);
                  } else {
                    return _buildTypingIndicator();
                  }
                },
              ),
            ),

            // Quick Suggested Questions Chips
            _buildSuggestedQuestionsBar(),

            // Chat Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CATEGORY BROWSING BAR
  // =========================================================================
  Widget _buildCategoryFilterBar() {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      color: theme.cardColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text("All Topics", style: TextStyle(fontSize: 11)),
              selected: _selectedCategory == null,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _selectedCategory = null),
            ),
          ),
          ...FaqCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(cat.displayName, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                checkmarkColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? cat : null;
                  });
                  if (selected) {
                    _showCategoryFaqModal(cat);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCategoryFaqModal(FaqCategory category) {
    final faqs = FaqService.getFaqsByCategory(category);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${category.displayName} Questions",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: faqs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = faqs[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(
                        item.question,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.send_rounded, size: 18, color: Colors.teal),
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleSubmitted(item.question);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MESSAGE BUBBLES
  // =========================================================================
  Widget _buildMessageBubble(ChatMessage msg) {
    final theme = Theme.of(context);
    final isUser = msg.isUser;
    final isSafety = msg.isSafetyNotice;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: isSafety
                  ? (theme.brightness == Brightness.dark ? const Color(0xFF451A03) : Colors.amber.shade100)
                  : (theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHighest : Colors.teal.shade50),
              child: Icon(
                isSafety ? Icons.warning_amber_rounded : Icons.smart_toy_rounded,
                size: 15,
                color: isSafety ? Colors.amber.shade700 : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.80,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary
                      : (isSafety
                          ? (theme.brightness == Brightness.dark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
                          : theme.cardColor),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isUser ? 14 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 14),
                  ),
                  border: Border.all(
                    color: isUser
                        ? theme.colorScheme.primary
                        : (isSafety ? Colors.amber.shade700 : theme.colorScheme.outlineVariant),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.03),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUser
                        ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                        : theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.teal.shade50,
            child: Icon(Icons.smart_toy_rounded, size: 15, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "Thinking...",
                      style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUGGESTED QUESTIONS CHIPS
  // =========================================================================
  Widget _buildSuggestedQuestionsBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: FaqService.defaultSuggestedQuestions.map((q) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.6),
                label: Text(
                  q,
                  style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface),
                ),
                onPressed: () => _handleSubmitted(q),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // INPUT BAR
  // =========================================================================
  Widget _buildInputBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: _handleSubmitted,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "Ask about FitLoop features...",
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13.5),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _handleSubmitted(_textController.text),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Icon(
                  Icons.send_rounded,
                  color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
