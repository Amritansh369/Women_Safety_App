/// The screens seen in the middle of an emergency, in Hindi. Keyed by the
/// English text, so anything missing just stays readable in English.
const _hindi = <String, String>{
  'Press and hold': 'दबाकर रखें',
  'Hold for SOS': 'SOS के लिए दबाकर रखें',
  'Sending SOS in': 'SOS भेजा जा रहा है',
  'Your location will go to your trusted contacts.':
      'आपका स्थान आपके भरोसेमंद संपर्कों को भेजा जाएगा।',
  'Cancel': 'रद्द करें',
  'Send now': 'अभी भेजें',
  'Call {number}': '{number} पर कॉल करें',
  'Stop siren': 'सायरन बंद करें',
  'Siren': 'सायरन',
  'Send location': 'स्थान भेजें',
  "HOLD:\nI'M SAFE": 'दबाकर रखें:\nमैं सुरक्षित हूँ',
  'Update sent': 'अपडेट भेज दिया गया',
  'Still waiting for a GPS fix': 'GPS का इंतज़ार है',
  'No contacts to alert': 'कोई संपर्क नहीं जोड़ा गया',
  'Call {number} now.': 'अभी {number} पर कॉल करें।',
  'Sending your SOS...': 'आपका SOS भेजा जा रहा है...',
  'Getting your location and alerting your contacts.':
      'स्थान लिया जा रहा है और संपर्कों को सूचित किया जा रहा है।',
  'Press send in your messages app': 'Messages ऐप में Send दबाएँ',
  'The alert is written but has NOT been sent yet.':
      'अलर्ट लिखा गया है, पर अभी भेजा नहीं गया है।',
  'SOS not sent yet': 'SOS अभी नहीं भेजा गया',
  'No signal? Retrying automatically. Calling {number} may still work.':
      'सिग्नल नहीं है? अपने आप दोबारा कोशिश हो रही है। {number} पर कॉल काम कर सकती है।',
  'SOS sent to {sent} of {total}': '{total} में से {sent} को SOS भेजा गया',
  "Location updates will continue until you're safe.":
      'आपके सुरक्षित होने तक स्थान अपडेट जारी रहेंगे।',
  'Heading to {place}': 'मंज़िल: {place}',
  'Retry {count} failed': '{count} असफल दोबारा भेजें',
  '{count} location update(s) sent': '{count} स्थान अपडेट भेजे गए',
  'Waiting': 'प्रतीक्षा में',
  'Sending': 'भेजा जा रहा है',
  'Sent': 'भेजा गया',
  'Delivered': 'पहुँच गया',
  'Press send': 'Send दबाएँ',
  'Failed': 'असफल',
  'To update contacts marked "Press send", tap Send location.':
      '"Send दबाएँ" वाले संपर्कों को अपडेट देने के लिए "स्थान भेजें" दबाएँ।',
  'Are you OK?': 'क्या आप ठीक हैं?',
  'SOS will be sent in {seconds} seconds.': '{seconds} सेकंड में SOS भेजा जाएगा।',
  "I'm safe": 'मैं सुरक्षित हूँ',
  'I need 10 more minutes': 'मुझे 10 मिनट और चाहिए',
  'You have arrived': 'आप पहुँच गए हैं',
  'Your Safe Walk has ended.': 'आपकी Safe Walk खत्म हो गई है।',
};

/// The app's language. Set from settings at startup and when it changes.
String appLanguage = 'en';

/// Translates [english], filling in any {placeholders} from [values].
String tr(String english, [Map<String, Object> values = const {}]) {
  var text = appLanguage == 'hi' ? _hindi[english] ?? english : english;
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return text;
}
