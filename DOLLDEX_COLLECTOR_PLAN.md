# DollDex Collector - Baslangic Plani

## Urun Kimligi

Uygulama adi: DollDex Collector

Konumlandirma: Resmi olmayan koleksiyon takip, katalog ve topluluk uygulamasi.

Ilk kural: Uygulama adi, ikon, magazaza gorselleri ve aciklama resmi marka ortakligi ima etmeyecek. Marka ve karakter adlari yalnizca koleksiyon katalog verisi olarak, gerekli hukuki dikkatle kullanilacak.

## Ilk Surum Hedefi

Ilk surumun amaci, Google Play'e daha sorunsuz cikabilecek temiz bir cekirdek kurmaktir:

- Google ile giris
- Katalog ve wiki
- Admin panelden icerik ekleme
- PNG/JPG/WebP URL onizleme ve gorsel olarak gosterme
- Kullanici koleksiyonu
- Arama ve filtreleme
- Yorum ve raporlama
- Pro uyelik altyapisi
- Pro olmayanlar icin reklam altyapisi
- Bildirim temeli
- Gizlilik politikasi, hesap silme ve Play Store uyumlulugu

Mesajlasma, arkadaslik ve gelismis sosyal akisi ikinci asamada eklemek daha guvenlidir. Boylece ilk incelemede moderasyon riski azalir.

## Fotoğraf URL Stratejisi

Kullanicilar ve adminler fotoğrafi uygulamaya dosya olarak yuklemeyecek, gorsel URL'si ekleyecek.

Uygulamada URL ham metin olarak gorunmeyecek; kartlarda ve detay sayfalarinda dogrudan fotoğraf olarak render edilecek.

URL kabul kurallari:

- Sadece `https://` kabul edilir.
- Dosya uzantisi veya response tipi gorsel olmali: PNG, JPG, JPEG, WebP.
- URL onizleme paneli olacak.
- Bozuk gorsel icin zarif placeholder gosterilecek.
- Supheli veya calismayan URL kaydedilmeden once uyari verilecek.
- Kullanici tarafindan girilen gorseller raporlanabilir olacak.

Uygulama icinde onerilebilecek gorsel barindirma secenekleri:

- Cloudinary: Gelistirici dostu, ucretsiz plani var, CDN ve donusturme destekli. En profesyonel secenek.
- Firebase Storage: Ileride kendi kontrollu yukleme istenirse en uyumlu secenek. Ucretsiz kota var ama buyumede maliyet dogurabilir.
- ImageKit veya benzeri CDN odakli servisler: Ikinci alternatif olarak incelenebilir.

Kisa urun metni:

"Fotoğraf URL'si ekleyin. Gorsel uygulamada otomatik onizlenir; link metni ziyaretcilere gosterilmez."

## Veri Modeli

Ana koleksiyonlar:

- `users`
- `characters`
- `items`
- `sets`
- `pets`
- `accessories`
- `collectionEntries`
- `comments`
- `reports`
- `notifications`
- `subscriptions`
- `adminLogs`
- `appConfig`

`items` temel alanlari:

- `name`
- `slug`
- `type`
- `characterIds`
- `setIds`
- `year`
- `releaseLine`
- `rarity`
- `imageUrls`
- `includedAccessoryIds`
- `petIds`
- `tags`
- `createdAt`
- `updatedAt`
- `createdBy`

`collectionEntries` temel alanlari:

- `userId`
- `itemId`
- `status`: owned, wanted, trade, selling
- `condition`: boxed, unboxed, complete, incomplete, damaged
- `quantity`
- `visibility`: public, friends, private
- `notes`
- `createdAt`
- `updatedAt`

## Ekranlar

Mobil:

- Giris
- Ana sayfa
- Arama
- Katalog listesi
- Karakter detayi
- Item detayi
- Set detayi
- Koleksiyonum
- Profil
- Bildirimler
- Pro
- Ayarlar
- Raporla

Web:

- Ana katalog
- Detay sayfalari
- Profil ve koleksiyon
- Admin panel
- Gizlilik politikasi
- Kullanim sartlari
- Hesap silme talebi

## Admin Panel

Admin panelde olacaklar:

- Karakter ekle/duzenle/sil
- Item ekle/duzenle/sil
- Set ekle/duzenle/sil
- Pet ve aksesuar ekle
- Fotoğraf URL onizlemesi
- Rapor kuyrugu
- Kullanici kisitlama
- Pro durum kontrolu
- App config
- Admin log

## Pro ve Reklam

Pro olmayan:

- Reklam gorur
- Temel koleksiyon ve katalog ozelliklerini kullanir

Pro olan:

- Reklamsiz
- Gelismis koleksiyon istatistikleri
- Daha fazla vitrin alani
- Gelismis filtreler
- Profil rozeti

Android'de Pro satin alma Google Play Billing ile yapilacak. Pro durumu sadece sunucu tarafindan dogrulanacak.

## Guvenlik ve Moderasyon

- Firestore Security Rules zorunlu.
- Kullanici kendi verisini duzenleyebilir.
- Admin harici katalog degistiremez.
- Raporlama tum kullanici iceriklerinde bulunur.
- Hesap silme uygulama icinde ve webde olur.
- Gereksiz Android izni istenmez.
- Mesajlasma ikinci asamaya birakilirsa ilk cikis daha risksiz olur.

## Gelistirme Sirasi

1. Flutter projesi olustur.
2. Firebase baglantisini hazirla.
3. Tasarim temasi ve ana navigasyonu kur.
4. Auth ekranini ekle.
5. Firestore model katmanini kur.
6. Katalog liste/detay ekranlarini yap.
7. URL gorsel onizleme bilesenini yap.
8. Admin panel MVP'sini yap.
9. Koleksiyona ekleme akisini yap.
10. Raporlama ve yorumlari ekle.
11. Reklam ve Pro temelini ekle.
12. Play Store uyumluluk sayfalarini hazirla.

## Teknik Not

Bu dosya, DollDex Collector icin ilk urun ve teknik yol haritasidir. Kod baslangici icin Flutter CLI ve Firebase CLI ile proje olusturulacak; yerel ortam komutlari calisabilir hale geldiginde iskelet uygulama kurulumu yapilacaktir.

## Eklenen Ilk Kod Modulleri

- Flutter uygulama kabugu
- Katalog ve koleksiyon modelleri
- Admin katalog formu
- URL gorsel dogrulama
- Google giris servis taslagi
- Firestore katalog ve koleksiyon repository taslaklari
- Raporlama modeli ve formu
- Pro entitlement modeli
- Google Play Billing servis taslagi
- AdMob servis taslagi
- Firebase Cloud Messaging servis taslagi
- Gizlilik ve hesap silme sayfa taslaklari
