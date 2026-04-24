"""
OtoParça A.Ş. – Flask Web Uygulaması
Veritabanı: SQLite (otoparca.db)
Çalıştırma: python app.py
Tarayıcı:   http://localhost:5000
"""

import sqlite3
import os
import decimal

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from init_db import init_database

app = Flask(__name__)
app.secret_key = "OtoParca_VTYS_2026_Secret"
app.jinja_env.globals['enumerate'] = enumerate

# ── Veritabanı Yolu ───────────────────────────────────────────
DB_PATH = os.path.join(os.path.dirname(__file__), "otoparca.db")

# Uygulama başlarken DB'yi hazırla
init_database()


def get_connection():
    conn = sqlite3.connect(DB_PATH, timeout=10)  # 10sn bekle, locked hatası azalır
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")   # Eş zamanlı okuma/yazma desteği
    conn.execute("PRAGMA busy_timeout = 10000") # 10sn busy timeout
    return conn


def check_db_connection():
    try:
        conn = get_connection()
        version = conn.execute("SELECT sqlite_version()").fetchone()[0]
        conn.close()
        return True, f"SQLite {version} — Bağlantı başarılı"
    except Exception as e:
        return False, str(e)


def query_db(sql, params=None, fetchall=True):
    conn = get_connection()
    try:
        cursor = conn.execute(sql, params or [])
        columns = [col[0] for col in cursor.description]
        if fetchall:
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
        else:
            row = cursor.fetchone()
            rows = dict(zip(columns, row)) if row else None
        return rows
    finally:
        conn.close()  # Hata olsa da bağlantıyı kapat


def execute_db(sql, params=None):
    conn = get_connection()
    try:
        conn.execute(sql, params or [])
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()  # Hata olsa da bağlantıyı kapat


# ===========================================================================
# ANA EKRAN
# ===========================================================================
@app.route("/")
def index():
    connected, db_info = check_db_connection()
    stats = {}
    if connected:
        try:
            stats["musteri"]     = query_db("SELECT COUNT(*) AS n FROM Musteri")[0]["n"]
            stats["urun"]        = query_db("SELECT COUNT(*) AS n FROM Urun")[0]["n"]
            stats["siparis"]     = query_db("SELECT COUNT(*) AS n FROM Siparis")[0]["n"]
            stats["bekleyen"]    = query_db("SELECT COUNT(*) AS n FROM Siparis WHERE Durum='Beklemede'")[0]["n"]
            stats["kritik_stok"] = query_db(
                "SELECT COUNT(*) AS n FROM vw_StokDurumu WHERE StokDurumu IN ('Tükendi','Kritik')"
            )[0]["n"]
            stats["bugun_ciro"]  = query_db(
                "SELECT COALESCE(SUM(ToplamTutar),0) AS n FROM Siparis "
                "WHERE date(SiparisTarihi) = date('now','localtime')"
            )[0]["n"]
        except Exception:
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
             request.form["telefon"], request.form.get("adres", "")]
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
             request.form["telefon"], request.form.get("adres", ""),
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
        except Exception:
            pass
        try:
            kategoriler       = query_db("SELECT * FROM Kategori ORDER BY KategoriAdi")
            tedarikci_listesi = query_db("SELECT * FROM Tedarikci WHERE AktifMi=1 ORDER BY FirmaAdi")
        except Exception:
            pass
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
            kayitlar = query_db("SELECT * FROM vw_SonSiparisler LIMIT 50")
        except Exception:
            pass
        try:
            musteriler_list = query_db("SELECT MusteriID, AdSoyad FROM Musteri ORDER BY AdSoyad")
        except Exception:
            pass
    return render_template("siparisler.html", kayitlar=kayitlar,
                           musteriler=musteriler_list, connected=connected)


@app.route("/siparis/durum", methods=["POST"])
def siparis_durum():
    try:
        execute_db(
            "UPDATE Siparis SET Durum=? WHERE SiparisID=?",
            [request.form["yeni_durum"], request.form["siparis_id"]]
        )
        flash("✅ Sipariş durumu güncellendi!", "success")
    except Exception as e:
        flash(f"❌ Hata: {e}", "danger")
    return redirect(url_for("siparisler"))


# ===========================================================================
# RAPORLAR
# ===========================================================================
@app.route("/raporlar")
def raporlar():
    connected, _ = check_db_connection()
    r1, r2, r3, r4 = [], [], [], []
    if connected:
        # Rapor 1: En çok satan 5 ürün
        try:
            r1 = query_db("""
                SELECT
                    u.UrunID, u.UrunKodu, u.OemKodu, u.UrunAdi,
                    k.KategoriAdi              AS Kategori,
                    u.SatisFiyati              AS "Satış Fiyatı (₺)",
                    SUM(sd.Miktar)             AS "Toplam Satış Adedi",
                    SUM(sd.AraToplam)          AS "Toplam Ciro (₺)",
                    COUNT(DISTINCT sd.SiparisID) AS "Sipariş Sayısı"
                FROM SiparisDetay sd
                JOIN Urun     u ON sd.UrunID    = u.UrunID
                JOIN Kategori k ON u.KategoriID = k.KategoriID
                GROUP BY u.UrunID, u.UrunKodu, u.OemKodu, u.UrunAdi, k.KategoriAdi, u.SatisFiyati
                ORDER BY "Toplam Satış Adedi" DESC
                LIMIT 5
            """)
        except Exception:
            pass

        # Rapor 2: Aylık ciro özeti
        try:
            r2 = query_db(
                "SELECT * FROM vw_AylikCiroOzeti ORDER BY Yil DESC, Ay DESC"
            )
        except Exception:
            pass

        # Rapor 3: Kritik stok
        try:
            r3 = query_db("""
                SELECT * FROM vw_StokDurumu
                WHERE StokDurumu IN ('Tükendi','Kritik')
                ORDER BY StokMiktari
            """)
        except Exception:
            pass

        # Rapor 4: Son siparişler
        try:
            r4 = query_db("SELECT * FROM vw_SonSiparisler LIMIT 20")
        except Exception:
            pass

    return render_template("raporlar.html", r1=r1, r2=r2, r3=r3, r4=r4, connected=connected)


# ===========================================================================
# API
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
        detaylar = query_db(
            "SELECT * FROM vw_SiparisDetayli WHERE SiparisID = ?", [siparis_id]
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

    # Decimal varsa float'a çevir
    for d in detaylar:
        for k, v in d.items():
            if isinstance(v, decimal.Decimal):
                d[k] = float(v)

    return jsonify({"success": True, "data": detaylar})


# ===========================================================================
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print("=" * 55)
    print("  OtoParça A.Ş. – Yönetim Sistemi")
    print(f"  Adres: http://localhost:{port}")
    print("=" * 55)
    app.run(debug=False, host="0.0.0.0", port=port)
