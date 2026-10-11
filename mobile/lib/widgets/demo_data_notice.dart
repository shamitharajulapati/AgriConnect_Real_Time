import 'package:flutter/material.dart';

class DemoDataNotice extends StatelessWidget {
  const DemoDataNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Text(
          'DEMO DATA · The live service is unavailable. This sample is for demonstration only.',
          style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      );
}
