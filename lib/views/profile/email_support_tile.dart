import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailSupportTile extends StatelessWidget {
  const EmailSupportTile({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@cses.store',
      query: 'subject=Hỗ trợ khách hàng CSES App&body=Xin chào đội ngũ hỗ trợ,',
    );

    if (!await launchUrl(emailUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ứng dụng email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.email_outlined),
      title: const Text('Email hỗ trợ'),
      subtitle: const Text('support@cses.store'),
      onTap: () => _launchEmail(context), // 👈 Nhấn để mở Gmail
    );
  }
}
