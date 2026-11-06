-- =====================================================================
-- 02_ornek_veri.sql : sektor ve hisse verileri
-- once 01_tablolar.sql calismis olmali
-- dosyayi tekrar calistirsam hata vermez (NOT EXISTS sayesinde)
-- 13 sektor ve 30 bilindik hisse ekliyorum
-- =====================================================================

USE BistDB;                                  -- BistDB veritabanini sectim, komutlar burada calisacak
GO                                           -- SSMS'e "paket burada bitti" dedim, SQL komutu degil

-- ---------------------------------------------------------------------
-- 1. sektorler (13 tane)
-- ---------------------------------------------------------------------
-- once sektor ekledik, cunku Hisse tablosu Sektor'e bagli (FK)
-- (VALUES ...) = elle yazdigim gecici tablo
-- NOT EXISTS   = sektor zaten varsa eklemiyorum
-- N'...'       = turkce karakter bozulmasin diye koydum
-- SektorId yazmadim, IDENTITY kendisi veriyor

INSERT INTO Sektor (SektorAdi)               -- Sektor tablosundaki SektorAdi sutununa ekleme yapiyorum
SELECT v.Ad                                  -- gecici tablodaki sektor adlarini aliyorum
FROM (VALUES                                 -- gecici tabloyu burada yazmaya basladim
    (N'Bankacılık'),                         -- her satirda bir sektor adi yazdim
    (N'Ulaştırma'),
    (N'Savunma'),
    (N'Enerji'),
    (N'Demir-Çelik'),
    (N'Holding'),
    (N'Perakende'),
    (N'Otomotiv'),
    (N'Telekomünikasyon'),
    (N'Gıda ve İçecek'),                     -- hisse sayisi artinca yeni sektorler ekledim
    (N'Dayanıklı Tüketim'),
    (N'Kimya'),
    (N'Cam')
) AS v(Ad)                                   -- gecici tabloya v, sutuna Ad adini verdim
WHERE NOT EXISTS (SELECT 1 FROM Sektor s WHERE s.SektorAdi = v.Ad);   -- tabloda zaten varsa eklemedim, tekrar calistirinca hata cikmasin diye
GO

-- ---------------------------------------------------------------------
-- 2. hisseler (30 tane)
-- ---------------------------------------------------------------------
-- JOIN sektor adindan SektorId'yi buluyor, numara ezberlemiyorum
-- sektor adini yanlis yazarsam o hisse eklenmez

INSERT INTO Hisse (Sembol, SirketAdi, SektorId)   -- Hisse tablosuna 3 sutunu dolduruyorum
SELECT v.Sembol, v.Sirket, s.SektorId             -- SektorId'yi gecici tablodan degil Sektor tablosundan aldim
FROM (VALUES                                      -- gecici tabloyu burada yazmaya basladim
    -- bankacilik (6)
    (N'GARAN', N'Türkiye Garanti Bankası',       N'Bankacılık'),   -- sembol, sirket adi, sektor adi yazdim (.IS yazmadim)
    (N'AKBNK', N'Akbank',                        N'Bankacılık'),
    (N'ISCTR', N'Türkiye İş Bankası',            N'Bankacılık'),
    (N'YKBNK', N'Yapı ve Kredi Bankası',         N'Bankacılık'),
    (N'VAKBN', N'Vakıflar Bankası',              N'Bankacılık'),
    (N'HALKB', N'Türkiye Halk Bankası',          N'Bankacılık'),
    -- ulastirma (3)
    (N'THYAO', N'Türk Hava Yolları',             N'Ulaştırma'),
    (N'PGSUS', N'Pegasus Hava Taşımacılığı',     N'Ulaştırma'),
    (N'TAVHL', N'TAV Havalimanları',             N'Ulaştırma'),
    -- savunma (1)
    (N'ASELS', N'Aselsan',                       N'Savunma'),
    -- enerji (3)
    (N'TUPRS', N'Tüpraş',                        N'Enerji'),
    (N'ENJSA', N'Enerjisa Enerji',               N'Enerji'),
    (N'AKSEN', N'Aksa Enerji',                   N'Enerji'),
    -- demir celik (2)
    (N'EREGL', N'Ereğli Demir ve Çelik',         N'Demir-Çelik'),
    (N'KRDMD', N'Kardemir',                      N'Demir-Çelik'),
    -- holding (2)
    (N'KCHOL', N'Koç Holding',                   N'Holding'),
    (N'SAHOL', N'Sabancı Holding',               N'Holding'),
    -- perakende (3)
    (N'BIMAS', N'BİM Birleşik Mağazalar',        N'Perakende'),
    (N'MGROS', N'Migros',                        N'Perakende'),
    (N'SOKM',  N'Şok Marketler',                 N'Perakende'),
    -- otomotiv (2)
    (N'FROTO', N'Ford Otosan',                   N'Otomotiv'),
    (N'TOASO', N'Tofaş Türk Otomobil Fabrikası', N'Otomotiv'),
    -- telekom (2)
    (N'TCELL', N'Turkcell',                      N'Telekomünikasyon'),
    (N'TTKOM', N'Türk Telekom',                  N'Telekomünikasyon'),
    -- gida ve icecek (3)
    (N'ULKER', N'Ülker Bisküvi',                 N'Gıda ve İçecek'),
    (N'AEFES', N'Anadolu Efes',                  N'Gıda ve İçecek'),
    (N'CCOLA', N'Coca-Cola İçecek',              N'Gıda ve İçecek'),
    -- dayanikli tuketim (1)
    (N'ARCLK', N'Arçelik',                       N'Dayanıklı Tüketim'),
    -- kimya (1)
    (N'PETKM', N'Petkim',                        N'Kimya'),
    -- cam (1)
    (N'SISE',  N'Şişecam',                       N'Cam')
) AS v(Sembol, Sirket, SektorAdi)                 -- gecici tabloya v, sutunlara Sembol, Sirket, SektorAdi adlarini verdim
JOIN Sektor s ON s.SektorAdi = v.SektorAdi        -- sektor adlarini eslestirdim, boylece SektorId geliyor
WHERE NOT EXISTS (SELECT 1 FROM Hisse h WHERE h.Sembol = v.Sembol);   -- sembol zaten varsa eklemedim
GO

-- ---------------------------------------------------------------------
-- 3. kontrol sorgulari
-- ---------------------------------------------------------------------

SELECT * FROM Sektor ORDER BY SektorId;      -- tum sektorleri getirdim, 13 satir gelmeli
GO


SELECT s.SektorAdi, h.Sembol, h.SirketAdi    -- sektor adi, sembol ve sirket adini sectim
FROM Hisse h                                 -- Hisse tablosuna h dedim
JOIN Sektor s ON s.SektorId = h.SektorId     -- Sektor tablosunu (s) SektorId uzerinden bagladim
ORDER BY s.SektorAdi, h.Sembol;              -- once sektore sonra sembole gore siraladim, 30 satir gelmeli
GO

-- sektor basina hisse sayisi (GROUP BY ornegi)
SELECT s.SektorAdi, COUNT(h.HisseId) AS HisseSayisi   -- sektor adini ve hisse sayisini sectim
FROM Sektor s
LEFT JOIN Hisse h ON h.SektorId = s.SektorId   -- LEFT JOIN: hissesi olmayan sektor 0 gorunur
GROUP BY s.SektorAdi                         -- her sektoru ayri grup yaptim, sayiyi gruba gore aldim
ORDER BY HisseSayisi DESC;                   -- en cok hissesi olan sektoru en uste koydum
GO



-- ---------------------------------------------------------------------
-- 4. hata testleri 
-- ---------------------------------------------------------------------
-- test icin: tek bir komutu fareyle secip sadece onu calistiriyorum
-- hata mesajinin ss'ini aliyorum
/*
-- test 1: ayni sembol iki kere   -> UQ_Hisse_Sembol hatasi
INSERT INTO Hisse (Sembol, SirketAdi, SektorId)
VALUES (N'THYAO', N'Deneme', (SELECT TOP 1 SektorId FROM Sektor));   -- THYAO zaten var, UNIQUE izin vermedi
-- test 2: ayni sektor iki kere   -> UQ_Sektor_SektorAdi hatasi
INSERT INTO Sektor (SektorAdi) VALUES (N'Bankacılık');               -- Bankacilik zaten var, UNIQUE izin vermedi
-- test 3: olmayan sektor         -> FK_Hisse_Sektor hatasi
INSERT INTO Hisse (Sembol, SirketAdi, SektorId)
VALUES (N'TEST1', N'Deneme', 999);                                    -- 999 numarali sektor yok, FK izin vermedi
-- test 4: sektorsuz hisse        -> NOT NULL hatasi
INSERT INTO Hisse (Sembol, SirketAdi, SektorId)
VALUES (N'TEST2', N'Deneme', NULL);                                   -- SektorId NOT NULL, bos birakmama izin vermedi
*/