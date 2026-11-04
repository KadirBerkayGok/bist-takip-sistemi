-- =====================================================================
-- BIST Hisse Senedi Takip ve Al/Sat Sinyal Uretimi Web Uygulamasi
-- 01_tablolar.sql : Veritabani ve tablolarin olusturulmasi (DDL)
-- Veritabani: Microsoft SQL Server
-- Not: Bu betik bir kez calistirilir. Tekrar calistirmak icin once
--      BistDB veritabanini silin (DROP DATABASE BistDB).
-- =====================================================================

IF DB_ID('BistDB') IS NULL
    CREATE DATABASE BistDB;
GO

USE BistDB;
GO

-- ---------------------------------------------------------------------
-- 1. Sektor
-- ---------------------------------------------------------------------
CREATE TABLE Sektor (
    SektorId  INT IDENTITY(1,1) NOT NULL
              CONSTRAINT PK_Sektor PRIMARY KEY,
    SektorAdi NVARCHAR(50) NOT NULL
              CONSTRAINT UQ_Sektor_SektorAdi UNIQUE
);
GO

-- ---------------------------------------------------------------------
-- 2. Hisse
-- ---------------------------------------------------------------------
CREATE TABLE Hisse (
    HisseId   INT IDENTITY(1,1) NOT NULL
              CONSTRAINT PK_Hisse PRIMARY KEY,
    Sembol    NVARCHAR(10)  NOT NULL
              CONSTRAINT UQ_Hisse_Sembol UNIQUE,      -- ornek: THYAO.IS
    SirketAdi NVARCHAR(100) NOT NULL,
    SektorId  INT NOT NULL
              CONSTRAINT FK_Hisse_Sektor REFERENCES Sektor(SektorId)
);
GO

-- ---------------------------------------------------------------------
-- 3. FiyatGecmisi (gunluk fiyatlar)
-- Not: UNIQUE (HisseId, Tarih) kisiti otomatik indeks olusturur.
--      Indeks performans testini ileride ayri bir tabloyla yapacagiz.
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
        CHECK (Yuksek IS NULL OR Dusuk IS NULL OR Yuksek >= Dusuk)
);
GO

-- ---------------------------------------------------------------------
-- 4. TeknikGosterge (hesaplanan hareketli ortalamalar)
-- ---------------------------------------------------------------------
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
GO

-- ---------------------------------------------------------------------
-- 5. Sinyal (AL / SAT)
-- ---------------------------------------------------------------------
CREATE TABLE Sinyal (
    SinyalId   INT IDENTITY(1,1) NOT NULL
               CONSTRAINT PK_Sinyal PRIMARY KEY,
    HisseId    INT NOT NULL
               CONSTRAINT FK_Sinyal_Hisse REFERENCES Hisse(HisseId),
    Tarih      DATE NOT NULL,
    SinyalTuru NVARCHAR(3) NOT NULL
               CONSTRAINT CK_Sinyal_Turu CHECK (SinyalTuru IN (N'AL', N'SAT')),
    CONSTRAINT UQ_Sinyal_HisseTarih UNIQUE (HisseId, Tarih)
);
GO

-- ---------------------------------------------------------------------
-- 6. Kullanici
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
                 CONSTRAINT DF_Kullanici_KayitTarihi DEFAULT GETDATE()
);
GO

-- ---------------------------------------------------------------------
-- 7. IzlemeListesi (Kullanici <-> Hisse, cok-cok iliski)
-- ---------------------------------------------------------------------
CREATE TABLE IzlemeListesi (
    KullaniciId   INT NOT NULL
                  CONSTRAINT FK_IzlemeListesi_Kullanici REFERENCES Kullanici(KullaniciId),
    HisseId       INT NOT NULL
                  CONSTRAINT FK_IzlemeListesi_Hisse REFERENCES Hisse(HisseId),
    EklenmeTarihi DATETIME NOT NULL
                  CONSTRAINT DF_IzlemeListesi_Eklenme DEFAULT GETDATE(),
    CONSTRAINT PK_IzlemeListesi PRIMARY KEY (KullaniciId, HisseId)
);
GO

-- ---------------------------------------------------------------------
-- 8. PortfoyIslem (sanal alim / satim kayitlari)
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
                CONSTRAINT DF_PortfoyIslem_Zaman DEFAULT GETDATE()
);
GO

-- ---------------------------------------------------------------------
-- 9. IslemLog (sistem gunlugu)
-- ---------------------------------------------------------------------
CREATE TABLE IslemLog (
    LogId INT IDENTITY(1,1) NOT NULL
          CONSTRAINT PK_IslemLog PRIMARY KEY,
    Zaman DATETIME NOT NULL
          CONSTRAINT DF_IslemLog_Zaman DEFAULT GETDATE(),
    Mesaj NVARCHAR(200) NOT NULL,
    Hata  NVARCHAR(500) NULL
);
GO

-- ---------------------------------------------------------------------
-- 10. StagingFiyat (Yahoo verisinin gecici duragi, kisitsiz ham veri)
-- ---------------------------------------------------------------------
CREATE TABLE StagingFiyat (
    Sembol  NVARCHAR(10)  NULL,
    Tarih   DATE          NULL,
    Acilis  DECIMAL(12,4) NULL,
    Yuksek  DECIMAL(12,4) NULL,
    Dusuk   DECIMAL(12,4) NULL,
    Kapanis DECIMAL(12,4) NULL,
    Hacim   BIGINT        NULL
);
GO

-- ---------------------------------------------------------------------
-- 11. AnlikFiyat (her hissenin en son bilinen fiyati - canli liste icin)
-- Hisse ile 1-1 iliski: HisseId hem PK hem FK.
-- Degisim yuzdesi saklanmaz, sorguda hesaplanir (tekrar bilgi olmasin).
-- ---------------------------------------------------------------------
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
GO
