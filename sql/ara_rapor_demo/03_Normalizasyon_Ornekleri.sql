USE BistRaporDemo;
GO
-- YALNIZCA OKUMA: Bunlar öğretici normalizasyon ÖNCESİ görünümlerdir.
-- Bir JOIN sonucunda tekrar görülmesi, mevcut ayrı tabloların bozuk olduğu anlamına gelmez.
-- Bu birleşik yapılar kalıcı tek tablo olsaydı aşağıdaki bağımlılıklar sorun oluştururdu.

-- ÖRNEK 1 / 3NF: HisseId -> SektorId -> SektorAdi.
-- Aynı sektör adı birçok hisse satırında tekrar eder.
SELECT h.HisseId,h.Sembol,h.SirketAdi,s.SektorId,s.SektorAdi
FROM dbo.Hisse h JOIN dbo.Sektor s ON s.SektorId=h.SektorId
WHERE s.SektorAdi=N'Bankacılık' ORDER BY h.HisseId;
-- SONRASI: Sektor(SektorId PK, SektorAdi UQ) + Hisse(..., SektorId FK).
-- Sektör adı değişikliği tek Sektor satırında yapılır; hisse olmadan sektör eklenebilir.
GO
-- ÖRNEK 2 / 1NF: Bir hücrede birden çok takip sembolü.
SELECT k.KullaniciId,k.KullaniciAdi,STRING_AGG(h.Sembol,N', ') TakipEdilenSemboller
FROM dbo.Kullanici k JOIN dbo.IzlemeListesi i ON i.KullaniciId=k.KullaniciId
JOIN dbo.Hisse h ON h.HisseId=i.HisseId GROUP BY k.KullaniciId,k.KullaniciAdi;
-- SONRASI: Her takip tek satır; PK(KullaniciId,HisseId), iki FK.
SELECT k.KullaniciAdi,h.Sembol,i.EklenmeTarihi FROM dbo.IzlemeListesi i
JOIN dbo.Kullanici k ON k.KullaniciId=i.KullaniciId
JOIN dbo.Hisse h ON h.HisseId=i.HisseId ORDER BY k.KullaniciAdi,h.Sembol;
-- Kullanıcı ve sembol açıklamaları takip tablosunda tutulursa 2NF de ihlal edilir:
-- KullaniciId -> KullaniciAdi ve HisseId -> Sembol, birleşik anahtarın parçalarıdır.
GO
-- ÖRNEK 3 / 2NF: (HisseId,Tarih) -> Kapanis, fakat HisseId -> SirketAdi.
SELECT TOP(6) h.HisseId,f.Tarih,h.Sembol,h.SirketAdi,f.Kapanis
FROM dbo.FiyatGecmisi f JOIN dbo.Hisse h ON h.HisseId=f.HisseId
WHERE h.Sembol=N'THYAO' ORDER BY f.Tarih;
-- SONRASI: Hisse + FiyatGecmisi; UQ(HisseId,Tarih), FK(HisseId).
-- Şirket adı fiyat günlerinden bağımsız bir kez saklanır.
GO
-- ÖRNEK 4 / 3NF: IslemId -> KullaniciId -> KullaniciAdi,Eposta.
SELECT TOP(8) p.IslemId,k.KullaniciId,k.KullaniciAdi,k.Eposta,
p.HisseId,p.IslemTuru,p.Adet,p.Fiyat,p.IslemZamani
FROM dbo.PortfoyIslem p JOIN dbo.Kullanici k ON k.KullaniciId=p.KullaniciId
ORDER BY k.KullaniciId,p.IslemZamani,p.IslemId;
-- SONRASI: Kullanici + PortfoyIslem; kullanıcı kimliği işlemde FK.
-- E-posta tek yerde güncellenir; son işlem silinse de kullanıcı kaydı korunur.
GO
-- ÖRNEK 5 / 2NF: (HisseId,Tarih) -> SMA20,SMA50; HisseId -> SirketAdi.
SELECT TOP(6) h.HisseId,t.Tarih,h.Sembol,h.SirketAdi,t.SMA20,t.SMA50
FROM dbo.TeknikGosterge t JOIN dbo.Hisse h ON h.HisseId=t.HisseId
WHERE h.Sembol=N'THYAO' AND t.SMA50 IS NOT NULL ORDER BY t.Tarih;
-- SONRASI: Hisse + TeknikGosterge; UQ(HisseId,Tarih), FK(HisseId).
-- Yapay GostergeId eklemek doğal birleşik anahtardaki kısmi bağımlılığı tek başına çözmez.
-- Her örnekte rapora: önceki ilişki, aday anahtarlar, FD, ihlal, ekleme/silme/güncelleme
-- anomalileri, sonraki ilişkiler ve PK/FK yazılmalıdır. Ayrıştırmada ortak kimlik,
-- açıklama tablosunun anahtarı olduğu için ilgili ikili ayrıştırmalar kayıpsızdır.
