-- =====================================================================
-- bist hisse takip ve sinyal uygulamasi veritabani taslagim
-- 01_tablolar.sql : tablolari ve baglantilari tanimladigim ddl dosyasi
-- ms sql server üzerinde calisiyorum
-- not: sifirdan kurarken sorun cikmasin diye bistdb varsa silip
--      oyle calistirmak lazim (drop database bistdb)
-- =====================================================================

-- sistemde bistdb adinda veritabani yoksa sifirdan olusturuyorum
IF DB_ID('BistDB') IS NULL
    CREATE DATABASE BistDB;
GO

-- bundan sonraki komutlar bistdb veritabaninda calissin diye adresi buraya cekiyorum
USE BistDB;
GO

-- ---------------------------------------------------------------------
-- tablolar zaten varsa once bagimlilik sirasina gore siliyorum
-- foreign key baglantilari patlamasin diye bagimli tablolari en ustte siliyorum
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS AnlikFiyat;      -- arayuzdeki son fiyat tablosunu siliyorum
DROP TABLE IF EXISTS StagingFiyat;    -- yahoofinance gecici veri alanini siliyorum
DROP TABLE IF EXISTS IslemLog;        -- sistem hata log tablosunu siliyorum
DROP TABLE IF EXISTS PortfoyIslem;    -- sanal alim satim gecmisi tablosunu siliyorum
DROP TABLE IF EXISTS IzlemeListesi;   -- kullanici takipleri tablosunu siliyorum
DROP TABLE IF EXISTS Kullanici;       -- kullanici hesaplari tablosunu siliyorum
DROP TABLE IF EXISTS Sinyal;          -- al/sat sinyalleri tablosunu siliyorum
DROP TABLE IF EXISTS TeknikGosterge;  -- hareketli ortalamalar tablosunu siliyorum
DROP TABLE IF EXISTS FiyatGecmisi;    -- gunluk fiyat gecmisi tablosunu siliyorum
DROP TABLE IF EXISTS Hisse;           -- hisse kütük tablosunu siliyorum
DROP TABLE IF EXISTS Sektor;          -- sektor tablosunu siliyorum
GO

-- ---------------------------------------------------------------------
-- 1. sektor tablosu
-- sektor isimlerini burada tutuyorum, tekrar etmesin diye unique yaptim
-- ---------------------------------------------------------------------
CREATE TABLE Sektor (
    SektorId  INT IDENTITY(1,1) NOT NULL                  -- 1'den baslayip otomatik artan id tanimladim
              CONSTRAINT PK_Sektor PRIMARY KEY,           -- sektor tablosunun birincil anahtari
    SektorAdi NVARCHAR(50) NOT NULL                       -- sektor adi bos kalmasin diye not null attim
              CONSTRAINT UQ_Sektor_SektorAdi UNIQUE       -- ayni sektor ismi iki kere girilmesin diye unique koydum
);
GO

-- ---------------------------------------------------------------------
-- 2. hisse tablosu
-- borsadaki hisseleri ve bagli olduklari sektorleri buraya bagladim
-- ---------------------------------------------------------------------
CREATE TABLE Hisse (
    HisseId   INT IDENTITY(1,1) NOT NULL                  -- her hisseye ozel otomatik id veriyorum
              CONSTRAINT PK_Hisse PRIMARY KEY,            -- hisse tablosunun primary key'i
    Sembol    NVARCHAR(10)  NOT NULL                      -- thyao.is gibi borsa kodlarini tutuyorum
              CONSTRAINT UQ_Hisse_Sembol UNIQUE,          -- ayni hisse kodunu tekrar eklemeyi engelledim
    SirketAdi NVARCHAR(100) NOT NULL,                     -- sirketin tam adini tutuyorum
    SektorId  INT NOT NULL                                -- hissenin hangi sektore ait oldugunu buraya yaziyorum
              CONSTRAINT FK_Hisse_Sektor REFERENCES Sektor(SektorId) -- sektor tablosundaki id ile baglanti kurdum
);
GO

-- ---------------------------------------------------------------------
-- 3. fiyatgecmisi (gunluk fiyat hareketleri)
-- unique(hisseid, tarih) kisitim zaten indeks olusturuyor
-- ilerde indeks performans testini ayri bir tabloyla deneyecegim
-- ---------------------------------------------------------------------
CREATE TABLE FiyatGecmisi (
    FiyatId BIGINT IDENTITY(1,1) NOT NULL                 -- satir sayisi cok artacak diye bigint ile otomatik id verdim
            CONSTRAINT PK_FiyatGecmisi PRIMARY KEY,       -- fiyat tablosunun primary key'i
    HisseId INT NOT NULL                                  -- fiyatın hangi hisseye ait oldugunu tutuyorum
            CONSTRAINT FK_FiyatGecmisi_Hisse REFERENCES Hisse(HisseId), -- hisse tablosuna yabanci anahtar attim
    Tarih   DATE NOT NULL,                                -- verinin ait oldugu gunu tutuyorum
    Acilis  DECIMAL(12,4) NULL,                           -- gunun acilis fiyati
    Yuksek  DECIMAL(12,4) NULL,                           -- gun icindeki en yuksek fiyat
    Dusuk   DECIMAL(12,4) NULL,                           -- gun icindeki en dusuk fiyat
    Kapanis DECIMAL(12,4) NOT NULL                        -- kapanis fiyati mutlaka olmali diye not null yaptim
            CONSTRAINT CK_FiyatGecmisi_Kapanis CHECK (Kapanis > 0), -- kapanis fiyati 0 veya eksi olamaz diye kontrol koydum
    Hacim   BIGINT NULL                                   -- gunluk islem hacmini tutuyorum
            CONSTRAINT CK_FiyatGecmisi_Hacim CHECK (Hacim >= 0), -- hacim negatif olamaz kontrolu ekledim
    CONSTRAINT UQ_FiyatGecmisi_HisseTarih UNIQUE (HisseId, Tarih), -- bir hissenin ayni gun sadece 1 kaydi olsun diye unique yaptim
    CONSTRAINT CK_FiyatGecmisi_YuksekDusuk
        CHECK (Yuksek IS NULL OR Dusuk IS NULL OR Yuksek >= Dusuk)  -- en yuksek fiyat en dusukten kucuk olamaz mantik kontrolu koydum
);
GO

-- ---------------------------------------------------------------------
-- 4. teknikgosterge (hareketli ortalama sonuclari)
-- sma20 ve sma50 gibi hesapladigim ortalamalari tutuyorum
-- ---------------------------------------------------------------------
CREATE TABLE TeknikGosterge (
    GostergeId INT IDENTITY(1,1) NOT NULL                 -- gosterge kayitlari icin otomatik id
               CONSTRAINT PK_TeknikGosterge PRIMARY KEY,   -- teknikgosterge tablosunun birincil anahtari
    HisseId    INT NOT NULL                               -- ortalamanin hangi hisseye ait oldugu
               CONSTRAINT FK_TeknikGosterge_Hisse REFERENCES Hisse(HisseId), -- hisse tablosu baglantisi
    Tarih      DATE NOT NULL,                             -- hesaplamayi yaptigim tarih
    SMA20      DECIMAL(12,4) NULL,                        -- 20 gunluk basit hareketli ortalama sonucu
    SMA50      DECIMAL(12,4) NULL,                        -- 50 gunluk basit hareketli ortalama sonucu
    CONSTRAINT UQ_TeknikGosterge_HisseTarih UNIQUE (HisseId, Tarih) -- her hisse icin gunde 1 tane gosterge kaydi tutuyorum
);
GO

-- ---------------------------------------------------------------------
-- 5. sinyal (al / sat sinyalleri)
-- stratejiden donen al ve sat kararlarini buraya basiyorum
-- ---------------------------------------------------------------------
CREATE TABLE Sinyal (
    SinyalId   INT IDENTITY(1,1) NOT NULL                 -- her sinyal kaydina otomatik id veriyorum
               CONSTRAINT PK_Sinyal PRIMARY KEY,          -- sinyal tablosunun birincil anahtari
    HisseId    INT NOT NULL                               -- sinyal hangi hisseye uretildiyse onun id'si
               CONSTRAINT FK_Sinyal_Hisse REFERENCES Hisse(HisseId), -- hisse tablosuna bagladim
    Tarih      DATE NOT NULL,                             -- sinyalin uretildigi gun
    SinyalTuru NVARCHAR(3) NOT NULL                        -- karari tutuyorum (AL veya SAT)
               CONSTRAINT CK_Sinyal_Turu CHECK (SinyalTuru IN (N'AL', N'SAT')), -- buraya AL veya SAT disinda veri girilmesini engelledim
    CONSTRAINT UQ_Sinyal_HisseTarih UNIQUE (HisseId, Tarih) -- ayni hisseye ayni gun 2 defa sinyal basilmasin diye kisit koydum
);
GO

-- ---------------------------------------------------------------------
-- 6. kullanici tablosu
-- sisteme kayit olan kullanicilari ve baslangic bakiyelerini tanimladim
-- ---------------------------------------------------------------------
CREATE TABLE Kullanici (
    KullaniciId  INT IDENTITY(1,1) NOT NULL               -- kullaniciya ozel otomatik id
                 CONSTRAINT PK_Kullanici PRIMARY KEY,     -- kullanici tablosunun birincil anahtari
    KullaniciAdi NVARCHAR(50)  NOT NULL                   -- kullanicinin sistemdeki rumuzu
                 CONSTRAINT UQ_Kullanici_KullaniciAdi UNIQUE, -- ayni kullanıcı adindan iki tane olmasin diye unique yaptim
    Eposta       NVARCHAR(100) NOT NULL                   -- kullanicinin e-posta adresi
                 CONSTRAINT UQ_Kullanici_Eposta UNIQUE,   -- ayni e-posta ile tekrar kayit olunamasin diye kisit koydum
    Bakiye       DECIMAL(14,2) NOT NULL                   -- sanal bakiye miktarini tutuyorum
                 CONSTRAINT DF_Kullanici_Bakiye DEFAULT 100000 -- yeni kayit olana varsayilan 100 bin tl veriyorum
                 CONSTRAINT CK_Kullanici_Bakiye CHECK (Bakiye >= 0), -- bakiye eksiye dusmesin kontrolu koydum
    KayitTarihi  DATETIME NOT NULL                        -- hesabın acildigi zaman
                 CONSTRAINT DF_Kullanici_KayitTarihi DEFAULT GETDATE() -- tarih verilmezse otomatik o anki zamani atiyorum
);
GO

-- ---------------------------------------------------------------------
-- 7. izlemelistesi (kullanici ve hisse n-n iliskisi)
-- kim hangi hisseleri takibe aldiysa burada esliyorum
-- ---------------------------------------------------------------------
CREATE TABLE IzlemeListesi (
    KullaniciId   INT NOT NULL                            -- takibi yapan kullanicinin id'si
                  CONSTRAINT FK_IzlemeListesi_Kullanici REFERENCES Kullanici(KullaniciId), -- kullanici tablosuna bagladim
    HisseId       INT NOT NULL                            -- takibe alinan hissenin id'si
                  CONSTRAINT FK_IzlemeListesi_Hisse REFERENCES Hisse(HisseId), -- hisse tablosuna bagladim
    EklenmeTarihi DATETIME NOT NULL                       -- takibe alma zamanini tutuyorum
                  CONSTRAINT DF_IzlemeListesi_Eklenme DEFAULT GETDATE(), -- eklenme aninin zamanini otomatik aliyorum
    CONSTRAINT PK_IzlemeListesi PRIMARY KEY (KullaniciId, HisseId) -- bir kullanici bir hisseyi tek bir kez izleme listesine ekleyebilsin diye birlesik pk yaptim
);
GO

-- ---------------------------------------------------------------------
-- 8. portfoyislem (sanal alim satim gecmisi)
-- kullanicilarin sanal ortamda yaptigi islemlerin kayitlari
-- ---------------------------------------------------------------------
CREATE TABLE PortfoyIslem (
    IslemId     INT IDENTITY(1,1) NOT NULL                -- her alim-satim islemine otomatik id veriyorum
                CONSTRAINT PK_PortfoyIslem PRIMARY KEY,    -- portfoyislem tablosunun birincil anahtari
    KullaniciId INT NOT NULL                              -- islemi yapan kullanicinin id'si
                CONSTRAINT FK_PortfoyIslem_Kullanici REFERENCES Kullanici(KullaniciId), -- kullanici tablosuna bagladim
    HisseId     INT NOT NULL                              -- alinan/satilan hissenin id'si
                CONSTRAINT FK_PortfoyIslem_Hisse REFERENCES Hisse(HisseId), -- hisse tablosuna bagladim
    IslemTuru   NVARCHAR(5) NOT NULL                      -- islemin yönü (ALIS veya SATIS)
                CONSTRAINT CK_PortfoyIslem_Turu CHECK (IslemTuru IN (N'ALIS', N'SATIS')), -- sadece ALIS veya SATIS girilebilsin kisiti attim
    Adet        INT NOT NULL                              -- kac lot alindigini veya satildigini tutuyorum
                CONSTRAINT CK_PortfoyIslem_Adet CHECK (Adet > 0), -- eksi veya 0 lot islem yapilamasin diye kontrol koydum
    Fiyat       DECIMAL(12,4) NOT NULL                    -- islem anindaki hisse fiyati
                CONSTRAINT CK_PortfoyIslem_Fiyat CHECK (Fiyat > 0), -- islem fiyati 0 veya eksi olamaz kisiti attim
    IslemZamani DATETIME NOT NULL                         -- islemin gerceklesme zamani
                CONSTRAINT DF_PortfoyIslem_Zaman DEFAULT GETDATE() -- zaman verilmezse otomatik anlik zamani basiyorum
);
GO

-- ---------------------------------------------------------------------
-- 9. islemlog (hata ve sistem loglari)
-- kod tarafinda patlayan yerleri veya loglari rahat izlemek icin kurdum
-- ---------------------------------------------------------------------
CREATE TABLE IslemLog (
    LogId INT IDENTITY(1,1) NOT NULL                      -- log kayitlarina otomatik artan id veriyorum
          CONSTRAINT PK_IslemLog PRIMARY KEY,             -- islemlog tablosunun birincil anahtari
    Zaman DATETIME NOT NULL                               -- hatanin veya logun dustugu an
          CONSTRAINT DF_IslemLog_Zaman DEFAULT GETDATE(), -- otomatik o anki saati basiyorum
    Mesaj NVARCHAR(200) NOT NULL,                         -- yapilan islem veya log aciklamasi
    Hata  NVARCHAR(500) NULL                              -- catch bloguna dusen hatanin detay metnini buraya atiyorum
);
GO

-- ---------------------------------------------------------------------
-- 10. stagingfiyat (yahoofinance aktarim alani)
-- python ile yahoo'dan cekecegim ham verileri once buraya basip sonra isleyecegim
-- esnek tuttum ki aktarim yaparken kisitlamalara takilmayalim
-- ---------------------------------------------------------------------
CREATE TABLE StagingFiyat (
    Sembol  NVARCHAR(10)  NULL,                           -- yahoo'dan gelen hisse sembolu
    Tarih   DATE          NULL,                           -- gelen verinin tarihi
    Acilis  DECIMAL(12,4) NULL,                           -- gelen acilis fiyati
    Yuksek  DECIMAL(12,4) NULL,                           -- gelen en yuksek fiyat
    Dusuk   DECIMAL(12,4) NULL,                           -- gelen en dusuk fiyat
    Kapanis DECIMAL(12,4) NULL,                           -- gelen kapanis fiyati
    Hacim   BIGINT        NULL                            -- gelen hacim verisi
);
GO

-- ---------------------------------------------------------------------
-- 11. anlikfiyat (arayuzde gosterecegim son veriler)
-- hisse tablosuyla 1-1 bagladim, hisseid hem pk hem fk yaptim
-- degisim yuzdesini veritabaninda tutmayip query yazarken hesaplayacagim
-- ---------------------------------------------------------------------
CREATE TABLE AnlikFiyat (
    HisseId          INT NOT NULL                         -- hisse tablosu ile birebir (1-1) iliski kursun diye hisseid'yi alan yaptim
                     CONSTRAINT PK_AnlikFiyat PRIMARY KEY -- hisseid'yi tablonun primary key'i yaptim
                     CONSTRAINT FK_AnlikFiyat_Hisse REFERENCES Hisse(HisseId), -- ayni zamanda hisse tablosuna foreign key attim
    SonFiyat         DECIMAL(12,4) NOT NULL               -- tahtadaki son anlik fiyat
                     CONSTRAINT CK_AnlikFiyat_SonFiyat CHECK (SonFiyat > 0), -- son fiyat 0 veya altında olamaz kisiti koydum
    OncekiKapanis    DECIMAL(12,4) NULL,                  -- bir önceki gunun kapanis fiyati (yuzde degisimi sorguda hesaplayacagim)
    GuncellemeZamani DATETIME NOT NULL                    -- verinin sisteme son aktarildigi an
                     CONSTRAINT DF_AnlikFiyat_Zaman DEFAULT GETDATE() -- guncelleme saatini otomatik atiyorum
);
GO