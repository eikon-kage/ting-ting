import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/categorizer.dart';
import 'package:ting_ting/models/models.dart';

void main() {
  group('Category.parseKeywords', () {
    test('tách theo dấu phẩy lẫn xuống dòng, bỏ khoảng trắng thừa', () {
      expect(Category.parseKeywords(' hoc phi , sach vo\ndong phuc '), [
        'hoc phi',
        'sach vo',
        'dong phuc',
      ]);
    });

    test('bỏ dấu và về chữ thường để so khớp kiểu gõ nào cũng ra', () {
      expect(Category.parseKeywords('Học Phí'), ['hoc phi']);
    });

    test('ô trống thì không có từ khoá nào', () {
      expect(Category.parseKeywords('  '), isEmpty);
      expect(Category.parseKeywords(null), isEmpty);
    });

    test('gõ trùng một từ hai lần chỉ tính một', () {
      expect(Category.parseKeywords('grab, GRAB, grab'), ['grab']);
    });
  });

  group('Category.sameName', () {
    test('khác dấu hay hoa thường vẫn là một nhóm', () {
      expect(Category.sameName('Ăn uống', 'an uong'), isTrue);
      expect(Category.sameName('Ăn uống', ' ĂN UỐNG '), isTrue);
    });

    test('tên khác nhau thì là hai nhóm', () {
      expect(Category.sameName('Ăn uống', 'Ăn vặt'), isFalse);
    });
  });

  group('Nhóm do user tự đặt', () {
    final categories = [
      const Category(name: Category.income, builtIn: true),
      const Category(name: 'Con cái', keywords: ['hoc phi', 'sua bot']),
      const Category(name: Category.uncategorized, builtIn: true),
    ];

    test('từ khoá của nhóm mới được dùng để đoán nhóm', () {
      expect(
        Categorizer.categorize(
          'Thanh toan HOC PHI thang 8',
          TxnDirection.expense,
          categories: categories,
        ).category,
        'Con cái',
      );
    });

    test('nhóm mặc định đã bị xoá thì không còn được gán nữa', () {
      // "Đi lại" không nằm trong danh sách của user -> GRAB về nhóm Khác.
      expect(
        Categorizer.categorize(
          'Thanh toan GRAB',
          TxnDirection.expense,
          categories: categories,
        ).category,
        Category.uncategorized,
      );
    });

    test('quy tắc của user vẫn được xét trước từ khoá của nhóm', () {
      final suggestion = Categorizer.categorize(
        'Thanh toan hoc phi cho me',
        TxnDirection.expense,
        userRules: [
          Rule(keyword: 'cho mẹ', category: 'Gia đình', autoExclude: true),
        ],
        categories: categories,
      );

      expect(suggestion.category, 'Gia đình');
      expect(suggestion.excluded, isTrue);
    });

    test('tiền vào không ăn từ khoá của nhóm chi', () {
      // "hoc phi" là từ khoá của nhóm Con cái, nhưng nhóm đó dành cho khoản
      // chi — tiền vào rơi về nhóm mặc định.
      expect(
        Categorizer.categorize(
          'Nhan tien hoc phi',
          TxnDirection.income,
          categories: categories,
        ).category,
        Category.income,
      );
    });
  });

  group('Nhóm suy ra từ ghi chú', () {
    final categories = [
      const Category(name: Category.income, builtIn: true),
      const Category(name: 'Ăn uống', keywords: ['highlands', 'an uong']),
      const Category(name: 'Con cái', keywords: ['hoc phi']),
      const Category(name: Category.uncategorized, builtIn: true),
    ];

    CategorySuggestion? note(String text, {List<Rule> rules = const []}) =>
        Categorizer.categorizeNote(
          text,
          userRules: rules,
          categories: categories,
        );

    test('gõ thẳng tên nhóm là trúng nhóm đó', () {
      expect(note('ăn uống')?.category, 'Ăn uống');
    });

    test('tên nhóm nhận ra cả khi gõ không dấu, chữ thường', () {
      expect(note('AN UONG voi sep')?.category, 'Ăn uống');
    });

    test('từ khoá của nhóm cũng ăn, không riêng gì tên', () {
      expect(note('cà phê highlands')?.category, 'Ăn uống');
    });

    test('nhóm chưa khai từ khoá nào vẫn gọi được bằng tên', () {
      expect(
        Categorizer.categorizeNote(
          'con cái',
          categories: const [Category(name: 'Con cái')],
        )?.category,
        'Con cái',
      );
    });

    test('ghi chú không nhắc tới nhóm nào thì giữ nguyên nhóm cũ', () {
      expect(note('trả tiền cho anh Hùng'), isNull);
      expect(note(''), isNull);
      expect(note('   '), isNull);
    });

    test('"khách sạn" không bị hiểu thành nhóm Khác', () {
      expect(note('khách sạn Đà Lạt'), isNull);
    });

    test(
      'quy tắc của user được xét trước, kèm cả yêu cầu loại khỏi báo cáo',
      () {
        final suggestion = note(
          'học phí cho mẹ',
          rules: [
            Rule(keyword: 'cho mẹ', category: 'Gia đình', autoExclude: true),
          ],
        );

        expect(suggestion?.category, 'Gia đình');
        expect(suggestion?.excluded, isTrue);
      },
    );

    test('tên nhóm thắng từ khoá của nhóm khác đứng trên', () {
      // "hoc phi" là từ khoá của Con cái, nhưng user gọi thẳng tên Ăn uống.
      expect(note('hoc phi va an uong')?.category, 'Ăn uống');
    });

    test('chiều tiền không xen vào: ghi chú trên khoản thu vẫn ăn', () {
      // Khác [Categorizer.categorize], nơi tiền vào luôn là Thu nhập.
      expect(note('ăn uống')?.category, isNot(Category.income));
    });
  });

  group('Bộ nhóm dựng sẵn', () {
    test('nhóm hệ thống nào cũng có mặt và được đánh dấu không xoá được', () {
      for (final name in Category.builtInNames) {
        final category = defaultCategories.firstWhere((c) => c.name == name);
        expect(category.builtIn, isTrue, reason: name);
      }
    });

    test('không có hai nhóm trùng tên', () {
      final names = defaultCategories.map((c) => c.name).toSet();
      expect(names.length, defaultCategories.length);
    });

    test('từ khoá dựng sẵn đã ở dạng bỏ dấu, chữ thường', () {
      for (final category in defaultCategories) {
        expect(
          category.keywords,
          Category.parseKeywords(category.keywords.join(',')),
          reason: category.name,
        );
      }
    });
  });
}
