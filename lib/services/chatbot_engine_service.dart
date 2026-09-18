import '../models/chat_option.dart';
import 'chatbot_local_data_service.dart';

class ChatbotEngineService {
  final ChatbotLocalDataService localDataService;

  ChatbotEngineService(this.localDataService);

  String? currentFlow;
  String? currentStep;

  final Map<String, dynamic> draftTransaction = {};

  String getWelcomeMessage() {
    return 'Hi! Let’s manage your business.';
  }

  List<ChatOption> getCurrentOptions() {
    if (currentFlow == null || currentStep == null) {
      return [
        ChatOption(label: 'Add Income', action: 'add_income'),
        ChatOption(label: 'Add Expense', action: 'add_expense'),
        ChatOption(label: 'Add Purchase', action: 'add_purchase'),
        ChatOption(label: 'Today Summary', action: 'today_summary'),
        ChatOption(label: 'month summary', action: 'month_summary'),
        ChatOption(label: 'Profit/Loss', action: 'profit_loss'),
        ChatOption(label: 'deleted transaction help', action: 'restore_help'),
        ChatOption(label: 'Deleted Business Help', action: 'restore_business_help'),
        ChatOption(label: 'Receipt Issue', action: 'receipt_issue'),
        ChatOption(label: 'Sync Issue', action: 'sync_issue'),
        ChatOption(label: 'Reports', action: 'reports'),
      ];
    }

    if (currentStep == 'category') {
      if (currentFlow == 'Income') {
        return [
          ChatOption(label: 'Sales', action: 'category:Sales'),
          ChatOption(label: 'Service Income', action: 'category:Service Income'),
          ChatOption(
            label: 'Advance Received',
            action: 'category:Advance Received',
          ),
          ChatOption(label: 'Other Income', action: 'category:Other Income'),
          ChatOption(label: 'Enter Other', action: 'category:Other'),
          ChatOption(label: 'Cancel', action: 'cancel_transaction'),
        ];
      }

      if (currentFlow == 'Expense') {
        return [
          ChatOption(label: 'Tea', action: 'category:Tea'),
          ChatOption(label: 'Transport', action: 'category:Transport'),
          ChatOption(label: 'Rent', action: 'category:Rent'),
          ChatOption(label: 'Salary', action: 'category:Salary'),
          ChatOption(label: 'Other Expense', action: 'category:Other Expense'),
          ChatOption(label: 'Enter Other', action: 'category:Other'),
          ChatOption(label: 'Cancel', action: 'cancel_transaction'),
        ];
      }

      return [
        ChatOption(label: 'Stock', action: 'category:Stock'),
        ChatOption(label: 'Material', action: 'category:Material'),
        ChatOption(label: 'Office Items', action: 'category:Office Items'),
        ChatOption(label: 'Raw Material', action: 'category:Raw Material'),
        ChatOption(label: 'Other Purchase', action: 'category:Other Purchase'),
        ChatOption(label: 'Enter Other', action: 'category:Other'),
        ChatOption(label: 'Cancel', action: 'cancel_transaction'),
      ];
    }

    if (currentStep == 'payment') {
      return [
        ChatOption(label: 'Cash', action: 'payment:Cash'),
        ChatOption(label: 'UPI', action: 'payment:UPI'),
        ChatOption(label: 'Bank Transfer', action: 'payment:Bank Transfer'),
        ChatOption(label: 'Card', action: 'payment:Card'),
        ChatOption(label: 'Enter Other', action: 'payment:Other'),
        ChatOption(label: 'Cancel', action: 'cancel_transaction'),
      ];
    }

    if (currentStep == 'date') {
      return [
        ChatOption(label: 'Today', action: 'date:Today'),
        ChatOption(label: 'Yesterday', action: 'date:Yesterday'),
        ChatOption(label: 'Enter Custom', action: 'date:Other'),
        ChatOption(label: 'Cancel', action: 'cancel_transaction'),
      ];
    }

    if (currentStep == 'confirm') {
      return [
        ChatOption(label: 'Save', action: 'save_transaction'),
        ChatOption(label: 'Edit', action: 'edit_transaction'),
        ChatOption(label: 'Cancel', action: 'cancel_transaction'),
      ];
    }

    return [
      ChatOption(label: 'Cancel', action: 'cancel_transaction'),
    ];
  }

  String handleAction(String action) {
    if (action == 'add_income') {
      return _startTransactionFlow('Income');
    }

    if (action == 'add_expense') {
      return _startTransactionFlow('Expense');
    }

    if (action == 'add_purchase') {
      return _startTransactionFlow('Purchase');
    }

    if (action.startsWith('category:')) {
      final category = action.replaceFirst('category:', '');
      
      if (category.toLowerCase() == 'other') {
        return 'Enter category:';
      }
      
      draftTransaction['category'] = category;
      currentStep = 'payment';

      return 'Select payment mode:';
    }

    if (action.startsWith('payment:')) {
      final paymentMode = action.replaceFirst('payment:', '');
      
      if (paymentMode.toLowerCase() == 'other') {
        return '''
Please enter your custom payment mode (e.g., Cash+Card, Cheque, etc.):
''';
      }
      
      draftTransaction['paymentMode'] = paymentMode;
      currentStep = 'date';

      return '''
Payment mode selected: $paymentMode

Select transaction date:
''';
    }

    if (action.startsWith('date:')) {
      final date = action.replaceFirst('date:', '');
      
      if (date.toLowerCase() == 'other') {
        return '''
Please enter the date in mm/dd/yyyy:
''';
      }
      
      draftTransaction['date'] = date;
      currentStep = 'confirm';

      return _buildConfirmationMessage();
    }

    if (action == 'save_transaction') {
      return _saveTransaction();
    }

    if (action == 'edit_transaction') {
      final type = currentFlow ?? 'Transaction';

      currentStep = 'amount';
      draftTransaction.clear();
      draftTransaction['type'] = type;

      return 'Re-enter ${type.toLowerCase()} amount:';
    }

    if (action == 'cancel_transaction') {
      _clearFlow();

      return 'Cancelled. What next?';
    }

    switch (action) {
      case 'main_menu':
        _clearFlow();
        return getWelcomeMessage();

      case 'today_summary':
        return localDataService.getTodaySummary();

      case 'month_summary':
        return localDataService.getMonthSummary();

      case 'profit_loss':
        return localDataService.getMonthProfit();

      case 'restore_help':
        return 'Restore transaction steps:\n1. Go to Quick Access\n2. Tap Backup and Sync\n3. Select Restore Data\n4. Choose your business';

      case 'restore_business_help':
        return 'Deleted business recovery steps:\n1. Go to Quick Access\n2. Tap Backup and Sync\n3. Select Restore Data\n4. Choose your business';

      case 'receipt_issue':
        return '1. Open business\n2. Tap Scan button\n3. Capture receipt clearly\n4. Check amount visible\n5. Avoid blur/shadows';

      case 'sync_issue':
        return '1. Check internet\n2. Check login\n3. Refresh dashboard\n4. Close & reopen app';

      case 'reports':
        return '1. Open Reports\n2. Select date\n3. Choose type\n4. Export PDF/Excel';

      default:
        return 'Not clear, choose from menu';
    }
  }

  String handleUserMessage(String message) {
    final text = message.toLowerCase().trim();

    if (text.isEmpty) {
      return 'Type something or choose option';
    }

    if (currentFlow != null && currentStep != null) {
      return _handleTransactionTextInput(message);
    }

    if (text.contains('add') && text.contains('income')) {
      return _startTransactionFlow('Income');
    }

    if (text.contains('add') && (text.contains('expense') || text.contains('expence'))) {
      _startTransactionFlow('Expense');
      final extractedAmount = _extractAmountFromText(text);
      if (extractedAmount != null) {
        return _handleTransactionTextInput(message);
      }
      return 'Enter expense amount:';
    }

    if (text.contains('add') && text.contains('purchase')) {
      _startTransactionFlow('Purchase');
      final extractedAmount = _extractAmountFromText(text);
      if (extractedAmount != null) {
        return _handleTransactionTextInput(message);
      }
      return 'Enter purchase amount:';
    }

    if (text.contains('today') && text.contains('summary')) {
      return localDataService.getTodaySummary();
    }

    if ((text.contains('this month') || text.contains('month')) &&
        text.contains('summary')) {
      return localDataService.getMonthSummary();
    }

    if (text.contains('today') && text.contains('income')) {
      return localDataService.getTodayIncome();
    }

    if (text.contains('today') && text.contains('expense')) {
      return localDataService.getTodayExpense();
    }

    if (text.contains('today') && text.contains('purchase')) {
      return localDataService.getTodayPurchase();
    }

    if ((text.contains('this month') || text.contains('month')) &&
        text.contains('income')) {
      return localDataService.getMonthIncome();
    }

    if ((text.contains('this month') || text.contains('month')) &&
        text.contains('expense')) {
      return localDataService.getMonthExpense();
    }

    if ((text.contains('this month') || text.contains('month')) &&
        text.contains('purchase')) {
      return localDataService.getMonthPurchase();
    }

    if (text.contains('profit') || text.contains('loss')) {
      return localDataService.getMonthProfit();
    }

    if (text.contains('receipt') ||
        text.contains('bill') ||
        text.contains('scan') ||
        text.contains('ocr') ||
        text.contains('amount not detecting') ||
        text.contains('wrong amount')) {
      return handleAction('receipt_issue');
    }

    final restoreIndexMatch = RegExp(r'restore(?:\s+transaction)?\s+(\d+)', caseSensitive: false).firstMatch(text);
    if (restoreIndexMatch != null) {
      final index = int.tryParse(restoreIndexMatch.group(1)!);
      if (index != null) {
        return _restoreDeletedTransactionByIndex(index);
      }
    }

    if (text.contains('restore') ||
        text.contains('undelete') ||
        text.contains('undo delete') ||
        text.contains('recover deleted')) {
      return _restoreLastDeletedTransaction();
    }

    if (text.contains('restore help') ||
        text.contains('how to restore') ||
        text.contains('restore transaction help')) {
      return handleAction('restore_help');
    }

    if (text.contains('deleted business') ||
        text.contains('restore business') ||
        text.contains('business restore')) {
      return handleAction('restore_business_help');
    }

    if (text.contains('sync') ||
        text.contains('data not showing') ||
        text.contains('another phone') ||
        text.contains('another mobile') ||
        text.contains('cloud') ||
        text.contains('backup')) {
      return handleAction('sync_issue');
    }

    if (text.contains('report') ||
        text.contains('pdf') ||
        text.contains('excel') ||
        text.contains('export') ||
        text.contains('statement')) {
      return handleAction('reports');
    }


    return 'Sorry, not clear. Try: Add income/expense/purchase, Today summary, Profit/loss';
  }

  String _startTransactionFlow(String type) {
    currentFlow = type;
    currentStep = 'amount';

    draftTransaction.clear();
    draftTransaction['type'] = type;

    return 'Enter $type amount:';
  }

  String _handleTransactionTextInput(String input) {
    final cleanInput = input.trim();

    if (currentStep == 'amount') {
      var amount = double.tryParse(cleanInput.replaceAll(',', ''));
      if (amount == null) {
        amount = _extractAmountFromText(cleanInput);
      }

      if (amount == null || amount <= 0) {
        return 'Invalid amount';
      }

      draftTransaction['amount'] = amount;

      if (currentFlow == 'Purchase') {
        final vendor = _parseVendor(cleanInput);
        if (vendor != null && vendor.isNotEmpty) {
          draftTransaction['vendor'] = vendor;
          currentStep = 'category';
          return 'Select category:';
        }

        currentStep = 'vendor';
        return 'Enter vendor name:';
      }

      final category = _parseCategory(cleanInput, currentFlow ?? '');
      if (category != null) {
        draftTransaction['category'] = category;
        currentStep = 'payment';
        return 'Select payment mode:';
      }

      currentStep = 'category';
      return 'Select category:';
    }

    if (currentStep == 'vendor') {
      if (cleanInput.isEmpty) {
        return 'Enter vendor name';
      }

      draftTransaction['vendor'] = cleanInput;
      currentStep = 'category';

      return 'Select category:';
    }

    if (currentStep == 'category') {
      draftTransaction['category'] = cleanInput;
      currentStep = 'payment';

      return 'Select payment mode:';
    }

    if (currentStep == 'payment') {
      draftTransaction['paymentMode'] = cleanInput;
      currentStep = 'date';

      return 'Select date:';
    }

    if (currentStep == 'date') {
      // Validate mm/dd/yyyy format
      final dateRegex = RegExp(r'^(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/\d{4}$');
      
      if (!dateRegex.hasMatch(cleanInput)) {
        return 'Use mm/dd/yyyy format';
      }
      
      draftTransaction['date'] = cleanInput;
      currentStep = 'confirm';

      return _buildConfirmationMessage();
    }

    if (currentStep == 'confirm') {
      final lower = cleanInput.toLowerCase();

      if (lower == 'save' || lower == 'yes' || lower == 'confirm') {
        return _saveTransaction();
      }

      if (lower == 'cancel' || lower == 'no') {
        _clearFlow();
        return 'Transaction cancelled.';
      }

      return 'Tap Save, Edit, or Cancel';
    }

    return 'Continue with transaction';
  }

  String _buildConfirmationMessage() {
    final String type = draftTransaction['type']?.toString() ?? '';
    final double amount =
        (draftTransaction['amount'] as num?)?.toDouble() ?? 0.0;
    final String category = draftTransaction['category']?.toString() ?? '';
    final String paymentMode = draftTransaction['paymentMode']?.toString() ?? '';
    final String date = draftTransaction['date']?.toString() ?? '';
    final String? vendor = draftTransaction['vendor']?.toString();

    final String vendorLine = vendor == null ? '' : '\nVendor: $vendor';

    return '$type: ${localDataService.formatAmount(amount)}$vendorLine\nCategory: $category\nPayment: $paymentMode\nDate: $date';
  }

  String _saveTransaction() {
    final String type = draftTransaction['type']?.toString() ?? 'Transaction';
    final double amount =
        (draftTransaction['amount'] as num?)?.toDouble() ?? 0.0;
    final String category = draftTransaction['category']?.toString() ?? '';
    final String paymentMode = draftTransaction['paymentMode']?.toString() ?? '';
    final String date = draftTransaction['date']?.toString() ?? '';
    final String? vendor = draftTransaction['vendor']?.toString();

    if (amount <= 0 || category.isEmpty || paymentMode.isEmpty || date.isEmpty) {
      return 'Missing details. Tap Edit';
    }

    localDataService.saveDemoTransaction(
      type: type,
      amount: amount,
      category: category,
      paymentMode: paymentMode,
      date: date,
      vendor: vendor,
    );

    final successMessage = '$type ${localDataService.formatAmount(amount)} saved!\n\nUpdated Summary:\n${localDataService.getMonthSummary()}';

    _clearFlow();

    return successMessage;
  }

  String _restoreLastDeletedTransaction() {
    if (localDataService.deletedDemoTransactions.isEmpty) {
      return 'No deleted transactions';
    }

    final bool success = localDataService.restoreDeletedDemoTransaction();
    if (!success) {
      return 'Restore failed';
    }

    return 'Restored!\n\n${localDataService.getMonthSummary()}';
  }

  String _restoreDeletedTransactionByIndex(int index) {
    if (localDataService.deletedDemoTransactions.isEmpty) {
      return 'No deleted transactions';
    }

    final bool success = localDataService.restoreDeletedDemoTransaction(index: index - 1);
    if (!success) {
      return 'Can\'t restore #$index';
    }

    return 'Restored #$index!\n\n${localDataService.getMonthSummary()}';
  }

  void _clearFlow() {
    currentFlow = null;
    currentStep = null;
    draftTransaction.clear();
  }

  /// Main method to parse voice commands and handle voice-based transactions
  String handleVoiceCommand(String voiceText) {
    final lowerText = voiceText.toLowerCase();
    
    // Parse transaction type
    final transactionType = _parseTransactionType(lowerText);
    if (transactionType == null) {
      return 'Can\'t detect type. Try again';
    }
    
    // Start the transaction flow
    _startTransactionFlow(transactionType);
    
    // Parse and populate available fields
    final amount = _parseAmount(lowerText);
    final category = _parseCategory(lowerText, transactionType);
    final paymentMode = _parsePaymentMode(lowerText);
    final date = _parseDate(lowerText);
    final vendor = _parseVendor(lowerText);
    
    // Set parsed values in draft transaction
    if (amount != null) {
      draftTransaction['amount'] = amount;
    }
    if (category != null) {
      draftTransaction['category'] = category;
    }
    if (paymentMode != null) {
      draftTransaction['paymentMode'] = paymentMode;
    }
    if (date != null) {
      draftTransaction['date'] = date;
    }
    if (vendor != null) {
      draftTransaction['vendor'] = vendor;
    }
    
    // Check if all required fields are available
    final requiredFields = ['amount', 'category', 'paymentMode', 'date'];
    final allFieldsPresent = requiredFields.every((field) => draftTransaction.containsKey(field) && draftTransaction[field] != null);
    
    if (allFieldsPresent) {
      // All fields found, return confirmation message
      return _buildConfirmationMessage();
    } else {
      // Missing some fields, return error
      return 'Missing details. Type manually';
    }
  }

  /// Detects transaction type from voice text
  String? _parseTransactionType(String text) {
    if (text.contains('income') || text.contains('earn') || text.contains('received') || text.contains('got')) {
      return 'Income';
    }
    if (text.contains('expense') || text.contains('spent') || text.contains('paid') || text.contains('cost me')) {
      return 'Expense';
    }
    if (text.contains('purchase') || text.contains('buy') || text.contains('bought') || text.contains('material')) {
      return 'Purchase';
    }
    return null;
  }

  /// Extracts numeric amount from text using regex
  double? _parseAmount(String text) {
    // Match amounts like "100", "1000", "50.50", etc.
    final regex = RegExp(r'\b(\d+(?:\.\d{1,2})?)\b');
    final match = regex.firstMatch(text);
    if (match != null) {
      final amountStr = match.group(1);
      return double.tryParse(amountStr ?? '');
    }
    return null;
  }

  double? _extractAmountFromText(String text) {
    final regex = RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)');
    final match = regex.firstMatch(text.replaceAll(RegExp(r'[^\d.,]'), ' '));
    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      return double.tryParse(amountStr ?? '');
    }
    return null;
  }

  /// Extracts category based on transaction type and keywords
  String? _parseCategory(String text, String transactionType) {
    if (transactionType == 'Income') {
      if (text.contains('sales')) return 'Sales';
      if (text.contains('service')) return 'Service Income';
      if (text.contains('advance')) return 'Advance Received';
      if (text.contains('other income')) return 'Other Income';
      return null;
    }
    
    if (transactionType == 'Expense') {
      if (text.contains('tea')) return 'Tea';
      if (text.contains('transport')) return 'Transport';
      if (text.contains('rent')) return 'Rent';
      if (text.contains('salary')) return 'Salary';
      if (text.contains('other expense')) return 'Other Expense';
      return null;
    }
    
    if (transactionType == 'Purchase') {
      if (text.contains('stock')) return 'Stock';
      if (text.contains('raw material') || text.contains('raw')) return 'Raw Material';
      if (text.contains('material')) return 'Material';
      if (text.contains('office')) return 'Office Items';
      if (text.contains('other purchase')) return 'Other Purchase';
      return null;
    }
    
    return null;
  }

  /// Extracts payment mode from text
  String? _parsePaymentMode(String text) {
    if (text.contains('cash') || text.contains('hand')) {
      return 'Cash';
    }
    if (text.contains('upi') || text.contains('google pay') || text.contains('phone pay')) {
      return 'UPI';
    }
    if (text.contains('bank') || text.contains('transfer') || text.contains('neft') || text.contains('rtgs')) {
      return 'Bank Transfer';
    }
    if (text.contains('card') || text.contains('credit') || text.contains('debit')) {
      return 'Card';
    }
    return null;
  }

  /// Extracts date from text
  String? _parseDate(String text) {
    if (text.contains('today')) {
      return 'Today';
    }
    if (text.contains('yesterday')) {
      return 'Yesterday';
    }
    return null;
  }

  /// Extracts vendor name from text using regex (words that follow "from", "supplier", "to", or "with")
  String? _parseVendor(String text) {
    final patterns = [
      RegExp(r'(?:from|supplier|to)\s+([a-zA-Z0-9\s]+?)(?:\s+(?:material|stock|office|raw|bank|upi|cash|card|today|yesterday|paid|for|on|with|at)|$)', caseSensitive: false),
      RegExp(r'(?:with)\s+([a-zA-Z0-9\s]+?)(?:\s+(?:for|at)|$)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final vendor = match.group(1)?.trim();
        if (vendor != null && vendor.isNotEmpty) {
          return vendor;
        }
      }
    }
    
    return null;
  }
}

