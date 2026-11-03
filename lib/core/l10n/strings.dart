/// Translatable strings (English / Hindi) from the artifact's `TR` table.
class Strings {
  static const Map<String, Map<String, String>> _tr = {
    'en': {
      'home': 'Home',
      'se': 'Search',
      'md': 'My Designs',
      'me': 'Profile',
      'studio': 'Studio',
      'h1': 'Create beautiful promotional images in minutes',
      'sub': 'Pick a design, customize it, and share your design.',
      'start': 'Start Creating',
      'ph': 'Search designs, occasions...',
      'pop': 'Popular Designs',
      'trend': 'Trending Designs',
      'rec': 'Recently Added',
      'use': 'Use',
      'tag': 'Create. Customize. Share.',
      'save': 'Save',
      'prev': 'Preview',
      'cust': 'Customize Design',
      'sbi': 'Search by Image',
      'cat': 'Categories',
      'exp': 'Export JPG',
      'share': 'Share',
      'login': 'Login',
      'free': 'Free',
      'prem': 'Premium',
    },
    'hi': {
      'home': 'होम',
      'se': 'खोजें',
      'md': 'मेरे डिज़ाइन',
      'me': 'प्रोफ़ाइल',
      'studio': 'स्टूडियो',
      'h1': 'मिनटों में सुंदर प्रचार चित्र बनाएं',
      'sub': 'डिज़ाइन चुनें, बदलें और अपना डिज़ाइन साझा करें।',
      'start': 'बनाना शुरू करें',
      'ph': 'डिज़ाइन, अवसर खोजें...',
      'pop': 'लोकप्रिय डिज़ाइन',
      'trend': 'ट्रेंडिंग डिज़ाइन',
      'rec': 'हाल ही में जोड़े गए',
      'use': 'इस्तेमाल करें',
      'tag': 'बनाएं। बदलें। साझा करें।',
      'save': 'सहेजें',
      'prev': 'पूर्वावलोकन',
      'cust': 'डिज़ाइन बदलें',
      'sbi': 'चित्र से खोजें',
      'cat': 'श्रेणियां',
      'exp': 'JPG निर्यात',
      'share': 'साझा करें',
      'login': 'लॉगिन',
      'free': 'मुफ़्त',
      'prem': 'प्रीमियम',
    },
  };

  const Strings(this.lang);

  /// `en` or `hi`.
  final String lang;

  bool get isHindi => lang == 'hi';

  /// Mirrors the artifact's `t(key)`.
  String call(String key) => _tr[lang]?[key] ?? _tr['en']![key] ?? key;

  // Onboarding / welcome modal copy (hard-coded per language in the artifact).
  String get introTitle =>
      isHindi ? 'Midas\'s Touch में आपका स्वागत है' : 'Welcome to Midas\'s Touch';

  List<List<String>> get introPoints => isHindi
      ? const [
          ['🔍', 'डिज़ाइन मुफ़्त में देखें'],
          ['📝', 'डाउनलोड के लिए रजिस्टर करें'],
          [
            '🪙',
            'कॉइन से बदलें · हर डिज़ाइन के लिए 1 कॉइन, बाद में दोबारा इस्तेमाल करें'
          ],
        ]
      : const [
          ['🔍', 'Explore designs for free'],
          ['📝', 'Register to download your design'],
          [
            '🪙',
            'Customise with coins · 1 coin per design, reuse it anytime'
          ],
        ];

  String get introStart => isHindi ? 'शुरू करें' : 'Start exploring';

  String get downloadLabel => isHindi ? 'डाउनलोड' : 'Download';
}
