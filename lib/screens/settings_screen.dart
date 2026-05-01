import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController locationController = TextEditingController();

  List<Map<String, dynamic>> items = [];
  bool isLoading = true;

  String getDriveImageUrl(String id) =>
      "https://drive.google.com/uc?export=view&id=$id";

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  // ================= LOAD =================
  Future<void> loadAllData() async {
    final settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('app_config')
        .get();

    final aboutSnapshot = await FirebaseFirestore.instance
        .collection('about_content')
        .orderBy('order')
        .get();

    if (settingsDoc.exists) {
      locationController.text = settingsDoc['location'] ?? '';
    }

    items = aboutSnapshot.docs.map((doc) {
      final data = doc.data();
      // Migrasi: kalau masih pakai image_id lama, convert ke list
      List<String> imageIds = [];
      if (data['image_ids'] != null) {
        imageIds = List<String>.from(data['image_ids']);
      } else if ((data['image_id'] ?? '').isNotEmpty) {
        imageIds = [data['image_id']];
      }
      return {"id": doc.id, ...data, "image_ids": imageIds, "isNew": false};
    }).toList();

    setState(() => isLoading = false);
  }

  // ================= ADD =================
  void addItem(String type) {
    Navigator.pop(context);
    setState(() {
      items.add({
        "id": null,
        "type": type,
        "title": "",
        "desc": "",
        "image_ids": <String>[""],
        "order": items.length,
        "created_at": Timestamp.now(),
        "isNew": true,
      });
    });
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Tambah Konten"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogOption(Icons.text_fields, "Text", () => addItem('text')),
            _dialogOption(
              Icons.image_outlined,
              "Image",
              () => addItem('image'),
            ),
            _dialogOption(
              Icons.credit_card_outlined,
              "Card",
              () => addItem('card'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2C6FAC)),
      title: Text(label),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ================= SAVE =================
  Future<void> saveItem(int index) async {
    final item = items[index];
    final collection = FirebaseFirestore.instance.collection('about_content');

    // Bersihkan image_ids dari string kosong
    final imageIds = (item['image_ids'] as List<String>)
        .where((id) => id.trim().isNotEmpty)
        .toList();

    final data = {
      "type": item['type'],
      "title": item['title'] ?? '',
      "desc": item['desc'] ?? '',
      "image_ids": imageIds,
      "order": index,
      "created_at": item['created_at'] ?? Timestamp.now(),
    };

    if (item['id'] == null) {
      final doc = await collection.add(data);
      setState(() {
        items[index]['id'] = doc.id;
        items[index]['isNew'] = false;
      });
    } else {
      await collection.doc(item['id']).update(data);
      setState(() => items[index]['isNew'] = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Tersimpan!"),
        backgroundColor: const Color(0xFF2C6FAC),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ================= DELETE =================
  Future<void> deleteItem(int index) async {
    final item = items[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus konten ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (item['id'] != null) {
      await FirebaseFirestore.instance
          .collection('about_content')
          .doc(item['id'])
          .delete();
    }
    setState(() => items.removeAt(index));
  }

  // ================= REORDER =================
  Future<void> onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });

    // Update order di Firestore
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < items.length; i++) {
      final id = items[i]['id'];
      if (id != null) {
        batch.update(
          FirebaseFirestore.instance.collection('about_content').doc(id),
          {'order': i},
        );
      }
    }
    await batch.commit();
  }

  // ================= FIELD BUILDER =================
  Widget buildField({
    required String label,
    required String value,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFEFF4F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _typeChip(String type) {
    final colors = {
      'text': [const Color(0xFFE8F4FD), const Color(0xFF2C6FAC)],
      'image': [const Color(0xFFE8F8F0), const Color(0xFF2E7D55)],
      'card': [const Color(0xFFFFF4E0), const Color(0xFFBA7517)],
    };
    final c = colors[type] ?? [Colors.grey.shade100, Colors.grey];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c[0],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c[1],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4F9),
      appBar: AppBar(
        title: const Text(
          "Pengaturan",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        backgroundColor: const Color(0xFF5BB9D6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5BB9D6)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== LOKASI =====
                  // ===== LOKASI =====
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD6E4F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Lokasi",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: locationController,
                          decoration: InputDecoration(
                            hintText: "Masukkan lokasi",
                            filled: true,
                            fillColor: const Color(0xFFEFF4F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('settings')
                                  .doc('app_config')
                                  .update({
                                    'location': locationController.text,
                                  });

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Lokasi tersimpan!"),
                                  backgroundColor: const Color(0xFF2C6FAC),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5BB9D6),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Simpan Lokasi",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Konten Tentang",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tahan & geser untuk mengubah urutan",
                    style: TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                  const SizedBox(height: 12),

                  if (items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 40,
                              color: Colors.black12,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Belum ada konten",
                              style: TextStyle(color: Colors.black38),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // ===== REORDERABLE LIST =====
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: onReorder,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final type = item['type'] as String;
                        final isNew = item['isNew'] == true;

                        return Container(
                          key: ValueKey(item['id'] ?? index),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isNew
                                  ? const Color(0xFF5BB9D6)
                                  : const Color(0xFFD6E4F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.fromLTRB(
                                14,
                                4,
                                8,
                                4,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                14,
                                0,
                                14,
                                14,
                              ),
                              leading: const Icon(
                                Icons.drag_handle,
                                color: Colors.black26,
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  _typeChip(type),
                                  const SizedBox(width: 8),
                                  // Preview judul kalau ada
                                  if (type != 'image' &&
                                      (item['title'] ?? '').isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        item['title'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (type == 'image')
                                    Text(
                                      "${(item['image_ids'] as List<String>).where((e) => e.isNotEmpty).length} gambar",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black38,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.save_outlined,
                                      color: Color(0xFF2C6FAC),
                                      size: 20,
                                    ),
                                    onPressed: () => saveItem(index),
                                    tooltip: "Simpan",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () => deleteItem(index),
                                    tooltip: "Hapus",
                                  ),
                                ],
                              ),
                              // Otomatis expand kalau baru ditambah
                              initiallyExpanded: isNew,
                              children: [
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: const Color(0xFFEFF4F9),
                                ),
                                const SizedBox(height: 10),

                                // IMAGE TYPE
                                if (type == 'image') ...[
                                  ...List.generate(
                                    (item['image_ids'] as List<String>).length,
                                    (i) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue:
                                                  (item['image_ids']
                                                      as List<String>)[i],
                                              decoration: InputDecoration(
                                                labelText: "Image ID ${i + 1}",
                                                filled: true,
                                                fillColor: const Color(
                                                  0xFFEFF4F9,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              onChanged: (val) {
                                                (item['image_ids']
                                                        as List<String>)[i] =
                                                    val;
                                              },
                                            ),
                                          ),
                                          if ((item['image_ids']
                                                      as List<String>)
                                                  .length >
                                              1)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  (item['image_ids']
                                                          as List<String>)
                                                      .removeAt(i);
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        (item['image_ids'] as List<String>).add(
                                          '',
                                        );
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFD6E4F0),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Color(0xFF2C6FAC),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            "Tambah Gambar",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF2C6FAC),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                // TEXT & CARD TYPE
                                if (type != 'image') ...[
                                  buildField(
                                    label: "Judul",
                                    value: item['title'] ?? '',
                                    onChanged: (val) => item['title'] = val,
                                  ),
                                  const SizedBox(height: 8),
                                  buildField(
                                    label: "Deskripsi",
                                    value: item['desc'] ?? '',
                                    onChanged: (val) => item['desc'] = val,
                                    maxLines: 3,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
