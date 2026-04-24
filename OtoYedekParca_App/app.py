"""
OtoParça A.Ş. – Flask Web Uygulaması
Veritabanı: OtoYedekParcaDB (MS SQL Server)
Çalıştırma: python app.py
Tarayıcı:   http://localhost:5000
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
import pyodbc
import os

app = Flask(__name__)
app.secret_key = "OtoParca_VTYS_2026_Secret"
app.jinja_env.globals['enumerate'] = enumerate  # Jinja2'de enumerate kullanımı için

# ── Bağlantı Ayarları ──────────────────────────────────────────────────────
# Eğer bağlantı hata verirse aşağıdaki SERVER değerini değiştirin:
#   → Sadece SQL Server (varsayılan):  "localhost"
#   → SQL Server Express:              r"localhost\SQLEXPRESS"   veya  r".\SQLEXPRESS"
#   → Özel instance:                   r"BILGISAYAR_ADI\SQLEXPRESS"
SERVER   = r"."                  # SQL Server 2025 — instance adı: nokta (.)
DATABASE = "OtoYedekParcaDB"

# ODBC Driver 18 (SQL Server 2025 için önerilir)
# Hata alırsanız "ODBC Driver 17 for SQL Server" yazın
def _build_conn_str(driver):
    return (
        f"DRIVER={{{driver}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )

CONN_STR = _build_conn_str("ODBC Driver 18 for SQL Server")


def get_connection():
    """Veritabanı bağlantısı döndürür. Driver 18 yoksa 17'yi dener."""
    try:
        return pyodbc.connect(CONN_STR, timeout=5)
    except pyodbc.Error:
        # Fallback: ODBC Driver 17
        return pyodbc.connect(_build_conn_str("ODBC Driver 17 for SQL Server"), timeout=5)

def check_db_connection():
    """Bağlantı durumunu döndürür: (True/False, mesaj)"""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()[0].split('\n')[0]
        conn.close()
        return True, version
    except Exception as e:
        return False, str(e)

def query_db(sql, params=None, fetchall=True):
    """SELECT sorgusu çalıştır, sonuç döndür."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(sql, params or [])
    columns = [col[0] for col in cursor.description]
    if fetchall:
        rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    else:
        row = cursor.fetchone()
        rows = dict(zip(columns, row)) if row else None
    conn.close()
    return rows

def execute_db(sql, params=None):
    """INSERT/UPDATE/DELETE çalıştır."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(sql, params or [])
    conn.commit()
    conn.close()

# ===========================================================================
# ANA EKRAN
# ===========================================================================
@app.route("/")
def index():
    connected, db_info = check_db_connection()
    stats = {}
    if connected:
        try:
            stats["musteri"]      = query_db("SELECT COUNT(*) AS n FROM Musteri")[0]["n"]
            stats["urun"]         = query_db("SELECT COUNT(*) AS n FROM Urun")[0]["n"]
            stats["siparis"]      = query_db("SELECT COUNT(*) AS n FROM Siparis")[0]["n"]
            stats["bekleyen"]     = query_db("SELECT COUNT(*) AS n FROM Siparis WHERE Durum='Beklemede'")[0]["n"]
            stats["kritik_stok"]  = query_db("SELECT COUNT(*) AS n FROM vw_StokDurumu WHERE StokDurumu IN ('Tükendi','Kritik')")[0]["n"]
            stats["bugun_ciro"]   = query_db("""
                SELECT ISNULL(SUM(ToplamTutar),0) AS n FROM Siparis
                WHERE CAST(SiparisTarihi AS DATE) = CAST(GETDATE() AS DATE)
            """)[0]["n"]
        except:
            pass
    return render_template("index.html", connected=connected, db_info=db_info, stats=stats)

# ===========================================================================
# MÜŞTERİLER
# ===========================================================================
@app.route("/musteriler")
def musteriler():
    connected, _ = check_db_connection()
    kayitlar = []
    if connected:
        kayitlar = query_db("SELECT * FROM Musteri ORDER BY MusteriID DESC")
    return render_template("musteriler.html", kayitlar=kayitlar, connected=connected)

@app.route("/musteri/ekle", methods=["POST"])
def musteri_ekle():
    try:
        execute_db(
            "INSERT INTO Musteri (AdSoyad, Email, Telefon, Adres) VALUES (?,?,?,?)",
            [request.form["adsoyad"], request.form["email"],
             request.form["telefon"], request.form.get("adres","")]
        )
        flash("✅ Müşteri başarıyla eklendi!", "success")
    except Exception as e:
        flash(f"❌ Hata: {e}", "danger")
    return redirect(url_for("musteriler"))

@app.route("/musteri/guncelle", methods=["POST"])
def musteri_guncelle():
    try:
        execute_db(
            "UPDATE Musteri SET AdSoyad=?, Email=?, Telefon=?, Adres=? WHERE MusteriID=?",
            [request.form["adsoyad"], request.form["email"],
             request.form["telefon"], request.form.get("adres",""),
             request.form["musteri_id"]]
        )
        flash("✅ Müşteri güncellendi!", "success")
    except Exception as e:
        flash(f"❌ Hata: {e}", "danger")
    return redirect(url_for("musteriler"))

@app.route("/musteri/sil/<int:musteri_id>")
def musteri_sil(musteri_id):
    try:
        execute_db("DELETE FROM Musteri WHERE MusteriID=?", [musteri_id])
        flash("🗑️ Müşteri silindi.", "warning")
    except Exception as e:
        flash(f"❌ Hata: Müşteriye ait sipariş kaydı mevcut olabilir. {e}", "danger")
    return redirect(url_for("musteriler"))

# ===========================================================================
# ÜRÜNLER
# ===========================================================================
@app.route("/urunler")
def urunler():
    connected, _ = check_db_connection()
    kayitlar, kategoriler, tedarikci_listesi = [], [], []
    if connected:
        try:
            kayitlar = query_db("SELECT * FROM vw_StokDurumu ORDER BY UrunID")
        except:
            # VIEW henüz oluşturulmadıysa doğrudan tablo sorgusu
            try:
                kayitlar = query_db("""
                    SELECT u.UrunID, u.UrunKodu, u.OemKodu, u.UrunAdi, u.AracModeli,
                           k.KategoriAdi, t.FirmaAdi AS TedarikciAdi,
                           u.StokMiktari, u.AlisFiyati, u.SatisFiyati,
                           (u.SatisFiyati - u.AlisFiyati) AS KarMarji,
                           CASE WHEN u.StokMiktari = 0  THEN N'Tükendi'
                                WHEN u.StokMiktari < 5  THEN N'Kritik'
                                WHEN u.StokMiktari < 15 THEN N'Düşük'
                                ELSE N'Yeterli' END AS StokDurumu,
                           ISNULL(sat.ToplamSatisAdedi, 0) AS ToplamSatisAdedi
                    FROM Urun u
                    JOIN Kategori   k ON u.KategoriID  = k.KategoriID
                    JOIN Tedarikci  t ON u.TedarikciID = t.TedarikciID
                    LEFT JOIN (
                        SELECT UrunID, SUM(Miktar) AS ToplamSatisAdedi
                        FROM SiparisDetay GROUP BY UrunID
                    ) sat ON sat.UrunID = u.UrunID
                    ORDER BY u.UrunID
                """)
            except: pass
        try:
            kategoriler       = query_db("SELECT * FROM Kategori ORDER BY KategoriAdi")
            tedarikci_listesi = query_db("SELECT * FROM Tedarikci WHERE AktifMi=1 ORDER BY FirmaAdi")
        except: pass
    return render_template("urunler.html", kayitlar=kayitlar,
                           kategoriler=kategoriler, tedarikciler=tedarikci_listesi,
                           connected=connected)

@app.route("/urun/ekle", methods=["POST"])
def urun_ekle():
    try:
        execute_db(
            """INSERT INTO Urun (KategoriID, TedarikciID, UrunAdi, UrunKodu, OemKodu,
               AracModeli, StokMiktari, AlisFiyati, SatisFiyati)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            [request.form["kategori_id"], request.form["tedarikci_id"],
             request.form["urun_adi"], request.form["urun_kodu"],
             request.form.get("oem_kodu", ""),
             request.form.get("arac_modeli", ""),
             request.form["stok_miktari"],
             request.form["alis_fiyati"], request.form["satis_fiyati"]]
        )
        flash("✅ Ürün eklendi!", "success")
    except Exception as e:
        flash(f"❌ Hata: {e}", "danger")
    return redirect(url_for("urunler"))

# ===========================================================================
# SİPARİŞLER
# ===========================================================================
@app.route("/siparisler")
def siparisler():
    connected, _ = check_db_connection()
    kayitlar, musteriler_list = [], []
    if connected:
        try:
            kayitlar = query_db("SELECT * FROM vw_SonSiparisler")
        except:
            # VIEW henüz oluşturulmadıysa doğrudan tablo sorgusu
            try:
                kayitlar = query_db("""
                    SELECT TOP 20
                        s.SiparisID,
                        m.AdSoyad  AS MusteriAdi,
                        s.SiparisTarihi,
                        s.Durum,
                        s.ToplamTutar
                    FROM Siparis s
                    JOIN Musteri m ON s.MusteriID = m.MusteriID
                    ORDER BY s.SiparisTarihi DESC
                """)
            except: pass
        try:
            musteriler_list = query_db("SELECT MusteriID, AdSoyad FROM Musteri ORDER BY AdSoyad")
        except: pass
    return render_template("siparisler.html", kayitlar=kayitlar,
                           musteriler=musteriler_list, connected=connected)

@app.route("/siparis/durum", methods=["POST"])
def siparis_durum():
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("EXEC sp_SiparisDurumGuncelle @SiparisID=?, @YeniDurum=?",
                       [request.form["siparis_id"], request.form["yeni_durum"]])
        conn.commit()
        conn.close()
        flash("✅ Sipariş durumu güncellendi!", "success")
    except Exception as e:
        flash(f"❌ Hata: {e}", "danger")
    return redirect(url_for("siparisler"))

# ===========================================================================
# RAPORLAR — Sayfa açıldığında otomatik yüklenir
# ===========================================================================
@app.route("/raporlar")
def raporlar():
    connected, _ = check_db_connection()
    r1, r2, r3, r4 = [], [], [], []
    if connected:
        # Rapor 1: En çok satan 5 ürün — SP yoksa doğrudan sorgu
        try:
            conn   = get_connection()
            cursor = conn.cursor()
            cursor.execute("EXEC sp_EnCokSatanUrunler @TopN=5")
            cols = [c[0] for c in cursor.description]
            r1   = [dict(zip(cols, row)) for row in cursor.fetchall()]
            conn.close()
        except:
            try:
                r1 = query_db("""
                    SELECT TOP 5
                        u.UrunID, u.UrunKodu, u.OemKodu, u.UrunAdi,
                        k.KategoriAdi             AS Kategori,
                        u.SatisFiyati             AS [Satış Fiyatı (₺)],
                        SUM(sd.Miktar)            AS [Toplam Satış Adedi],
                        SUM(sd.AraToplam)         AS [Toplam Ciro (₺)],
                        COUNT(DISTINCT sd.SiparisID) AS [Sipariş Sayısı]
                    FROM SiparisDetay sd
                    JOIN Urun     u ON sd.UrunID    = u.UrunID
                    JOIN Kategori k ON u.KategoriID = k.KategoriID
                    GROUP BY u.UrunID, u.UrunKodu, u.OemKodu, u.UrunAdi, k.KategoriAdi, u.SatisFiyati
                    ORDER BY [Toplam Satış Adedi] DESC
                """)
            except: pass

        # Rapor 2: Aylık ciro özeti — VIEW yoksa doğrudan sorgu
        try:
            r2 = query_db("SELECT * FROM vw_AylikCiroOzeti ORDER BY Yil DESC, Ay DESC")
        except:
            try:
                r2 = query_db("""
                    SELECT
                        YEAR(s.SiparisTarihi)         AS Yil,
                        MONTH(s.SiparisTarihi)        AS Ay,
                        DATENAME(MONTH,s.SiparisTarihi) AS AyAdi,
                        COUNT(DISTINCT s.SiparisID)   AS SiparisSayisi,
                        SUM(sd.AraToplam)             AS ToplamCiro,
                        AVG(s.ToplamTutar)            AS OrtSiparisTutari,
                        COUNT(DISTINCT s.MusteriID)   AS AktifMusteriSayisi
                    FROM Siparis s
                    JOIN SiparisDetay sd ON sd.SiparisID = s.SiparisID
                    WHERE s.Durum <> N'İptal'
                    GROUP BY YEAR(s.SiparisTarihi), MONTH(s.SiparisTarihi),
                             DATENAME(MONTH,s.SiparisTarihi)
                    ORDER BY Yil DESC, Ay DESC
                """)
            except: pass

        # Rapor 3: Kritik stok — VIEW yoksa doğrudan sorgu
        try:
            r3 = query_db("""
                SELECT * FROM vw_StokDurumu
                WHERE StokDurumu IN (N'Tükendi', N'Kritik')
                ORDER BY StokMiktari
            """)
        except:
            try:
                r3 = query_db("""
                    SELECT u.UrunKodu, u.OemKodu, u.UrunAdi, k.KategoriAdi,
                           t.FirmaAdi AS TedarikciAdi, u.StokMiktari,
                           CASE WHEN u.StokMiktari = 0 THEN N'Tükendi'
                                ELSE N'Kritik' END AS StokDurumu
                    FROM Urun u
                    JOIN Kategori k  ON u.KategoriID  = k.KategoriID
                    JOIN Tedarikci t ON u.TedarikciID = t.TedarikciID
                    WHERE u.StokMiktari < 5
                    ORDER BY u.StokMiktari
                """)
            except: pass

        # Rapor 4: Son siparişler — VIEW yoksa doğrudan sorgu
        try:
            r4 = query_db("SELECT * FROM vw_SonSiparisler")
        except:
            try:
                r4 = query_db("""
                    SELECT TOP 20 s.SiparisID,
                           m.AdSoyad AS MusteriAdi,
                           s.SiparisTarihi, s.Durum, s.ToplamTutar
                    FROM Siparis s
                    JOIN Musteri m ON s.MusteriID = m.MusteriID
                    ORDER BY s.SiparisTarihi DESC
                """)
            except: pass

    return render_template("raporlar.html", r1=r1, r2=r2, r3=r3, r4=r4, connected=connected)

# ===========================================================================
# API — Bağlantı durumu (JSON)
# ===========================================================================
@app.route("/api/baglantiDurumu")
def api_baglanti():
    connected, msg = check_db_connection()
    return jsonify({"connected": connected, "message": msg})

@app.route("/api/siparis_detay/<int:siparis_id>")
def api_siparis_detay(siparis_id):
    connected, _ = check_db_connection()
    if not connected:
        return jsonify({"success": False, "error": "Veritabanı bağlantısı yok."})
    
    try:
        # Önce SiparisDetayli VIEW'ı deniyoruz (OemKodu içeren güncel haliyle)
        detaylar = query_db("SELECT * FROM vw_SiparisDetayli WHERE SiparisID = ?", [siparis_id])
    except:
        # VIEW yoksa fallback sorgu (OemKodu dahil)
        try:
            detaylar = query_db("""
                SELECT 
                    sd.DetayID,
                    u.UrunKodu,
                    u.OemKodu,
                    u.UrunAdi,
                    sd.Miktar,
                    sd.BirimFiyat,
                    sd.AraToplam
                FROM SiparisDetay sd
                JOIN Urun u ON u.UrunID = sd.UrunID
                WHERE sd.SiparisID = ?
            """, [siparis_id])
        except Exception as e:
            return jsonify({"success": False, "error": str(e)})

    # PyODBC Decimal objeleri jsonify'ı çökertir, float'a çeviriyoruz
    import decimal
    for d in detaylar:
        for k, v in d.items():
            if isinstance(v, decimal.Decimal):
                d[k] = float(v)

    return jsonify({"success": True, "data": detaylar})

# ===========================================================================
if __name__ == "__main__":
    print("="*55)
    print("  OtoParça A.Ş. – Yönetim Sistemi")
    print("  Adres: http://localhost:5000")
    print("="*55)
    app.run(debug=True, host="0.0.0.0", port=5000)
