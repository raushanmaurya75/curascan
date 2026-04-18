import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chatbot_service.dart';
import '../services/user_profile_service.dart';

// Colors from home.dart for consistency
const Color primaryGreen = Color(0xFF00796B);
const Color primaryLight = Color(0xFF4DB6AC);
const Color backgroundLight = Color(0xFFF0F4F7);
const Color cardWhite = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF212121);
const Color textLight = Color(0xFF757575);
const Color shadowDark = Color(0xFFC5DDE8);

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;
  final int confidence;
  final String? urgency;
  final List<String>? suggestions;
  final String? nextSteps;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    this.confidence = 0,
    this.urgency,
    this.suggestions,
    this.nextSteps,
  });
}

class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});
  
  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isLoading = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late AnimationController _animationController;
  late Animation<double> _animation;
  Map<String, dynamic> _userProfile = {};
  File? _selectedImage;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadUserProfile();
    _addWelcomeMessage();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserProfile() async {
    final profile = await UserProfileService.getUserProfile();
    setState(() {
      _userProfile = profile;
    });
  }
  
  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: '''Hello! I'm Swasthya, your AI Health Assistant. 🏥

I can help you with:
• Understanding your symptoms
• Analyzing skin conditions or rashes (share a photo)
• Personalized health advice based on your profile
• When to seek medical care

How are you feeling today?''',
      isUser: false,
      timestamp: DateTime.now(),
      confidence: 100,
    ));
  }
  
  void _toggleChat() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    
    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        imageUrl: _selectedImage?.path,
      ));
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();
    
    // Prepare conversation history
    final history = _messages.where((m) => m.text.isNotEmpty).map((m) => {
      'text': m.text,
      'isUser': m.isUser,
    }).toList();
    
    // Convert image to base64 if present
    String? imageBase64;
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      } catch (e) {
        print('Error encoding image: $e');
      }
    }
    
    // Clear selected image
    setState(() {
      _selectedImage = null;
    });
    
    // Call AI service
    try {
      final result = await ChatbotService.sendMessage(
        userMessage: text,
        conversationHistory: history,
        userProfile: _userProfile,
        imageBase64: imageBase64,
      );
      
      setState(() {
        _messages.add(ChatMessage(
          text: result['response'] ?? 'I apologize, I could not process that.',
          isUser: false,
          timestamp: DateTime.now(),
          confidence: result['confidence'] ?? 70,
          urgency: result['urgency'],
          suggestions: result['suggestions']?.cast<String>(),
          nextSteps: result['nextSteps'],
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'I apologize, there was an error processing your request. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
    
    _scrollToBottom();
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }
  
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'emergency':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.yellow.shade700;
      default:
        return primaryGreen;
    }
  }
  
  IconData _getUrgencyIcon(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'emergency':
        return Icons.emergency;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chat window
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              right: 20,
              bottom: 90,
              child: Opacity(
                opacity: _animation.value,
                child: Transform.scale(
                  scale: _animation.value,
                  alignment: Alignment.bottomRight,
                  child: _isExpanded ? _buildChatWindow() : const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
        
        // Floating button
        Positioned(
          right: 20,
          bottom: 20,
          child: GestureDetector(
            onTap: _toggleChat,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isExpanded
                    ? const Icon(Icons.close, color: cardWhite, size: 28, key: ValueKey('close'))
                    : const Icon(Icons.health_and_safety, color: cardWhite, size: 28, key: ValueKey('chat')),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildChatWindow() {
    return Material(
      elevation: 20,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withOpacity(0.3),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: backgroundLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardWhite.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: cardWhite,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Swasthya',
                          style: TextStyle(
                            color: cardWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'AI Health Assistant',
                          style: TextStyle(
                            color: cardWhite.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardWhite.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: cardWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            
            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Swasthya is thinking...',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Selected image preview
            if (_selectedImage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Image ready to send',
                        style: TextStyle(
                          color: textLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            
            // Input area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: shadowDark.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Image buttons
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'camera') {
                          _takePhoto();
                        } else if (value == 'gallery') {
                          _pickImage();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'camera',
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt, color: primaryGreen),
                              SizedBox(width: 8),
                              Text('Take Photo'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gallery',
                          child: Row(
                            children: [
                              Icon(Icons.photo_library, color: primaryGreen),
                              SizedBox(width: 8),
                              Text('Choose from Gallery'),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate,
                          color: primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask about symptoms, health tips...',
                          hintStyle: TextStyle(color: textLight.withOpacity(0.6), fontSize: 14),
                          filled: true,
                          fillColor: backgroundLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Send button
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryGreen, primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.send,
                          color: cardWhite,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGreen, primaryLight],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: cardWhite,
                      size: 14,
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? primaryGreen : cardWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shadowDark.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image if present
                        if (message.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(message.imageUrl!),
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (message.imageUrl != null)
                          const SizedBox(height: 8),
                        
                        // Text message
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isUser ? cardWhite : textDark,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        
                        // Urgency badge for AI responses
                        if (!isUser && message.urgency != null && message.urgency != 'low')
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getUrgencyColor(message.urgency).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getUrgencyColor(message.urgency).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getUrgencyIcon(message.urgency),
                                  color: _getUrgencyColor(message.urgency),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  message.urgency!.toUpperCase(),
                                  style: TextStyle(
                                    color: _getUrgencyColor(message.urgency),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Confidence indicator for AI responses
                        if (!isUser && message.confidence > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Confidence: ',
                                  style: TextStyle(
                                    color: isUser ? cardWhite.withOpacity(0.8) : textLight,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${message.confidence}%',
                                  style: TextStyle(
                                    color: message.confidence >= 80
                                        ? Colors.green
                                        : message.confidence >= 50
                                            ? Colors.orange
                                            : Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Suggestions for AI responses
            if (!isUser && message.suggestions != null && message.suggestions!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 36),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: message.suggestions!.map((suggestion) {
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: primaryGreen.withOpacity(0.1),
                      side: BorderSide.none,
                      onPressed: () {
                        _messageController.text = suggestion;
                        _sendMessage();
                      },
                    );
                  }).toList(),
                ),
              ),
            
            // Next steps for AI responses
            if (!isUser && message.nextSteps != null && message.nextSteps!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 36),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryLight.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward, color: primaryGreen, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        message.nextSteps!,
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
