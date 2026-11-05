-- =====================================================================
-- bist hisse takip ve sinyal uygulamasi veritabani taslagim
-- 01_tablolar.sql : tablolari ve baglantilari tanimladigim ddl dosyasi
-- ms sql server üzerinde calisiyorum
-- not: sifirdan kurarken sorun cikmasin diye bistdb varsa silip
--      oyle calistirmak lazim (drop database bistdb)
-- =====================================================================

IF DB_ID('BistDB') IS NULL
    CREATE DATABASE BistDB;
GO

USE BistDB;
GO

-- ---------------------------------------------------------------------
-- tablolar zaten varsa once bagimlilik sirasina gore siliyorum
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS AnlikFiyat;
DROP TABLE IF EXISTS StagingFiyat;
DROP TABLE IF EXISTS IslemLog;
DROP TABLE IF EXISTS PortfoyIslem;
DROP TABLE IF EXISTS IzlemeListesi;
DROP TABLE IF EXISTS Kullanici;
DROP TABLE IF EXISTS Sinyal;
DROP TABLE IF EXISTS TeknikGosterge;
DROP TABLE IF EXISTS FiyatGecmisi;
DROP TABLE IF EXISTS Hisse;
DROP TABLE IF EXISTS Sektor;
GO

-- ---------------------------------------------------------------------
-- 1. sektor tablosu
-- sektor isimlerini burada tutuyorum, tekrar etmesin diye unique yaptim
-- ---------------------------------------------------------------------
CREATE TABLE Sektor (
    SektorId  INT IDENTITY(1,1) NOT NULL
              CONSTRAINT PK_Sektor PRIMARY KEY,
    SektorAdi NVARCHAR(50) NOT NULL
              CONSTRAINT UQ_Sektor_SektorAdi UNIQUE);
GO

-- ---------------------------------------------------------------------
-- 2. hisse tablosu
-- borsadaki hisseleri ve bagli olduklari sektorleri buraya bagladim
-- ---------------------------------------------------------------------
CREATE TABLE Hisse (
    HisseId   INT IDENTITY(1,1) NOT NULL
              CONSTRAINT PK_Hisse PRIMARY KEY,
    Sembol    NVARCHAR(10)  NOT NULL
              CONSTRAINT UQ_Hisse_Sembol UNIQUE,      -- thyao.is gibi semboller icin
    SirketAdi NVARCHAR(100) NOT NULL,
    SektorId  INT NOT NULL
              CONSTRAINT FK_Hisse_Sektor REFERENCES Sektor(SektorId));
GO

-- ---------------------------------------------------------------------
-- 3. fiyatgecmisi (gunluk fiyat hareketleri)
-- unique(hisseid, tarih) kisitim zaten indeks olusturuyor
-- ilerde indeks performans testini ayri bir tabloyla deneyecegim
-- ---------------------------------------------------------------------
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
        CHECK (Yuksek IS NULL OR Dusuk IS NULL OR Yuksek >= Dusuk));
GO

-- ---------------------------------------------------------------------
-- 4. teknikgosterge (hareketli ortalama sonuclari)
-- sma20 ve sma50 gibi hesapladigim ortalamalari tutuyorum
-- ---------------------------------------------------------------------
CREATE TABLE TeknikGosterge (
    GostergeId INT IDENTITY(1,1) NOT NULL
               CONSTRAINT PK_TeknikGosterge PRIMARY KEY,
    HisseId    INT NOT NULL
               CONSTRAINT FK_TeknikGosterge_Hisse REFERENCES Hisse(HisseId),
    Tarih      DATE NOT NULL,
    SMA20      DECIMAL(12,4) NULL,
    SMA50      DECIMAL(12,4) NULL,
    CONSTRAINT UQ_TeknikGosterge_HisseTarih UNIQUE (HisseId, Tarih));
GO

-- ---------------------------------------------------------------------
-- 5. sinyal (al / sat sinyalleri)
-- stratejiden donen al ve sat kararlarini buraya basiyorum
-- ---------------------------------------------------------------------
CREATE TABLE Sinyal (
    SinyalId   INT IDENTITY(1,1) NOT NULL
               CONSTRAINT PK_Sinyal PRIMARY KEY,
    HisseId    INT NOT NULL
               CONSTRAINT FK_Sinyal_Hisse REFERENCES Hisse(HisseId),
    Tarih      DATE NOT NULL,
    SinyalTuru NVARCHAR(3) NOT NULL
               CONSTRAINT CK_Sinyal_Turu CHECK (SinyalTuru IN (N'AL', N'SAT')),
    CONSTRAINT UQ_Sinyal_HisseTarih UNIQUE (HisseId, Tarih));
GO

-- ---------------------------------------------------------------------
-- 6. kullanici tablosu
-- sisteme kayit olan kullanicilari ve baslangic bakiyelerini tanimladim
-- ---------------------------------------------------------------------
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
                 CONSTRAINT DF_Kullanici_KayitTarihi DEFAULT GETDATE());
GO

-- ---------------------------------------------------------------------
-- 7. izlemelistesi (kullanici ve hisse n-n iliskisi)
-- kim hangi hisseleri takibe aldiysa burada esliyorum
-- ---------------------------------------------------------------------
CREATE TABLE IzlemeListesi (
    KullaniciId   INT NOT NULL
                  CONSTRAINT FK_IzlemeListesi_Kullanici REFERENCES Kullanici(KullaniciId),
    HisseId       INT NOT NULL
                  CONSTRAINT FK_IzlemeListesi_Hisse REFERENCES Hisse(HisseId),
    EklenmeTarihi DATETIME NOT NULL
                  CONSTRAINT DF_IzlemeListesi_Eklenme DEFAULT GETDATE(),
    CONSTRAINT PK_IzlemeListesi PRIMARY KEY (KullaniciId, HisseId));
GO

-- ---------------------------------------------------------------------
-- 8. portfoyislem (sanal alim satim gecmisi)
-- kullanicilarin sanal ortamda yaptigi islemlerin kayitlari
-- ---------------------------------------------------------------------
CREATE TABLE PortfoyIslem (
    IslemId     INT IDENTITY(1,1) NOT NULL
                CONSTRAINT PK_PortfoyIslem PRIMARY KEY,
    KullaniciId INT NOT NULL
                CONSTRAINT FK_PortfoyIslem_Kullanici REFERENCES Kullanici(KullaniciId),
    HisseId     INT NOT NULL
                CONSTRAINT FK_PortfoyIslem_Hisse REFERENCES Hisse(HisseId),
    IslemTuru   NVARCHAR(5) NOT NULL
                CONSTRAINT CK_PortfoyIslem_Turu CHECK (IslemTuru IN (N'ALIS', N'SATIS')),
    Adet        INT NOT NULL
                CONSTRAINT CK_PortfoyIslem_Adet CHECK (Adet > 0),
    Fiyat       DECIMAL(12,4) NOT NULL
                CONSTRAINT CK_PortfoyIslem_Fiyat CHECK (Fiyat > 0),
    IslemZamani DATETIME NOT NULL
                CONSTRAINT DF_PortfoyIslem_Zaman DEFAULT GETDATE());
GO

-- ---------------------------------------------------------------------
-- 9. islemlog (hata ve sistem loglari)
-- kod tarafinda patlayan yerleri veya loglari rahat izlemek icin kurdum
-- ---------------------------------------------------------------------
CREATE TABLE IslemLog (
    LogId INT IDENTITY(1,1) NOT NULL
          CONSTRAINT PK_IslemLog PRIMARY KEY,
    Zaman DATETIME NOT NULL
          CONSTRAINT DF_IslemLog_Zaman DEFAULT GETDATE(),
    Mesaj NVARCHAR(200) NOT NULL,
    Hata  NVARCHAR(500) NULL);
GO

-- ---------------------------------------------------------------------
-- 10. stagingfiyat (yahoofinance aktarim alani)
-- python ile yahoo'dan cekecegim ham verileri once buraya basip sonra isleyecegim
-- ---------------------------------------------------------------------
CREATE TABLE StagingFiyat (
    Sembol  NVARCHAR(10)  NULL,
    Tarih   DATE          NULL,
    Acilis  DECIMAL(12,4) NULL,
    Yuksek  DECIMAL(12,4) NULL,
    Dusuk   DECIMAL(12,4) NULL,
    Kapanis DECIMAL(12,4) NULL,
    Hacim   BIGINT        NULL);
GO

-- ---------------------------------------------------------------------
-- 11. anlikfiyat (arayuzde gosterecegim son veriler)
-- hisse tablosuyla 1-1 bagladim, hisseid hem pk hem fk yaptim
-- degisim yuzdesini veritabaninda tutmayip query yazarken hesaplayacagim
-- ---------------------------------------------------------------------
CREATE TABLE AnlikFiyat (
    HisseId          INT NOT NULL
                     CONSTRAINT PK_AnlikFiyat PRIMARY KEY
                     CONSTRAINT FK_AnlikFiyat_Hisse REFERENCES Hisse(HisseId),
    SonFiyat         DECIMAL(12,4) NOT NULL
                     CONSTRAINT CK_AnlikFiyat_SonFiyat CHECK (SonFiyat > 0),
    OncekiKapanis    DECIMAL(12,4) NULL,
    GuncellemeZamani DATETIME NOT NULL
                     CONSTRAINT DF_AnlikFiyat_Zaman DEFAULT GETDATE());
GO