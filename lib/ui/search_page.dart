import 'package:flutter/material.dart';

import '../models/models.dart';
import 'controllers/category_catalog.dart';
import 'controllers/search_controller.dart';
import 'format.dart';
import 'home_page.dart';
import 'widgets/amount_range_bar.dart';
import 'widgets/date_range_bar.dart';

/// Tìm và lọc giao dịch theo từ khoá, khoảng ngày, nhóm và thu/chi.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  final _controller = TxnSearchController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _query.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDetail(Txn txn) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TxnDetailSheet(txn: txn),
  );

  /// Mở lịch cho một đầu của khoảng ngày, đầu kia giữ nguyên — chọn mỗi "Từ
  /// ngày" là ra "từ hôm đó đến nay".
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await pickRangeDate(
      context,
      isStart: isStart,
      initial: (isStart ? _controller.from : _controller.to) ?? DateTime.now(),
    );
    if (picked == null) return;
    _controller.setDateRange(
      from: isStart ? picked : _controller.from,
      to: isStart ? _controller.to : picked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tìm nội dung, ghi chú...',
            border: InputBorder.none,
          ),
          onChanged: _controller.queryChanged,
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final results = _controller.results;
          final net = _controller.net;
          return Column(
            children: [
              DateRangeBar(
                from: _controller.from,
                to: _controller.to,
                onPickStart: () => _pickDate(isStart: true),
                onPickEnd: () => _pickDate(isStart: false),
                onClear: _controller.hasDateFilter
                    ? _controller.clearDateRange
                    : null,
              ),
              AmountRangeBar(
                min: _controller.minAmount,
                max: _controller.maxAmount,
                onChanged: ({int? min, int? max}) =>
                    _controller.setAmountRange(min: min, max: max),
                onClear: _controller.hasAmountFilter
                    ? _controller.clearAmountRange
                    : null,
              ),
              SizedBox(
                height: 52,
                // Nghe danh sách nhóm để user vừa sửa nhóm xong là bộ lọc đổi
                // theo, không phải mở lại màn.
                child: ListenableBuilder(
                  listenable: CategoryCatalog.instance,
                  builder: (context, _) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final direction in TxnDirection.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: FilterChip(
                            label: Text(direction.label),
                            selected: _controller.direction == direction,
                            onSelected: (_) =>
                                _controller.toggleDirection(direction),
                          ),
                        ),
                      const VerticalDivider(width: 12),
                      for (final category in CategoryCatalog.instance.names)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: FilterChip(
                            label: Text(category),
                            selected: _controller.category == category,
                            onSelected: (_) =>
                                _controller.toggleCategory(category),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if (results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_controller.count} giao dịch',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        formatSigned(net.abs(), isIncome: net >= 0),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy giao dịch nào',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (_, i) => TxnTile(
                          txn: results[i],
                          onTap: () => _openDetail(results[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
