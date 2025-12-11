import 'package:flutter/material.dart';
import '../models/subtitle.dart';

class SubtitleList extends StatelessWidget {
  final List<Subtitle> subtitles;
  final int selectedIndex;
  final Function(int) onSelect;
  final VoidCallback onAdd;
  final Function(int) onDelete;
  final Function(int, String) onUpdate;

  const SubtitleList({
    super.key,
    required this.subtitles,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildTableHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: subtitles.length,
            itemBuilder: (_, i) => _buildRow(i),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Text('字幕列表', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onAdd,
            tooltip: '添加字幕',
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 40, child: Text('#', style: TextStyle(fontSize: 12))),
          SizedBox(
              width: 90, child: Text('开始', style: TextStyle(fontSize: 12))),
          SizedBox(
              width: 90, child: Text('结束', style: TextStyle(fontSize: 12))),
          Expanded(child: Text('内容', style: TextStyle(fontSize: 12))),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildRow(int index) {
    final sub = subtitles[index];
    final selected = index == selectedIndex;
    return InkWell(
      onTap: () => onSelect(index),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F0FE) : null,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text('${sub.index}', style: const TextStyle(fontSize: 12)),
            ),
            SizedBox(
              width: 90,
              child:
                  Text(sub.startTimeStr, style: const TextStyle(fontSize: 11)),
            ),
            SizedBox(
              width: 90,
              child: Text(sub.endTimeStr, style: const TextStyle(fontSize: 11)),
            ),
            Expanded(
              child: selected
                  ? TextField(
                      controller: TextEditingController(text: sub.text),
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (v) => onUpdate(index, v),
                    )
                  : Text(
                      sub.text,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            SizedBox(
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () => onDelete(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
