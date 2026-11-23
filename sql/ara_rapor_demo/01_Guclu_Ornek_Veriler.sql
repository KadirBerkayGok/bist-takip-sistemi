-- BIST ara rapor için güçlendirilmiş örnek veri ortamı
-- BistDB değişmez. BistRaporDemo zaten varsa durur; tekrar çalıştırmak verileri silmez.
-- Gerçek piyasa verisi değildir. Hafta sonları dışlanır, resmi tatiller modellenmez.
USE master;
SET NOCOUNT ON;
IF DB_ID(N'BistRaporDemo') IS NOT NULL
    THROW 51000, N'BistRaporDemo zaten var. Mevcut veriler değiştirilmedi. Kontrol dosyasını çalıştırın.', 1;
EXEC(N'CREATE DATABASE BistRaporDemo');
EXEC sys.sp_executesql N'USE BistRaporDemo; SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRY BEGIN TRANSACTION;
CREATE TABLE Sektor (
    SektorId  INT IDENTITY(1,1) NOT NULL
              CONSTRAINT PK_Sektor PRIMARY KEY,
    SektorAdi NVARCHAR(50) NOT NULL
              CONSTRAINT UQ_Sektor_SektorAdi UNIQUE
);
CREATE TABLE Hisse (
    HisseId   INT IDENTITY(1,1) NOT NULL
              CONSTRAINT PK_Hisse PRIMARY KEY,
    Sembol    NVARCHAR(10)  NOT NULL
              CONSTRAINT UQ_Hisse_Sembol UNIQUE,
    SirketAdi NVARCHAR(100) NOT NULL,
    SektorId  INT NOT NULL
              CONSTRAINT FK_Hisse_Sektor REFERENCES Sektor(SektorId)
);
CREATE TABLE FiyatGecmisi (
    FiyatId BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_FiyatGecmisi PRIMARY KEY,
    HisseId INT NOT NULL
            CONSTRAINT FK_FiyatGecmisi_Hisse REFERENCES Hisse(HisseId),
    Tarih   DATE NOT NULL,
    Acilis  DECIMAL(12,4) NULL,
    Yuksek  DECIMAL(12,4) NULL,
    Dusuk   DECIMAL(12,4) NULL,
    Kapanis DECIMAL(12,4) NOT NULL
            CONSTRAINT CK_FiyatGecmisi_Kapanis CHECK (Kapanis > 0),
    Hacim   BIGINT NULL
            CONSTRAINT CK_FiyatGecmisi_Hacim CHECK (Hacim >= 0),
    CONSTRAINT UQ_FiyatGecmisi_HisseTarih UNIQUE (HisseId, Tarih),
    CONSTRAINT CK_FiyatGecmisi_YuksekDusuk
        CHECK (Yuksek IS NULL OR Dusuk IS NULL OR Yuksek >= Dusuk)
);
CREATE TABLE TeknikGosterge (
    GostergeId INT IDENTITY(1,1) NOT NULL
               CONSTRAINT PK_TeknikGosterge PRIMARY KEY,
    HisseId    INT NOT NULL
               CONSTRAINT FK_TeknikGosterge_Hisse REFERENCES Hisse(HisseId),
    Tarih      DATE NOT NULL,
    SMA20      DECIMAL(12,4) NULL,
    SMA50      DECIMAL(12,4) NULL,
    CONSTRAINT UQ_TeknikGosterge_HisseTarih UNIQUE (HisseId, Tarih)
);
CREATE TABLE Sinyal (
    SinyalId   INT IDENTITY(1,1) NOT NULL
               CONSTRAINT PK_Sinyal PRIMARY KEY,
    HisseId    INT NOT NULL
               CONSTRAINT FK_Sinyal_Hisse REFERENCES Hisse(HisseId),
    Tarih      DATE NOT NULL,
    SinyalTuru NVARCHAR(3) NOT NULL
               CONSTRAINT CK_Sinyal_Turu CHECK (SinyalTuru IN (N''AL'', N''SAT'')),
    CONSTRAINT UQ_Sinyal_HisseTarih UNIQUE (HisseId, Tarih)
);
CREATE TABLE Kullanici (
    KullaniciId  INT IDENTITY(1,1) NOT NULL
                 CONSTRAINT PK_Kullanici PRIMARY KEY,
    KullaniciAdi NVARCHAR(50)  NOT NULL
                 CONSTRAINT UQ_Kullanici_KullaniciAdi UNIQUE,
    Eposta       NVARCHAR(100) NOT NULL
                 CONSTRAINT UQ_Kullanici_Eposta UNIQUE,
    Bakiye       DECIMAL(14,2) NOT NULL
                 CONSTRAINT DF_Kullanici_Bakiye DEFAULT 100000
                 CONSTRAINT CK_Kullanici_Bakiye CHECK (Bakiye >= 0),
    KayitTarihi  DATETIME NOT NULL
                 CONSTRAINT DF_Kullanici_KayitTarihi DEFAULT GETDATE()
);
CREATE TABLE IzlemeListesi (
    KullaniciId   INT NOT NULL
                  CONSTRAINT FK_IzlemeListesi_Kullanici REFERENCES Kullanici(KullaniciId),
    HisseId       INT NOT NULL
                  CONSTRAINT FK_IzlemeListesi_Hisse REFERENCES Hisse(HisseId),
    EklenmeTarihi DATETIME NOT NULL
                  CONSTRAINT DF_IzlemeListesi_Eklenme DEFAULT GETDATE(),
    CONSTRAINT PK_IzlemeListesi PRIMARY KEY (KullaniciId, HisseId)
);
CREATE TABLE PortfoyIslem (
    IslemId     INT IDENTITY(1,1) NOT NULL
                CONSTRAINT PK_PortfoyIslem PRIMARY KEY,
    KullaniciId INT NOT NULL
                CONSTRAINT FK_PortfoyIslem_Kullanici REFERENCES Kullanici(KullaniciId),
    HisseId     INT NOT NULL
                CONSTRAINT FK_PortfoyIslem_Hisse REFERENCES Hisse(HisseId),
    IslemTuru   NVARCHAR(5) NOT NULL
                CONSTRAINT CK_PortfoyIslem_Turu CHECK (IslemTuru IN (N''ALIS'', N''SATIS'')),
    Adet        INT NOT NULL
                CONSTRAINT CK_PortfoyIslem_Adet CHECK (Adet > 0),
    Fiyat       DECIMAL(12,4) NOT NULL
                CONSTRAINT CK_PortfoyIslem_Fiyat CHECK (Fiyat > 0),
    IslemZamani DATETIME NOT NULL
                CONSTRAINT DF_PortfoyIslem_Zaman DEFAULT GETDATE()
);
CREATE TABLE IslemLog (
    LogId INT IDENTITY(1,1) NOT NULL
          CONSTRAINT PK_IslemLog PRIMARY KEY,
    Zaman DATETIME NOT NULL
          CONSTRAINT DF_IslemLog_Zaman DEFAULT GETDATE(),
    Mesaj NVARCHAR(200) NOT NULL,
    Hata  NVARCHAR(500) NULL
);
CREATE TABLE StagingFiyat (
    Sembol  NVARCHAR(10)  NULL,
    Tarih   DATE          NULL,
    Acilis  DECIMAL(12,4) NULL,
    Yuksek  DECIMAL(12,4) NULL,
    Dusuk   DECIMAL(12,4) NULL,
    Kapanis DECIMAL(12,4) NULL,
    Hacim   BIGINT        NULL
);
CREATE TABLE AnlikFiyat (
    HisseId          INT NOT NULL
                     CONSTRAINT PK_AnlikFiyat PRIMARY KEY
                     CONSTRAINT FK_AnlikFiyat_Hisse REFERENCES Hisse(HisseId),
    SonFiyat         DECIMAL(12,4) NOT NULL
                     CONSTRAINT CK_AnlikFiyat_SonFiyat CHECK (SonFiyat > 0),
    OncekiKapanis    DECIMAL(12,4) NULL,
    GuncellemeZamani DATETIME NOT NULL
                     CONSTRAINT DF_AnlikFiyat_Zaman DEFAULT GETDATE()
);
INSERT INTO Sektor (SektorAdi)
SELECT v.Ad
FROM (VALUES
    (N''Bankacılık''),
    (N''Ulaştırma''),
    (N''Savunma''),
    (N''Enerji''),
    (N''Demir-Çelik''),
    (N''Holding''),
    (N''Perakende''),
    (N''Otomotiv''),
    (N''Telekomünikasyon''),
    (N''Gıda ve İçecek''),
    (N''Dayanıklı Tüketim''),
    (N''Kimya''),
    (N''Cam'')
) AS v(Ad)
WHERE NOT EXISTS (SELECT 1 FROM Sektor s WHERE s.SektorAdi = v.Ad);

INSERT INTO Hisse (Sembol, SirketAdi, SektorId)
SELECT v.Sembol, v.Sirket, s.SektorId
FROM (VALUES

    (N''GARAN'', N''Türkiye Garanti Bankası'',       N''Bankacılık''),
    (N''AKBNK'', N''Akbank'',                        N''Bankacılık''),
    (N''ISCTR'', N''Türkiye İş Bankası'',            N''Bankacılık''),
    (N''YKBNK'', N''Yapı ve Kredi Bankası'',         N''Bankacılık''),
    (N''VAKBN'', N''Vakıflar Bankası'',              N''Bankacılık''),
    (N''HALKB'', N''Türkiye Halk Bankası'',          N''Bankacılık''),

    (N''THYAO'', N''Türk Hava Yolları'',             N''Ulaştırma''),
    (N''PGSUS'', N''Pegasus Hava Taşımacılığı'',     N''Ulaştırma''),
    (N''TAVHL'', N''TAV Havalimanları'',             N''Ulaştırma''),

    (N''ASELS'', N''Aselsan'',                       N''Savunma''),

    (N''TUPRS'', N''Tüpraş'',                        N''Enerji''),
    (N''ENJSA'', N''Enerjisa Enerji'',               N''Enerji''),
    (N''AKSEN'', N''Aksa Enerji'',                   N''Enerji''),

    (N''EREGL'', N''Ereğli Demir ve Çelik'',         N''Demir-Çelik''),
    (N''KRDMD'', N''Kardemir'',                      N''Demir-Çelik''),

    (N''KCHOL'', N''Koç Holding'',                   N''Holding''),
    (N''SAHOL'', N''Sabancı Holding'',               N''Holding''),

    (N''BIMAS'', N''BİM Birleşik Mağazalar'',        N''Perakende''),
    (N''MGROS'', N''Migros'',                        N''Perakende''),
    (N''SOKM'',  N''Şok Marketler'',                 N''Perakende''),

    (N''FROTO'', N''Ford Otosan'',                   N''Otomotiv''),
    (N''TOASO'', N''Tofaş Türk Otomobil Fabrikası'', N''Otomotiv''),

    (N''TCELL'', N''Turkcell'',                      N''Telekomünikasyon''),
    (N''TTKOM'', N''Türk Telekom'',                  N''Telekomünikasyon''),

    (N''ULKER'', N''Ülker Bisküvi'',                 N''Gıda ve İçecek''),
    (N''AEFES'', N''Anadolu Efes'',                  N''Gıda ve İçecek''),
    (N''CCOLA'', N''Coca-Cola İçecek'',              N''Gıda ve İçecek''),

    (N''ARCLK'', N''Arçelik'',                       N''Dayanıklı Tüketim''),

    (N''PETKM'', N''Petkim'',                        N''Kimya''),

    (N''SISE'',  N''Şişecam'',                       N''Cam'')
) AS v(Sembol, Sirket, SektorAdi)
JOIN Sektor s ON s.SektorAdi = v.SektorAdi
WHERE NOT EXISTS (SELECT 1 FROM Hisse h WHERE h.Sembol = v.Sembol);

-- Tamamı eğitim amaçlı kurgu veridir. Resmi tatiller modellenmemiştir.
INSERT dbo.Kullanici(KullaniciAdi,Eposta,KayitTarihi) VALUES
(N''deniz_demo'',N''deniz@example.com'',''20260101''),
(N''ece_demo'',N''ece@example.com'',''20260101''),
(N''arda_demo'',N''arda@example.com'',''20260101''),
(N''selin_demo'',N''selin@example.com'',''20260101''),
(N''mert_demo'',N''mert@example.com'',''20260101'');

-- 5 kullanıcının her biri 4 hisseyi takip eder; örtüşen takipler N:N ilişkiyi gösterir.
;WITH H AS (SELECT HisseId,ROW_NUMBER() OVER(ORDER BY Sembol) rn FROM dbo.Hisse),
K AS (SELECT KullaniciId,ROW_NUMBER() OVER(ORDER BY KullaniciAdi) rn FROM dbo.Kullanici)
INSERT dbo.IzlemeListesi(KullaniciId,HisseId,EklenmeTarihi)
SELECT k.KullaniciId,h.HisseId,''20260102'' FROM K k CROSS JOIN H h
WHERE h.rn IN (1,2,k.rn+2,k.rn+7);

-- Pazartesi-cuma günleri. Bunlar gerçek BIST işlem takvimi veya gerçek fiyatlar değildir.
CREATE TABLE #Gun(n int NOT NULL PRIMARY KEY,Tarih date NOT NULL UNIQUE);
;WITH N AS (SELECT 0 n UNION ALL SELECT n+1 FROM N WHERE n<249),
G AS (SELECT DATEADD(day,n,CONVERT(date,''20260105'',112)) Tarih FROM N),
W AS (SELECT Tarih,ROW_NUMBER() OVER(ORDER BY Tarih) n FROM G
WHERE DATEDIFF(day,CONVERT(date,''19000101'',112),Tarih)%7<5)
INSERT #Gun SELECT n,Tarih FROM W WHERE n<=120 OPTION(MAXRECURSION 250);

;WITH H AS (SELECT HisseId,Sembol,ROW_NUMBER() OVER(ORDER BY Sembol) rn FROM dbo.Hisse),
P AS (SELECT HisseId,Sembol,rn,n,Tarih,
CAST(80+rn*7+18*SIN((n+rn*2)*0.09)+0.02*n AS decimal(12,4)) Kapanis
FROM H CROSS JOIN #Gun),
O AS (SELECT *,COALESCE(LAG(Kapanis) OVER(PARTITION BY HisseId ORDER BY n),Kapanis) Acilis FROM P)
INSERT dbo.StagingFiyat(Sembol,Tarih,Acilis,Yuksek,Dusuk,Kapanis,Hacim)
SELECT Sembol,Tarih,Acilis,
CASE WHEN Acilis>Kapanis THEN Acilis ELSE Kapanis END+1.5,
CASE WHEN Acilis<Kapanis THEN Acilis ELSE Kapanis END-1.5,
Kapanis,100000+rn*25000+n*1200 FROM O;

INSERT dbo.FiyatGecmisi(HisseId,Tarih,Acilis,Yuksek,Dusuk,Kapanis,Hacim)
SELECT h.HisseId,s.Tarih,s.Acilis,s.Yuksek,s.Dusuk,s.Kapanis,s.Hacim
FROM dbo.StagingFiyat s JOIN dbo.Hisse h ON h.Sembol=s.Sembol;

-- Tam pencere oluşmadan ortalama yayımlanmaz: ilk 19 SMA20, ilk 49 SMA50 NULL.
;WITH W AS (
SELECT HisseId,Tarih,
COUNT(*) OVER(PARTITION BY HisseId ORDER BY Tarih ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) c20,
COUNT(*) OVER(PARTITION BY HisseId ORDER BY Tarih ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) c50,
AVG(Kapanis) OVER(PARTITION BY HisseId ORDER BY Tarih ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) a20,
AVG(Kapanis) OVER(PARTITION BY HisseId ORDER BY Tarih ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) a50
FROM dbo.FiyatGecmisi)
INSERT dbo.TeknikGosterge(HisseId,Tarih,SMA20,SMA50)
SELECT HisseId,Tarih,CASE WHEN c20=20 THEN a20 END,CASE WHEN c50=50 THEN a50 END FROM W;

-- Strateji: SMA20 yukarı keserse AL, aşağı keserse SAT. Eşitlik önceki günde kabul edilir.
;WITH W AS (SELECT *,
LAG(SMA20) OVER(PARTITION BY HisseId ORDER BY Tarih) p20,
LAG(SMA50) OVER(PARTITION BY HisseId ORDER BY Tarih) p50 FROM dbo.TeknikGosterge)
INSERT dbo.Sinyal(HisseId,Tarih,SinyalTuru)
SELECT HisseId,Tarih,CASE WHEN SMA20>SMA50 THEN N''AL'' ELSE N''SAT'' END
FROM W WHERE (p20<=p50 AND SMA20>SMA50) OR (p20>=p50 AND SMA20<SMA50);

;WITH W AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY HisseId ORDER BY Tarih DESC) rn,
LAG(Kapanis) OVER(PARTITION BY HisseId ORDER BY Tarih) Onceki FROM dbo.FiyatGecmisi)
INSERT dbo.AnlikFiyat(HisseId,SonFiyat,OncekiKapanis,GuncellemeZamani)
SELECT HisseId,Kapanis,Onceki,DATEADD(hour,18,CAST(Tarih AS datetime)) FROM W WHERE rn=1;

-- Her kullanıcı iki farklı hissede alış yapar; bir kısmını daha sonraki gün satar.
-- Bu kayıtlar stratejinin performans testi değil, portföy ilişkisi örnekleridir.
;WITH W AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY KullaniciId ORDER BY HisseId) rn FROM dbo.IzlemeListesi),
T AS (SELECT * FROM (VALUES(60,N''ALIS'',10),(80,N''SATIS'',4)) v(Gun,Tur,Adet))
INSERT dbo.PortfoyIslem(KullaniciId,HisseId,IslemTuru,Adet,Fiyat,IslemZamani)
SELECT w.KullaniciId,w.HisseId,t.Tur,t.Adet,f.Kapanis,DATEADD(hour,18,CAST(g.Tarih AS datetime))
FROM W w CROSS JOIN T t JOIN #Gun g ON g.n=t.Gun
JOIN dbo.FiyatGecmisi f ON f.HisseId=w.HisseId AND f.Tarih=g.Tarih WHERE w.rn<=2;

UPDATE k SET Bakiye=100000+x.Net
FROM dbo.Kullanici k CROSS APPLY(SELECT SUM(CASE WHEN p.IslemTuru=N''ALIS''
THEN -p.Adet*p.Fiyat ELSE p.Adet*p.Fiyat END) Net FROM dbo.PortfoyIslem p
WHERE p.KullaniciId=k.KullaniciId)x;

INSERT dbo.IslemLog(Mesaj,Hata) VALUES
(N''DEMO: 3600 kurgu fiyat kalıcı tabloya aktarıldı.'',NULL),
(N''DEMO: SMA20 ve SMA50 tam pencere kontrolüyle hesaplandı.'',NULL),
(N''DEMO: SMA kesişimlerinden sinyaller hesaplandı.'',NULL),
(N''DEMO: 20 sanal işlem ve kullanıcı bakiyeleri hazırlandı.'',NULL);

COMMIT; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;';
