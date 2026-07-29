const _withDiacritics =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
    'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _withoutDiacritics =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
    'ooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Bỏ dấu tiếng Việt để so khớp từ khoá bất kể chữ có dấu hay không.
String removeDiacritics(String input) {
  final buffer = StringBuffer();
  for (final char in input.split('')) {
    final i = _withDiacritics.indexOf(char);
    buffer.write(i >= 0 ? _withoutDiacritics[i] : char);
  }
  return buffer.toString();
}

/// Chuẩn hoá để đối chiếu từ khoá: bỏ dấu và về chữ thường.
String flatten(String input) => removeDiacritics(input.toLowerCase());
