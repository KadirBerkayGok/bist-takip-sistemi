USE BistRaporDemo;
GO
SET NOCOUNT ON;
-- Bu dosya yalnızca okur; aşağıdaki denetimlerde sorun varsa hata verir.
IF (SELECT COUNT(*) FROM dbo.Hisse)<>30 OR (SELECT COUNT(*) FROM dbo.Sektor)<>13
 THROW 51001,N'Hisse veya sektör sayısı beklenenden farklı.',1;
IF (SELECT COUNT(*) FROM dbo.FiyatGecmisi)<>3600
 OR (SELECT COUNT(*) FROM dbo.TeknikGosterge)<>3600
 OR (SELECT COUNT(*) FROM dbo.StagingFiyat)<>3600
 THROW 51002,N'Fiyat veya gösterge sayısı beklenenden farklı.',1;
IF EXISTS(SELECT HisseId FROM dbo.FiyatGecmisi GROUP BY HisseId HAVING COUNT(*)<>120)
 THROW 51003,N'Hisse başına 120 gün sağlanmadı.',1;
IF EXISTS(SELECT 1 FROM dbo.FiyatGecmisi WHERE Acilis<=0 OR Dusuk<=0
 OR Yuksek<Acilis OR Yuksek<Kapanis OR Dusuk>Acilis OR Dusuk>Kapanis OR Hacim<0)
 THROW 51004,N'Fiyat aralığı tutarsız.',1;
IF (SELECT COUNT(*) FROM dbo.TeknikGosterge WHERE SMA20 IS NULL)<>570
 OR (SELECT COUNT(*) FROM dbo.TeknikGosterge WHERE SMA50 IS NULL)<>1470
 THROW 51005,N'Ortalama pencereleri tutarsız.',1;
IF EXISTS(SELECT 1 FROM dbo.Kullanici k CROSS APPLY(
 SELECT CAST(100000+SUM(CASE WHEN IslemTuru=N'ALIS' THEN -Adet*Fiyat ELSE Adet*Fiyat END)
 AS decimal(14,2)) Beklenen FROM dbo.PortfoyIslem p WHERE p.KullaniciId=k.KullaniciId)x
 WHERE k.Bakiye<>x.Beklenen)
 THROW 51006,N'Bakiye ve işlem toplamı uyumsuz.',1;
IF EXISTS(SELECT 1 FROM(SELECT SUM(CASE WHEN IslemTuru=N'ALIS' THEN Adet ELSE -Adet END)
 OVER(PARTITION BY KullaniciId,HisseId ORDER BY IslemZamani,IslemId ROWS UNBOUNDED PRECEDING) Lot
 FROM dbo.PortfoyIslem)q WHERE Lot<0)
 THROW 51007,N'Eldeki lotu aşan satış var.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Sinyal WHERE SinyalTuru=N'AL')
 OR NOT EXISTS(SELECT 1 FROM dbo.Sinyal WHERE SinyalTuru=N'SAT')
 THROW 51008,N'Her iki yönde kesişim örneği bulunamadı.',1;
;WITH W AS(SELECT *,LAG(SMA20)OVER(PARTITION BY HisseId ORDER BY Tarih) p20,
LAG(SMA50)OVER(PARTITION BY HisseId ORDER BY Tarih) p50 FROM dbo.TeknikGosterge)
SELECT HisseId,Tarih,CASE WHEN SMA20>SMA50 THEN N'AL' ELSE N'SAT' END SinyalTuru
INTO #Beklenen FROM W WHERE (p20<=p50 AND SMA20>SMA50) OR(p20>=p50 AND SMA20<SMA50);
IF EXISTS(SELECT HisseId,Tarih,SinyalTuru FROM #Beklenen EXCEPT SELECT HisseId,Tarih,SinyalTuru FROM dbo.Sinyal)
 OR EXISTS(SELECT HisseId,Tarih,SinyalTuru FROM dbo.Sinyal EXCEPT SELECT HisseId,Tarih,SinyalTuru FROM #Beklenen)
 THROW 51009,N'Sinyaller kesişim kuralıyla eşleşmiyor.',1;
DROP TABLE #Beklenen;
PRINT N'Bütün veri tutarlılığı kontrolleri başarılı.';
GO
-- 1. Rapor için genel sayı özeti
SELECT N'Sektor' Tablo,COUNT(*) KayitSayisi FROM dbo.Sektor UNION ALL
SELECT N'Hisse',COUNT(*) FROM dbo.Hisse UNION ALL
SELECT N'Kullanici',COUNT(*) FROM dbo.Kullanici UNION ALL
SELECT N'IzlemeListesi',COUNT(*) FROM dbo.IzlemeListesi UNION ALL
SELECT N'StagingFiyat',COUNT(*) FROM dbo.StagingFiyat UNION ALL
SELECT N'FiyatGecmisi',COUNT(*) FROM dbo.FiyatGecmisi UNION ALL
SELECT N'AnlikFiyat',COUNT(*) FROM dbo.AnlikFiyat UNION ALL
SELECT N'TeknikGosterge',COUNT(*) FROM dbo.TeknikGosterge UNION ALL
SELECT N'Sinyal',COUNT(*) FROM dbo.Sinyal UNION ALL
SELECT N'PortfoyIslem',COUNT(*) FROM dbo.PortfoyIslem UNION ALL
SELECT N'IslemLog',COUNT(*) FROM dbo.IslemLog;
GO
-- 2. Küçük tablolar: ayrı ayrı seçip çalıştırın ve ekran görüntüsü alın.
SELECT * FROM dbo.Sektor ORDER BY SektorId;
SELECT * FROM dbo.Hisse ORDER BY HisseId;
SELECT * FROM dbo.Kullanici ORDER BY KullaniciId;
SELECT * FROM dbo.IzlemeListesi ORDER BY KullaniciId,HisseId;
SELECT * FROM dbo.AnlikFiyat ORDER BY HisseId;
SELECT * FROM dbo.PortfoyIslem ORDER BY KullaniciId,IslemZamani,HisseId;
SELECT * FROM dbo.IslemLog ORDER BY LogId;
GO
-- 3. Büyük tablolar: bütün kayıtlar yerine okunaklı bir kesit + toplam kayıt sayısını gösterin.
-- Rapor açıklaması: "3600 kayıt içinden THYAO için son 8 örnek kayıt gösterilmiştir."
SELECT TOP(8) s.* FROM dbo.StagingFiyat s WHERE Sembol=N'THYAO' ORDER BY Tarih DESC;
SELECT TOP(8) f.* FROM dbo.FiyatGecmisi f JOIN dbo.Hisse h ON h.HisseId=f.HisseId
WHERE h.Sembol=N'THYAO' ORDER BY Tarih DESC;
SELECT TOP(8) t.* FROM dbo.TeknikGosterge t JOIN dbo.Hisse h ON h.HisseId=t.HisseId
WHERE h.Sembol=N'THYAO' ORDER BY Tarih DESC;
SELECT TOP(12) s.*,h.Sembol FROM dbo.Sinyal s JOIN dbo.Hisse h ON h.HisseId=s.HisseId
ORDER BY Tarih DESC,h.Sembol;
GO
-- 4. NULL değerinin nedenini göstermek için 19/20 ve 49/50. gün sınırları
;WITH W AS(SELECT t.*,h.Sembol,ROW_NUMBER() OVER(PARTITION BY t.HisseId ORDER BY Tarih) Gun
FROM dbo.TeknikGosterge t JOIN dbo.Hisse h ON h.HisseId=t.HisseId WHERE h.Sembol=N'THYAO')
SELECT Gun,Sembol,Tarih,SMA20,SMA50 FROM W WHERE Gun IN(19,20,49,50,51,120) ORDER BY Gun;
GO
-- 5. SMA20'nin ilk tam penceresini bağımsız AVG ile karşılaştırın.
SELECT h.Sembol,t.Tarih,t.SMA20,
(SELECT CAST(AVG(f.Kapanis) AS decimal(12,4)) FROM dbo.FiyatGecmisi f
 WHERE f.HisseId=t.HisseId AND f.Tarih<=t.Tarih) Ilk20GunOrtalamasi
FROM dbo.TeknikGosterge t JOIN dbo.Hisse h ON h.HisseId=t.HisseId
WHERE t.Tarih=(SELECT MIN(Tarih) FROM dbo.TeknikGosterge WHERE SMA20 IS NOT NULL);
GO
-- 6. Hesaplanan sinyalleri önceki ve sonraki ortalamalarıyla açıklayın.
;WITH W AS(SELECT *,LAG(SMA20)OVER(PARTITION BY HisseId ORDER BY Tarih) OncekiSMA20,
LAG(SMA50)OVER(PARTITION BY HisseId ORDER BY Tarih) OncekiSMA50 FROM dbo.TeknikGosterge)
SELECT TOP(12) h.Sembol,s.Tarih,w.OncekiSMA20,w.OncekiSMA50,w.SMA20,w.SMA50,s.SinyalTuru
FROM dbo.Sinyal s JOIN W w ON w.HisseId=s.HisseId AND w.Tarih=s.Tarih
JOIN dbo.Hisse h ON h.HisseId=s.HisseId ORDER BY s.Tarih DESC,h.Sembol;
GO
