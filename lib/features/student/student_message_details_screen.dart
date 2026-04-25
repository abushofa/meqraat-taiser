import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class StudentMessageDetailsScreen extends StatefulWidget {
  final int messageId;

  const StudentMessageDetailsScreen({
    super.key,
    required this.messageId,
  });

  @override
  State<StudentMessageDetailsScreen> createState() =>
      _StudentMessageDetailsScreenState();
}

class _StudentMessageDetailsScreenState
    extends State<StudentMessageDetailsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _message;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    try {
      final dio = await ApiClient.getInstance();

      final res = await dio.get(
        '/student/get_message.php',
        queryParameters: {
          'id': widget.messageId,
        },
      );

      setState(() {
        _message = res.data['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الرسالة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _message == null
              ? const Center(child: Text('تعذر تحميل الرسالة'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _message!['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_message!['body'] ?? ''),
                    ],
                  ),
                ),
    );
  }
}