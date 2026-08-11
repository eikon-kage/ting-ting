import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../domain/vietqr.dart';
import '../domain/vietqr_banks.dart';
import '../models/models.dart';
import 'controllers/qr_controller.dart';
import 'format.dart';
import 'widgets/bank_logo.dart';

/// Màn "Mã QR nhận tiền": chọn ngân hàng, gõ số tài khoản, ra ngay mã VietQR
/// quét được bằng app ngân hàng bất kỳ, và tải ảnh về để gửi cho người khác.
///
/// Mã được dựng ngay trên máy theo chuẩn EMVCo của NAPAS, không qua dịch vụ
/// sinh mã nào — chạy được lúc mất mạng, và số tài khoản không bị đưa cho bên
/// thứ ba chỉ để lấy về một tấm ảnh.
class QrPage extends StatefulWidget {
  const QrPage({super.key});

  @override
  State<QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<QrPage> {
  final _controller = QrController();
  final _accountField = TextEditingController();
  final _holderField = TextEditingController();
  final _amountField = TextEditingController();
  final _noteField = TextEditingController();
  final _scrollController = ScrollController();

  /// Bọc quanh thẻ mã QR để xuất đúng phần đó ra ảnh.
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.init().then((_) {
      if (!mounted) return;
      _syncFields();
    });
  }

  @override
  void dispose() {
    _accountField.dispose();
    _holderField.dispose();
    _amountField.dispose();
    _noteField.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Kéo mấy ô nhập theo state của controller.
  ///
  /// Chỉ đi một chiều như vậy: controller là nơi giữ mã đang tạo, [TextField]
  /// chỉ là chỗ gõ. Gọi sau mỗi lần nạp lại từ danh sách đã lưu.
  void _syncFields() {
    _accountField.text = _controller.accountNumber;
    _holderField.text = _controller.holderName;
    _amountField.text = _controller.amount?.toString() ?? '';
    _noteField.text = _controller.note;
    final bank = _controller.bank;
    if (bank != null) _warmLogo(bank);
  }

  Future<void> _pickBank() async {
    final picked = await showModalBottomSheet<VietQrBank>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BankPicker(),
    );
    if (picked == null || !mounted) return;
    _controller.selectBank(picked);
    await _warmLogo(picked);
  }

  /// Nạp sẵn logo vào bộ nhớ ảnh.
  ///
  /// Ảnh xuất ra là bản chụp lại đúng những gì đang vẽ, mà [Image.asset] giải mã
  /// file ở khung hình sau — bấm tải ngay lúc vừa chọn ngân hàng thì logo kịp
  /// trống trong tấm ảnh.
  Future<void> _warmLogo(VietQrBank bank) =>
      precacheImage(AssetImage(bank.logoAsset), context);

  Future<void> _copyAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: _controller.accountNumber.trim()),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Đã copy số tài khoản')),
    );
  }

  /// Kéo thẻ vào tầm nhìn rồi đợi vẽ xong khung hình.
  ///
  /// [ListView] chỉ dựng phần đang nhìn thấy, mà thẻ đã cuộn khỏi màn thì không
  /// còn lớp vẽ nào để lấy ảnh ra. Chưa dựng thì cuộn xuống đáy — thẻ nằm ngay
  /// trên nút tải nên xuống tới đáy là chắc chắn có nó.
  Future<void> _showCard() async {
    if (_cardKey.currentContext == null && _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
    }
    final cardContext = _cardKey.currentContext;
    if (cardContext == null || !cardContext.mounted) return;
    await Scrollable.ensureVisible(
      cardContext,
      duration: const Duration(milliseconds: 200),
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Mở danh sách mã đã lưu, chọn một cái thì nạp thẳng vào form.
  Future<void> _openSaved() async {
    final picked = await showModalBottomSheet<SavedQr>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SavedList(controller: _controller),
    );
    if (picked == null || !mounted) return;
    _controller.loadSaved(picked);
    _syncFields();
  }

  Future<void> _remember() async {
    await _controller.remember();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu mã, lần sau khỏi nhập lại')),
    );
  }

  Future<void> _download() async {
    await _showCard();
    if (!mounted) return;
    final outcome = await _controller.download(_cardKey);
    if (outcome == null || !mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.message),
        backgroundColor: outcome.failed ? scheme.errorContainer : null,
        showCloseIcon: outcome.failed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã QR nhận tiền'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _controller.history.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Mã đã lưu',
                    icon: Badge.count(
                      count: _controller.history.length,
                      child: const Icon(Icons.bookmarks_outlined),
                    ),
                    onPressed: _openSaved,
                  ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final bank = _controller.bank;
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: bank == null
                    ? const Icon(Icons.account_balance_rounded)
                    : BankLogo(bank),
                title: Text(bank?.shortName ?? 'Chọn ngân hàng'),
                subtitle: Text(
                  bank?.fullName ?? 'Ngân hàng đang giữ tài khoản nhận tiền',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickBank,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountField,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(qrAccountLimit),
                ],
                decoration: InputDecoration(
                  labelText: 'Số tài khoản',
                  hintText: '0123456789',
                  border: const OutlineInputBorder(),
                  errorText: _controller.error,
                  suffixIcon: _controller.accountNumber.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Copy số tài khoản',
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          onPressed: _copyAccount,
                        ),
                ),
                onChanged: _controller.accountChanged,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _holderField,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tên chủ tài khoản (không bắt buộc)',
                  hintText: 'NGUYEN VAN A',
                  helperText: 'Chỉ in lên ảnh. App ngân hàng tự hiện tên thật.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                onChanged: _controller.holderChanged,
              ),
              const SizedBox(height: 24),
              Text(
                'Điền sẵn cho người chuyển',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Bỏ trống cả hai ô dưới thì mã dùng lại được nhiều lần, người '
                'chuyển tự gõ số tiền.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountField,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  // Giới hạn của ô số tiền trong mã QR. Chặn ở đây thì lỗi
                  // "số tiền lớn quá" không bao giờ phải hiện ra.
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: InputDecoration(
                  labelText: 'Số tiền',
                  suffixText: 'đ',
                  border: const OutlineInputBorder(),
                  helperText: _controller.amount == null
                      ? null
                      : formatMoney(_controller.amount!),
                ),
                onChanged: (value) {
                  final amount = parseAmount(value);
                  _controller.amountChanged(amount == 0 ? null : amount);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteField,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nội dung chuyển khoản',
                  hintText: 'Tra tien com trua',
                  border: const OutlineInputBorder(),
                  helperText: _controller.normalizedNote.isEmpty
                      ? 'Tối đa $qrNoteLimit ký tự, dấu tiếng Việt sẽ bị bỏ'
                      : 'Người chuyển thấy: ${_controller.normalizedNote}',
                  helperMaxLines: 2,
                ),
                onChanged: _controller.noteChanged,
              ),
              const SizedBox(height: 28),
              Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: _QrCard(
                    payload: _controller.payload,
                    bank: bank,
                    accountNumber: _controller.accountNumber.trim(),
                    holderName: _controller.holderName.trim(),
                    amount: _controller.amount,
                    note: _controller.normalizedNote,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _controller.ready && !_controller.busy
                    ? _download
                    : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Tải ảnh mã QR về'),
              ),
              const SizedBox(height: 8),
              // Tải ảnh về cũng tự lưu, nhưng không phải lần nào cũng cần ảnh:
              // nhiều lúc chỉ chìa màn hình ra cho người ta quét.
              OutlinedButton.icon(
                onPressed: _controller.ready && !_controller.saved
                    ? _remember
                    : null,
                icon: Icon(
                  _controller.saved
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                ),
                label: Text(_controller.saved ? 'Đã lưu mã này' : 'Lưu mã này'),
              ),
              const SizedBox(height: 8),
              Text(
                'Android không cho app tự ghi vào thư mục của bạn, nên ảnh đi '
                'qua bảng chia sẻ của hệ thống — chọn "Lưu vào tệp", Ảnh, hay '
                'gửi thẳng cho người cần chuyển tiền.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Nền trắng chữ đen cố định, không theo theme của app: ảnh này đi ra ngoài để
/// người khác quét, mà mã QR nền tối thì nhiều máy đọc không ra.
const Color _cardSurface = Color(0xFFFFFFFF);
const Color _cardInk = Color(0xFF1B1B1F);
const Color _cardMuted = Color(0xFF6B6B72);
const Color _cardLine = Color(0xFFE3E3E8);

/// Thẻ sẽ được xuất thành ảnh: mã QR cùng những dòng chữ người nhận ảnh cần để
/// biết mình sắp chuyển cho ai.
class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.payload,
    required this.bank,
    required this.accountNumber,
    required this.holderName,
    required this.amount,
    required this.note,
  });

  final String? payload;
  final VietQrBank? bank;
  final String accountNumber;
  final String holderName;
  final int? amount;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo đã có sẵn tên ngân hàng trong đó, nên không in thêm chữ nữa.
          if (bank case final bank?)
            BankLogo(bank, height: 38, framed: false)
          else
            const Text(
              'VietQR',
              style: TextStyle(
                color: _cardInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            height: 240,
            child: payload == null
                ? const _QrPlaceholder()
                : QrImageView(
                    data: payload!,
                    size: 240,
                    padding: EdgeInsets.zero,
                    backgroundColor: _cardSurface,
                    // Mức M chịu được vết bẩn, nếp gấp và ảnh chụp lại màn
                    // hình; mức L mặc định thì mã đi vòng qua ba cái Zalo là
                    // hết quét được.
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _cardInk,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _cardInk,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (holderName.isNotEmpty)
            Text(
              holderName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _cardInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (accountNumber.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                accountNumber,
                style: const TextStyle(
                  color: _cardInk,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          if (amount != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                formatMoney(amount!),
                style: const TextStyle(
                  color: _cardInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _cardMuted, fontSize: 13),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: _cardLine),
          ),
          const Text(
            'Quét bằng app ngân hàng bất kỳ',
            style: TextStyle(color: _cardMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Chỗ của mã QR khi chưa đủ dữ liệu — giữ nguyên kích thước thẻ để nó không
/// nhảy lên nhảy xuống theo từng chữ user gõ.
class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _cardLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chọn ngân hàng và nhập số tài khoản để hiện mã',
            textAlign: TextAlign.center,
            style: TextStyle(color: _cardMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// Những mã đã lưu. Chạm một dòng là nạp lại vào form, nút thùng rác thì bỏ.
///
/// Nghe thẳng controller thay vì nhận sẵn danh sách: xoá xong sheet phải tự vẽ
/// lại, mà sheet thì nằm ngoài cây widget của màn hình bên dưới.
class _SavedList extends StatelessWidget {
  const _SavedList({required this.controller});

  final QrController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final history = controller.history;
          return Column(
            children: [
              ListTile(
                title: Text(
                  'Mã đã lưu',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Chạm để dùng lại'),
              ),
              const Divider(height: 1),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('Không còn mã nào đã lưu'))
                    : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) =>
                            _savedTile(context, history[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _savedTile(BuildContext context, SavedQr entry) {
    final bank = bankByBin(entry.bankBin);
    final holder = entry.holderName.trim();
    final note = normalizeQrNote(entry.note);
    return ListTile(
      leading: bank == null
          ? const Icon(Icons.account_balance_rounded)
          : BankLogo(bank),
      title: Text(
        holder.isEmpty ? (bank?.shortName ?? 'VietQR') : holder.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          entry.accountNumber,
          if (entry.amount != null) formatMoney(entry.amount!),
          if (note.isNotEmpty) note,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Bỏ mã này',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () => controller.forget(entry),
      ),
      onTap: () => Navigator.of(context).pop(entry),
    );
  }
}

/// Danh sách ngân hàng kèm ô tìm — bốn mươi dòng thì cuộn tay lâu hơn gõ.
class _BankPicker extends StatefulWidget {
  const _BankPicker();

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = searchBanks(_query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm ngân hàng...',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Không có ngân hàng nào khớp'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, index) {
                        final bank = matches[index];
                        return ListTile(
                          leading: BankLogo(bank),
                          title: Text(bank.shortName),
                          subtitle: Text(
                            bank.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(bank),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
