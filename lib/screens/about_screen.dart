import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  String getDriveImageUrl(String id) =>
      "https://drive.google.com/uc?export=view&id=$id";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4F9),
      appBar: AppBar(
        title: const Text(
          "Tentang",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('about_content')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5BB9D6)),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Belum ada konten",
                style: TextStyle(color: Colors.black38),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'];

              // IMAGE
              if (type == 'image') {
                List<String> ids = [];
                if (data['image_ids'] != null) {
                  ids = List<String>.from(data['image_ids']);
                } else if ((data['image_id'] ?? '').isNotEmpty) {
                  ids = [data['image_id']];
                }
                ids = ids.where((id) => id.trim().isNotEmpty).toList();
                if (ids.isEmpty) return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ids.length == 1
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            getDriveImageUrl(ids.first),
                            fit: BoxFit.cover,
                          ),
                        )
                      : _ImageSlider(urls: ids.map(getDriveImageUrl).toList()),
                );
              }

              // TEXT
              if (type == 'text') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((data['title'] ?? '').isNotEmpty)
                        Text(
                          data['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if ((data['title'] ?? '').isNotEmpty)
                        const SizedBox(height: 6),
                      if ((data['desc'] ?? '').isNotEmpty)
                        Text(
                          data['desc'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                );
              }

              // CARD
              if (type == 'card') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD6E4F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((data['title'] ?? '').isNotEmpty)
                          Text(
                            data['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        if ((data['title'] ?? '').isNotEmpty)
                          const SizedBox(height: 6),
                        if ((data['desc'] ?? '').isNotEmpty)
                          Text(
                            data['desc'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox();
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _card({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }
}

// ===== SLIDER WIDGET =====
class _ImageSlider extends StatefulWidget {
  final List<String> urls;
  const _ImageSlider({required this.urls});

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider> {
  int _current = 0;
  final PageController _ctrl = PageController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF5BB9D6),
                            strokeWidth: 2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.urls.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _current == i ? const Color(0xFF5BB9D6) : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
