import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TemplateScreen extends StatelessWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Templates',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text('Manage your WhatsApp message templates here.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
            const Expanded(
              child: Center(
                child: _ComingSoonWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonWidget extends StatelessWidget {
  const _ComingSoonWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(Icons.description_outlined, size: 38, color: Color(0xFF2979FF)),
        ),
        const SizedBox(height: 18),
        Text('Templates Coming Soon',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Text('Template management will be available here.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}