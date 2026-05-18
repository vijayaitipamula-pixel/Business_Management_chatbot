class ChatbotLocalDataService {
  double todayIncome = 5000;
  double todayExpense = 1200;
  double todayPurchase = 2000;

  double monthIncome = 85000;
  double monthExpense = 32000;
  double monthPurchase = 18000;

  final List<Map<String, dynamic>> savedDemoTransactions = [];
  final List<Map<String, dynamic>> deletedDemoTransactions = [];

  double get todayProfit {
    return todayIncome - todayExpense - todayPurchase;
  }

  double get monthProfit {
    return monthIncome - monthExpense - monthPurchase;
  }

  String formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  String getTodaySummary() {
    return '''
Today Summary:

Income: ${formatAmount(todayIncome)}
Expense: ${formatAmount(todayExpense)}
Purchase: ${formatAmount(todayPurchase)}
Profit: ${formatAmount(todayProfit)}
''';
  }

  String getMonthSummary() {
    return '''
This Month Summary:

Income: ${formatAmount(monthIncome)}
Expense: ${formatAmount(monthExpense)}
Purchase: ${formatAmount(monthPurchase)}
Profit: ${formatAmount(monthProfit)}
''';
  }

  String getTodayIncome() {
    return 'Today income is ${formatAmount(todayIncome)}.';
  }

  String getTodayExpense() {
    return 'Today expense is ${formatAmount(todayExpense)}.';
  }

  String getTodayPurchase() {
    return 'Today purchase is ${formatAmount(todayPurchase)}.';
  }

  String getMonthIncome() {
    return 'This month income is ${formatAmount(monthIncome)}.';
  }

  String getMonthExpense() {
    return 'This month expense is ${formatAmount(monthExpense)}.';
  }

  String getMonthPurchase() {
    return 'This month purchase is ${formatAmount(monthPurchase)}.';
  }

  String getMonthProfit() {
    return 'This month profit is ${formatAmount(monthProfit)}.';
  }

  void saveDemoTransaction({
    required String type,
    required double amount,
    required String category,
    required String paymentMode,
    required String date,
    String? vendor,
  }) {
    savedDemoTransactions.add({
      'type': type,
      'amount': amount,
      'category': category,
      'paymentMode': paymentMode,
      'date': date,
      'vendor': vendor,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (type == 'Income') {
      todayIncome += amount;
      monthIncome += amount;
    } else if (type == 'Expense') {
      todayExpense += amount;
      monthExpense += amount;
    } else if (type == 'Purchase') {
      todayPurchase += amount;
      monthPurchase += amount;
    }
  }

  bool deleteDemoTransaction(int index) {
    if (index < 0 || index >= savedDemoTransactions.length) {
      return false;
    }

    final tx = savedDemoTransactions.removeAt(index);
    deletedDemoTransactions.add({
      ...tx,
      'deletedAt': DateTime.now().toIso8601String(),
    });
    _adjustSummaryForTransaction(tx, isRestore: false);
    return true;
  }

  bool restoreDeletedDemoTransaction({int? index}) {
    if (deletedDemoTransactions.isEmpty) {
      return false;
    }

    final restoreIndex = index ?? deletedDemoTransactions.length - 1;
    if (restoreIndex < 0 || restoreIndex >= deletedDemoTransactions.length) {
      return false;
    }

    final tx = Map<String, dynamic>.from(deletedDemoTransactions.removeAt(restoreIndex));
    tx.remove('deletedAt');
    savedDemoTransactions.add(tx);
    _adjustSummaryForTransaction(tx, isRestore: true);
    return true;
  }

  String getDeletedDemoTransactionsSummary() {
    if (deletedDemoTransactions.isEmpty) {
      return 'No deleted demo transactions available.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Deleted Demo Transactions:');

    for (int i = 0; i < deletedDemoTransactions.length; i++) {
      final tx = deletedDemoTransactions[i];
      final amount = (tx['amount'] as num).toDouble();
      final vendor = tx['vendor'];

      final details = StringBuffer();
      details.write('${tx['type']} - ${formatAmount(amount)}');
      if (vendor != null && vendor.toString().isNotEmpty) {
        details.write(' - Vendor: $vendor');
      }
      details.write(' - ${tx['category']} - ${tx['paymentMode']} - ${tx['date']}');
      buffer.writeln('${i + 1}. ${details.toString()}');
    }

    buffer.writeln('\nYou can restore the last deleted transaction by asking "Restore deleted transaction" or restore a specific one by number.');
    return buffer.toString();
  }

  void _adjustSummaryForTransaction(Map<String, dynamic> tx, {required bool isRestore}) {
    final amount = (tx['amount'] as num).toDouble();
    final type = tx['type']?.toString() ?? '';
    final delta = isRestore ? amount : -amount;

    if (type == 'Income') {
      todayIncome += delta;
      monthIncome += delta;
    } else if (type == 'Expense') {
      todayExpense += delta;
      monthExpense += delta;
    } else if (type == 'Purchase') {
      todayPurchase += delta;
      monthPurchase += delta;
    }
  }

  String getSavedDemoTransactionsSummary() {
    if (savedDemoTransactions.isEmpty) {
      return 'No demo transactions saved yet.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Saved Demo Transactions:');

    for (int i = 0; i < savedDemoTransactions.length; i++) {
      final tx = savedDemoTransactions[i];
      final amount = (tx['amount'] as num).toDouble();
      final vendor = tx['vendor'];

      final details = StringBuffer();
      details.write('${tx['type']} - ${formatAmount(amount)}');
      if (vendor != null && vendor.toString().isNotEmpty) {
        details.write(' - Vendor: $vendor');
      }
      details.write(' - ${tx['category']} - ${tx['paymentMode']} - ${tx['date']}');
      buffer.writeln('${i + 1}. ${details.toString()}');
    }

    return buffer.toString();
  }
}