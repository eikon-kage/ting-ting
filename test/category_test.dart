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

    test('tiền vào luôn là Thu nhập, không xét từ khoá', () {
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

  group('Bộ nhóm dựng sẵn', () {
    test('có đủ ba nhóm hệ thống và chúng được đánh dấu không xoá được', () {
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
