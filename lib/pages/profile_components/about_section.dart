import 'package:flutter/material.dart';
import 'package:my_plant/components/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  Future<void> _launchUri(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Plantitao is a capstone research project brought to life by a dedicated team of developers and researchers.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'Our goal is to empower local plant sellers and cultivate a connected community of enthusiasts by providing a seamless mobile platform for discovering, buying, and selling plants currently within the Dipolog City.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        const Divider(height: 30, color: Colors.white24),
        const Text(
          'The Team',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 10),
        const ListTile(
          leading: Icon(Icons.person_outline, color: Colors.white),
          title: Text('Erica V. Manaban', style: TextStyle(color: Colors.white)),
          dense: true,
        ),
        const ListTile(
          leading: Icon(Icons.person_outline, color: Colors.white),
          title: Text('Al Ahmer Rhoden M. Timpahan',
              style: TextStyle(color: Colors.white)),
          dense: true,
        ),
        const ListTile(
          leading: Icon(Icons.person_outline, color: Colors.white),
          title:
              Text('John Lloyd Martalla', style: TextStyle(color: Colors.white)),
          dense: true,
        ),
        const Divider(height: 30, color: Colors.white24),
        const Text(
          'Contact Us',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.email_outlined, color: Colors.white),
          title: const Text('ahmertimpahan297@gmail.com',
              style: TextStyle(color: Colors.white)),
          dense: true,
          onTap: () => _launchUri(context, 'mailto:ahmertimpahan27@gmail.com'),
        ),
        ListTile(
          leading: const Icon(Icons.phone_outlined, color: Colors.white),
          title: const Text('0915 011 1915',
              style: TextStyle(color: Colors.white)),
          dense: true,
          onTap: () => _launchUri(context, 'tel:09150111915'),
        ),
      ],
    );
  }
}
