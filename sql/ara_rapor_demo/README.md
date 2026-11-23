# Ara rapor için örnek veri ortamı

Bu çalışma mevcut `BistDB` veritabanından bağımsız `BistRaporDemo` ortamını oluşturur. 11 tablonun yapısı projenin mevcut şemasına dayanır. Fiyatlar eğitim amaçlı kurgu veridir; gerçek piyasa verisi veya yatırım önerisi değildir.

## Çalıştırma sırası

1. SQL Server bağlantısında `01_Guclu_Ornek_Veriler.sql` dosyasını çalıştırın. Yeni veritabanı oluşturma yetkisi gerekir. `BistRaporDemo` zaten varsa dosya hata vererek durur; mevcut verileri silmez. Şema ve veri yükleme işlemleri transaction içindedir; hata durumunda yeni veritabanı boş kalabilir. Böyle bir durumda silme işlemi yapmadan hatayı inceleyin.
2. `02_Kontrol_ve_Rapor_Sorgulari.sql` dosyasını çalıştırın. İlk bölüm veri tutarlılığını denetler, sonraki SELECT sorguları rapor görselleri içindir.
3. `03_Normalizasyon_Ornekleri.sql` dosyasındaki sorguları örnekleri incelemek için ayrı ayrı çalıştırın. Bu dosya veri değiştirmez.

SQL dosyalarında `GO` ayırıcılarını destekleyen bir istemci kullanın (örneğin VS Code MSSQL). Bağlantı parolanızı dosyalara yazmayın.

## Veri kapsamı

- 13 sektör, 30 hisse, 5 demo kullanıcı ve 20 takip ilişkisi.
- 30 hissenin her biri için 120 günlük fiyat: StagingFiyat ve FiyatGecmisi tablolarında 3600'er kayıt.
- 3600 gösterge: SMA20 ilk 19, SMA50 ilk 49 gözlemde NULL; tam pencere oluşunca hesaplanır.
- SMA20'nin SMA50'yi yukarı kesmesinde AL, aşağı kesmesinde SAT: bu veri setinde 60 sinyal.
- 30 son fiyat kaydı, 20 sanal portföy işlemi ve 4 açıklayıcı log kaydı.

Hafta sonları dışlanır; resmi tatiller modellenmemiştir. Bu nedenle tarihler resmi BIST işlem takvimi olarak sunulmamalıdır. Son fiyatlar veri setinin son gününe aittir; canlı fiyat değildir.

Sinyaller SQL window function kullanılarak hesaplanır. Portföy kayıtları strateji performans testi değildir. Loglar hazırlama betiğinde eklenir; trigger veya stored procedure uygulandığı iddia edilmez. Yeni web uygulaması veya gerçek veri çekme özelliği bu değişiklik kapsamında değildir.

## Normalizasyon ve ekran görüntüleri

Beş öğretici örnek; sektör bilgisinin ayrılması, çok değerli takip listesi, fiyat kayıtlarındaki şirket bilgisi, işlemlerdeki kullanıcı bilgisi ve göstergelerdeki şirket bilgisi üzerinedir. JOIN ile oluşturulan normalizasyon öncesi görünümler mevcut şemanın bozuk olduğunu göstermez; tek bir kalıcı tablo olsaydı oluşacak tekrarları anlatır. Rapor ayrıca aday anahtarları, fonksiyonel bağımlılıkları, anomalileri ve ayrıştırmayı açıklamalıdır.

Ekran görüntüleri `rapor/ara_rapor_1/guncel_veri_tablolari/` altındadır. Büyük tablolarda seçilmiş örnek satırlar gösterilir; `12_kayit_sayilari.png` toplamları gösterir. Teknik gösterge ve sinyal görselleri okunabilirlik için sembolle birleştirilmiş sorgu sonuçlarıdır; bütün fiziksel sütunları göstermez.

## Doğrulama

SQL Server 2022 üzerinde kurulum ve iki sorgu dosyası başarıyla çalıştırıldı. Kontroller; kayıt sayıları, hisse başına 120 gözlem, fiyat aralıkları, NULL pencere sayıları, bakiyelerin işlem toplamıyla uyumu, eldeki lotu aşan satış olmaması ve sinyallerin kesişim kuralıyla eşleşmesini kapsar.
