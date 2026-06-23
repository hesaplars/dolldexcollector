import 'package:flutter/material.dart';

enum AppLanguage {
  tr,
  en,
}

class AppLanguageController extends ValueNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguage.tr);

  void setLanguage(AppLanguage language) {
    value = language;
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    required AppLanguageController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope not found');
    return scope!.notifier!;
  }

  static AppLanguage languageOf(BuildContext context) {
    return controllerOf(context).value;
  }
}

String t(BuildContext context, String key) {
  final language = AppLanguageScope.languageOf(context);
  final table = language == AppLanguage.tr ? _tr : _en;
  return table[key] ?? _en[key] ?? key;
}

const _tr = {
  'appName': 'DollDex Collector',
  'notifications': 'Bildirimler',
  'social': 'Sosyal',
  'theme': 'Tema',
  'catalog': 'Katalog',
  'collection': 'Koleksiyon',
  'profile': 'Profil',
  'pro': 'Pro',
  'admin': 'Admin',
  'catalogSubtitle': 'Karakter, bebek, set, pet ve aksesuarlar.',
  'searchHint': 'Karakter, set veya parça ara',
  'characters': 'Karakterler',
  'all': 'Tümü',
  'filter': 'Filtrele',
  'cancel': 'Vazgeç',
  'delete': 'Sil',
  'allConditions': 'Tüm durumlar',
  'dolls': 'Bebekler',
  'sets': 'Setler',
  'pets': 'Petler',
  'accessories': 'Aksesuarlar',
  'owned': 'Sahibim',
  'want': 'İstiyorum',
  'report': 'Raporla',
  'addToCollection': 'Koleksiyona ekle',
  'comments': 'Yorumlar',
  'commentHint': 'Not yaz veya ilgili parça linki yapıştır',
  'postComment': 'Yorum gönder',
  'reportComment': 'Yorumu raporla',
  'collectionSubtitle':
      'Sahip olduğun, istediğin, takaslık ve satılık parçalar.',
  'wanted': 'İstenen',
  'trade': 'Takas',
  'selling': 'Satılık',
  'yourShelfReady': 'Rafın hazır',
  'yourShelfBody':
      'Koleksiyonunu oluşturmaya başlamak için katalogdan parça ekle.',
  'quantityShort': 'Adet',
  'removeFromCollection': 'Koleksiyondan kaldır',
  'removeCollectionConfirm':
      'Bu parçayı koleksiyonundan kaldırmak istediğine emin misin?',
  'noCollectionFilterResults': 'Bu filtrede parça yok',
  'noCollectionFilterResultsBody': 'Başka bir koleksiyon durumu seç.',
  'noCatalogResults': 'Sonuç bulunamadı',
  'noCatalogResultsBody': 'Aramayı veya filtreleri değiştirerek tekrar dene.',
  'profileSubtitle': 'Vitrin, gizlilik ayarları ve hesap araçları.',
  'profileStats': 'Profil özeti',
  'profileShowcaseTitle': 'Profil vitrini',
  'profileShowcaseEmpty': 'Koleksiyonundan parçalar ekledikçe burada görünür.',
  'collectorAccount': 'Koleksiyoner hesabı',
  'signInBody':
      'Koleksiyonunu, istek listeni ve profilini senkronize etmek için giriş yap.',
  'continueGoogle': 'Google ile devam et',
  'accountTools': 'Hesap araçları',
  'privacyPolicy': 'Gizlilik politikası',
  'privacyRequired': 'Google Play ve web için gerekli.',
  'termsOfUse': 'Kullanım koşulları',
  'termsRequired': 'Uygulama kuralları ve kullanıcı sorumlulukları.',
  'deleteAccount': 'Hesap silme talebi',
  'deleteRequired': 'Uygulama içinde ve webde gerekli.',
  'completeProfileRequired': 'Profil kurulumu gerekli',
  'completeProfileBody':
      'Sosyal özellikleri kullanmadan önce benzersiz kullanıcı adını ve yaş uygunluğunu tamamla.',
  'username': 'Kullanıcı adı',
  'usernameRules': '3-15 karakter: küçük harf, rakam ve alt çizgi.',
  'usernameInvalid':
      'Kullanıcı adı 3-15 karakter olmalı; sadece harf, rakam ve alt çizgi kullanılabilir.',
  'usernameTaken': 'Bu kullanıcı adı alınmış.',
  'usernameChangeWarning':
      'Kullanıcı adını belirledikten sonra 6 ayda yalnızca bir kez değiştirebilirsin.',
  'usernameChangeLocked': 'Kullanıcı adı 6 ayda bir kez değiştirilebilir.',
  'birthYear': 'Doğum yılı',
  'birthYearInvalid': 'Geçerli bir doğum yılı gir.',
  'ageRequirement':
      'DollDex Collector kullanmak için en az 13 yaşında olmalısın.',
  'ageTooYoung': 'Yaş sınırı nedeniyle hesap kurulumu tamamlanamaz.',
  'acceptPrivacy': 'Gizlilik politikasını okudum ve kabul ediyorum.',
  'acceptTerms': 'Kullanım koşullarını okudum ve kabul ediyorum.',
  'acceptPoliciesRequired':
      'Devam etmek için gizlilik politikası ve kullanım koşullarını kabul etmelisin.',
  'saveProfile': 'Profili tamamla',
  'profileSaved': 'Profil tamamlandı.',
  'profileSaveFailed': 'Profil kaydedilemedi:',
  'avatarStudio': 'Avatar stüdyosu',
  'avatarStudioBody':
      'Avatarlar ve neon çerçeveler sadece Pro üyelerimize özeldir. Gotik profilini özelleştir!',
  'proFrames': 'Pro çerçeve renkleri',
  'proFramesLocked': 'Çerçeve renkleri Pro kullanıcılar için açıktır.',
  'deleteReason': 'Silme nedeni veya not',
  'sendDeleteRequest': 'Silme talebi gönder',
  'deleteRequestSaved': 'Hesap silme talebin kaydedildi.',
  'deleteRequestFailed': 'Silme talebi gönderilemedi:',
  'socialSubtitle':
      'Kullanıcı ara, arkadaş ekle, engelle, mesaj gönder ve genel sohbete katıl.',
  'socialSignInRequired':
      'Sosyal özellikleri kullanmak için Google hesabınla giriş yapmalısın.',
  'userSearch': 'Kullanıcı arama',
  'searchUsername': 'Kullanıcı adı ara',
  'search': 'Ara',
  'noUsersFound': 'Henüz kullanıcı bulunamadı.',
  'socialSearchFailed': 'Kullanıcı arama başarısız:',
  'sendFriendRequest': 'Arkadaş isteği gönder',
  'friendRequestSent': 'Arkadaş isteği gönderildi.',
  'blockUser': 'Kullanıcıyı engelle',
  'userBlocked': 'Kullanıcı engellendi.',
  'message': 'Mesaj',
  'sendMessage': 'Mesaj gönder',
  'messageSent': 'Mesaj gönderildi.',
  'globalChat': 'Genel sohbet',
  'globalMessage': 'Genel sohbete mesaj yaz',
  'globalChatEmpty': 'Genel sohbette henüz mesaj yok.',
  'openProfile': 'Profili aç',
  'publicProfile': 'Kullanıcı profili',
  'publicProfileSubtitle': 'Herkese açık koleksiyon, yorumlar ve beğeniler.',
  'publicCollection': 'Herkese açık koleksiyon',
  'publicCollectionEmpty': 'Açık koleksiyon yok',
  'publicCollectionEmptyBody':
      'Bu kullanıcının herkese açık koleksiyon parçası henüz yok.',
  'like': 'Beğen',
  'liked': 'Beğenildi.',
  'proSubtitle': 'Karanlık koleksiyon dünyasının tüm ayrıcalıklarını açın.',
  'proBenefits': 'Pro avantajları',
  'noAds': 'Android ve webde reklamsız kullanım',
  'advancedStats': 'Gelişmiş koleksiyon istatistikleri',
  'profileShowcase': 'Daha geniş profil vitrini',
  'powerFilters': 'Daha güçlü filtreler',
  'monthly': 'Aylık',
  'yearly': 'Yıllık',
  'playBilling': 'Play Billing',
  'serverVerified': 'Aylık Standart Ödeme',
  'bestCollectors': 'Düzenli koleksiyonerler için iyi seçenek',
  'connectBilling': 'Google Play Billing bağla',
  'monetizationReady': 'Reklam ve Pro hazırlığı',
  'adPlacementList': 'Pro olmayanlarda katalog listesi altında banner alanı.',
  'adPlacementDetail':
      'Detay sayfalarında içerikten sonra rahatsız etmeyen reklam alanı.',
  'proServerCheck': 'Pro durumu yayında sadece sunucu doğrulamasıyla açılacak.',
  'adPlaceholder':
      'Reklam alanı. Gerçek AdMob ID eklenene kadar reklam SDK kapalı kalır.',
  'adminSubtitle':
      'Katalog düzenleme, görsel URL önizleme ve moderasyon araçları.',
  'adminOnly': 'Admin erişimi gerekli',
  'adminOnlyBody': 'Bu bölüm sadece admin rolüne sahip hesaplarda görünür.',
  'adminCatalog': 'Katalog yönetimi',
  'editEntry': 'Kaydı düzenle',
  'editingEntry': 'Düzenleniyor',
  'cancelEdit': 'Düzenlemeyi iptal et',
  'deleteEntry': 'Kaydı sil',
  'imagePreview': 'Görsel önizleme',
  'pasteImageUrl': 'Güvenli görsel URL yapıştır',
  'savedEntriesImage':
      'Kaydedilen parçalar katalogda link olarak değil, görsel olarak görünür.',
  'moderationQueue': 'Moderasyon sırası',
  'noReports': 'Henüz rapor yok',
  'noReportsBody':
      'Raporlanan yorumlar, profiller ve görseller burada görünür.',
  'openTarget': 'Hedefi aç',
  'markReviewing': 'İncelemede',
  'dismissReport': 'Reddet',
  'resolveReport': 'Raporu çözüldü işaretle',
  'legalSubtitle': 'DollDex Collector uyumluluk sayfası',
  'privacyBody':
      'Son güncelleme: 21 Haziran 2026\n\nDollDex Collector, kullanıcılarının gizliliğine son derece önem vermektedir. Bu Gizlilik Politikası, uygulamamızı ve ilgili servislerimizi kullandığınızda verilerinizin nasıl toplandığını, işlendiğini ve korunduğunu açıklamaktadır.\n\n1. Toplanan Veriler ve Amacı\nUygulama, güvenli bir kullanım, koleksiyon kataloglama ve topluluk iletişimi sunmak amacıyla aşağıdaki kişisel verileri işler:\n- Hesap ve Kimlik Bilgileri: Google Oturum Açma (Google Sign-In) servisi aracılığıyla sağlanan benzersiz Google kimlik belirteci, e-posta adresi, profil adı ve profil fotoğrafı.\n- Kullanıcı Profili: Tarafınızdan belirlenen benzersiz @kullanıcı_adı, doğum yılı bazlı yaş aralığı doğrulaması, profil biyografisi, kuşanılan kapak fotoğrafı, çerçeve ve rozet tercihleri.\n- Kullanıcı İçeriği: Koleksiyonunuza eklediğiniz oyuncak bebek ve aksesuar kayıtları, yorumlarınız, genel sohbet mesajları, özel mesajlar (Direct Messages), takipleri gösteren arkadaşlık ilişkileri ve diğer kullanıcıları raporlama geçmişiniz.\n- Teknik ve Kalite Verileri: Uygulamanın kararlılığını sağlamak için crash logları (hata kayıtları), cihaz bilgileri ve uygulama içi performans istatistikleri.\n\n2. Veri İşleme Amaçları\nToplanan kişisel verileriniz şu amaçlarla işlenmektedir:\n- Hesabınızın güvenli şekilde oluşturulması ve kimlik doğrulanması,\n- Koleksiyonunuzun cihazlarınız arasında (bulut ortamında) senkronize edilmesi,\n- Diğer kullanıcılarla özel mesajlaşabilmeniz ve sosyal akışta etkileşim kurabilmeniz,\n- Topluluk güvenliğinin sağlanması, moderasyon süreçlerinin yürütülmesi ve kötüye kullanımın engellenmesi,\n- İsteğe bağlı sunulan DollDex Pro aboneliğinin doğrulanması ve pro özelliklerin aktifleştirilmesi,\n- Yasal yükümlülüklere uyum sağlanması.\n\n3. Verilerin Saklanması ve Altyapı\nUygulamamızın altyapısı Google Firebase servisleri (Firebase Authentication ve Cloud Firestore) üzerinde barındırılmaktadır. Verileriniz, Google\'ın yüksek güvenlik standartlarına sahip bulut sunucularında şifrelenmiş olarak saklanır. Yetkili yöneticiler verilerinize yalnızca destek talepleri, güvenlik denetimleri ve moderasyon amacıyla sınırlı olarak erişebilir.\n\n4. Veri Paylaşımı ve Üçüncü Taraflar\nDollDex Collector, kişisel verilerinizi üçüncü şahıslara satmaz veya kiralamaz. Verileriniz yalnızca Firebase altyapısı üzerinde işlenir. Yasal bir zorunluluk, mahkeme kararı veya resmi makamların talebi durumunda veriler ilgili yasal mercilerle paylaşılabilir.\n\n5. Kullanıcı Hakları ve Veri Silme\nKullanıcılar, kişisel verilerine ve koleksiyon kayıtlarına uygulama üzerinden diledikleri an erişebilir ve güncelleyebilirler.\nHesap Silme: Uygulama içindeki ayarlar menüsünden veya doğrudan hesap silme sekmesinden hesabınızın ve tüm verilerinizin silinmesini talep edebilirsiniz. Silme talebi onaylandığında profil bilgileriniz, @kullanıcı_adınız, koleksiyon kayıtlarınız, yorumlarınız ve mesajlarınız veri tabanımızdan tamamen temizlenir veya geri döndürülemez şekilde anonimleştirilir. Ancak güvenlik, moderasyon geçmişi denetimi, dolandırıcılığın önlenmesi ve yasal zorunluluklar gereği bazı sınırlı kayıtlar ilgili yasal süre boyunca saklanmaya devam edebilir.',
  'termsBody':
      'Son güncelleme: 21 Haziran 2026\n\nGiriş ve Hizmetin Tanımı\nDollDex Collector (bundan böyle "Uygulama" olarak anılacaktır), oyuncak bebekler, gotik figürler, karakterler, evcil hayvanlar (pet) ve ilgili aksesuarlardan oluşan koleksiyonları kataloglamak, takip etmek, sergilemek, diğer koleksiyoncularla paylaşmak ve topluluk içi etkileşimi (sohbet, mesajlaşma, sosyal akış) sağlamak amacıyla geliştirilmiş bağımsız bir mobil ve web uygulamasıdır. DollDex Collector, çocuklara yönelik resmi bir uygulama değildir ve üçüncü taraf oyuncak markalarıyla hiçbir ticari veya resmi bağı bulunmamaktadır.\n\nKabul ve Yaş Sınırı\nUygulamayı indirdiğinizde, kaydolduğunuzda veya kullandığınızda bu Kullanım Koşullarını eksiksiz olarak kabul etmiş sayılarsınız. Uygulamaya üye olabilmek ve sosyal özellikleri (mesajlaşma, sohbet, akış) kullanabilmek için en az 13 (on üç) yaşında olmanız gerekmektedir. Kayıt esnasında doğum yılınızı doğru şekilde beyan etmek sizin sorumluluğunuzdadır. 13 yaş altındaki kullanıcılar sosyal özelliklere erişemez ve yalnızca katalog görüntüleme ile sınırlı yerel kullanım yapabilirler.\n\nKullanıcı Tarafından Oluşturulan İçerik (UGC) ve Davranış Kuralları\nKullanıcılar; yükledikleri fotoğraflar, yazdıkları yorumlar, profil bilgileri, gönderdikleri özel veya genel mesajlar ve oluşturdukları koleksiyon kayıtları dahil olmak üzere paylaştıkları tüm içeriklerden kişisel olarak sorumludur.\nUygulama içinde aşağıdaki davranışlar kesinlikle yasaktır:\n- Taciz, hakaret, nefret söylemi, şiddet teşviki, tehdit veya ayrımcılık içeren içerik paylaşımı,\n- Telif hakları, ticari markalar veya diğer kişilerin fikri mülkiyet haklarını ihlal eden görsellerin veya bilgilerin yetkisiz kullanımı,\n- Spam, yanıltıcı bilgiler, dolandırıcılık amaçlı ilanlar veya reklamlar,\n- Kişisel verilerin (telefon, adres vb.) ifşası veya gizliliği ihlal eden paylaşımlar,\n- Yasa dışı veya topluluk güvenliğini tehdit eden içerikler.\nDollDex Collector, bu kurallara uymayan içerikleri bildirim yapmaksızın kaldırma, kullanıcıyı engelleme ve hesabı askıya alma veya kalıcı olarak silme hakkını saklı tutar.\n\nKatalog Verileri ve Takas\nUygulama içi katalog verileri topluluk katkısıyla oluşturulmaktadır. Katalog verilerinin kesin doğruluğu, eksiksizliği veya resmi niteliği taahhüt edilmez. Kullanıcıların kendi aralarında gerçekleştirebilecekleri olası takas, alışveriş veya anlaşmalardan doğacak hukuki, mali ve lojistik riskler tamamen kullanıcılara aittir; Uygulama bu süreçlere taraf veya aracı değildir.\n\nFiyatlandırma, Abonelikler ve Pro Üyelik\nUygulamanın bazı özellikleri reklam desteklidir. Reklamları kaldırmak, özel profil avatarları, kapak fotoğrafları, özel gotik profil çerçeveleri, prestijli rozetler edinmek ve gelişmiş istatistiksel analiz özelliklerine erişmek isteyen kullanıcılar DollDex Pro aboneliği satın alabilirler. Abonelik ödemeleri Google Play Billing veya ilgili uygulama mağazası ödeme sistemleri üzerinden tahsil edilir ve ilgili uygulama mağazasının abonelik kurallarına tabidir.\n\nSorumluluğun Sınırlandırılması\nDollDex Collector, uygulamanın kesintisiz veya hatasız çalışacağını garanti etmez. Uygulama, Firebase ve Google servisleri üzerinden sunulmakta olup, veri kaybı veya teknik aksaklıklardan dolayı doğrudan ya da dolaylı oluşabilecek zararlardan sorumlu tutulamaz.',
  'deleteBody':
      'Hesabının silinmesini talep ettiğinde profil, kullanıcı adı, koleksiyon, yorum, sosyal ilişki ve mesaj verilerinin silinmesi veya anonimleştirilmesi için işlem başlatılır. Güvenlik, moderasyon, ödeme uyuşmazlığı veya yasal zorunluluk nedeniyle sınırlı kayıtlar gerekli süre boyunca saklanabilir.',
  'notificationsSubtitle':
      'Mesajlar, yorumlar, takipler, raporlar ve Pro güncellemeleri.',
  'noNotifications': 'Henüz bildirim yok',
  'noNotificationsBody':
      'Sosyal etkileşimleriniz (takip, mesaj, arkadaşlık) ve duyurular burada görünecektir.',
  'commentAdded': 'yorum eklendi',
  'catalogEntrySaved': 'katalog kaydı kaydedildi',
  'collectionUpdated': 'koleksiyon güncellendi',
  'entryNotFound': 'Katalog parçası bulunamadı',
  'entryNotFoundBody': 'Bu parça kaldırılmış veya henüz hazır olmayabilir.',
  'wikiPlaceholder':
      'Wiki detayları, bağlı karakterler, set içerikleri, petler ve aksesuarlar burada görünecek.',
  'commentPlaceholder':
      'Koleksiyoner notları ve paylaşılan parça linkleri burada görünecek.',
  'signInNeedsFirebase': 'Giriş için önce Firebase kurulumu gerekiyor.',
  'signInSuccess': 'Google hesabın bağlandı.',
  'signInCancelled': 'Google girişi iptal edildi.',
  'signInFailed': 'Google girişi başarısız:',
  'signedIn': 'Giriş yapıldı.',
  'signOut': 'Çıkış yap',
  'signOutFailed': 'Çıkış başarısız:',
  'reportSaved': 'Rapor kaydedildi.',
  'markedAs': 'olarak işaretlendi.',
  'templateCharacterName': 'Karakter profili',
  'templateCharacterSubtitle': 'Wiki kayıt şablonu',
  'templateCharacterDescription':
      'Karakter sayfaları bebekleri, petleri ve aksesuarları birbirine bağlar.',
  'templateDollName': 'Oyuncak Bebek',
  'templateDollSubtitle': 'Sahibim, istiyorum, takas',
  'templateDollDescription':
      'Oyuncak bebekler koleksiyon parçası olarak takip edilir.',
  'templatePetName': 'Pet arkadaşı',
  'templatePetSubtitle': 'Karaktere bağlı',
  'templatePetDescription':
      'Petler karakterlere ve bebek sürümlerine bağlanabilir.',
  'templateAccessoryName': 'Aksesuar parçası',
  'templateAccessorySubtitle': 'Set tamamlama parçası',
  'templateAccessoryDescription':
      'Aksesuarlar kullanıcıların detaylı setleri tamamlamasına yardım eder.',
  'typeCharacter': 'Karakter',
  'typeDoll': 'Bebek',
  'typeSet': 'Set',
  'typePet': 'Pet',
  'typeAccessory': 'Aksesuar',
  'statusOwned': 'sahibim',
  'statusWanted': 'istiyorum',
  'statusTrade': 'takas',
  'statusSelling': 'satılık',
};

const _en = {
  'appName': 'DollDex Collector',
  'notifications': 'Notifications',
  'social': 'Social',
  'theme': 'Theme',
  'catalog': 'Catalog',
  'collection': 'Collection',
  'profile': 'Profile',
  'pro': 'Pro',
  'admin': 'Admin',
  'catalogSubtitle': 'Characters, dolls, sets, pets and accessories.',
  'searchHint': 'Search by character, set or item',
  'characters': 'Characters',
  'all': 'All',
  'filter': 'Filter',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'allConditions': 'All conditions',
  'dolls': 'Dolls',
  'sets': 'Sets',
  'pets': 'Pets',
  'accessories': 'Accessories',
  'owned': 'Owned',
  'want': 'Want',
  'report': 'Report',
  'addToCollection': 'Add to collection',
  'comments': 'Comments',
  'commentHint': 'Share a note or paste a related item link',
  'postComment': 'Post comment',
  'reportComment': 'Report comment',
  'collectionSubtitle': 'Track owned, wanted, trade and sale pieces.',
  'wanted': 'Wanted',
  'trade': 'Trade',
  'selling': 'Selling',
  'yourShelfReady': 'Your shelf is ready',
  'yourShelfBody':
      'Add items from the catalog to start building your collection.',
  'quantityShort': 'Qty',
  'removeFromCollection': 'Remove from collection',
  'removeCollectionConfirm':
      'Are you sure you want to remove this item from your collection?',
  'noCollectionFilterResults': 'No items in this filter',
  'noCollectionFilterResultsBody': 'Choose another collection status.',
  'noCatalogResults': 'No results found',
  'noCatalogResultsBody': 'Try changing the search or filters.',
  'profileSubtitle': 'Showcase, privacy and account tools.',
  'profileStats': 'Profile summary',
  'profileShowcaseTitle': 'Profile showcase',
  'profileShowcaseEmpty': 'Items from your collection will appear here.',
  'collectorAccount': 'Collector account',
  'signInBody': 'Sign in to sync your collection, wishlist and profile.',
  'continueGoogle': 'Continue with Google',
  'accountTools': 'Account tools',
  'privacyPolicy': 'Privacy policy',
  'privacyRequired': 'Required for Google Play and web.',
  'termsOfUse': 'Terms of use',
  'termsRequired': 'App rules and user responsibilities.',
  'deleteAccount': 'Delete account request',
  'deleteRequired': 'Required inside the app and on the web.',
  'completeProfileRequired': 'Profile setup required',
  'completeProfileBody':
      'Complete your unique username and age eligibility before using social features.',
  'username': 'Username',
  'usernameRules':
      '3-15 characters: lowercase letters, numbers and underscore.',
  'usernameInvalid':
      'Username must be 3-15 characters and can only use letters, numbers and underscore.',
  'usernameTaken': 'This username is already taken.',
  'usernameChangeWarning':
      'After setting your username, you can change it only once every 6 months.',
  'usernameChangeLocked': 'Username can only be changed once every 6 months.',
  'birthYear': 'Birth year',
  'birthYearInvalid': 'Enter a valid birth year.',
  'ageRequirement':
      'You must be at least 13 years old to use DollDex Collector.',
  'ageTooYoung':
      'Profile setup cannot be completed because of the age requirement.',
  'acceptPrivacy': 'I have read and accept the privacy policy.',
  'acceptTerms': 'I have read and accept the terms of use.',
  'acceptPoliciesRequired':
      'You must accept the privacy policy and terms of use to continue.',
  'saveProfile': 'Complete profile',
  'profileSaved': 'Profile completed.',
  'profileSaveFailed': 'Profile could not be saved:',
  'avatarStudio': 'Avatar studio',
  'avatarStudioBody':
      'Avatars and neon frames are exclusive to Pro members. Customize your gothic profile!',
  'proFrames': 'Pro frame colors',
  'proFramesLocked': 'Frame colors are available for Pro users.',
  'deleteReason': 'Deletion reason or note',
  'sendDeleteRequest': 'Send deletion request',
  'deleteRequestSaved': 'Your account deletion request was saved.',
  'deleteRequestFailed': 'Deletion request could not be sent:',
  'socialSubtitle':
      'Search users, add friends, block, send messages and join the global chat.',
  'socialSignInRequired': 'Sign in with Google to use social features.',
  'userSearch': 'User search',
  'searchUsername': 'Search username',
  'search': 'Search',
  'noUsersFound': 'No users found yet.',
  'socialSearchFailed': 'User search failed:',
  'sendFriendRequest': 'Send friend request',
  'friendRequestSent': 'Friend request sent.',
  'blockUser': 'Block user',
  'userBlocked': 'User blocked.',
  'message': 'Message',
  'sendMessage': 'Send message',
  'messageSent': 'Message sent.',
  'globalChat': 'Global chat',
  'globalMessage': 'Write to global chat',
  'globalChatEmpty': 'No messages in global chat yet.',
  'openProfile': 'Open profile',
  'publicProfile': 'User profile',
  'publicProfileSubtitle': 'Public collection, comments and likes.',
  'publicCollection': 'Public collection',
  'publicCollectionEmpty': 'No public collection',
  'publicCollectionEmptyBody':
      'This user does not have public collection items yet.',
  'like': 'Like',
  'liked': 'Liked.',
  'proSubtitle': 'Unlock all privileges of the dark collection universe.',
  'proBenefits': 'Pro benefits',
  'noAds': 'No ads across Android and web',
  'advancedStats': 'Advanced collection stats',
  'profileShowcase': 'Expanded profile showcase',
  'powerFilters': 'More powerful filters',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
  'playBilling': 'Play Billing',
  'serverVerified': 'Monthly Standard Billing',
  'bestCollectors': 'Best for regular collectors',
  'connectBilling': 'Connect Google Play Billing',
  'monetizationReady': 'Ads and Pro readiness',
  'adPlacementList': 'Banner area below catalog lists for non-Pro users.',
  'adPlacementDetail': 'Non-disruptive ad area after detail page content.',
  'proServerCheck': 'Pro status will only unlock after server verification.',
  'adPlaceholder':
      'Ad area. The ad SDK stays disabled until a real AdMob ID is added.',
  'adminSubtitle': 'Catalog editing, image URL preview and moderation tools.',
  'adminOnly': 'Admin access required',
  'adminOnlyBody':
      'This section is only visible for accounts with the admin role.',
  'adminCatalog': 'Catalog management',
  'editEntry': 'Edit entry',
  'editingEntry': 'Editing',
  'cancelEdit': 'Cancel edit',
  'deleteEntry': 'Delete entry',
  'imagePreview': 'Image preview',
  'pasteImageUrl': 'Paste a secure image URL',
  'savedEntriesImage':
      'Saved entries will show the picture in catalog cards and detail pages, not the raw URL.',
  'moderationQueue': 'Moderation queue',
  'noReports': 'No reports yet',
  'noReportsBody': 'Reported comments, profiles and images will appear here.',
  'openTarget': 'Open target',
  'markReviewing': 'Reviewing',
  'dismissReport': 'Dismiss',
  'resolveReport': 'Mark report resolved',
  'legalSubtitle': 'DollDex Collector compliance page',
  'privacyBody':
      'Last updated: June 21, 2026\n\nDollDex Collector highly values the privacy of its users. This Privacy Policy explains how your data is collected, processed, and protected when you use our app and related services.\n\n1. Data Collected and Its Purpose\nThe App processes the following personal data to provide secure usage, collection cataloging, and community communication:\n- Account and Identity Information: Unique Google identifier, email address, profile name, and profile photo provided via Google Sign-In.\n- User Profile: Unique @username set by you, age eligibility verification based on birth year, profile bio, and custom choices for cover photo, frame, and badges.\n- User Content: Doll and accessory entries added to your collection, comments, global chat messages, private direct messages (DMs), friend relationships (following), and your user reporting history.\n- Technical and Quality Data: Crash logs, device information, and in-app performance metrics to ensure App stability.\n\n2. Purposes of Data Processing\nYour personal data is processed for the following purposes:\n- Secure account creation and authentication.\n- Syncing your collection across your devices in the cloud.\n- Enabling private messaging and social interactions on the feed.\n- Providing community safety, performing moderation, and preventing abuse.\n- Verifying the optional DollDex Pro subscription and enabling premium features.\n- Complying with legal obligations.\n\n3. Data Storage and Infrastructure\nOur App\'s infrastructure is hosted on Google Firebase services (Firebase Authentication and Cloud Firestore). Your data is stored encrypted on cloud servers with high security standards. Authorized administrators access your data only when necessary for support, security audits, and moderation purposes.\n\n4. Data Sharing and Third Parties\nDollDex Collector does not sell or rent your personal data to third parties. Your data is only processed on Firebase infrastructure. In case of legal obligations, court orders, or requests from official authorities, data may be shared with the relevant legal bodies.\n\n5. User Rights and Data Deletion\nUsers can access and update their personal data and collection entries within the App at any time.\nAccount Deletion: You can request the deletion of your account and all associated data from the settings menu or the dedicated account deletion section. Once confirmed, your profile information, @username, collection entries, comments, and messages will be permanently purged or anonymized. However, limited records may continue to be stored for security, moderation history checks, fraud prevention, and legal compliance.',
  'termsBody':
      'Last updated: June 21, 2026\n\nIntroduction and Description of Service\nDollDex Collector (hereinafter referred to as the "App") is an independent mobile and web application developed to catalog, track, showcase, and share collections of dolls, gothic figures, characters, pets, and related accessories, as well as to enable community interaction (chat, messaging, social feed) among collectors. DollDex Collector is not an official application for children and has no commercial or official affiliation with third-party toy brands.\n\nAcceptance and Age Limitation\nBy downloading, registering with, or using the App, you accept these Terms of Use in full. To register and use the social features (messaging, chat, feed), you must be at least 13 (thirteen) years old. It is your responsibility to declare your birth year accurately during registration. Users under the age of 13 cannot access social features and are limited to local catalog browsing only.\n\nUser Generated Content (UGC) and Code of Conduct\nUsers are personally responsible for all content they share, including uploaded photos, comments, profile information, public/private messages, and collection entries.\nThe following behavior is strictly prohibited:\n- Sharing content containing harassment, insults, hate speech, incitement of violence, threats, or discrimination.\n- Unauthorized use of images or information that violates copyrights, trademarks, or intellectual property rights of others.\n- Sharing spam, misleading information, fraudulent listings, or advertisements.\n- Disclosing personal data (phone numbers, addresses, etc.) or sharing contents that violate privacy.\n- Sharing illegal content or content that threatens community safety.\nDollDex Collector reserves the right to remove non-compliant content without notice, block users, and suspend or permanently delete accounts.\n\nCatalog Data and Trading\nThe catalog data within the App is created through community contributions. The absolute accuracy, completeness, or official status of catalog data is not guaranteed. Any financial, legal, or logistical risks arising from trades, purchases, or agreements between users are solely the responsibility of the users; the App is not a party or mediator in these processes.\n\nPricing, Subscriptions and Pro Membership\nSome features of the App are ad-supported. Users who wish to remove ads, unlock exclusive profile avatars, cover photos, special gothic profile frames, prestigious badges, and access advanced statistical analytics can purchase a DollDex Pro subscription. Subscription payments are processed via Google Play Billing or respective app store payment systems and are subject to the subscription rules of the respective store.\n\nLimitation of Liability\nDollDex Collector does not guarantee that the App will operate uninterrupted or error-free. The App is provided over Google and Firebase services; it cannot be held liable for any direct or indirect damages resulting from data loss or technical interruptions.',
  'deleteBody':
      'When you request account deletion, deletion or anonymization starts for your profile, username, collection, comments, social relationships and message data. Limited records may be retained when required for safety, moderation, payment disputes or legal obligations.',
  'notificationsSubtitle':
      'Messages, comments, follows, reports and Pro updates.',
  'noNotifications': 'No notifications yet',
  'noNotificationsBody':
      'Social interactions (follows, messages, friends) and announcements will appear here.',
  'commentAdded': 'comment added',
  'catalogEntrySaved': 'catalog entry saved',
  'collectionUpdated': 'collection updated',
  'entryNotFound': 'Catalog entry not found',
  'entryNotFoundBody':
      'This item may have been removed or is not available yet.',
  'wikiPlaceholder':
      'Wiki details, linked characters, set contents, pets and accessories will appear here.',
  'commentPlaceholder':
      'This page will show collector notes and shared item links.',
  'signInNeedsFirebase': 'Firebase setup is required before sign-in.',
  'signInSuccess': 'Your Google account is connected.',
  'signInCancelled': 'Google sign-in was cancelled.',
  'signInFailed': 'Google sign-in failed:',
  'signedIn': 'Signed in.',
  'signOut': 'Sign out',
  'signOutFailed': 'Sign-out failed:',
  'reportSaved': 'Report saved.',
  'markedAs': 'marked as',
  'templateCharacterName': 'Character Profile',
  'templateCharacterSubtitle': 'Wiki entry template',
  'templateCharacterDescription':
      'Character pages will connect dolls, pets and accessories.',
  'templateDollName': 'Doll Release',
  'templateDollSubtitle': 'Owned, wanted, trade',
  'templateDollDescription':
      'Doll releases will be tracked as collection pieces.',
  'templatePetName': 'Pet Companion',
  'templatePetSubtitle': 'Linked to character',
  'templatePetDescription': 'Pets can connect to characters and doll releases.',
  'templateAccessoryName': 'Accessory Piece',
  'templateAccessorySubtitle': 'Set completion item',
  'templateAccessoryDescription':
      'Accessories help users complete detailed sets.',
  'typeCharacter': 'Character',
  'typeDoll': 'Doll',
  'typeSet': 'Set',
  'typePet': 'Pet',
  'typeAccessory': 'Accessory',
  'statusOwned': 'owned',
  'statusWanted': 'wanted',
  'statusTrade': 'trade',
  'statusSelling': 'selling',
};
