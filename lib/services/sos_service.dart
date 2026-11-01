import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_info.dart';
import '../models/location_fix.dart';

/// Every message in each language, with {placeholders}. English stays in plain
/// ASCII where possible: one non-GSM character (even a long dash) cuts an SMS
/// segment from 160 characters to 70, which costs the user more and splits the
/// map link. The other languages always cost that, which the settings screen
/// says, so they're kept short.
const _phrases = <String, Map<String, String>>{
  'en': {
    'who': 'Your contact',
    'sos': 'SOS! {who} needs help now.',
    'sosFrom': 'SOS from {who}: {message}',
    'location': 'Location: {link} (within {metres} m, {time}).',
    'lastLocation': 'Last known location: {link} (within {metres} m, {time}).',
    'noLocation': 'Location unavailable right now.',
    'heading': 'Was heading to {place}.',
    'blood': 'Blood group {group}.',
    'call': 'Please call them.',
    'sentBy': 'Sent by {app}.',
    'update': '{app} update: SOS still active. {where}',
    'allClear': '{app}: {who} has marked themselves safe. The SOS has ended.',
    'test': 'This is a TEST from {app}. {who} added you as an emergency '
        'contact. No action is needed.',
    'walkStarted': '{app}: {who} started a Safe Walk{place} and should arrive '
        'by {time}. You will get an SOS if they do not check in.',
    'walkPlace': ' to {place}',
    'walkArrived': '{app}: {who} reached their destination. The Safe Walk has '
        'ended.',
    'lowBattery': '{app}: {who} is on a Safe Walk and their battery is at '
        '{level}%, so their phone may switch off. {where}',
  },
  'hi': {
    'who': 'आपके संपर्क',
    'sos': 'SOS! {who} को अभी मदद चाहिए।',
    'sosFrom': '{who} का SOS: {message}',
    'location': 'स्थान: {link} ({metres} मी के भीतर, {time})।',
    'lastLocation': 'आखिरी ज्ञात स्थान: {link} ({metres} मी के भीतर, {time})।',
    'noLocation': 'अभी स्थान उपलब्ध नहीं है।',
    'heading': 'मंज़िल: {place}।',
    'blood': 'ब्लड ग्रुप {group}।',
    'call': 'कृपया उन्हें कॉल करें।',
    'sentBy': '{app} से भेजा गया।',
    'update': '{app} अपडेट: SOS अभी जारी है। {where}',
    'allClear': '{app}: {who} ने खुद को सुरक्षित बताया है। SOS खत्म हो गया है।',
    'test': 'यह {app} का टेस्ट है। {who} ने आपको आपातकालीन संपर्क बनाया है। '
        'कुछ करने की ज़रूरत नहीं है।',
    'walkStarted': '{app}: {who} ने Safe Walk शुरू की है{place} और {time} तक '
        'पहुँचना है। चेक-इन न होने पर आपको SOS मिलेगा।',
    'walkPlace': ' (मंज़िल: {place})',
    'walkArrived': '{app}: {who} अपनी मंज़िल पर पहुँच गए हैं। Safe Walk खत्म हो '
        'गई है।',
    'lowBattery': '{app}: {who} Safe Walk पर हैं और बैटरी {level}% है, फ़ोन बंद '
        'हो सकता है। {where}',
  },
  'bn': {
    'who': 'আপনার পরিচিত',
    'sos': 'SOS! {who}-এর এখনই সাহায্য দরকার।',
    'sosFrom': '{who}-এর SOS: {message}',
    'location': 'অবস্থান: {link} ({metres} মিটারের মধ্যে, {time})।',
    'lastLocation': 'শেষ জানা অবস্থান: {link} ({metres} মিটারের মধ্যে, {time})।',
    'noLocation': 'এখন অবস্থান পাওয়া যাচ্ছে না।',
    'heading': 'গন্তব্য: {place}।',
    'blood': 'রক্তের গ্রুপ {group}।',
    'call': 'অনুগ্রহ করে তাঁকে ফোন করুন।',
    'sentBy': '{app} থেকে পাঠানো।',
    'update': '{app} আপডেট: SOS এখনও চালু আছে। {where}',
    'allClear': '{app}: {who} নিজেকে নিরাপদ জানিয়েছেন। SOS শেষ হয়েছে।',
    'test': 'এটি {app}-এর একটি পরীক্ষা। {who} আপনাকে জরুরি পরিচিত হিসেবে যোগ '
        'করেছেন। কিছু করার দরকার নেই।',
    'walkStarted': '{app}: {who} Safe Walk শুরু করেছেন{place} এবং {time}-এর '
        'মধ্যে পৌঁছানোর কথা। চেক-ইন না করলে আপনি SOS পাবেন।',
    'walkPlace': ' (গন্তব্য: {place})',
    'walkArrived': '{app}: {who} গন্তব্যে পৌঁছেছেন। Safe Walk শেষ হয়েছে।',
    'lowBattery': '{app}: {who} Safe Walk-এ আছেন এবং ব্যাটারি {level}%, ফোন বন্ধ '
        'হয়ে যেতে পারে। {where}',
  },
  'mr': {
    'who': 'तुमच्या संपर्कातील व्यक्ती',
    'sos': 'SOS! {who} यांना आत्ता मदतीची गरज आहे.',
    'sosFrom': '{who} यांचा SOS: {message}',
    'location': 'ठिकाण: {link} ({metres} मी च्या आत, {time}).',
    'lastLocation': 'शेवटचे माहीत ठिकाण: {link} ({metres} मी च्या आत, {time}).',
    'noLocation': 'सध्या ठिकाण उपलब्ध नाही.',
    'heading': 'गंतव्य: {place}.',
    'blood': 'रक्तगट {group}.',
    'call': 'कृपया त्यांना फोन करा.',
    'sentBy': '{app} कडून पाठवले.',
    'update': '{app} अपडेट: SOS अजून सुरू आहे. {where}',
    'allClear': '{app}: {who} यांनी स्वतःला सुरक्षित सांगितले आहे. SOS संपला आहे.',
    'test': 'ही {app} ची चाचणी आहे. {who} यांनी तुम्हाला आपत्कालीन संपर्क म्हणून '
        'जोडले आहे. काहीही करण्याची गरज नाही.',
    'walkStarted': '{app}: {who} यांनी Safe Walk सुरू केली आहे{place} आणि {time} '
        'पर्यंत पोहोचायचे आहे. चेक-इन न झाल्यास तुम्हाला SOS मिळेल.',
    'walkPlace': ' (गंतव्य: {place})',
    'walkArrived': '{app}: {who} गंतव्यस्थानी पोहोचले आहेत. Safe Walk संपली आहे.',
    'lowBattery': '{app}: {who} Safe Walk वर आहेत आणि बॅटरी {level}% आहे, फोन बंद '
        'होऊ शकतो. {where}',
  },
  'ta': {
    'who': 'உங்கள் தொடர்பு',
    'sos': 'SOS! {who} அவர்களுக்கு இப்போதே உதவி தேவை.',
    'sosFrom': '{who} அவர்களின் SOS: {message}',
    'location': 'இருப்பிடம்: {link} ({metres} மீ-க்குள், {time}).',
    'lastLocation': 'கடைசியாக அறிந்த இருப்பிடம்: {link} ({metres} மீ-க்குள், {time}).',
    'noLocation': 'இப்போது இருப்பிடம் கிடைக்கவில்லை.',
    'heading': 'செல்லுமிடம்: {place}.',
    'blood': 'இரத்த வகை {group}.',
    'call': 'தயவுசெய்து அவர்களை அழையுங்கள்.',
    'sentBy': '{app} அனுப்பியது.',
    'update': '{app} தகவல்: SOS இன்னும் செயலில் உள்ளது. {where}',
    'allClear': '{app}: {who} தான் பாதுகாப்பாக இருப்பதாகத் தெரிவித்துள்ளார். SOS '
        'முடிந்தது.',
    'test': 'இது {app} சோதனை. {who} உங்களை அவசரத் தொடர்பாகச் சேர்த்துள்ளார். '
        'நீங்கள் எதுவும் செய்ய வேண்டாம்.',
    'walkStarted': '{app}: {who} Safe Walk தொடங்கியுள்ளார்{place}, {time}-க்குள் '
        'சென்றடைய வேண்டும். செக்-இன் செய்யாவிட்டால் உங்களுக்கு SOS வரும்.',
    'walkPlace': ' (செல்லுமிடம்: {place})',
    'walkArrived': '{app}: {who} சேருமிடத்தை அடைந்துவிட்டார். Safe Walk முடிந்தது.',
    'lowBattery': '{app}: {who} Safe Walk-இல் இருக்கிறார், பேட்டரி {level}%, போன் '
        'அணைந்துவிடலாம். {where}',
  },
  'te': {
    'who': 'మీ పరిచయస్తులు',
    'sos': 'SOS! {who} గారికి ఇప్పుడే సహాయం కావాలి.',
    'sosFrom': '{who} గారి SOS: {message}',
    'location': 'స్థానం: {link} ({metres} మీ లోపు, {time}).',
    'lastLocation': 'చివరిగా తెలిసిన స్థానం: {link} ({metres} మీ లోపు, {time}).',
    'noLocation': 'ప్రస్తుతం స్థానం అందుబాటులో లేదు.',
    'heading': 'గమ్యం: {place}.',
    'blood': 'రక్త గ్రూపు {group}.',
    'call': 'దయచేసి వారికి ఫోన్ చేయండి.',
    'sentBy': '{app} నుండి పంపబడింది.',
    'update': '{app} అప్‌డేట్: SOS ఇంకా కొనసాగుతోంది. {where}',
    'allClear': '{app}: {who} తాము సురక్షితంగా ఉన్నామని తెలిపారు. SOS ముగిసింది.',
    'test': 'ఇది {app} పరీక్ష. {who} మిమ్మల్ని అత్యవసర పరిచయంగా చేర్చారు. మీరు '
        'ఏమీ చేయనవసరం లేదు.',
    'walkStarted': '{app}: {who} Safe Walk ప్రారంభించారు{place}, {time} లోపు '
        'చేరుకోవాలి. చెక్-ఇన్ చేయకపోతే మీకు SOS వస్తుంది.',
    'walkPlace': ' (గమ్యం: {place})',
    'walkArrived': '{app}: {who} గమ్యం చేరుకున్నారు. Safe Walk ముగిసింది.',
    'lowBattery': '{app}: {who} Safe Walk లో ఉన్నారు, బ్యాటరీ {level}%, ఫోన్ ఆగిపోవచ్చు. '
        '{where}',
  },
};

/// Builds the text of every message the app sends.
class SosMessages {
  static String alert({
    required String name,
    required LocationFix? fix,
    required DateTime now,
    String bloodGroup = '',
    String customMessage = '',
    String destination = '',
    String language = 'en',
  }) {
    String say(String key, [Map<String, String> values = const {}]) =>
        _say(language, key, values);
    final who = _who(name, language);
    final opening = customMessage.trim().isEmpty
        ? say('sos', {'who': who})
        : say('sosFrom', {'who': who, 'message': customMessage.trim()});
    return [
      opening,
      _where(fix, now, language),
      if (destination.trim().isNotEmpty)
        say('heading', {'place': destination.trim()}),
      if (bloodGroup.trim().isNotEmpty)
        say('blood', {'group': bloodGroup.trim()}),
      say('call'),
      say('sentBy'),
    ].join(' ');
  }

  static String update({
    required LocationFix? fix,
    required DateTime now,
    String language = 'en',
  }) =>
      _say(language, 'update', {'where': _where(fix, now, language)});

  static String allClear(String name, {String language = 'en'}) =>
      _say(language, 'allClear', {'who': _who(name, language)});

  static String test(String name, {String language = 'en'}) =>
      _say(language, 'test', {'who': _who(name, language)});

  static String walkStarted(
    String name,
    String destination,
    DateTime eta, {
    String language = 'en',
  }) {
    final place = destination.trim();
    return _say(language, 'walkStarted', {
      'who': _who(name, language),
      'place': place.isEmpty ? '' : _say(language, 'walkPlace', {'place': place}),
      'time': _time(eta),
    });
  }

  static String walkArrived(String name, {String language = 'en'}) =>
      _say(language, 'walkArrived', {'who': _who(name, language)});

  static String lowBattery({
    required String name,
    required int level,
    required LocationFix? fix,
    required DateTime now,
    String language = 'en',
  }) =>
      _say(language, 'lowBattery', {
        'who': _who(name, language),
        'level': '$level',
        'where': _where(fix, now, language),
      });

  static String _who(String name, String language) =>
      name.trim().isEmpty ? _say(language, 'who') : name.trim();

  static String _where(LocationFix? fix, DateTime now, String language) {
    if (fix == null) return _say(language, 'noLocation');
    return _say(language, fix.isFresh(now) ? 'location' : 'lastLocation', {
      'link': fix.mapsLink,
      'metres': '${fix.accuracy.round()}',
      'time': _time(fix.time),
    });
  }

  /// Falls back to English, so an unknown language can't stop an alert.
  static String _say(
    String language,
    String key, [
    Map<String, String> values = const {},
  ]) {
    final phrases = _phrases[language] ?? _phrases['en']!;
    var text = phrases[key] ?? _phrases['en']![key]!;
    for (final entry in {'app': appName, ...values}.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  static String _time(DateTime time) =>
      DateFormat('HH:mm').format(time.toLocal());
}

/// Places a phone call through the dialer.
Future<bool> callNumber(String phone) async {
  try {
    return await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    return false;
  }
}
